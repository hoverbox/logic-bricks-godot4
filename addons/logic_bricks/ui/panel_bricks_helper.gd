@tool
extends RefCounted

const BrickGraphNode = preload("res://addons/logic_bricks/ui/brick_graph_node.gd")
const BrickRegistry = preload("res://addons/logic_bricks/core/brick_registry.gd")
const DocumentationHelper = preload("res://addons/logic_bricks/core/documentation_helper.gd")

var panel = null


func setup(owner_panel) -> void:
	panel = owner_panel


func apply_brick_visual_style(graph_node: GraphNode, brick_type: String) -> void:
	var header_color := Color.WHITE
	match brick_type:
		"sensor": header_color = panel._brick_sensor_color
		"controller": header_color = panel._brick_controller_color
		"actuator": header_color = panel._brick_actuator_color
		_: return

	var titlebar := StyleBoxFlat.new()
	titlebar.bg_color = header_color
	titlebar.corner_radius_top_left = 4
	titlebar.corner_radius_top_right = 4
	titlebar.content_margin_left = 10.0
	var titlebar_selected := titlebar.duplicate()
	titlebar_selected.bg_color = header_color.lightened(0.12)
	titlebar_selected.border_width_left = 3
	titlebar_selected.border_width_top = 3
	titlebar_selected.border_width_right = 3
	titlebar_selected.border_color = Color.WHITE
	graph_node.add_theme_stylebox_override("titlebar", titlebar)
	graph_node.add_theme_stylebox_override("titlebar_selected", titlebar_selected)
	var titlebar_hbox := graph_node.get_titlebar_hbox()
	if titlebar_hbox.get_child_count() > 0 and titlebar_hbox.get_child(0) is Label:
		var title_label := titlebar_hbox.get_child(0) as Label
		title_label.add_theme_color_override("font_color", panel._brick_header_text_color)
		title_label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
		title_label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		title_label.add_theme_constant_override("outline_size", 0)

	var body := StyleBoxFlat.new()
	body.bg_color = panel._brick_body_color
	body.corner_radius_bottom_left = 4
	body.corner_radius_bottom_right = 4
	var body_selected := body.duplicate()
	body_selected.bg_color = panel._brick_body_color.lightened(0.08)
	body_selected.border_width_left = 3
	body_selected.border_width_right = 3
	body_selected.border_width_bottom = 3
	body_selected.border_color = Color.WHITE
	graph_node.add_theme_stylebox_override("panel", body)
	graph_node.add_theme_stylebox_override("panel_selected", body_selected)


func apply_brick_connection_ports(graph_node: GraphNode, brick_type: String) -> void:
	var connection_row = graph_node.get_node_or_null("BrickConnectionRow")
	if connection_row == null:
		return
	var slot_index = connection_row.get_index()
	if brick_type == "sensor":
		graph_node.set_slot(slot_index, false, 0, Color.WHITE, true, 0, panel._brick_sensor_color)
	elif brick_type == "controller":
		graph_node.set_slot(slot_index, true, 0, panel._brick_sensor_color, true, 0, panel._brick_actuator_color)
	else:
		graph_node.set_slot(slot_index, true, 0, panel._brick_actuator_color, false, 0, Color.WHITE)


func _font_with_graph_oversampling(source: Font) -> Font:
	if source == null:
		return null
	var copy := source.duplicate(true) as Font
	if copy == null:
		return source
	for property in copy.get_property_list():
		if property.get("name", "") == "oversampling":
			copy.set("oversampling", 3.0)
			break
	return copy


func apply_crisp_brick_fonts(graph_node: GraphNode) -> void:
	if panel._crisp_brick_font == null:
		panel._crisp_brick_font = _font_with_graph_oversampling(graph_node.get_theme_font("font"))
	if panel._crisp_brick_title_font == null:
		panel._crisp_brick_title_font = _font_with_graph_oversampling(graph_node.get_theme_font("title_font", "GraphNode"))
	if panel._crisp_brick_title_font != null:
		graph_node.add_theme_font_override("title_font", panel._crisp_brick_title_font)
	if panel._crisp_brick_font == null:
		return
	graph_node.add_theme_font_override("font", panel._crisp_brick_font)
	for child in graph_node.find_children("*", "Control", true, false):
		if child is Control:
			(child as Control).add_theme_font_override("font", panel._crisp_brick_font)


func add_brick_bottom_padding(graph_node: GraphNode) -> void:
	var spacer := Control.new()
	spacer.name = "BrickBottomPadding"
	spacer.custom_minimum_size = Vector2(0, 8)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_node.add_child(spacer)


func create_graph_node(brick_type: String, brick_class: String, position: Vector2) -> void:
	var brick_instance = create_brick_instance(brick_class)
	if not brick_instance:
		push_error("Logic Bricks: Failed to create brick instance for: " + brick_class)
		return

	if panel.current_node and brick_instance.has_method("apply_context_defaults"):
		brick_instance.call("apply_context_defaults", panel.current_node)

	var graph_node = BrickGraphNode.new()
	graph_node.name = "brick_node_%d" % panel.next_node_id
	panel.next_node_id += 1
	graph_node.position_offset = position
	graph_node.title = brick_instance.get_brick_name()
	graph_node.set_meta("brick_data", {
		"brick_type": brick_type,
		"brick_class": brick_class,
		"brick_instance": brick_instance
	})

	apply_brick_visual_style(graph_node, brick_type)
	panel._create_brick_ui(graph_node, brick_instance)
	apply_brick_connection_ports(graph_node, brick_type)
	_add_controller_view_button(graph_node, brick_type, brick_instance)
	add_brick_bottom_padding(graph_node)
	apply_crisp_brick_fonts(graph_node)
	setup_graph_node_context_menu(graph_node)
	graph_node.dragged.connect(panel._on_brick_node_dragged.bind(graph_node))
	panel.graph_edit.add_child(graph_node)
	panel._save_graph_to_metadata("Add Logic Brick", false)


func create_graph_node_from_data(node_data: Dictionary) -> GraphNode:
	if node_data.get("is_reroute", false):
		var port_color = node_data.get("color", Color.WHITE)
		var reroute = panel._create_reroute_node(node_data["position"] + Vector2(4, 4), port_color, false)
		reroute.name = node_data["id"]
		reroute.position_offset = node_data["position"]
		return reroute

	var brick_type = node_data["brick_type"]
	var brick_class = node_data["brick_class"]
	var brick_instance = create_brick_instance(brick_class)
	if not brick_instance:
		return null

	var instance_name = node_data.get("instance_name", "")
	if not instance_name.is_empty():
		brick_instance.set_instance_name(instance_name)
	brick_instance.debug_enabled = node_data.get("debug_enabled", false)
	brick_instance.debug_message = node_data.get("debug_message", "")
	var properties: Dictionary = node_data.get("properties", {})
	for prop_name in properties:
		brick_instance.set_property(prop_name, properties[prop_name])

	_sync_waypoint_nodes(brick_class, brick_instance)

	var graph_node = BrickGraphNode.new()
	graph_node.name = node_data["id"]
	graph_node.position_offset = node_data["position"]
	graph_node.title = brick_instance.get_brick_name()
	graph_node.set_meta("brick_data", {
		"brick_type": brick_type,
		"brick_class": brick_class,
		"brick_instance": brick_instance
	})

	apply_brick_visual_style(graph_node, brick_type)
	panel._create_brick_ui(graph_node, brick_instance)
	apply_brick_connection_ports(graph_node, brick_type)
	_add_controller_view_button(graph_node, brick_type, brick_instance)
	add_brick_bottom_padding(graph_node)
	apply_crisp_brick_fonts(graph_node)
	setup_graph_node_context_menu(graph_node)
	graph_node.dragged.connect(panel._on_brick_node_dragged.bind(graph_node))
	panel.graph_edit.add_child(graph_node)
	return graph_node


func create_brick_instance(brick_class: String):
	var script_path: String = BrickRegistry.get_script_path(brick_class)
	if script_path.is_empty():
		push_error("Logic Bricks: No script registered for brick class: " + brick_class)
		return null
	var base_script = load("res://addons/logic_bricks/core/logic_brick.gd")
	if not base_script:
		push_error("Logic Bricks: could not load base class logic_brick.gd")
		return null
	var brick_script = load(script_path)
	if not brick_script:
		push_error("Logic Bricks: Failed to load script: " + script_path)
		return null
	if not brick_script.can_instantiate():
		push_error("Logic Bricks: Script cannot be instantiated (check for parse errors): " + script_path)
		return null
	return brick_script.new()


func setup_graph_node_context_menu(graph_node: GraphNode) -> void:
	var popup_menu = PopupMenu.new()
	popup_menu.add_item("Duplicate", 0)
	popup_menu.add_item("View Documentation", 2)
	popup_menu.add_separator()
	popup_menu.add_item("Delete", 1)
	panel._apply_popup_menu_size(popup_menu)
	popup_menu.id_pressed.connect(panel._on_graph_node_context_menu.bind(graph_node))
	graph_node.add_child(popup_menu)
	graph_node.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			popup_menu.position = graph_node.get_screen_position() + event.position
			popup_menu.popup()
	)


func on_graph_node_context_menu(id: int, graph_node: GraphNode) -> void:
	if id == 2:
		if graph_node.has_meta("brick_data"):
			var brick_data: Dictionary = graph_node.get_meta("brick_data")
			DocumentationHelper.open_brick(str(brick_data.get("brick_class", "")), panel.current_brick_domain)
		return
	await panel._clipboard_helper.on_graph_node_context_menu(id, graph_node)


func _add_controller_view_button(graph_node: GraphNode, brick_type: String, brick_instance) -> void:
	if brick_type != "controller":
		return
	panel._update_controller_title(graph_node, brick_instance)
	var view_code_btn = Button.new()
	view_code_btn.text = "View Code"
	view_code_btn.tooltip_text = "Open the generated script and jump to this chain's code"
	view_code_btn.pressed.connect(panel._on_view_chain_code.bind(graph_node))
	graph_node.add_child(view_code_btn)


func _sync_waypoint_nodes(brick_class: String, brick_instance) -> void:
	if brick_class == "WaypointPathActuator" and panel.current_node is Node3D:
		var waypoint_3d = load("res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd")
		if waypoint_3d:
			waypoint_3d.sync_waypoint_nodes(panel.current_node, brick_instance)
	elif brick_class == "WaypointPath2DActuator" and panel.current_node is Node2D:
		var waypoint_2d = load("res://addons/logic_bricks/bricks/actuators/2d/waypoint_path_2d_actuator.gd")
		if waypoint_2d:
			waypoint_2d.sync_waypoint_nodes(panel.current_node, brick_instance)
