extends RefCounted

var panel = null
var view_state_id: String = ""
var _view_option: OptionButton


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


func create_view_filter(toolbar: HBoxContainer) -> void:
	var label := Label.new()
	label.text = "View State:"
	toolbar.add_child(label)
	_view_option = OptionButton.new()
	_view_option.name = "ViewStateFilter"
	_view_option.tooltip_text = "Show chains for a state, including All States chains and shared bricks. Unconnected bricks stay visible. This does not change game behavior."
	toolbar.add_child(_view_option)
	_view_option.item_selected.connect(_on_view_state_selected)
	refresh_view_filter()


func refresh_view_filter() -> void:
	if not is_instance_valid(_view_option):
		return
	_view_option.clear()
	_view_option.add_item("All")
	_view_option.set_item_metadata(0, "")
	var selected_index := 0
	for state in panel.states_data:
		_view_option.add_item(str(state.get("name", "State")))
		var index := _view_option.item_count - 1
		var state_id := str(state.get("id", ""))
		_view_option.set_item_metadata(index, state_id)
		if state_id == view_state_id:
			selected_index = index
	_view_option.select(selected_index)
	view_state_id = str(_view_option.get_item_metadata(selected_index))
	apply_view_filter.call_deferred()


func _on_view_state_selected(index: int) -> void:
	view_state_id = str(_view_option.get_item_metadata(index))
	apply_view_filter()


func apply_view_filter() -> void:
	if not is_instance_valid(panel.graph_edit):
		return
	var nodes: Dictionary = {}
	for child in panel.graph_edit.get_children():
		if child is GraphNode and not child.is_queued_for_deletion() and (child.has_meta("brick_data") or child.has_meta("is_reroute")):
			nodes[str(child.name)] = child
	var incoming: Dictionary = {}
	var outgoing: Dictionary = {}
	for connection in panel.graph_edit.get_connection_list():
		var from_name := str(connection["from_node"])
		var to_name := str(connection["to_node"])
		if not incoming.has(to_name):
			incoming[to_name] = []
		if not outgoing.has(from_name):
			outgoing[from_name] = []
		incoming[to_name].append(from_name)
		outgoing[from_name].append(to_name)
	var assigned: Dictionary = {}
	var shown: Dictionary = {}
	if not view_state_id.is_empty():
		for node_name in nodes:
			var node: GraphNode = nodes[node_name]
			var data: Dictionary = node.get_meta("brick_data", {})
			if data.get("brick_type", "") != "controller":
				continue
			var members := _collect_chain_members(node_name, nodes, incoming, outgoing)
			assigned.merge(members, true)
			var brick = data.get("brick_instance")
			var state_id := str(brick.get_property("state_id", ""))
			if bool(brick.get_property("all_states", false)) or state_id.is_empty() or state_id == view_state_id:
				shown.merge(members, true)
	for node_name in nodes:
		var node: GraphNode = nodes[node_name]
		var show_brick := view_state_id.is_empty() or shown.has(node_name) or not assigned.has(node_name)
		_set_brick_view_visible(node, show_brick)
		var warning = panel.graph_edit.get_node_or_null(NodePath(panel._warning_node_name(node)))
		if warning:
			warning.visible = show_brick
	for child in panel.graph_edit.get_children():
		if child is GraphFrame:
			child.visible = view_state_id.is_empty() or _frame_has_visible_members(str(child.name), {})
			if not child.visible:
				child.selected = false
	panel.graph_edit.set_state_filter_active(not view_state_id.is_empty())
	panel.graph_edit.queue_redraw()


func _set_brick_view_visible(node: GraphNode, show_brick: bool) -> void:
	# GraphNode rebuilds its port caches from visible rows. Hiding a connected
	# node empties those caches while GraphEdit still draws its connections.
	# Keep layout alive and suppress rendering/input instead.
	var saved_key := "logic_bricks_state_filter_view"
	if not show_brick and not node.has_meta(saved_key):
		node.set_meta(saved_key, {"modulate": node.modulate, "selectable": node.selectable, "draggable": node.draggable})
	node.set_meta("logic_bricks_state_filter_hidden", not show_brick)
	if node.has_meta(saved_key):
		var saved: Dictionary = node.get_meta(saved_key)
		var tint: Color = saved["modulate"]
		if not show_brick:
			tint.a = 0.0
		node.modulate = tint
		node.selectable = bool(saved["selectable"]) if show_brick else false
		node.draggable = bool(saved["draggable"]) if show_brick else false
		if show_brick:
			node.remove_meta(saved_key)
	if not show_brick:
		node.selected = false
	var controls: Array = [node]
	controls.append_array(node.find_children("*", "Control", true, false))
	for control in controls:
		if not show_brick:
			if not control.has_meta(saved_key + "_input"):
				control.set_meta(saved_key + "_input", {"mouse_filter": control.mouse_filter, "focus_mode": control.focus_mode})
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			control.focus_mode = Control.FOCUS_NONE
			control.release_focus()
		elif control.has_meta(saved_key + "_input"):
			var saved_input: Dictionary = control.get_meta(saved_key + "_input")
			control.mouse_filter = int(saved_input["mouse_filter"])
			control.focus_mode = int(saved_input["focus_mode"])
			control.remove_meta(saved_key + "_input")


func _collect_chain_members(controller_name: String, nodes: Dictionary, incoming: Dictionary, outgoing: Dictionary) -> Dictionary:
	# Walk back through dependent gates and reroutes, but never fan out from
	# shared triggers: that would pull unrelated states into the filtered view.
	var members: Dictionary = {}
	var pending: Array = [controller_name]
	while not pending.is_empty():
		var node_name := str(pending.pop_back())
		if members.has(node_name) or not nodes.has(node_name):
			continue
		members[node_name] = true
		pending.append_array(incoming.get(node_name, []))
	# Outputs belong to this chain only up to its actions. A downstream gate
	# has its own state and is considered separately above.
	pending = outgoing.get(controller_name, []).duplicate()
	var visited: Dictionary = {}
	while not pending.is_empty():
		var node_name := str(pending.pop_back())
		if visited.has(node_name) or not nodes.has(node_name):
			continue
		visited[node_name] = true
		var node: GraphNode = nodes[node_name]
		if node.has_meta("is_reroute"):
			members[node_name] = true
			pending.append_array(outgoing.get(node_name, []))
		elif node.get_meta("brick_data", {}).get("brick_type", "") == "actuator":
			members[node_name] = true
	return members


func _frame_has_visible_members(frame_name: String, visited: Dictionary) -> bool:
	if visited.has(frame_name):
		return false
	visited[frame_name] = true
	var members: Array = panel.frame_node_mapping.get(frame_name, [])
	if members.is_empty():
		return true
	for member_name in members:
		var member = panel.graph_edit.get_node_or_null(NodePath(str(member_name)))
		if member is GraphFrame:
			if _frame_has_visible_members(str(member_name), visited):
				return true
		elif member is GraphNode and not bool(member.get_meta("logic_bricks_state_filter_hidden", false)):
			return true
	return false
