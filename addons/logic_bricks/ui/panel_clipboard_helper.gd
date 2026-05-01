extends RefCounted

var panel = null

func setup(target_panel) -> void:
    panel = target_panel

func take_graph_snapshot() -> Dictionary:
    if not panel.current_node or not panel.current_node.has_meta("logic_bricks_graph"):
        return {}
    return panel.current_node.get_meta("logic_bricks_graph").duplicate(true)

func restore_graph_snapshot(snapshot: Dictionary) -> void:
    if not panel.current_node:
        return
    if snapshot.is_empty():
        if panel.current_node.has_meta("logic_bricks_graph"):
            panel.current_node.remove_meta("logic_bricks_graph")
    else:
        panel.current_node.set_meta("logic_bricks_graph", snapshot.duplicate(true))
    panel._mark_scene_modified()
    panel._reload_graph_deferred.call_deferred()

func reload_graph_deferred() -> void:
    await panel._load_graph_from_metadata()

func record_undo(action_name: String, before_snapshot: Dictionary, after_snapshot: Dictionary) -> void:
    if not panel.plugin:
        return
    var ur = panel.plugin.get_undo_redo()
    ur.create_action(action_name)
    ur.add_do_method(panel, "_restore_graph_snapshot", after_snapshot)
    ur.add_undo_method(panel, "_restore_graph_snapshot", before_snapshot)
    ur.commit_action(false)

func save_graph_to_metadata() -> void:
    if not panel.current_node:
        return
    if panel._is_part_of_instance(panel.current_node) and not panel._instance_override:
        return

    var graph_data = {
        "nodes": [],
        "connections": [],
        "next_id": panel.next_node_id
    }

    for child in panel.graph_edit.get_children():
        if child is GraphNode and child.has_meta("brick_data"):
            var brick_data = child.get_meta("brick_data")
            var node_data = {
                "id": child.name,
                "position": child.position_offset,
                "brick_type": brick_data["brick_type"],
                "brick_class": brick_data["brick_class"],
                "instance_name": brick_data["brick_instance"].get_instance_name(),
                "debug_enabled": brick_data["brick_instance"].debug_enabled,
                "debug_message": brick_data["brick_instance"].debug_message,
                "properties": brick_data["brick_instance"].get_properties()
            }
            graph_data["nodes"].append(node_data)
        elif child is GraphNode and child.has_meta("is_reroute"):
            var node_data = {
                "id": child.name,
                "position": child.position_offset,
                "is_reroute": true
            }
            graph_data["nodes"].append(node_data)

    for conn in panel.graph_edit.get_connection_list():
        graph_data["connections"].append({
            "from_node": conn["from_node"],
            "from_port": conn["from_port"],
            "to_node": conn["to_node"],
            "to_port": conn["to_port"]
        })

    panel.current_node.set_meta("logic_bricks_graph", graph_data)
    panel._mark_scene_modified()

func on_graph_node_context_menu(id: int, graph_node: GraphNode) -> void:
    match id:
        0:
            await duplicate_graph_node(graph_node)
        1:
            var before_snapshot = take_graph_snapshot()
            graph_node.queue_free()
            await panel.get_tree().process_frame
            save_graph_to_metadata()
            record_undo("Delete Logic Brick", before_snapshot, take_graph_snapshot())

func duplicate_graph_node(original_node: GraphNode) -> GraphNode:
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
        save_graph_to_metadata()
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
        var new_node = await duplicate_graph_node(node)
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

    save_graph_to_metadata()

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

func paste_selection(clipboard: Dictionary) -> void:
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

    save_graph_to_metadata()

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
    save_graph_to_metadata()
    panel._save_frames_to_metadata()
    record_undo("Delete Logic Brick(s)", before_snapshot, take_graph_snapshot())
