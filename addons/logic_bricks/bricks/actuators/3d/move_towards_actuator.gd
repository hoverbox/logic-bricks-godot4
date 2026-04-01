@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Move Towards actuator - Seek target, flee from target, or follow navigation path
## Similar to UPBGE's Steering actuator


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Move Towards"


func _initialize_properties() -> void:
	properties = {
		"behavior": "seek",                    # "seek", "flee", "path_follow"
		"target_mode": "group",                # "group", "node_name"
		"target_name": "",                     # Group name or node name of target
		"arrival_distance": 1.0,               # Distance at which target is considered reached
		"velocity": 5.0,                       # Movement speed
		"acceleration": 0.0,                   # Acceleration (0 = instant, >0 = gradual)
		"turn_speed": 0.0,                     # Turn speed in degrees/sec (0 = instant rotation)
		"face_target": false,                  # Whether to rotate toward target
		"facing_axis": "+z",                   # Which axis points toward target
		"use_navmesh_normal": false,           # Use navmesh surface normal for up direction
		"self_terminate": false,               # Stop executing when target reached
		"lock_y_velocity": false               # Lock Y axis velocity (Godot's vertical axis)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "behavior",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Seek,Flee,Path Follow",
			"default": "seek"
		},
		{
			"name": "target_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Group,Node Name",
			"default": "group"
		},
		{
			"name": "target_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "arrival_distance",
			"type": TYPE_FLOAT,
			"default": 1.0
		},
		{
			"name": "velocity",
			"type": TYPE_FLOAT,
			"default": 5.0
		},
		{
			"name": "acceleration",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "turn_speed",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "face_target",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "facing_axis",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "+X,-X,+Y,-Y,+Z,-Z",
			"default": "+z"
		},
		{
			"name": "use_navmesh_normal",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "self_terminate",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "lock_y_velocity",
			"type": TYPE_BOOL,
			"default": false
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Moves toward or away from a target.\nSeek: move directly toward target\nFlee: move away from target\nPath Follow: use NavigationAgent3D to pathfind toward target.\n\n⚠ Path Follow adds an @export in the Inspector — assign your NavigationAgent3D there.",
		"behavior": "Seek: move directly toward nearest target\nFlee: move directly away from nearest target\nPath Follow: use NavigationAgent3D to navigate around obstacles",
		"target_mode": "How to find the target:\nGroup: find the nearest node in the named group\nNode Name: find a node anywhere in the scene tree by name",
		"target_name": "Group name or node name to target.\nFor Group: the nearest node in this group will be used.\nFor Node Name: finds a node anywhere in the scene tree.",
		"arrival_distance": "Distance at which the target is considered reached.",
		"velocity": "Movement speed.",
		"acceleration": "Acceleration rate. 0 = instant full speed.",
		"turn_speed": "Rotation speed in degrees/sec. 0 = instant.",
		"face_target": "Rotate the node to face the target.",
		"facing_axis": "Which local axis points toward the target.",
		"use_navmesh_normal": "Align to navmesh surface normal (Path Follow only).",
		"self_terminate": "Stop executing when target is reached.",
		"lock_y_velocity": "Lock vertical (Y) velocity to zero.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var behavior = properties.get("behavior", "seek")
	var target_mode = properties.get("target_mode", "group")
	var target_name = properties.get("target_name", properties.get("target_group", ""))  # fallback for legacy
	var arrival_distance = properties.get("arrival_distance", 1.0)
	var vel = properties.get("velocity", 5.0)
	var acceleration = properties.get("acceleration", 0.0)
	var turn_speed = properties.get("turn_speed", 0.0)
	var face_target = properties.get("face_target", false)
	var facing_axis = properties.get("facing_axis", "+z")
	var use_navmesh_normal = properties.get("use_navmesh_normal", false)
	var self_terminate = properties.get("self_terminate", false)
	var lock_y_velocity = properties.get("lock_y_velocity", false)
	
	# Normalize enums
	if typeof(behavior) == TYPE_STRING:
		behavior = behavior.to_lower().replace(" ", "_")
	if typeof(facing_axis) == TYPE_STRING:
		facing_axis = facing_axis.to_lower()
	if typeof(target_mode) == TYPE_STRING:
		target_mode = target_mode.to_lower().replace(" ", "_")
	
	var code_lines: Array[String] = []
	var member_vars: Array[String] = []
	
	# Early exit if no target name
	if target_name.is_empty():
		code_lines.append("pass  # No target name set")
		return {"actuator_code": "\n".join(code_lines)}
	
	# For path_follow, add an @export for the NavigationAgent3D and stuck-detection state
	var nav_var = "_nav_agent_%s" % chain_name
	if behavior == "path_follow":
		member_vars.append("@export var %s: NavigationAgent3D" % nav_var)
		member_vars.append("var _mt_stuck_offset_%s: Vector3 = Vector3.ZERO" % nav_var)
	
	# Get instance name for arrived flag — empty string means no flag written
	var inst_name = get_instance_name()
	
	match behavior:
		"seek", "flee":
			code_lines.append(_generate_direct_movement(behavior, target_mode, target_name, arrival_distance, vel, acceleration, turn_speed, face_target, facing_axis, lock_y_velocity, self_terminate))
		
		"path_follow":
			code_lines.append(_generate_pathfinding_movement(target_mode, target_name, nav_var, arrival_distance, vel, acceleration, turn_speed, face_target, facing_axis, use_navmesh_normal, lock_y_velocity, self_terminate))
		
		_:
			code_lines.append("pass  # Unknown behavior")
	
	var result = {
		"actuator_code": "\n".join(code_lines)
	}
	if member_vars.size() > 0:
		result["member_vars"] = member_vars
	return result


func _generate_direct_movement(behavior: String, target_mode: String, target_name: String, arrival_dist: float, vel: float, accel: float, turn: float, face: bool, axis: String, lock_y: bool, terminate: bool) -> String:
	var lines: Array[String] = []
	var escaped = target_name.replace("\"", "\\\"")
	
	# Find target based on mode
	if target_mode == "node_name":
		lines.append("var _nearest_target = get_tree().root.find_child(\"%s\", true, false)" % escaped)
		lines.append("if _nearest_target and _nearest_target is Node3D:")
		lines.append("\tvar _nearest_dist = global_position.distance_to(_nearest_target.global_position)")
	else:
		# Group mode — find nearest in group
		lines.append("var _targets = get_tree().get_nodes_in_group(\"%s\")" % escaped)
		lines.append("if _targets.size() > 0:")
		lines.append("\tvar _nearest_target = null")
		lines.append("\tvar _nearest_dist = INF")
		lines.append("\tfor _t in _targets:")
		lines.append("\t\tvar _dist = global_position.distance_to(_t.global_position)")
		lines.append("\t\tif _dist < _nearest_dist:")
		lines.append("\t\t\t_nearest_dist = _dist")
		lines.append("\t\t\t_nearest_target = _t")
		lines.append("\t")
		lines.append("\tif _nearest_target:")
	
	var indent = "\t" if target_mode == "node_name" else "\t\t"
	
	# Check arrival / self-terminate
	if terminate:
		lines.append("%sif _nearest_dist <= %.2f:" % [indent, arrival_dist])
		lines.append("%s\treturn  # Target reached, self-terminate" % indent)
	
	# Calculate movement direction
	lines.append("%svar _to_target = _nearest_target.global_position - global_position" % indent)
	
	if behavior == "flee":
		lines.append("%svar _move_dir = -_to_target.normalized()" % indent)
	else:
		lines.append("%svar _move_dir = _to_target.normalized()" % indent)
	
	# Lock Y if needed
	if lock_y:
		lines.append("%s_move_dir.y = 0.0" % indent)
		lines.append("%s_move_dir = _move_dir.normalized()" % indent)
	
	# Apply velocity
	if accel > 0.0:
		lines.append("%svar _target_vel = _move_dir * %.2f" % [indent, vel])
		lines.append("%svar _current_vel = Vector3.ZERO" % indent)
		lines.append("%svar _cb3d = (self as Node) as CharacterBody3D" % indent)
		lines.append("%sif _cb3d:" % indent)
		lines.append("%s\t_current_vel = _cb3d.velocity" % indent)
		lines.append("%svar _new_vel = _current_vel.move_toward(_target_vel, %.2f * _delta)" % [indent, accel])
	else:
		lines.append("%svar _new_vel = _move_dir * %.2f" % [indent, vel])
	
	# Face target if enabled
	if face:
		var face_target_pos = "_nearest_target.global_position" if behavior == "seek" else "global_position - _to_target"
		var face_code = _generate_look_at_code(face_target_pos, axis, turn)
		for line in face_code.split("\n"):
			lines.append(indent + line)
	
	# Apply movement
	lines.append("%svar _cb3d = (self as Node) as CharacterBody3D" % indent)
	lines.append("%sif _cb3d:" % indent)
	lines.append("%s\t_cb3d.velocity.x = _new_vel.x" % indent)
	lines.append("%s\t_cb3d.velocity.z = _new_vel.z" % indent)
	lines.append("%selse:" % indent)
	lines.append("%s\tglobal_position += _new_vel * _delta" % indent)
	
	return "\n".join(lines)


func _generate_pathfinding_movement(target_mode: String, target_name: String, nav_var: String, arrival_dist: float, vel: float, accel: float, turn: float, face: bool, axis: String, use_normal: bool, lock_y: bool, terminate: bool) -> String:
	var lines: Array[String] = []
	var escaped = target_name.replace("\"", "\\\"")

	# Check nav agent export
	lines.append("if not %s:" % nav_var)
	lines.append("\tpush_warning(\"Move Towards: No NavigationAgent3D assigned to '%s' — drag one into the inspector\")" % nav_var)
	lines.append("else:")

	# Find target based on mode
	if target_mode == "node_name":
		lines.append("\tvar _nearest_target = get_tree().root.find_child(\"%s\", true, false)" % escaped)
		lines.append("\tif _nearest_target and _nearest_target is Node3D:")
		lines.append("\t\tvar _nearest_dist = global_position.distance_to(_nearest_target.global_position)")
	else:
		# Group mode — find nearest in group
		lines.append("\tvar _targets = get_tree().get_nodes_in_group(\"%s\")" % escaped)
		lines.append("\tif _targets.size() > 0:")
		lines.append("\t\tvar _nearest_target = null")
		lines.append("\t\tvar _nearest_dist = INF")
		lines.append("\t\tfor _t in _targets:")
		lines.append("\t\t\tvar _dist = global_position.distance_to(_t.global_position)")
		lines.append("\t\t\tif _dist < _nearest_dist:")
		lines.append("\t\t\t\t_nearest_dist = _dist")
		lines.append("\t\t\t\t_nearest_target = _t")
		lines.append("\t\t")
		lines.append("\t\tif _nearest_target:")

	var indent = "\t\t" if target_mode == "node_name" else "\t\t\t"

	# Arrival check
	if terminate:
		lines.append("%sif _nearest_dist <= %.2f:" % [indent, arrival_dist])
		lines.append("%s\treturn  # Target reached, self-terminate" % indent)

	lines.append("%s%s.target_position = _nearest_target.global_position + _mt_stuck_offset_%s" % [indent, nav_var, nav_var])
	lines.append("%sif not %s.is_navigation_finished():" % [indent, nav_var])
	lines.append("%s\tvar _next_pos = %s.get_next_path_position()" % [indent, nav_var])
	lines.append("%s\tvar _move_dir = (_next_pos - global_position).normalized()" % indent)

	if lock_y:
		lines.append("%s\t_move_dir.y = 0.0" % indent)
		lines.append("%s\t_move_dir = _move_dir.normalized()" % indent)

	if accel > 0.0:
		lines.append("%s\tvar _target_vel = _move_dir * %.2f" % [indent, vel])
		lines.append("%s\tvar _current_vel = Vector3.ZERO" % indent)
		lines.append("%s\tvar _cb3d = (self as Node) as CharacterBody3D" % indent)
		lines.append("%s\tif _cb3d:" % indent)
		lines.append("%s\t\t_current_vel = _cb3d.velocity" % indent)
		lines.append("%s\tvar _new_vel = _current_vel.move_toward(_target_vel, %.2f * _delta)" % [indent, accel])
	else:
		lines.append("%s\tvar _new_vel = _move_dir * %.2f" % [indent, vel])

	if face:
		var face_code = _generate_look_at_code("_next_pos", axis, turn)
		for line in face_code.split("\n"):
			lines.append("%s\t%s" % [indent, line])

	lines.append("%s\tvar _cb3d = (self as Node) as CharacterBody3D" % indent)
	lines.append("%s\tif _cb3d:" % indent)
	lines.append("%s\t\t_cb3d.velocity.x = _new_vel.x" % indent)
	lines.append("%s\t\t_cb3d.velocity.z = _new_vel.z" % indent)
	lines.append("%s\telse:" % indent)
	lines.append("%s\t\tglobal_position += _new_vel * _delta" % indent)

	# Raycast stuck detection
	lines.append("%s\tif _mt_stuck_offset_%s == Vector3.ZERO:" % [indent, nav_var])
	lines.append("%s\t\tvar _ray_params = PhysicsRayQueryParameters3D.new()" % indent)
	lines.append("%s\t\t_ray_params.from = global_position + Vector3.UP * 0.5" % indent)
	lines.append("%s\t\t_ray_params.to = _ray_params.from + _move_dir * 1.5" % indent)
	lines.append("%s\t\t_ray_params.exclude = [get_rid(), _nearest_target.get_rid()]" % indent)
	lines.append("%s\t\tvar _ray_hit = get_world_3d().direct_space_state.intersect_ray(_ray_params)" % indent)
	lines.append("%s\t\tif _ray_hit:" % indent)
	lines.append("%s\t\t\tvar _perp = _move_dir.cross(Vector3.UP).normalized()" % indent)
	lines.append("%s\t\t\tvar _side = 1.0 if randf() > 0.5 else -1.0" % indent)
	lines.append("%s\t\t\t_mt_stuck_offset_%s = _perp * _side * randf_range(1.5, 3.0)" % [indent, nav_var])
	lines.append("%selse:" % indent)
	lines.append("%s\tif %s.is_navigation_finished():" % [indent, nav_var])
	lines.append("%s\t\t_mt_stuck_offset_%s = Vector3.ZERO" % [indent, nav_var])

	return "\n".join(lines)


func _generate_look_at_code(target_pos: String, axis: String, turn_speed: float) -> String:
	var lines: Array[String] = []
	
	# Determine which axis points forward
	var axis_vector = "Vector3.FORWARD"
	match axis:
		"+x": axis_vector = "Vector3.RIGHT"
		"-x": axis_vector = "Vector3.LEFT"
		"+y": axis_vector = "Vector3.UP"
		"-y": axis_vector = "Vector3.DOWN"
		"+z": axis_vector = "Vector3.FORWARD"
		"-z": axis_vector = "Vector3.BACK"
	
	lines.append("var _look_dir = %s - global_position" % target_pos)
	lines.append("_look_dir.y = 0.0  # Only rotate around Y axis")
	lines.append("if _look_dir.length() > 0.001:")
	
	if turn_speed > 0.0:
		# Gradual rotation
		lines.append("\tvar _target_angle = atan2(_look_dir.x, _look_dir.z)")
		lines.append("\tvar _current_angle = rotation.y")
		lines.append("\trotation.y = lerp_angle(_current_angle, _target_angle, deg_to_rad(%.2f) * _delta)" % turn_speed)
	else:
		# Instant rotation
		lines.append("\tlook_at(global_position + _look_dir, Vector3.UP)")
	
	return "\n".join(lines)
