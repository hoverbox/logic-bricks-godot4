@tool
extends GraphEdit

const LiveDebugOverlay = preload("res://addons/logic_bricks/ui/logic_graph_debug_overlay.gd")

## GraphEdit with switchable connection routing for Logic Bricks.
## Bezier uses Godot's native GraphEdit rendering. Stepped reshapes the
## native Line2D connection visuals after GraphEdit updates them.
var connection_style: String = "bezier"
var _native_line_points: Dictionary = {}
var _state_filter_active: bool = false
var _live_debug_active_nodes: Dictionary = {}
var _live_debug_overlay: Control = null


func _ready() -> void:
	set_process(true)
	_live_debug_overlay = LiveDebugOverlay.new()
	_live_debug_overlay.name = "LogicBricksLiveDebugOverlay"
	_live_debug_overlay.z_index = 100
	add_child(_live_debug_overlay)
	_live_debug_overlay.call("setup", self)
	move_child(_live_debug_overlay, get_child_count() - 1)


func set_connection_style(style: String) -> void:
	var normalized := "stepped" if style == "stepped" else "bezier"
	if normalized == connection_style:
		return

	if normalized == "bezier":
		_restore_native_connection_lines()

	connection_style = normalized
	if connection_style == "stepped":
		call_deferred("_apply_stepped_connections")
	queue_redraw()


func _process(_delta: float) -> void:
	if connection_style == "stepped":
		_apply_stepped_connections()
	if _state_filter_active:
		_apply_connection_visibility()


func set_state_filter_active(active: bool) -> void:
	_state_filter_active = active
	_apply_connection_visibility()


func _apply_connection_visibility() -> void:
	var layer := get_node_or_null(NodePath("_connection_layer"))
	if layer == null:
		return
	var lines: Array[Line2D] = []
	for child in layer.get_children():
		if child is Line2D and not child.is_queued_for_deletion():
			lines.append(child)
	var connections := get_connection_list()
	# Native GraphEdit creates one Line2D per connection, in insertion order.
	# Hide only the visuals: the connection list must remain intact for saving,
	# code generation, and restoring the All view.
	if lines.size() != connections.size():
		return
	for index in range(connections.size()):
		var connection: Dictionary = connections[index]
		var from_node := get_node_or_null(NodePath(connection["from_node"]))
		var to_node := get_node_or_null(NodePath(connection["to_node"]))
		lines[index].visible = not _state_filter_active or (from_node is GraphNode and to_node is GraphNode and not bool(from_node.get_meta("logic_bricks_state_filter_hidden", false)) and not bool(to_node.get_meta("logic_bricks_state_filter_hidden", false)))


func _apply_stepped_connections() -> void:
	var layer := get_node_or_null(NodePath("_connection_layer"))
	if layer == null:
		return

	for child in layer.get_children():
		if not (child is Line2D):
			continue
		var line := child as Line2D
		var points := line.points
		if points.size() < 2:
			continue

		var line_id := line.get_instance_id()
		# Native GraphEdit curves normally contain more than four points. Cache
		# them whenever Godot refreshes the connection so Bezier can be restored.
		if not _native_line_points.has(line_id) or points.size() != 4:
			_native_line_points[line_id] = points.duplicate()

		var from_position: Vector2 = points[0]
		var to_position: Vector2 = points[points.size() - 1]
		var mid_x: float = (from_position.x + to_position.x) * 0.5
		line.points = PackedVector2Array([
			from_position,
			Vector2(mid_x, from_position.y),
			Vector2(mid_x, to_position.y),
			to_position,
		])


func _restore_native_connection_lines() -> void:
	var layer := get_node_or_null(NodePath("_connection_layer"))
	if layer == null:
		_native_line_points.clear()
		return

	for child in layer.get_children():
		if not (child is Line2D):
			continue
		var line := child as Line2D
		var line_id := line.get_instance_id()
		if _native_line_points.has(line_id):
			line.points = _native_line_points[line_id]
	_native_line_points.clear()


func get_closest_visual_connection_at_point(point: Vector2, max_distance: float = 10.0) -> Dictionary:
	if connection_style != "stepped":
		var connection := get_closest_connection_at_point(point, max_distance)
		if not connection.is_empty() and (_get_port_position(connection["from_node"], int(connection["from_port"]), true) == null or _get_port_position(connection["to_node"], int(connection["to_port"]), false) == null):
			return {}
		return connection

	var closest: Dictionary = {}
	var closest_distance := max_distance
	for connection in get_connection_list():
		var from_position_variant: Variant = _get_port_position(connection["from_node"], int(connection["from_port"]), true)
		var to_position_variant: Variant = _get_port_position(connection["to_node"], int(connection["to_port"]), false)
		if from_position_variant == null or to_position_variant == null:
			continue
		var from_position: Vector2 = from_position_variant as Vector2
		var to_position: Vector2 = to_position_variant as Vector2

		var mid_x: float = (from_position.x + to_position.x) * 0.5
		var bend_a: Vector2 = Vector2(mid_x, from_position.y)
		var bend_b: Vector2 = Vector2(mid_x, to_position.y)
		var distance: float = minf(
			_point_to_segment_distance(point, from_position, bend_a),
			minf(
				_point_to_segment_distance(point, bend_a, bend_b),
				_point_to_segment_distance(point, bend_b, to_position)
			)
		)
		if distance < closest_distance:
			closest_distance = distance
			closest = connection
	return closest


func _get_port_position(node_name: StringName, port_index: int, output: bool) -> Variant:
	var node := get_node_or_null(NodePath(node_name))
	if not (node is GraphNode) or not node.visible or bool(node.get_meta("logic_bricks_state_filter_hidden", false)):
		return null
	var graph_node := node as GraphNode
	if output and (port_index < 0 or port_index >= graph_node.get_output_port_count()):
		return null
	if not output and (port_index < 0 or port_index >= graph_node.get_input_port_count()):
		return null

	var local_position := graph_node.get_output_port_position(port_index) if output else graph_node.get_input_port_position(port_index)
	var canvas_position := graph_node.get_global_transform_with_canvas() * local_position
	return get_global_transform_with_canvas().affine_inverse() * canvas_position


func _point_to_segment_distance(point: Vector2, segment_a: Vector2, segment_b: Vector2) -> float:
	var segment := segment_b - segment_a
	var length_squared := segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_to(segment_a)
	var t := clampf((point - segment_a).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(segment_a + segment * t)


## Editor-only Live Debug visualization ---------------------------------------
## The runtime sends a low-frequency list of active brick IDs. The GraphEdit
## uses that state to animate dots locally along active connections.
func set_live_debug_active_nodes(brick_ids: Array) -> void:
	_live_debug_active_nodes.clear()
	for brick_id in brick_ids:
		_live_debug_active_nodes[str(brick_id)] = true
	if _live_debug_overlay and is_instance_valid(_live_debug_overlay):
		_live_debug_overlay.queue_redraw()


func clear_live_debug_activity() -> void:
	_live_debug_active_nodes.clear()
	if _live_debug_overlay and is_instance_valid(_live_debug_overlay):
		_live_debug_overlay.queue_redraw()


func has_live_debug_activity() -> bool:
	return not _live_debug_active_nodes.is_empty()


func is_live_debug_connection_active(connection: Dictionary) -> bool:
	if _live_debug_active_nodes.is_empty():
		return false
	var from_name := str(connection.get("from_node", ""))
	var to_name := str(connection.get("to_node", ""))
	if from_name.is_empty() or to_name.is_empty():
		return false
	return _live_debug_side_reaches_active(from_name, true, {}) and _live_debug_side_reaches_active(to_name, false, {})


func _live_debug_side_reaches_active(node_name: String, upstream: bool, visited: Dictionary) -> bool:
	if visited.has(node_name):
		return false
	visited[node_name] = true
	var node := get_node_or_null(NodePath(node_name))
	if not (node is GraphNode):
		return false
	if not bool(node.get_meta("is_reroute", false)):
		return _live_debug_active_nodes.has(node_name)

	for connection in get_connection_list():
		if upstream and str(connection.get("to_node", "")) == node_name:
			if _live_debug_side_reaches_active(str(connection.get("from_node", "")), true, visited.duplicate()):
				return true
		elif not upstream and str(connection.get("from_node", "")) == node_name:
			if _live_debug_side_reaches_active(str(connection.get("to_node", "")), false, visited.duplicate()):
				return true
	return false


func get_live_debug_connection_point(connection: Dictionary, t: float) -> Variant:
	var from_position_variant: Variant = _get_port_position(StringName(str(connection.get("from_node", ""))), int(connection.get("from_port", 0)), true)
	var to_position_variant: Variant = _get_port_position(StringName(str(connection.get("to_node", ""))), int(connection.get("to_port", 0)), false)
	if not (from_position_variant is Vector2) or not (to_position_variant is Vector2):
		return null
	var from_position := from_position_variant as Vector2
	var to_position := to_position_variant as Vector2
	var clamped_t := clampf(t, 0.0, 1.0)

	if connection_style == "stepped":
		var mid_x := (from_position.x + to_position.x) * 0.5
		var points := PackedVector2Array([
			from_position,
			Vector2(mid_x, from_position.y),
			Vector2(mid_x, to_position.y),
			to_position,
		])
		return _point_along_polyline(points, clamped_t)

	# Approximate GraphEdit's native Bezier routing. The dots are drawn by the
	# editor overlay only, so this has no runtime game cost.
	var handle_length := maxf(absf(to_position.x - from_position.x) * 0.5, 40.0)
	var control_a := from_position + Vector2(handle_length, 0.0)
	var control_b := to_position - Vector2(handle_length, 0.0)
	return _cubic_bezier_point(from_position, control_a, control_b, to_position, clamped_t)


func _cubic_bezier_point(a: Vector2, b: Vector2, c: Vector2, d: Vector2, t: float) -> Vector2:
	var inv := 1.0 - t
	return a * inv * inv * inv + b * 3.0 * inv * inv * t + c * 3.0 * inv * t * t + d * t * t * t


func _point_along_polyline(points: PackedVector2Array, t: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	var total_length := 0.0
	var segment_lengths: Array[float] = []
	for index in range(points.size() - 1):
		var segment_length := points[index].distance_to(points[index + 1])
		segment_lengths.append(segment_length)
		total_length += segment_length
	if total_length <= 0.0001:
		return points[0]
	var target := clampf(t, 0.0, 1.0) * total_length
	var travelled := 0.0
	for index in range(segment_lengths.size()):
		var length := segment_lengths[index]
		if target <= travelled + length or index == segment_lengths.size() - 1:
			var local_t := 0.0 if length <= 0.0001 else (target - travelled) / length
			return points[index].lerp(points[index + 1], clampf(local_t, 0.0, 1.0))
		travelled += length
	return points[points.size() - 1]
