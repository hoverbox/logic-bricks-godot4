@tool
extends EditorPlugin

const LogicBrickPanel = preload("res://addons/logic_bricks/ui/logic_brick_panel.gd")
const LogicBrickManager = preload("res://addons/logic_bricks/core/logic_brick_manager.gd")
const WaypointPathActuator = preload("res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd")

var panel: Control
var manager: LogicBrickManager

# Waypoint handle state
var _wp_node: Node3D = null          # Node currently showing waypoint handles
var _wp_actuator_data: Array = []    # Array of {brick_instance, chain_name} for all WaypointPath actuators on _wp_node
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
	
	add_control_to_bottom_panel(panel, "Logic Bricks")
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)
	
	# Ensure the GlobalVars autoload is registered so generated code can reference it
	ensure_global_vars_autoload("res://addons/logic_bricks/global_vars.gd")
	
	print("Logic Bricks Plugin: Enabled")


## Called by Godot just before the scene is saved.
## Purges any CanvasLayer nodes left behind by SplitScreenActuator's _ready()
## so the serializer never encounters SubViewport nodes with a null common_parent.
func _save_external_data() -> void:
	var edited_root = get_editor_interface().get_edited_scene_root()
	if not edited_root:
		return
	var stale: Array = []
	for child in edited_root.get_children():
		if child is CanvasLayer and child.name.begins_with("_ss_canvas_"):
			stale.append(child)
	for cl in stale:
		cl.free()


func _exit_tree() -> void:
	if get_editor_interface().get_selection().selection_changed.is_connected(_on_selection_changed):
		get_editor_interface().get_selection().selection_changed.disconnect(_on_selection_changed)
	
	if panel:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
	
	print("Logic Bricks Plugin: Disabled")


func _on_selection_changed() -> void:
	if panel:
		var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
		if selected_nodes.size() > 0:
			var sel = selected_nodes[0]
			panel.set_selected_node(sel)
			
			# Show waypoint handles if node has WaypointPath actuators
			# Keep showing if we were dragging (handle click deselects the node briefly)
			if not _dragging_handle:
				if sel is Node3D:
					_update_waypoint_node(sel)
				else:
					_update_waypoint_node(null)
		else:
			# No selection — but keep handles if dragging
			if not _dragging_handle:
				panel.set_selected_node(null)
				_update_waypoint_node(null)
	
	update_overlays()


func _update_waypoint_node(node: Node3D) -> void:
	_wp_node = node
	_wp_actuator_data = []
	
	if not node:
		return
	
	# Collect all WaypointPath actuator brick instances from the node's chain metadata
	if not node.has_meta("logic_bricks"):
		return
	
	var chains = node.get_meta("logic_bricks")
	for chain in chains:
		for actuator_data in chain.get("actuators", []):
			if actuator_data.get("type", "") == "WaypointPathActuator":
				var brick = WaypointPathActuator.new()
				brick.deserialize(actuator_data)
				_wp_actuator_data.append({
					"brick": brick,
					"chain_name": chain.get("name", ""),
				})


## Draw waypoint handles over the 3D viewport
func _forward_3d_draw_over_viewport(viewport_control: Control) -> void:
	if not _wp_node or _wp_actuator_data.is_empty():
		return
	
	var camera = _editor_camera
	if not camera:
		camera = get_editor_interface().get_editor_viewport_3d(0).get_camera_3d()
	if not camera:
		return
	
	for act_data in _wp_actuator_data:
		var brick = act_data["brick"]
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
	if not _wp_node or _wp_actuator_data.is_empty():
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if click is on a handle
				for act_idx in range(_wp_actuator_data.size()):
					var brick = _wp_actuator_data[act_idx]["brick"]
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
	if not _wp_node or not _wp_node.has_meta("logic_bricks"):
		return
	
	var chains = _wp_node.get_meta("logic_bricks")
	
	for act_data in _wp_actuator_data:
		var chain_name = act_data["chain_name"]
		var brick = act_data["brick"]
		
		for chain in chains:
			if chain.get("name", "") != chain_name:
				continue
			for actuator_data in chain.get("actuators", []):
				if actuator_data.get("type", "") == "WaypointPathActuator":
					actuator_data["properties"]["waypoints"] = brick.properties.get("waypoints", []).duplicate()
					break
	
	_wp_node.set_meta("logic_bricks", chains)
	
	# Also trigger a code regeneration so the generated script stays in sync
	if manager:
		manager.regenerate_script(_wp_node)
	
	# Mark scene modified
	get_editor_interface().mark_scene_as_unsaved()


## Register the GlobalVars autoload singleton
func ensure_global_vars_autoload(script_path: String) -> void:
	if not ProjectSettings.has_setting("autoload/GlobalVars"):
		add_autoload_singleton("GlobalVars", script_path)
		print("Logic Bricks: Registered GlobalVars autoload")

