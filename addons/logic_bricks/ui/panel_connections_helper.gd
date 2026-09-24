extends RefCounted

var panel = null

func setup(target_panel) -> void:
	panel = target_panel

func create_reroute_node(position: Vector2, port_color: Color = Color.WHITE, save_now: bool = true) -> GraphNode:
	var graph_node := GraphNode.new()
	graph_node.name = "reroute_%d" % panel.next_node_id
	panel.next_node_id += 1
	graph_node.title = ""
	graph_node.position_offset = position - Vector2(4, 4)
	graph_node.custom_minimum_size = Vector2(8, 8)
	graph_node.size = Vector2(8, 8)
	graph_node.resizable = false
	graph_node.draggable = true
	graph_node.z_index = 100

	var empty_style := StyleBoxEmpty.new()
	for style_name in ["panel", "panel_selected", "titlebar", "titlebar_selected"]:
		graph_node.add_theme_stylebox_override(style_name, empty_style)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 1)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_node.add_child(spacer)
	graph_node.set_slot(0, true, 0, port_color, true, 0, port_color)
	graph_node.set_meta("is_reroute", true)
	graph_node.set_meta("reroute_color", port_color)
	graph_node.dragged.connect(panel._on_reroute_dragged.bind(graph_node))
	graph_node.resized.connect(panel._center_reroute_ports.bind(graph_node))
	panel.graph_edit.add_child(graph_node)
	panel.call_deferred("_center_reroute_ports", graph_node)
	if save_now:
		panel._save_graph_to_metadata("Add Reroute", true, false)
	return graph_node

func center_reroute_ports(reroute: GraphNode) -> void:
	if not is_instance_valid(reroute):
		return
	reroute.add_theme_constant_override("port_h_offset", int(round(reroute.size.x * 0.5)))

func insert_reroute_on_connection(connection: Dictionary, mouse_position: Vector2) -> void:
	if connection.is_empty():
		return
	var from_node = panel.graph_edit.get_node_or_null(NodePath(connection["from_node"]))
	if not from_node or not (from_node is GraphNode):
		return
	var port_color := Color.WHITE
	if connection["from_port"] < from_node.get_output_port_count():
		port_color = from_node.get_output_port_color(connection["from_port"])

	var before_snapshot = panel._take_graph_snapshot()
	var graph_position: Vector2 = (mouse_position + panel.graph_edit.scroll_offset) / panel.graph_edit.zoom
	var reroute := create_reroute_node(graph_position, port_color, false)
	panel.graph_edit.disconnect_node(connection["from_node"], connection["from_port"], connection["to_node"], connection["to_port"])
	panel.graph_edit.connect_node(connection["from_node"], connection["from_port"], reroute.name, 0)
	panel.graph_edit.connect_node(reroute.name, 0, connection["to_node"], connection["to_port"])
	panel._save_graph_to_metadata("Add Reroute", false)
	panel._record_undo("Add Reroute", before_snapshot, panel._take_graph_snapshot())

func on_connection_style_selected(index: int) -> void:
	var style := "stepped" if index == 1 else "bezier"
	if panel.graph_edit and panel.graph_edit.has_method("set_connection_style"):
		panel.graph_edit.set_connection_style(style)
	panel._save_graph_to_metadata("Change Connection Style", false)

func apply_connection_style(style: String) -> void:
	var normalized := "stepped" if style == "stepped" else "bezier"
	if panel.graph_edit and panel.graph_edit.has_method("set_connection_style"):
		panel.graph_edit.set_connection_style(normalized)
	if panel._connection_style_option:
		panel._connection_style_option.select(1 if normalized == "stepped" else 0)

func on_connection_request(from_node: String, from_port: int, to_node: String, to_port: int) -> void:
	var before_snapshot = panel._take_graph_snapshot()
	var from_graph_node = panel.graph_edit.get_node_or_null(NodePath(from_node))
	var to_graph_node = panel.graph_edit.get_node_or_null(NodePath(to_node))

	if from_graph_node and to_graph_node:
		var from_data = from_graph_node.get_meta("brick_data") if from_graph_node.has_meta("brick_data") else null
		var to_data = to_graph_node.get_meta("brick_data") if to_graph_node.has_meta("brick_data") else null
		if from_data and to_data and from_data["brick_type"] == "sensor" and to_data["brick_type"] == "actuator":
			var mid_x: float = (from_graph_node.position_offset.x + to_graph_node.position_offset.x) / 2.0
			var mid_y: float = (from_graph_node.position_offset.y + to_graph_node.position_offset.y) / 2.0
			panel._create_graph_node("controller", "Controller", Vector2(mid_x, mid_y))

			var controller_node: GraphNode = null
			for child in panel.graph_edit.get_children():
				if child is GraphNode and child.has_meta("brick_data"):
					var data = child.get_meta("brick_data")
					if data["brick_type"] == "controller":
						controller_node = child
			if controller_node:
				panel.graph_edit.connect_node(from_node, from_port, controller_node.name, 0)
				panel.graph_edit.connect_node(controller_node.name, 0, to_node, to_port)
				panel._save_graph_to_metadata("Connect Logic Bricks", false)
				panel._record_undo("Connect Logic Bricks", before_snapshot, panel._take_graph_snapshot())
			return

	panel.graph_edit.connect_node(from_node, from_port, to_node, to_port)
	panel._save_graph_to_metadata("Connect Logic Bricks", false)
	panel._record_undo("Connect Logic Bricks", before_snapshot, panel._take_graph_snapshot())

func on_disconnection_request(from_node: String, from_port: int, to_node: String, to_port: int) -> void:
	var before_snapshot = panel._take_graph_snapshot()
	panel.graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	panel._save_graph_to_metadata("Disconnect Logic Bricks", false)
	panel._record_undo("Disconnect Logic Bricks", before_snapshot, panel._take_graph_snapshot())

func try_insert_reroute_from_input(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.alt_pressed):
		return false
	var connection = panel.graph_edit.get_closest_visual_connection_at_point(event.position, 10.0) if panel.graph_edit.has_method("get_closest_visual_connection_at_point") else panel.graph_edit.get_closest_connection_at_point(event.position, 10.0)
	if connection.is_empty():
		return false
	insert_reroute_on_connection(connection, event.position)
	return true

func on_reroute_dragged(_from: Vector2, _to: Vector2, reroute: GraphNode) -> void:
	var connections = panel.graph_edit.get_connection_list()
	for conn in connections:
		if conn["from_node"] == reroute.name or conn["to_node"] == reroute.name:
			panel._save_graph_to_metadata()
			return

	var reroute_center: Vector2 = reroute.position_offset + reroute.size / 2.0
	var best_conn = null
	var best_dist := 40.0
	for conn in connections:
		var from_node = panel.graph_edit.get_node_or_null(NodePath(conn["from_node"]))
		var to_node = panel.graph_edit.get_node_or_null(NodePath(conn["to_node"]))
		if not from_node or not to_node:
			continue
		var from_pos: Vector2 = from_node.position_offset + Vector2(from_node.size.x, from_node.size.y / 2.0)
		var to_pos: Vector2 = to_node.position_offset + Vector2(0, to_node.size.y / 2.0)
		var dist := point_to_segment_distance(reroute_center, from_pos, to_pos)
		if dist < best_dist:
			best_dist = dist
			best_conn = conn

	if best_conn:
		panel.graph_edit.disconnect_node(best_conn["from_node"], best_conn["from_port"], best_conn["to_node"], best_conn["to_port"])
		panel.graph_edit.connect_node(best_conn["from_node"], best_conn["from_port"], reroute.name, 0)
		panel.graph_edit.connect_node(reroute.name, 0, best_conn["to_node"], best_conn["to_port"])
	panel._save_graph_to_metadata()

func point_to_segment_distance(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	var ab := seg_b - seg_a
	var ap := point - seg_a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq == 0.0:
		return ap.length()
	var t := clampf(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest := seg_a + ab * t
	return point.distance_to(closest)
