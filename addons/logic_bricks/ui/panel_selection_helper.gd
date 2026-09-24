@tool
extends RefCounted

var panel = null


func setup(owner_panel) -> void:
	panel = owner_panel


func set_selected_node(node: Node) -> void:
	if panel.is_locked:
		return
	if node == panel.current_node:
		return

	panel._instance_override = false
	hide_instance_panel()

	panel._suppress_dirty_mark = true
	if panel.current_node and not is_part_of_instance(panel.current_node):
		panel._save_graph_to_metadata()
		panel._frames_helper.save_frames_to_metadata(panel)
	panel._suppress_dirty_mark = false

	panel._clear_all_apply_warnings()
	panel._apply_validation_active = false
	panel._clear_unapplied_changes()
	panel.current_node = node
	if panel.current_node and panel.manager:
		panel.manager.migrate_node_metadata(panel.current_node)
	update_ui()


func update_ui() -> void:
	if not is_instance_valid(panel.node_info_label) or not is_instance_valid(panel.graph_edit):
		return
	panel.node_info_label.remove_theme_color_override("font_color")
	hide_script_required_overlay()

	if not panel.current_node:
		panel.current_brick_domain = ""
		panel.node_info_label.text = "No node selected - Select a Node3D, Node2D, or UI Control node in the scene tree"
		panel.graph_edit.visible = false
		panel._apply_side_panel_visibility()
		if panel._toolbar:
			panel._toolbar.visible = false
		if panel._toolbar_separator:
			panel._toolbar_separator.visible = false
		if panel._instructions_label:
			panel._instructions_label.visible = true
		return

	if not is_supported_node(panel.current_node):
		panel.current_brick_domain = ""
		panel.node_info_label.text = "Unsupported node type: %s - Use a Node3D, Node2D, or UI Control node" % panel.current_node.get_class()
		panel.graph_edit.visible = false
		panel._apply_side_panel_visibility()
		if panel._toolbar:
			panel._toolbar.visible = false
		if panel._toolbar_separator:
			panel._toolbar_separator.visible = false
		if panel._instructions_label:
			panel._instructions_label.visible = true
		return

	if is_part_of_instance(panel.current_node) and not panel._instance_override:
		panel.node_info_label.text = "⚠ Instanced Node: %s" % panel.current_node.name
		panel.node_info_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
		panel.graph_edit.visible = false
		panel._apply_side_panel_visibility()
		if panel._toolbar:
			panel._toolbar.visible = false
		if panel._toolbar_separator:
			panel._toolbar_separator.visible = false
		if panel._instructions_label:
			panel._instructions_label.visible = false
		show_instance_panel()
		return

	hide_instance_panel()

	panel.current_brick_domain = get_selected_node_domain()
	panel._refresh_add_menu_from_registry(false)

	if panel.current_node.get_script() == null:
		panel._clear_graph_display()
		panel.node_info_label.text = "⚠ Node: %s (%s) - Script required" % [panel.current_node.name, panel.current_node.get_class()]
		panel.node_info_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
		panel.graph_edit.visible = true
		panel._apply_side_panel_visibility()
		if panel.side_panel:
			panel.side_panel.visible = false
		if panel._toolbar:
			panel._toolbar.visible = false
		if panel._toolbar_separator:
			panel._toolbar_separator.visible = false
		if panel._instructions_label:
			panel._instructions_label.visible = false
		show_script_required_overlay()
		return

	panel.node_info_label.text = "✓ Node: %s (%s) - Right-click to add %s bricks" % [panel.current_node.name, panel.current_node.get_class(), panel.current_brick_domain.to_upper()]
	panel.graph_edit.visible = true
	panel._apply_side_panel_visibility()
	if panel._toolbar:
		panel._toolbar.visible = true
	if panel._toolbar_separator:
		panel._toolbar_separator.visible = true
	if panel._instructions_label:
		panel._instructions_label.visible = false

	panel._load_states_from_metadata(true)
	panel._load_variables_from_metadata()
	await panel._load_graph_from_metadata()
	panel._frames_helper.load_frames_from_metadata(panel)
	refresh_brick_state_ui()
	refresh_variable_brick_context_ui()


func refresh_brick_state_ui() -> void:
	if not panel.graph_edit or not panel._property_helper:
		return
	for child in panel.graph_edit.get_children():
		if child is GraphNode and child.has_meta("brick_data"):
			var brick_data = child.get_meta("brick_data")
			var brick_instance = brick_data.get("brick_instance")
			if not brick_instance:
				continue
			var brick_type = str(brick_data.get("brick_type", ""))
			if brick_type in ["controller", "actuator"]:
				panel._property_helper._refresh_state_dropdown(child, brick_instance)
				if brick_type == "controller":
					panel._property_helper._update_controller_title(child, brick_instance)


func refresh_variable_brick_context_ui() -> void:
	if not panel.graph_edit or not panel._property_helper:
		return
	for child in panel.graph_edit.get_children():
		if not (child is GraphNode and child.has_meta("brick_data")):
			continue
		var brick_data = child.get_meta("brick_data")
		var brick_instance = brick_data.get("brick_instance")
		if brick_instance:
			panel._property_helper._refresh_variable_brick_operation_control(child, brick_instance)


func is_supported_node(node: Node) -> bool:
	return node is Node3D or node is Node2D or node is Control


func get_selected_node_domain() -> String:
	if panel.current_node is Control:
		return "ui"
	if panel.current_node is Node2D:
		return "2d"
	if panel.current_node is Node3D:
		return "3d"
	return ""


func show_script_required_overlay() -> void:
	if not panel._script_required_overlay:
		return
	var parent_with_logic = get_parent_with_script_or_logic()
	if panel._script_parent_warning:
		panel._script_parent_warning.text = "This is a child of a node with a script/logic."
		panel._script_parent_warning.visible = parent_with_logic != null
	if panel._script_select_parent_button:
		panel._script_select_parent_button.visible = parent_with_logic != null
	panel._script_required_overlay.visible = true
	panel._script_required_overlay.move_to_front()


func get_parent_with_script_or_logic() -> Node:
	if not panel.current_node:
		return null
	var parent = panel.current_node.get_parent()
	while parent:
		if parent.get_script() != null or parent.has_meta("logic_bricks_graph") or parent.has_meta("logic_bricks"):
			return parent
		parent = parent.get_parent()
	return null


func on_select_parent_pressed() -> void:
	var parent_with_logic = get_parent_with_script_or_logic()
	if not parent_with_logic or not panel.editor_interface:
		return
	var selection = panel.editor_interface.get_selection()
	selection.clear()
	selection.add_node(parent_with_logic)


func hide_script_required_overlay() -> void:
	if panel._script_required_overlay:
		panel._script_required_overlay.visible = false


func show_instance_panel() -> void:
	if panel._instance_panel:
		panel._instance_panel.visible = true
		return

	panel._instance_panel = PanelContainer.new()
	panel._instance_panel.name = "InstancePanel"
	panel._instance_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel._instance_panel.add_child(vbox)

	var title = Label.new()
	title.text = "⚠  Instanced Scene"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "This node belongs to an instanced scene.\nChanges made here will only affect this instance.\nTo change all instances, edit the original scene."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc)
	vbox.add_child(HSeparator.new())

	var btn_box = HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_box)

	var open_btn = Button.new()
	open_btn.text = "📂  Open Original Scene"
	open_btn.tooltip_text = "Open the original scene file for this instance"
	open_btn.pressed.connect(panel._on_open_original_pressed)
	btn_box.add_child(open_btn)

	var override_btn = Button.new()
	override_btn.text = "✏  Edit This Instance"
	override_btn.tooltip_text = "Add Logic Bricks to this instance only.\nWarning: these bricks will not appear in the original scene."
	override_btn.pressed.connect(panel._on_edit_instance_pressed)
	btn_box.add_child(override_btn)

	var parent = panel.graph_edit.get_parent()
	var graph_index = panel.graph_edit.get_index()
	parent.add_child(panel._instance_panel)
	parent.move_child(panel._instance_panel, graph_index)


func hide_instance_panel() -> void:
	if panel._instance_panel:
		panel._instance_panel.visible = false


func on_open_original_pressed() -> void:
	if not panel.current_node or not panel.editor_interface:
		return
	var target = panel.current_node
	var edited_root = panel.editor_interface.get_edited_scene_root()
	while target:
		if target.scene_file_path != "" and target != edited_root:
			panel.editor_interface.open_scene_from_path(target.scene_file_path)
			return
		target = target.get_parent()


func on_edit_instance_pressed() -> void:
	panel._instance_override = true
	hide_instance_panel()
	update_ui()


func is_part_of_instance(node: Node) -> bool:
	if not panel.editor_interface:
		return false
	var edited_scene_root = panel.editor_interface.get_edited_scene_root()
	if not edited_scene_root:
		return false
	var current = node
	while current:
		if current == edited_scene_root:
			return false
		if current.scene_file_path != "" and current != edited_scene_root:
			return true
		current = current.get_parent()
	return false


func on_lock_toggled() -> void:
	panel.is_locked = not panel.is_locked
	if panel.is_locked:
		panel.lock_button.text = "🔒"
		panel.lock_button.modulate = Color(1.0, 0.8, 0.8)
		if panel.current_node:
			panel.node_info_label.text = "🔒 Locked: " + panel.current_node.name
	else:
		panel.lock_button.text = "🔓"
		panel.lock_button.modulate = Color.WHITE
		if panel.current_node:
			panel.node_info_label.text = "Selected: " + panel.current_node.name
