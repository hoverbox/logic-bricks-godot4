@tool
extends RefCounted

## Live debugging: highlights bricks that are active in the running game
## (data sent by logic_bricks_debugger.gd through the editor debugger).

var panel = null


func setup(target_panel) -> void:
	panel = target_panel


## Low-overhead live debug snapshot. The running game reports only which chains
## are active four times per second. The editor applies the visual state here; no
## per-brick debugger messages or highlight timers run in the gameplay loop.
func clear_runtime_live_debug() -> void:
	if panel.graph_edit and panel.graph_edit.has_method("clear_live_debug_activity"):
		panel.graph_edit.call("clear_live_debug_activity")
	if panel.graph_edit:
		for child in panel.graph_edit.get_children():
			if child is GraphNode and not child.has_meta("is_reroute"):
				child.modulate = Color.WHITE


func receive_runtime_graph_snapshot_batch(batch: Array) -> void:
	if panel.current_node == null or not is_instance_valid(panel.current_node):
		return
	var active_ids: Array = []
	var found_current := false
	for path_entry in batch:
		if not (path_entry is Array) or path_entry.size() < 2:
			continue
		var runtime_path := str(path_entry[0])
		if not _runtime_path_matches_current_node(runtime_path):
			continue
		found_current = true
		if path_entry[1] is Array:
			active_ids = path_entry[1]
		break
	if not found_current:
		if panel.graph_edit.has_method("clear_live_debug_activity"):
			panel.graph_edit.call("clear_live_debug_activity")
		return

	# Keep the bricks themselves visually unchanged. The GraphEdit animates
	# lightweight dots along connections that belong to the active chain.
	for child in panel.graph_edit.get_children():
		if child is GraphNode and not child.has_meta("is_reroute"):
			child.modulate = Color.WHITE
	if panel.graph_edit.has_method("set_live_debug_active_nodes"):
		panel.graph_edit.call("set_live_debug_active_nodes", active_ids)


## Runtime -> editor half of the two-way Logic Bricks bridge.
## Batched messages keep runtime debugger traffic low even when many Always or
## physics chains execute every frame.
func receive_runtime_brick_activity_batch(batch: Array) -> void:
	for path_entry in batch:
		if not (path_entry is Array) or path_entry.size() < 2:
			continue
		var runtime_path := str(path_entry[0])
		var bricks = path_entry[1]
		if not (bricks is Array):
			continue
		for brick_entry in bricks:
			if not (brick_entry is Array) or brick_entry.is_empty():
				continue
			var brick_id := str(brick_entry[0])
			var state := str(brick_entry[1]) if brick_entry.size() > 1 else "active"
			receive_runtime_brick_activity(runtime_path, brick_id, state)


## Generated scripts report stable graph-node IDs through EngineDebugger and the
## EditorDebuggerPlugin forwards them here. Only the graph for the matching scene
## node is highlighted, so identical brick_node_N IDs on other nodes are ignored.
func receive_runtime_brick_activity(runtime_node_path: String, brick_id: String, _state: String = "active") -> void:
	if panel.current_node == null or not is_instance_valid(panel.current_node):
		return
	if brick_id.is_empty() or not _runtime_path_matches_current_node(runtime_node_path):
		return
	var graph_node: Node = panel.graph_edit.get_node_or_null(NodePath(brick_id))
	if not (graph_node is GraphNode):
		return

	var token := int(graph_node.get_meta("logic_bricks_live_debug_token", 0)) + 1
	graph_node.set_meta("logic_bricks_live_debug_token", token)
	graph_node.modulate = Color(0.62, 1.0, 0.62, 1.0)
	var timer = panel.get_tree().create_timer(0.22)
	timer.timeout.connect(func():
		if is_instance_valid(graph_node) and int(graph_node.get_meta("logic_bricks_live_debug_token", 0)) == token:
			graph_node.modulate = Color.WHITE
	)


func _runtime_path_matches_current_node(runtime_node_path: String) -> bool:
	if runtime_node_path.is_empty():
		return true
	var editor_path := str(panel.current_node.get_path())
	if runtime_node_path == editor_path:
		return true
	# The running SceneTree and editor SceneTree can have different root prefixes.
	# Compare from the edited scene root downward as a stable fallback.
	var scene_root: Node = panel.editor_interface.get_edited_scene_root() if panel.editor_interface else null
	if scene_root == null:
		return false
	var rel := str(scene_root.get_path_to(panel.current_node))
	if rel == ".":
		return runtime_node_path.ends_with("/" + str(scene_root.name))
	return runtime_node_path.ends_with("/" + str(scene_root.name) + "/" + rel)
