@tool
extends EditorPlugin

const NodeReferenceSync = preload("res://addons/logic_bricks/core/node_reference_sync.gd")
const GraphSnapshot = preload("res://addons/logic_bricks/core/graph_snapshot.gd")

const LogicBrickPanel = preload("res://addons/logic_bricks/ui/logic_brick_panel.gd")
const LogicBrickManager = preload("res://addons/logic_bricks/core/logic_brick_manager.gd")
const WaypointPathActuator = preload("res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd")
const LogicBricksEditorDebugger = preload("res://addons/logic_bricks/editor_live_debugger.gd")

const PLUGIN_CFG_PATH := "res://addons/logic_bricks/plugin.cfg"
const RELOAD_MENU_ITEM := "Reload Logic Bricks"
const GLOBAL_VARS_PATH := "res://logic_bricks_global_vars.gd"
const LEGACY_GLOBAL_VARS_PATH := "res://addons/logic_bricks/global_vars.gd"

var panel: Control
var manager: LogicBrickManager
var live_debugger: EditorDebuggerPlugin = null

# Waypoint handle state
var _wp_node: Node3D = null          # Node currently showing waypoint handles
var _wp_actuator_data: Array = []    # Array of {brick_instance, chain_index, actuator_index} for all WaypointPath actuators on _wp_node
var _dragging_handle: bool = false   # True while dragging a handle
var _drag_actuator_idx: int = -1     # Which actuator is being dragged
var _drag_wp_idx: int = -1           # Which waypoint within that actuator
var _drag_plane: Plane = Plane()     # World-space drag plane
var _editor_camera: Camera3D = null  # Cached from _forward_3d_gui_input each frame


func _enter_tree() -> void:
	manager = LogicBrickManager.new()
	manager.editor_interface = get_editor_interface()

	panel = LogicBrickPanel.new()
	panel.manager = manager
	panel.editor_interface = get_editor_interface()
	panel.plugin = self

	live_debugger = LogicBricksEditorDebugger.new()
	live_debugger.setup(panel)
	add_debugger_plugin(live_debugger)

	add_control_to_bottom_panel(panel, "Logic Bricks")
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

	# Keep bricks pointing at renamed nodes (see core/node_reference_sync.gd).
	scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_tree_node_added)
	get_tree().node_renamed.connect(_on_tree_node_renamed)
	_remember_scene_node_names()

	# Keep project-owned global data outside the addon folder so replacing/updating
	# the addon cannot wipe a student's globals. Migrate the legacy addon-local
	# file on first run when possible.
	_ensure_project_global_vars_file()
	ensure_global_vars_autoload(GLOBAL_VARS_PATH)
	ensure_debugger_autoload("res://addons/logic_bricks/logic_bricks_debugger.gd")

	# Project > Tools > Reload Logic Bricks, and an automatic reload when the
	# addon was replaced while the editor was open (see _is_stale()).
	add_tool_menu_item(RELOAD_MENU_ITEM, reload_plugin)
	GraphSnapshot.register_setting()
	get_editor_interface().get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)

	# Show the node that is already selected (e.g. after a reload).
	_on_selection_changed.call_deferred()

	print("Logic Bricks Plugin: Enabled")


## Called by Godot just before the scene is saved.
## Purges any CanvasLayer nodes left behind by SplitScreenActuator's _ready()
## so the serializer never encounters SubViewport nodes with a null common_parent.
func _save_external_data() -> void:
	if panel:
		panel._variables_helper.flush_pending_typing()
	var edited_root = get_editor_interface().get_edited_scene_root()
	if not edited_root:
		return
	var stale: Array = []
	for child in edited_root.get_children():
		if child is CanvasLayer and child.name.begins_with("_ss_canvas_"):
			stale.append(child)
	for cl in stale:
		cl.free()


func _build() -> bool:
	if panel:
		panel._variables_helper.flush_pending_typing()
	return true


func _exit_tree() -> void:
	remove_tool_menu_item(RELOAD_MENU_ITEM)
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		filesystem.filesystem_changed.disconnect(_on_filesystem_changed)
	if panel:
		panel._variables_helper.flush_pending_typing()
	if live_debugger:
		remove_debugger_plugin(live_debugger)
		live_debugger = null
	if get_editor_interface().get_selection().selection_changed.is_connected(_on_selection_changed):
		get_editor_interface().get_selection().selection_changed.disconnect(_on_selection_changed)
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.disconnect(_on_tree_node_added)
	if get_tree().node_renamed.is_connected(_on_tree_node_renamed):
		get_tree().node_renamed.disconnect(_on_tree_node_renamed)

	if panel:
		# Bring a popped-out panel back first; otherwise its window stays open
		# after the plugin is disabled, wired to a freed panel.
		if panel.get("_popout_window") != null:
			panel._dock_window()
		remove_control_from_bottom_panel(panel)
		panel.queue_free()

	print("Logic Bricks Plugin: Disabled")


# ── Node rename tracking ────────────────────────────────────────────────────
# Godot's node_renamed signal does not say what the old name was, so the names
# of the edited scene's nodes are remembered here.
var _scene_node_names: Dictionary = {}  # instance id -> name


func _edited_scene_contains(node: Node) -> bool:
	var root := get_editor_interface().get_edited_scene_root()
	return root != null and is_instance_valid(node) and (node == root or root.is_ancestor_of(node))


func _remember_scene_node_names() -> void:
	_scene_node_names.clear()
	var root := get_editor_interface().get_edited_scene_root()
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		_scene_node_names[node.get_instance_id()] = str(node.name)
		stack.append_array(node.get_children())


func _on_scene_changed(scene_root: Node) -> void:
	_remember_scene_node_names()
	if scene_root == null or panel == null:
		return
	# Renames made inside scenes this one instances, while it was closed.
	var result: Dictionary = await panel.apply_external_brick_change(
		func(): return NodeReferenceSync.apply_pending_renames(scene_root))
	var changed: Array = result.get("changed", [])
	for rename in result.get("renames", []):
		if not str(rename["skipped"]).is_empty():
			_notify("Logic Bricks: '%s' was renamed to '%s' in an instanced scene, but bricks here were not updated because %s." % [rename["old"], rename["new"], rename["skipped"]], true)
	if changed.is_empty():
		return
	get_editor_interface().mark_scene_as_unsaved()
	var names := PackedStringArray()
	var total := 0
	for entry in changed:
		total += int(entry["count"])
		names.append(str(entry["node"].name))
	_notify("Logic Bricks: updated %d brick setting(s) on %s for nodes renamed in instanced scenes. Press Apply Code on %s to update the script." % [
		total, ", ".join(names), "that node" if names.size() == 1 else "those nodes"], false)


func _on_tree_node_added(node: Node) -> void:
	if _edited_scene_contains(node):
		_scene_node_names[node.get_instance_id()] = str(node.name)


func _on_tree_node_renamed(node: Node) -> void:
	if not _edited_scene_contains(node):
		return
	var id := node.get_instance_id()
	var old_name := str(_scene_node_names.get(id, ""))
	var new_name := str(node.name)
	_scene_node_names[id] = new_name
	if old_name.is_empty() or old_name == new_name or panel == null:
		return
	var root := get_editor_interface().get_edited_scene_root()

	# Scenes that instance this one get the rename when they are next opened.
	var dependents := PackedStringArray()
	if not root.scene_file_path.is_empty():
		NodeReferenceSync.record_scene_rename(root.scene_file_path, old_name, new_name)
		dependents = NodeReferenceSync.scenes_instancing(root.scene_file_path)
	if not dependents.is_empty():
		var files := PackedStringArray(Array(dependents).map(func(p): return p.get_file()))
		_notify("Logic Bricks: bricks in %s that refer to '%s' will be updated the next time you open %s." % [
			", ".join(files), old_name, "it" if files.size() == 1 else "them"], false)

	var result: Dictionary = await panel.apply_external_brick_change(
		func(): return NodeReferenceSync.rename_in_scene(root, old_name, new_name))
	var changed: Array = result["changed"]
	if changed.is_empty():
		if not str(result["skipped"]).is_empty():
			_notify("Logic Bricks: '%s' was renamed to '%s', but bricks were not updated because %s." % [old_name, new_name, result["skipped"]], true)
		return
	get_editor_interface().mark_scene_as_unsaved()
	var total := 0
	var names: PackedStringArray = []
	for entry in changed:
		total += int(entry["count"])
		names.append(str(entry["node"].name))
	_notify("Logic Bricks: %d brick setting(s) now point to '%s' instead of '%s' (on %s). Press Apply Code on %s to update the script." % [
		total, new_name, old_name, ", ".join(names), "that node" if names.size() == 1 else "those nodes"], false)


func _notify(message: String, is_warning: bool) -> void:
	var interface := get_editor_interface()
	if interface.has_method("get_editor_toaster"):
		var toaster = interface.call("get_editor_toaster")
		if toaster:
			toaster.push_toast(message, EditorToaster.SEVERITY_WARNING if is_warning else EditorToaster.SEVERITY_INFO)
	if is_warning:
		push_warning(message)
	else:
		print(message)


# ── Reloading ───────────────────────────────────────────────────────────────
# Replacing the addon folder while the editor is open makes Godot reload the
# plugin's scripts into the objects that already exist. Variables added by the
# update are then left empty (null) instead of being created, and the panel
# fails on its next action ("Nonexistent function ... in base 'Nil'").
# Turning the plugin off and on again builds everything fresh.

## Turns the plugin off and on again. Also in Project > Tools.
func reload_plugin() -> void:
	var interface := get_editor_interface()
	interface.set_plugin_enabled.call_deferred(PLUGIN_CFG_PATH, false)
	interface.set_plugin_enabled.call_deferred(PLUGIN_CFG_PATH, true)


## True when an update left the plugin or panel with empty helper objects.
func _is_stale() -> bool:
	if get("_scene_node_names") == null:
		return true
	if panel == null:
		return false
	for owner_object in [panel, panel.get("_property_helper")]:
		if owner_object == null:
			return true
		for property in owner_object.get_property_list():
			var prop_name := str(property["name"])
			if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			if prop_name.begins_with("_") and (prop_name.ends_with("_helper") or prop_name.ends_with("_builder") or prop_name.ends_with("_rules") or prop_name.ends_with("_pickers")) and owner_object.get(prop_name) == null:
				return true
	return false


## Reloads if needed; returns true when a reload was started.
func _reload_if_stale() -> bool:
	if not _is_stale():
		return false
	_notify("Logic Bricks was updated while the editor was open. Reloading the plugin.", false)
	reload_plugin()
	return true


func _on_filesystem_changed() -> void:
	_reload_if_stale()


func _on_selection_changed() -> void:
	if _reload_if_stale():
		return
	if panel:
		var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
		if selected_nodes.size() > 0:
			var sel = selected_nodes[0]

			# Ctrl/Cmd + Scene-dock drag is a node-reference gesture. Godot selects
			# the dragged Scene node before the drop begins; keep Logic Bricks on
			# the node being programmed so the destination field does not disappear.
			var reference_drag_modifier := Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
			if not reference_drag_modifier:
				panel.set_selected_node(sel)

			# Show waypoint handles if node has WaypointPath actuators
			# Keep showing if we were dragging (handle click deselects the node briefly)
			if not _dragging_handle:
				if sel is Node3D:
					_update_waypoint_node(sel)
				else:
					_update_waypoint_node(null)
		else:
			# No selection — but keep the Logic Bricks target during a Ctrl/Cmd
			# reference drag, and keep waypoint handles while they are dragged.
			var reference_drag_modifier := Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)
			if not _dragging_handle and not reference_drag_modifier:
				panel.set_selected_node(null)
				_update_waypoint_node(null)

	update_overlays()


## Godot only calls _forward_3d_gui_input() and _forward_3d_draw_over_viewport()
## for plugins whose _handles() accepts the edited object. Without this the
## waypoint handles were never drawn and could not be dragged.
func _handles(object: Object) -> bool:
	return object is Node3D and _has_waypoint_actuator(object)


func _has_waypoint_actuator(node: Node) -> bool:
	if not node.has_meta("logic_bricks"):
		return false
	var chains = node.get_meta("logic_bricks")
	if not (chains is Array):
		return false
	for chain in chains:
		if not (chain is Dictionary):
			continue
		for actuator_data in chain.get("actuators", []):
			if actuator_data is Dictionary and str(actuator_data.get("type", "")) == "WaypointPathActuator":
				return true
	return false


func _update_waypoint_node(node: Node3D) -> void:
	_wp_node = node
	_wp_actuator_data = []

	if not node:
		return

	# Collect all WaypointPath actuator brick instances from the node's chain metadata
	if not node.has_meta("logic_bricks"):
		return

	var chains = node.get_meta("logic_bricks")
	for chain_idx in range(chains.size()):
		var chain = chains[chain_idx]
		var actuators = chain.get("actuators", [])
		for actuator_idx in range(actuators.size()):
			var actuator_data = actuators[actuator_idx]
			if actuator_data.get("type", "") == "WaypointPathActuator":
				var brick = WaypointPathActuator.new()
				brick.deserialize(actuator_data)
				_wp_actuator_data.append({
					"brick": brick,
					"chain_index": chain_idx,
					"actuator_index": actuator_idx,
				})


## Draw waypoint handles over the 3D viewport
func _forward_3d_draw_over_viewport(viewport_control: Control) -> void:
	if not is_instance_valid(_wp_node) or _wp_actuator_data.is_empty():
		return

	var camera = _editor_camera
	if not camera:
		camera = get_editor_interface().get_editor_viewport_3d(0).get_camera_3d()
	if not camera:
		return

	for act_data in _wp_actuator_data:
		var brick = act_data["brick"]
		var path_source = str(brick.properties.get("path_source", "node_positions")).to_lower()
		if path_source == "path3d":
			continue
		var waypoints = brick.properties.get("waypoints", [])
		var space = brick.properties.get("space", "world")
		if typeof(space) == TYPE_STRING:
			space = space.to_lower()

		var world_positions: Array[Vector3] = []
		for wp in waypoints:
			var v = WaypointPathActuator.parse_waypoint(str(wp))
			if space == "local":
				v = _wp_node.global_position + v
			world_positions.append(v)

		if world_positions.is_empty():
			continue

		# Draw connecting lines first
		for i in range(world_positions.size() - 1):
			var p0 = camera.unproject_position(world_positions[i])
			var p1 = camera.unproject_position(world_positions[i + 1])
			# Only draw if both points are in front of camera
			if camera.is_position_behind(world_positions[i]) or camera.is_position_behind(world_positions[i + 1]):
				continue
			viewport_control.draw_line(p0, p1, Color(0.3, 0.8, 1.0, 0.7), 2.0)

		# Draw loop line back to start
		var loop_mode = brick.properties.get("loop_mode", "loop")
		if typeof(loop_mode) == TYPE_STRING:
			loop_mode = loop_mode.to_lower().replace(" ", "_")
		if loop_mode == "loop" and world_positions.size() > 1:
			var p0 = camera.unproject_position(world_positions[-1])
			var p1 = camera.unproject_position(world_positions[0])
			if not camera.is_position_behind(world_positions[-1]) and not camera.is_position_behind(world_positions[0]):
				viewport_control.draw_dashed_line(p0, p1, Color(0.3, 0.8, 1.0, 0.4), 2.0)

		# Draw handles
		for i in range(world_positions.size()):
			if camera.is_position_behind(world_positions[i]):
				continue
			var screen_pos = camera.unproject_position(world_positions[i])
			var is_dragging_this = (_drag_actuator_idx == _wp_actuator_data.find(act_data) and _drag_wp_idx == i)
			var color = Color(1.0, 0.6, 0.1) if is_dragging_this else Color(0.3, 0.8, 1.0)
			viewport_control.draw_circle(screen_pos, 8.0, color)
			viewport_control.draw_circle(screen_pos, 8.0, Color.WHITE, false, 1.5)
			# Index label
			viewport_control.draw_string(
				ThemeDB.fallback_font,
				screen_pos + Vector2(12, 4),
				str(i),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				12,
				Color.WHITE
			)


## Handle mouse input for dragging waypoint handles
func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	_editor_camera = viewport_camera
	if not is_instance_valid(_wp_node) or _wp_actuator_data.is_empty():
		# If the node was freed mid-drag, clean up drag state gracefully
		if _dragging_handle:
			_dragging_handle = false
			_drag_actuator_idx = -1
			_drag_wp_idx = -1
		return EditorPlugin.AFTER_GUI_INPUT_PASS

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if click is on a handle
				for act_idx in range(_wp_actuator_data.size()):
					var brick = _wp_actuator_data[act_idx]["brick"]
					var path_source = str(brick.properties.get("path_source", "node_positions")).to_lower()
					if path_source == "path3d":
						continue
					var waypoints = brick.properties.get("waypoints", [])
					var space = brick.properties.get("space", "world")
					if typeof(space) == TYPE_STRING:
						space = space.to_lower()

					for wp_idx in range(waypoints.size()):
						var v = WaypointPathActuator.parse_waypoint(str(waypoints[wp_idx]))
						var world_pos = _wp_node.global_position + v if space == "local" else v
						var screen_pos = viewport_camera.unproject_position(world_pos)

						if viewport_camera.is_position_behind(world_pos):
							continue

						if event.position.distance_to(screen_pos) < 12.0:
							# Start drag
							_dragging_handle = true
							_drag_actuator_idx = act_idx
							_drag_wp_idx = wp_idx
							# Drag plane: face the camera, at the handle's world position
							_drag_plane = Plane(-viewport_camera.global_transform.basis.z, world_pos)
							update_overlays()
							return EditorPlugin.AFTER_GUI_INPUT_STOP
			else:
				if _dragging_handle:
					_dragging_handle = false
					_drag_actuator_idx = -1
					_drag_wp_idx = -1
					# Persist the new waypoint positions back to the graph metadata
					_save_waypoints_to_graph()
					update_overlays()
					return EditorPlugin.AFTER_GUI_INPUT_STOP

	if event is InputEventMouseMotion and _dragging_handle:
		# Guard: node may have been freed while drag was in progress
		if not is_instance_valid(_wp_node):
			_dragging_handle = false
			_drag_actuator_idx = -1
			_drag_wp_idx = -1
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		# Project mouse ray onto drag plane to get new world position
		var ray_origin = viewport_camera.project_ray_origin(event.position)
		var ray_dir = viewport_camera.project_ray_normal(event.position)
		var intersection = _drag_plane.intersects_ray(ray_origin, ray_dir)

		if intersection != null:
			var new_world_pos: Vector3 = intersection
			var brick = _wp_actuator_data[_drag_actuator_idx]["brick"]
			var space = brick.properties.get("space", "world")
			if typeof(space) == TYPE_STRING:
				space = space.to_lower()

			# Convert to local offset if needed
			var store_pos = new_world_pos
			if space == "local":
				store_pos = new_world_pos - _wp_node.global_position

			var waypoints = brick.properties.get("waypoints", []).duplicate()
			while waypoints.size() <= _drag_wp_idx:
				waypoints.append("0.000,0.000,0.000")
			waypoints[_drag_wp_idx] = WaypointPathActuator.serialize_waypoint(store_pos)
			brick.set_property("waypoints", waypoints)

			update_overlays()
		return EditorPlugin.AFTER_GUI_INPUT_STOP

	return EditorPlugin.AFTER_GUI_INPUT_PASS


## Write dragged waypoint positions back into the chain metadata so they persist
func _save_waypoints_to_graph() -> void:
	if not is_instance_valid(_wp_node) or not _wp_node.has_meta("logic_bricks"):
		return

	var chains = _wp_node.get_meta("logic_bricks")

	for act_data in _wp_actuator_data:
		var chain_index = int(act_data.get("chain_index", -1))
		var actuator_index = int(act_data.get("actuator_index", -1))
		var brick = act_data["brick"]

		if chain_index < 0 or chain_index >= chains.size():
			continue

		var chain = chains[chain_index]
		var actuators = chain.get("actuators", [])
		if actuator_index < 0 or actuator_index >= actuators.size():
			continue

		var actuator_data = actuators[actuator_index]
		if actuator_data.get("type", "") != "WaypointPathActuator":
			continue

		if not actuator_data.has("properties") or not (actuator_data["properties"] is Dictionary):
			actuator_data["properties"] = {}
		actuator_data["properties"]["waypoints"] = brick.properties.get("waypoints", []).duplicate()

	_wp_node.set_meta("logic_bricks", chains)
	# Apply Code rebuilds chains from the graph metadata, so the new positions
	# must go there too or the next Apply would put the old ones back.
	_save_waypoints_to_graph_metadata(chains)

	# Also trigger a code regeneration so the generated script stays in sync
	if manager:
		manager.regenerate_script(_wp_node)

	# Mark scene modified
	get_editor_interface().mark_scene_as_unsaved()


func _save_waypoints_to_graph_metadata(chains: Array) -> void:
	if not _wp_node.has_meta("logic_bricks_graph"):
		return
	var waypoints_by_id: Dictionary = {}
	for chain in chains:
		if not (chain is Dictionary):
			continue
		for actuator_data in chain.get("actuators", []):
			if actuator_data is Dictionary and str(actuator_data.get("type", "")) == "WaypointPathActuator":
				var graph_id := str(actuator_data.get("graph_node_id", ""))
				if not graph_id.is_empty():
					waypoints_by_id[graph_id] = actuator_data.get("properties", {}).get("waypoints", []).duplicate()
	if waypoints_by_id.is_empty():
		return
	var graph_data = _wp_node.get_meta("logic_bricks_graph")
	if not (graph_data is Dictionary):
		return
	graph_data = graph_data.duplicate(true)
	for graph_node in graph_data.get("nodes", []):
		if graph_node is Dictionary and waypoints_by_id.has(str(graph_node.get("id", ""))):
			if not (graph_node.get("properties", null) is Dictionary):
				graph_node["properties"] = {}
			graph_node["properties"]["waypoints"] = waypoints_by_id[str(graph_node["id"])]
	_wp_node.set_meta("logic_bricks_graph", graph_data)
	# Refresh the panel if it is showing this node, so its bricks match.
	if panel and panel.current_node == _wp_node and panel.has_method("_load_graph_from_metadata"):
		panel._load_graph_from_metadata()


func _ensure_project_global_vars_file() -> void:
	if FileAccess.file_exists(GLOBAL_VARS_PATH):
		return

	var source := ""
	if FileAccess.file_exists(LEGACY_GLOBAL_VARS_PATH):
		var legacy := FileAccess.open(LEGACY_GLOBAL_VARS_PATH, FileAccess.READ)
		if legacy:
			source = legacy.get_as_text()
			legacy.close()

	if source.strip_edges().is_empty():
		source = "extends Node\n\n## Auto-generated by Logic Bricks plugin\n## Global variables shared across all scenes\n## This file lives outside addons/ so addon updates do not erase project data.\n\n# === LOGIC BRICKS GLOBALS START ===\n# (no global variables)\n# === LOGIC BRICKS GLOBALS END ===\n"

	var file := FileAccess.open(GLOBAL_VARS_PATH, FileAccess.WRITE)
	if not file:
		push_error("Logic Bricks: Could not create project GlobalVars file: " + GLOBAL_VARS_PATH)
		return
	file.store_string(source)
	file.close()
	get_editor_interface().get_resource_filesystem().scan()


## Register the GlobalVars autoload singleton.
## Keep the saved value as a res:// path instead of a uid:// value. The two
## autoload scripts intentionally ship without .gd.uid sidecars so each project
## generates UIDs in its own cache instead of inheriting stale addon UIDs.
func ensure_global_vars_autoload(script_path: String) -> void:
	_set_autoload_path("GlobalVars", script_path)


## Register the standalone runtime debugger autoload.
## It observes watched metadata and script properties without changing generated scripts.
func ensure_debugger_autoload(script_path: String) -> void:
	_set_autoload_path("LogicBricksDebugger", script_path)


func _set_autoload_path(autoload_name: String, script_path: String) -> void:
	var setting_name := "autoload/" + autoload_name
	var desired := "*" + script_path
	var existing := str(ProjectSettings.get_setting(setting_name, ""))
	if existing == desired:
		return

	ProjectSettings.set_setting(setting_name, desired)
	ProjectSettings.save()
	if existing.is_empty():
		print("Logic Bricks: Registered %s autoload" % autoload_name)
	else:
		print("Logic Bricks: Updated %s autoload path (was: %s)" % [autoload_name, existing.trim_prefix("*")])
