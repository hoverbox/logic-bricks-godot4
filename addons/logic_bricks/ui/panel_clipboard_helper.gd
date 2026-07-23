extends RefCounted

var panel = null

func setup(target_panel) -> void:
	panel = target_panel

func _copy_snapshot_value(value):
	# Metadata values are not guaranteed to be containers. Some older projects and
	# settings store booleans or other scalar Variants, which do not implement duplicate().
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value


func _snapshot_values_equal(a, b) -> bool:
	# Godot raises an error for some cross-type Variant comparisons (for example,
	# bool == Dictionary), so compare types before comparing their values.
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a.keys():
			if not b.has(key) or not _snapshot_values_equal(a[key], b[key]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for i in range(a.size()):
			if not _snapshot_values_equal(a[i], b[i]):
				return false
		return true
	return a == b

func take_graph_snapshot(target_node: Node = panel.current_node) -> Dictionary:
	if not target_node or not is_instance_valid(target_node):
		return {}
	var scene_root: Node = null
	if panel.editor_interface:
		scene_root = panel.editor_interface.get_edited_scene_root()
	return {
		"graph": _copy_snapshot_value(target_node.get_meta("logic_bricks_graph", {})),
		"frames": _copy_snapshot_value(target_node.get_meta("logic_bricks_frames", [])),
		"variables": _copy_snapshot_value(target_node.get_meta("logic_bricks_variables", [])),
		"states": _copy_snapshot_value(target_node.get_meta("logic_bricks_states", [])),
		"debug_watch_state": _copy_snapshot_value(target_node.get_meta("logic_bricks_debug_watch_state", {})),
		"global_usage": _copy_snapshot_value(target_node.get_meta("logic_bricks_global_usage", {})),
		"global_vars": _copy_snapshot_value(scene_root.get_meta("logic_bricks_global_vars", [])) if scene_root else [],
	}

func _set_or_remove_meta(target: Node, key: String, value, empty_value) -> void:
	if _snapshot_values_equal(value, empty_value):
		if target.has_meta(key):
			target.remove_meta(key)
	else:
		target.set_meta(key, _copy_snapshot_value(value))

func restore_graph_snapshot(target_node: Node, snapshot: Dictionary) -> void:
	if not target_node or not is_instance_valid(target_node):
		return
	_set_or_remove_meta(target_node, "logic_bricks_graph", snapshot.get("graph", {}), {})
	_set_or_remove_meta(target_node, "logic_bricks_frames", snapshot.get("frames", []), [])
	_set_or_remove_meta(target_node, "logic_bricks_variables", snapshot.get("variables", []), [])
	_set_or_remove_meta(target_node, "logic_bricks_states", snapshot.get("states", []), [])
	_set_or_remove_meta(target_node, "logic_bricks_debug_watch_state", snapshot.get("debug_watch_state", {}), {})
	_set_or_remove_meta(target_node, "logic_bricks_global_usage", snapshot.get("global_usage", {}), {})
	if panel.editor_interface:
		var scene_root = panel.editor_interface.get_edited_scene_root()
		if scene_root:
			_set_or_remove_meta(scene_root, "logic_bricks_global_vars", snapshot.get("global_vars", []), [])
	panel._mark_scene_modified()
	panel._reload_graph_deferred.call_deferred(target_node)

func reload_graph_deferred(target_node: Node) -> void:
	await panel.get_tree().process_frame
	if not target_node or not is_instance_valid(target_node):
		return
	if panel.current_node != target_node:
		return
	await panel._load_graph_from_metadata()
	panel._load_variables_from_metadata()
	panel._load_states_from_metadata(true)
	panel._frames_helper.load_frames_from_metadata(panel)
	panel._update_global_vars_script()

func record_undo(action_name: String, before_snapshot: Dictionary, after_snapshot: Dictionary, target_node: Node = panel.current_node, merge: bool = false) -> void:
	if not panel.plugin or not target_node or not is_instance_valid(target_node):
		return
	if _snapshot_values_equal(before_snapshot, after_snapshot):
		return
	var ur = panel.plugin.get_undo_redo()
	var merge_mode = UndoRedo.MERGE_ENDS if merge else UndoRedo.MERGE_DISABLE
	ur.create_action(action_name, merge_mode)
	ur.add_do_method(panel, "_restore_graph_snapshot_for_node", target_node, after_snapshot)
	ur.add_undo_method(panel, "_restore_graph_snapshot_for_node", target_node, before_snapshot)
	ur.commit_action(false)

func save_graph_to_metadata(action_name: String = "Edit Logic Bricks", record_change: bool = true, merge: bool = true) -> void:
	if not panel.current_node:
		return
	if panel._is_part_of_instance(panel.current_node) and not panel._instance_override:
		return
	var target_node = panel.current_node
	var before_snapshot = take_graph_snapshot(target_node)
	var graph_data = {
		"nodes": [],
		"connections": [],
		"next_id": panel.next_node_id
	}
	for child in panel.graph_edit.get_children():
		if child is GraphNode and child.has_meta("brick_data"):
			var brick_data = child.get_meta("brick_data")
			graph_data["nodes"].append({
				"id": child.name,
				"position": child.position_offset,
				"brick_type": brick_data["brick_type"],
				"brick_class": brick_data["brick_class"],
				"instance_name": brick_data["brick_instance"].get_instance_name(),
				"debug_enabled": brick_data["brick_instance"].debug_enabled,
				"debug_message": brick_data["brick_instance"].debug_message,
				"properties": brick_data["brick_instance"].get_properties()
			})
		elif child is GraphNode and child.has_meta("is_reroute"):
			graph_data["nodes"].append({"id": child.name, "position": child.position_offset, "is_reroute": true})
	for conn in panel.graph_edit.get_connection_list():
		graph_data["connections"].append({
			"from_node": conn["from_node"], "from_port": conn["from_port"],
			"to_node": conn["to_node"], "to_port": conn["to_port"]
		})
	target_node.set_meta("logic_bricks_graph", graph_data)
	panel._mark_scene_modified()
	if record_change:
		record_undo(action_name, before_snapshot, take_graph_snapshot(target_node), target_node, merge)

func on_graph_node_context_menu(id: int, graph_node: GraphNode) -> void:
	match id:
		0:
			await duplicate_graph_node(graph_node)
		1:
			var before_snapshot = take_graph_snapshot()
			graph_node.queue_free()
			await panel.get_tree().process_frame
			save_graph_to_metadata("Delete Logic Brick", false)
			record_undo("Delete Logic Brick", before_snapshot, take_graph_snapshot())

func duplicate_graph_node(original_node: GraphNode, record_change: bool = true) -> GraphNode:
	var before_snapshot = take_graph_snapshot()
	if not original_node.has_meta("brick_data"):
		return null

	var brick_data = original_node.get_meta("brick_data")
	var brick_instance = brick_data["brick_instance"]

	var original_name = brick_instance.instance_name
	if original_name.is_empty():
		original_name = brick_data["brick_class"].replace("Sensor", "").replace("Controller", "").replace("Actuator", "")

	var new_name = generate_unique_brick_name(original_name)
	var new_position = original_node.position_offset + Vector2(50, 50)
	panel._create_graph_node(brick_data["brick_type"], brick_data["brick_class"], new_position)

	var new_node = panel.graph_edit.get_child(panel.graph_edit.get_child_count() - 1)
	if new_node and new_node.has_meta("brick_data"):
		var new_brick_data = new_node.get_meta("brick_data")
		var new_brick_instance = new_brick_data["brick_instance"]

		var properties = brick_instance.get_properties()
		for key in properties:
			new_brick_instance.set_property(key, properties[key])

		new_brick_instance.set_instance_name(new_name)
		new_brick_instance.debug_enabled = brick_instance.debug_enabled
		new_brick_instance.debug_message = brick_instance.debug_message

		var name_edit = new_node.get_node_or_null("InstanceNameEdit")
		if name_edit:
			name_edit.text = new_name

		for child in new_node.get_children():
			if not child is PopupMenu:
				child.queue_free()

		await panel.get_tree().process_frame
		panel._create_brick_ui(new_node, new_brick_instance)
		panel._setup_graph_node_context_menu(new_node)
		new_node.selected = true
		save_graph_to_metadata("Duplicate Logic Brick", false)
		if record_change:
			record_undo("Duplicate Logic Brick", before_snapshot, take_graph_snapshot())
		return new_node

	return null

func generate_unique_brick_name(base_name: String) -> String:
	var clean_name = base_name
	var regex = RegEx.new()
	regex.compile("_\\d{3}$")
	var result = regex.search(base_name)
	if result:
		clean_name = base_name.substr(0, result.get_start())

	var existing_names = []
	for child in panel.graph_edit.get_children():
		if child is GraphNode and child.has_meta("brick_data"):
			var brick_data = child.get_meta("brick_data")
			var brick_instance = brick_data["brick_instance"]
			existing_names.append(brick_instance.instance_name)

	var suffix_num = 1
	var new_name = clean_name + "_%03d" % suffix_num
	while new_name in existing_names:
		suffix_num += 1
		new_name = clean_name + "_%03d" % suffix_num
		if suffix_num > 999:
			new_name = clean_name + "_%d" % Time.get_ticks_msec()
			break
	return new_name

func duplicate_selected_nodes() -> void:
	var before_snapshot = take_graph_snapshot()
	var selected_nodes = []
	for child in panel.graph_edit.get_children():
		if child is GraphNode and child.selected:
			selected_nodes.append(child)

	if selected_nodes.is_empty():
		return

	var internal_connections = []
	var connection_list = panel.graph_edit.get_connection_list()
	for conn in connection_list:
		var from_node = panel.graph_edit.get_node(NodePath(conn["from_node"]))
		var to_node = panel.graph_edit.get_node(NodePath(conn["to_node"]))
		if from_node in selected_nodes and to_node in selected_nodes:
			internal_connections.append({
				"from": from_node,
				"from_port": conn["from_port"],
				"to": to_node,
				"to_port": conn["to_port"]
			})

	var node_mapping = {}
	for node in selected_nodes:
		node.selected = false
		var new_node = await duplicate_graph_node(node, false)
		if new_node:
			node_mapping[node] = new_node

	await panel.get_tree().process_frame

	for conn in internal_connections:
		var old_from = conn["from"]
		var old_to = conn["to"]
		if old_from in node_mapping and old_to in node_mapping:
			var new_from = node_mapping[old_from]
			var new_to = node_mapping[old_to]
			panel.graph_edit.connect_node(new_from.name, conn["from_port"], new_to.name, conn["to_port"])

	save_graph_to_metadata("Duplicate Logic Bricks", false)
	record_undo("Duplicate Logic Bricks", before_snapshot, take_graph_snapshot())

func on_copy_bricks_pressed() -> void:
	if not panel.current_node:
		push_warning("Logic Bricks: No node selected to copy from.")
		return

	var selected_nodes: Array = []
	for child in panel.graph_edit.get_children():
		if child is GraphNode and child.selected:
			selected_nodes.append(child)

	if not selected_nodes.is_empty():
		panel._selection_clipboard = capture_selection(selected_nodes)
		panel._clipboard_graph = {}
		return

	if not panel.current_node.has_meta("logic_bricks_graph"):
		push_warning("Logic Bricks: No logic bricks on this node to copy.")
		return

	panel._clipboard_graph = panel.current_node.get_meta("logic_bricks_graph").duplicate(true)

	if panel.current_node.has_meta("logic_bricks_variables"):
		panel._clipboard_vars = panel.current_node.get_meta("logic_bricks_variables").duplicate(true)
	else:
		panel._clipboard_vars = []

	var clipboard_globals: Array = []
	if panel.editor_interface:
		var scene_root = panel.editor_interface.get_edited_scene_root()
		if scene_root and scene_root.has_meta("logic_bricks_global_vars"):
			clipboard_globals = scene_root.get_meta("logic_bricks_global_vars").duplicate(true)
	panel._clipboard_graph["_global_vars"] = clipboard_globals
	panel._selection_clipboard = {}

func capture_selection(selected_nodes: Array) -> Dictionary:
	var selected_names: Dictionary = {}
	for node in selected_nodes:
		selected_names[node.name] = true

	var node_data_list: Array = []
	for node in selected_nodes:
		if not node.has_meta("brick_data"):
			continue
		var bd = node.get_meta("brick_data")
		var bi = bd["brick_instance"]
		node_data_list.append({
			"id": node.name,
			"position": node.position_offset,
			"brick_type": bd["brick_type"],
			"brick_class": bd["brick_class"],
			"instance_name": bi.get_instance_name(),
			"debug_enabled": bi.debug_enabled,
			"debug_message": bi.debug_message,
			"properties": bi.get_properties().duplicate(true)
		})

	var internal_conns: Array = []
	for conn in panel.graph_edit.get_connection_list():
		if conn["from_node"] in selected_names and conn["to_node"] in selected_names:
			internal_conns.append(conn.duplicate())

	return {"nodes": node_data_list, "connections": internal_conns}

func on_paste_bricks_pressed() -> void:
	if not panel.current_node:
		push_warning("Logic Bricks: No node selected to paste to.")
		return

	if panel._is_part_of_instance(panel.current_node):
		push_warning("Logic Bricks: Cannot paste to an instanced node.")
		return

	if not panel._selection_clipboard.is_empty():
		await paste_selection(panel._selection_clipboard)
		return

	if panel._clipboard_graph.is_empty():
		push_warning("Logic Bricks: Nothing to paste. Copy bricks from a node first.")
		return

	var before_snapshot = take_graph_snapshot()
	var paste_graph = panel._clipboard_graph.duplicate(true)
	var pasted_globals: Array = paste_graph.get("_global_vars", [])
	paste_graph.erase("_global_vars")

	panel.current_node.set_meta("logic_bricks_graph", paste_graph)

	if panel._clipboard_vars.size() > 0:
		panel.current_node.set_meta("logic_bricks_variables", panel._clipboard_vars.duplicate(true))

	if pasted_globals.size() > 0 and panel.editor_interface:
		var scene_root = panel.editor_interface.get_edited_scene_root()
		if scene_root:
			var existing: Array = []
			if scene_root.has_meta("logic_bricks_global_vars"):
				existing = scene_root.get_meta("logic_bricks_global_vars").duplicate(true)
			var existing_names: Dictionary = {}
			for v in existing:
				existing_names[v.get("name", "")] = true
			for v in pasted_globals:
				if not existing_names.get(v.get("name", ""), false):
					existing.append(v.duplicate())
			scene_root.set_meta("logic_bricks_global_vars", existing)

	panel._mark_scene_modified()
	await panel._load_graph_from_metadata()
	panel._load_variables_from_metadata()
	record_undo("Paste Logic Bricks", before_snapshot, take_graph_snapshot())

func paste_selection(clipboard: Dictionary) -> void:
	var before_snapshot = take_graph_snapshot()
	var node_list: Array = clipboard.get("nodes", [])
	if node_list.is_empty():
		return

	for child in panel.graph_edit.get_children():
		if child is GraphNode:
			child.selected = false

	var paste_offset = Vector2(40, 40)
	var node_map: Dictionary = {}

	for node_data in node_list:
		var new_id = "brick_node_%d" % panel.next_node_id
		panel.next_node_id += 1

		var new_data = node_data.duplicate(true)
		new_data["id"] = new_id
		new_data["position"] = Vector2(node_data["position"]) + paste_offset

		var new_node = panel._create_graph_node_from_data(new_data)
		if new_node:
			node_map[node_data["id"]] = new_node

	await panel.get_tree().process_frame

	for new_node in node_map.values():
		if is_instance_valid(new_node):
			new_node.selected = true

	for conn in clipboard.get("connections", []):
		var from_node = node_map.get(conn["from_node"])
		var to_node = node_map.get(conn["to_node"])
		if from_node and to_node and is_instance_valid(from_node) and is_instance_valid(to_node):
			panel.graph_edit.connect_node(from_node.name, conn["from_port"], to_node.name, conn["to_port"])

	save_graph_to_metadata("Paste Logic Bricks", false)
	record_undo("Paste Logic Bricks", before_snapshot, take_graph_snapshot())

func on_delete_nodes_request(nodes: Array) -> void:
	var before_snapshot = take_graph_snapshot()

	for node_name in nodes:
		var node = panel.graph_edit.get_node(NodePath(node_name))
		if node:
			if node is GraphFrame:
				panel.frame_node_mapping.erase(node.name)
				panel.frame_titles.erase(node.name)
				if panel.selected_frame == node:
					panel.selected_frame = null
					panel.frame_settings_container.visible = false
			panel.graph_edit.remove_child(node)
			node.free()

	panel._update_frames_list()
	save_graph_to_metadata("Delete Logic Brick(s)", false)
	panel._save_frames_to_metadata(false)
	record_undo("Delete Logic Brick(s)", before_snapshot, take_graph_snapshot())

func save_template_to_file(path: String) -> void:
	if not panel.current_node:
		return

	var selected_nodes: Array = []
	for child in panel.graph_edit.get_children():
		if child is GraphNode and child.selected:
			selected_nodes.append(child)

	var template_data: Dictionary = {}
	var save_entire_graph := selected_nodes.is_empty()
	if save_entire_graph:
		save_graph_to_metadata()
		template_data = panel.current_node.get_meta("logic_bricks_graph", {}).duplicate(true)
	else:
		template_data = capture_selection(selected_nodes)

	var selected_names: Dictionary = {}
	for node_data in template_data.get("nodes", []):
		selected_names[str(node_data.get("id", ""))] = true

	var saved_frames: Array = []
	if panel.current_node.has_meta("logic_bricks_frames"):
		for frame_data in panel.current_node.get_meta("logic_bricks_frames"):
			var frame_nodes: Array = frame_data.get("nodes", [])
			var include_frame := save_entire_graph
			if not include_frame and not frame_nodes.is_empty():
				include_frame = true
				for node_name in frame_nodes:
					if not selected_names.has(str(node_name)):
						include_frame = false
						break
			if include_frame:
				saved_frames.append(frame_data.duplicate(true))

	var local_vars: Array = []
	if panel.current_node.has_meta("logic_bricks_variables"):
		local_vars = panel.current_node.get_meta("logic_bricks_variables").duplicate(true)

	var envelope := {
		"format": "logic_bricks_template",
		"version": 1,
		"created_with": "Logic Bricks",
		"payload": var_to_str({
			"graph": template_data,
			"frames": saved_frames,
			"variables": local_vars
		})
	}

	if not path.to_lower().ends_with(".lbtemplate"):
		path += ".lbtemplate"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Logic Bricks: Could not save template to %s" % path)
		return
	file.store_string(JSON.stringify(envelope, "\t"))
	file.close()
	print("Logic Bricks: Template saved to ", path)


func load_template_from_file(path: String) -> void:
	if not panel.current_node:
		return
	if not FileAccess.file_exists(path):
		push_error("Logic Bricks: Template file not found: %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Logic Bricks: Could not open template: %s" % path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or parsed.get("format", "") != "logic_bricks_template":
		push_error("Logic Bricks: This is not a valid Logic Bricks template.")
		return
	if int(parsed.get("version", 0)) > 1:
		push_error("Logic Bricks: This template was created by a newer unsupported template format.")
		return
	var payload = str_to_var(str(parsed.get("payload", "")))
	if not payload is Dictionary:
		push_error("Logic Bricks: Template payload is damaged or unreadable.")
		return

	var graph: Dictionary = payload.get("graph", {})
	if graph.is_empty() or graph.get("nodes", []).is_empty():
		push_warning("Logic Bricks: This template contains no bricks.")
		return

	var before_snapshot = take_graph_snapshot()
	await paste_selection(graph)

	# Merge variables by name without replacing existing definitions.
	var existing_vars: Array = []
	if panel.current_node.has_meta("logic_bricks_variables"):
		existing_vars = panel.current_node.get_meta("logic_bricks_variables").duplicate(true)
	var existing_var_names: Dictionary = {}
	for variable in existing_vars:
		existing_var_names[str(variable.get("name", ""))] = true
	for variable in payload.get("variables", []):
		var variable_name := str(variable.get("name", ""))
		if not variable_name.is_empty() and not existing_var_names.has(variable_name):
			existing_vars.append(variable.duplicate(true))
			existing_var_names[variable_name] = true
	panel.current_node.set_meta("logic_bricks_variables", existing_vars)

	# Recreate included frames around the newly pasted node IDs.
	var pasted_selected: Array = []
	for child in panel.graph_edit.get_children():
		if child is GraphNode and child.selected:
			pasted_selected.append(child)
	var old_nodes: Array = graph.get("nodes", [])
	var old_to_new: Dictionary = {}
	for i in range(min(old_nodes.size(), pasted_selected.size())):
		old_to_new[str(old_nodes[i].get("id", ""))] = pasted_selected[i].name

	for frame_data in payload.get("frames", []):
		var new_frame_data = frame_data.duplicate(true)
		new_frame_data["name"] = "template_frame_%d" % Time.get_ticks_usec()
		new_frame_data["position"] = Vector2(frame_data.get("position", Vector2.ZERO)) + Vector2(40, 40)
		var remapped_nodes: Array = []
		for old_name in frame_data.get("nodes", []):
			if old_to_new.has(str(old_name)):
				remapped_nodes.append(old_to_new[str(old_name)])
		new_frame_data["nodes"] = remapped_nodes
		var current_frames: Array = panel.current_node.get_meta("logic_bricks_frames", []).duplicate(true)
		current_frames.append(new_frame_data)
		panel.current_node.set_meta("logic_bricks_frames", current_frames)

	panel._mark_scene_modified()
	await panel._load_graph_from_metadata()
	panel._load_variables_from_metadata()
	panel._frames_helper.load_frames_from_metadata(panel)
	record_undo("Load Logic Bricks Template", before_snapshot, take_graph_snapshot())
	print("Logic Bricks: Template loaded from ", path)
