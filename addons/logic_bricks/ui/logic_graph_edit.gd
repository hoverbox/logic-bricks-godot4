@tool
extends GraphEdit

## GraphEdit with switchable connection routing for Logic Bricks.
## Bezier uses Godot's native GraphEdit rendering. Stepped reshapes the
## native Line2D connection visuals after GraphEdit updates them.
var connection_style: String = "bezier"
var _native_line_points: Dictionary = {}


func _ready() -> void:
	set_process(true)


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
		return get_closest_connection_at_point(point, max_distance)

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
	if not (node is GraphNode):
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
