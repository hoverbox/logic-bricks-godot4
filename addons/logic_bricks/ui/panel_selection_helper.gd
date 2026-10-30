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

	panel._variables_helper.flush_pending_typing()
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
	panel._states_helper.view_state_id = ""
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
		# Once Logic Bricks (or a script) were deliberately added only to an instance,
		# do not make the user approve that same local edit every time they reselect it.
		# Keep the warning when the source scene root already has a script: in that case
		# local changes may be unintentionally diverging from authored source logic.
		if _should_auto_edit_local_instance(panel.current_node):
			panel._instance_override = true
		else:
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
	panel._version_helper.refresh_notice()


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
			panel._property_helper.typing_assistance.refresh_graph(child)


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
		if parent_with_logic:
			panel._script_parent_warning.text = "⚠ PHYSICS PARENT: %s\nChild scripts are disabled because '%s' is a physics object. Add Logic Bricks to that physics object instead." % [panel.current_node.name, parent_with_logic.name]
		panel._script_parent_warning.visible = parent_with_logic != null
	if panel.add_script_button:
		panel.add_script_button.visible = parent_with_logic == null
	if panel._script_required_desc:
		panel._script_required_desc.visible = parent_with_logic == null
	if panel._script_select_parent_button:
		panel._script_select_parent_button.text = "Select Physics Parent"
		panel._script_select_parent_button.visible = parent_with_logic != null
	panel._script_required_overlay.visible = true
	panel._script_required_overlay.move_to_front()


func get_parent_with_script_or_logic() -> Node:
	if not panel.current_node or not panel.editor_interface:
		return null
	var scene_root = panel.editor_interface.get_edited_scene_root()
	if not scene_root or panel.current_node == scene_root or not scene_root.is_ancestor_of(panel.current_node):
		return null

	# A physics object owns the gameplay logic for its subtree. Walk upward from
	# the selected child so this also works when a level has a regular Node3D/Node2D
	# root with CharacterBody, RigidBody, StaticBody, or Area setups beneath it.
	var ancestor: Node = panel.current_node.get_parent()
	while ancestor:
		if ancestor is CollisionObject3D or ancestor is CollisionObject2D:
			return ancestor
		if ancestor == scene_root:
			break
		ancestor = ancestor.get_parent()
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
	if panel.add_script_button:
		panel.add_script_button.visible = true
	if panel._script_required_desc:
		panel._script_required_desc.visible = true


func _should_auto_edit_local_instance(node: Node) -> bool:
	var instance_root: Node = _find_instance_root(node)
	if not instance_root or instance_root.scene_file_path.is_empty():
		return false
	if _source_scene_root_has_script(instance_root.scene_file_path):
		return false

	# A script/Logic Bricks payload that exists only on this instance is an
	# intentional local override, so reopening it should go straight to editing.
	return node.get_script() != null or node.has_meta("logic_bricks_graph") or node.has_meta("logic_bricks")


func _source_scene_root_has_script(scene_path: String) -> bool:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return false
	var state: SceneState = packed.get_state()
	if state == null or state.get_node_count() == 0:
		return false
	for property_index in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0, property_index) == &"script":
			return state.get_node_property_value(0, property_index) != null
	return false


func show_instance_panel() -> void:
	if panel._instance_panel:
		panel._instance_panel.visible = true
		_refresh_instance_override_state()
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
	desc.name = "InstanceDescription"
	desc.text = "This node belongs to an instanced scene.\nChanges made here will only affect this instance.\nTo change all instances, edit the original scene."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc)

	var override_status = Label.new()
	override_status.name = "OverrideStatus"
	override_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	override_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(override_status)
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

	var reset_btn = Button.new()
	reset_btn.name = "ResetOverridesButton"
	reset_btn.text = "↶  Reset Instance Overrides"
	reset_btn.tooltip_text = "Revert inherited property changes so this instance follows the original scene again. The placed root transform is preserved."
	reset_btn.pressed.connect(panel._on_reset_instance_overrides_pressed)
	btn_box.add_child(reset_btn)

	var parent = panel.graph_edit.get_parent()
	var graph_index = panel.graph_edit.get_index()
	parent.add_child(panel._instance_panel)
	parent.move_child(panel._instance_panel, graph_index)
	_refresh_instance_override_state()


func _refresh_instance_override_state() -> void:
	if not panel._instance_panel or not panel.current_node:
		return
	var instance_root := _find_instance_root(panel.current_node)
	var has_overrides := _instance_has_property_overrides(instance_root)
	var status := panel._instance_panel.find_child("OverrideStatus", true, false) as Label
	var reset_btn := panel._instance_panel.find_child("ResetOverridesButton", true, false) as Button
	if status:
		if has_overrides:
			status.text = "⚠ Local property changes detected on this instance. These can block updates from the original scene."
			status.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
		else:
			status.text = "✓ No local property overrides detected. The update problem is coming from something else."
			status.add_theme_color_override("font_color", Color(0.55, 0.9, 0.55))
	if reset_btn:
		reset_btn.visible = has_overrides


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


func _instance_has_property_overrides(instance_root: Node) -> bool:
	if not instance_root or instance_root.scene_file_path.is_empty():
		return false
	var packed := load(instance_root.scene_file_path) as PackedScene
	if not packed:
		return false
	var source_root := packed.instantiate()
	if not source_root:
		return false
	var changed := _nodes_have_property_overrides(instance_root, source_root, instance_root)
	source_root.free()
	return changed


func _nodes_have_property_overrides(node: Node, source_node: Node, instance_root: Node) -> bool:
	for prop in source_node.get_property_list():
		var property_name := str(prop.get("name", ""))
		var usage := int(prop.get("usage", 0))
		if property_name.is_empty() or (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if node == instance_root and property_name in ["position", "rotation", "rotation_degrees", "scale", "transform", "global_position", "global_rotation", "global_rotation_degrees", "global_scale", "global_transform"]:
			continue
		var source_value = source_node.get(property_name)
		var current_value = node.get(property_name)
		if not _instance_values_equal(current_value, source_value):
			return true
	for source_child in source_node.get_children():
		var child := node.get_node_or_null(NodePath(str(source_child.name)))
		if child and _nodes_have_property_overrides(child, source_child, instance_root):
			return true
	return false


func _instance_values_equal(a, b) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Resource and b is Resource:
		var a_path: String = str(a.resource_path)
		var b_path: String = str(b.resource_path)
		if not a_path.is_empty() or not b_path.is_empty():
			return a_path == b_path
		# Scene-local subresources are duplicated when a PackedScene is instantiated,
		# so object identity would report false overrides here.
		return true
	if a is Object or b is Object:
		return true
	return a == b


func on_reset_instance_overrides_pressed() -> void:
	if not panel.current_node or not panel.editor_interface:
		return
	var instance_root := _find_instance_root(panel.current_node)
	if not instance_root or instance_root.scene_file_path.is_empty():
		return
	var packed := load(instance_root.scene_file_path) as PackedScene
	if not packed:
		return
	var source_root := packed.instantiate()
	if not source_root:
		return
	_reset_properties_from_source(instance_root, source_root, instance_root)
	source_root.free()
	panel.editor_interface.mark_scene_as_unsaved()
	update_ui()


func _find_instance_root(node: Node) -> Node:
	var edited_root = panel.editor_interface.get_edited_scene_root() if panel.editor_interface else null
	var current := node
	var found: Node = null
	while current and current != edited_root:
		if not current.scene_file_path.is_empty():
			found = current
		current = current.get_parent()
	return found


func _reset_properties_from_source(node: Node, source_node: Node, instance_root: Node) -> void:
	for prop in source_node.get_property_list():
		var property_name := str(prop.get("name", ""))
		var usage := int(prop.get("usage", 0))
		if property_name.is_empty() or (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		# The instance root transform belongs to the level placement, not the source scene.
		if node == instance_root and property_name in ["position", "rotation", "rotation_degrees", "scale", "transform", "global_position", "global_rotation", "global_rotation_degrees", "global_scale", "global_transform"]:
			continue
		var source_value = source_node.get(property_name)
		var current_value = node.get(property_name)
		if not _instance_values_equal(current_value, source_value):
			node.set(property_name, source_value)
	for source_child in source_node.get_children():
		var child := node.get_node_or_null(NodePath(str(source_child.name)))
		if child:
			_reset_properties_from_source(child, source_child, instance_root)


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
