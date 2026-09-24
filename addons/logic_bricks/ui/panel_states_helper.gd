extends RefCounted

var panel = null


func setup(target_panel) -> void:
	panel = target_panel


func create_states_tab() -> void:
	panel.states_panel = VBoxContainer.new()
	panel.states_panel.add_theme_constant_override("separation", 8)
	panel.states_panel.name = "States"
	panel.states_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header = HBoxContainer.new()
	panel.states_panel.add_child(header)

	var title = Label.new()
	title.text = "States"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font = title.get_theme_font("bold", "EditorFonts")
	if title_font:
		title.add_theme_font_override("font", title_font)
	header.add_child(title)

	panel.state_debug_button = Button.new()
	var state_debug_enabled := false
	if panel.current_node and is_instance_valid(panel.current_node):
		state_debug_enabled = bool(panel.current_node.get_meta("logic_bricks_debug_watch_state", false))
	panel.state_debug_button.button_pressed = state_debug_enabled
	panel._style_debug_watch_button(panel.state_debug_button, state_debug_enabled)
	panel.state_debug_button.tooltip_text = "Show this node's current state in the Runtime Debug Overlay"
	panel.state_debug_button.toggled.connect(on_state_debug_watch_toggled.bind(panel.state_debug_button))
	header.add_child(panel.state_debug_button)

	var add_state_button = Button.new()
	add_state_button.text = "+ Add"
	add_state_button.pressed.connect(add_state)
	header.add_child(add_state_button)

	panel.states_panel.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.states_panel.add_child(scroll)

	panel.states_list = VBoxContainer.new()
	panel.states_list.add_theme_constant_override("separation", 8)
	panel.states_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel.states_list)

	refresh_states_ui()


func sanitize_state_id(text_value: String) -> String:
	var sanitized_name = text_value.strip_edges().to_lower().replace(" ", "_")
	sanitized_name = sanitized_name.replace("-", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	sanitized_name = regex.sub(sanitized_name, "", true)
	if sanitized_name.is_empty():
		sanitized_name = "state"
	return sanitized_name


func generate_unique_state_id(base_name: String) -> String:
	var candidate = sanitize_state_id(base_name)
	var suffix = 1
	var existing: Dictionary = {}
	for state_data in panel.states_data:
		existing[str(state_data.get("id", ""))] = true
	while existing.has(candidate):
		candidate = "%s_%d" % [sanitize_state_id(base_name), suffix]
		suffix += 1
	return candidate


func get_default_states() -> Array[Dictionary]:
	return [
		{
			"id": "state_1",
			"name": "State 1"
		}
	]


func load_states_from_metadata(suppress_graph_save: bool = false) -> void:
	panel.states_data.clear()
	if panel.current_node and panel.current_node.has_meta("logic_bricks_states"):
		var saved = panel.current_node.get_meta("logic_bricks_states")
		if saved is Array:
			var migrate_state_watch := false
			for state_data in saved:
				var copied_state: Dictionary = state_data.duplicate(true)
				if bool(copied_state.get("debug_watch", false)):
					migrate_state_watch = true
				copied_state.erase("debug_watch")
				panel.states_data.append(copied_state)
			if migrate_state_watch:
				panel.current_node.set_meta("logic_bricks_debug_watch_state", true)
	if panel.state_debug_button and is_instance_valid(panel.state_debug_button):
		var state_watch_enabled := bool(panel.current_node.get_meta("logic_bricks_debug_watch_state", false)) if panel.current_node else false
		panel.state_debug_button.set_pressed_no_signal(state_watch_enabled)
		panel._style_debug_watch_button(panel.state_debug_button, state_watch_enabled)
	if panel.states_data.is_empty():
		panel.states_data = get_default_states()
		if not suppress_graph_save:
			save_states_to_metadata()
		else:
			if panel.current_node and is_instance_valid(panel.current_node):
				panel.current_node.set_meta("logic_bricks_states", panel.states_data.duplicate(true))
	refresh_states_ui()
	panel._refresh_brick_state_ui()


func save_states_to_metadata() -> void:
	if not panel.current_node or not is_instance_valid(panel.current_node):
		return
	panel.current_node.set_meta("logic_bricks_states", panel.states_data.duplicate(true))
	panel._mark_scene_modified()
	panel._save_graph_to_metadata()


func refresh_states_ui() -> void:
	if not panel.states_list:
		return
	for child in panel.states_list.get_children():
		child.queue_free()
	for i in range(panel.states_data.size()):
		create_state_item_ui(i, panel.states_data[i])


func create_state_item_ui(index: int, state_data: Dictionary) -> void:
	var item_panel = PanelContainer.new()
	panel.states_list.add_child(item_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	item_panel.add_child(vbox)

	var header = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	var name_edit = LineEdit.new()
	name_edit.text = str(state_data.get("name", "State"))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(on_state_name_changed.bind(index))
	header.add_child(name_edit)

	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.custom_minimum_size = Vector2(24, 0)
	delete_btn.tooltip_text = "Delete state"
	delete_btn.pressed.connect(delete_state.bind(index))
	header.add_child(delete_btn)


func on_state_debug_watch_toggled(enabled: bool, button: Button) -> void:
	if not panel.current_node or not is_instance_valid(panel.current_node):
		return
	panel.current_node.set_meta("logic_bricks_debug_watch_state", enabled)
	panel._style_debug_watch_button(button, enabled)
	panel._mark_scene_modified()


func add_state() -> void:
	var state_name = "State %d" % (panel.states_data.size() + 1)
	var state_id = generate_unique_state_id(state_name)
	panel.states_data.append({
		"id": state_id,
		"name": state_name
	})
	refresh_states_ui()
	save_states_to_metadata()
	panel._refresh_brick_state_ui()


func delete_state(index: int) -> void:
	if index < 0 or index >= panel.states_data.size():
		return
	panel.states_data.remove_at(index)
	if panel.states_data.is_empty():
		panel.states_data = get_default_states()
	refresh_states_ui()
	save_states_to_metadata()
	panel._refresh_brick_state_ui()


func on_state_name_changed(new_text: String, index: int) -> void:
	if index < 0 or index >= panel.states_data.size():
		return
	panel.states_data[index]["name"] = new_text
	save_states_to_metadata()
	panel._refresh_brick_state_ui()


func get_state_options() -> Array:
	var result: Array = []
	for state_data in panel.states_data:
		result.append({"id": str(state_data.get("id", "")), "name": str(state_data.get("name", ""))})
	return result


func get_state_display_name(state_id: String) -> String:
	for state_data in panel.states_data:
		if str(state_data.get("id", "")) == state_id:
			return str(state_data.get("name", state_id))
	return state_id
