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
		"target_group": "",                    # Group name of target objects
		"nav_agent_name": "NavigationAgent3D", # Name of NavigationAgent3D child node (Path Follow only)
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
			"name": "target_group",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "nav_agent_name",
			"type": TYPE_STRING,
			"default": "NavigationAgent3D"
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


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var behavior = properties.get("behavior", "seek")
	var target_group = properties.get("target_group", "")
	var nav_agent_name = properties.get("nav_agent_name", "NavigationAgent3D")
	var arrival_distance = properties.get("arrival_distance", 1.0)
	var velocity = properties.get("velocity", 5.0)
	var acceleration = properties.get("acceleration", 0.0)
	var turn_speed = properties.get("turn_speed", 0.0)
	var face_target = properties.get("face_target", false)
	var facing_axis = properties.get("facing_axis", "+z")
	var use_navmesh_normal = properties.get("use_navmesh_normal", false)
	var self_terminate = properties.get("self_terminate", false)
	var lock_y_velocity = properties.get("lock_y_velocity", false)
	
	# Normalize enums
	if typeof(behavior) == TYPE_STRING:
		behavior = behavior.to_lower()
	if typeof(facing_axis) == TYPE_STRING:
		facing_axis = facing_axis.to_lower()
	
	var code_lines: Array[String] = []
	
	# Early exit if no target group
	if target_group.is_empty():
		code_lines.append("pass # No target group set")
		return {"actuator_code": "\n".join(code_lines)}
	
	# Get target position based on behavior
	match behavior:
		"seek", "flee":
			code_lines.append(_generate_direct_movement(behavior, target_group, arrival_distance, velocity, acceleration, turn_speed, face_target, facing_axis, lock_y_velocity, self_terminate))
		
		"path_follow":
			code_lines.append(_generate_pathfinding_movement(target_group, nav_agent_name, arrival_distance, velocity, acceleration, turn_speed, face_target, facing_axis, use_navmesh_normal, lock_y_velocity, self_terminate))
		
		_:
			code_lines.append("pass # Unknown behavior")
	
	return {
		"actuator_code": "\n".join(code_lines)
	}


func _generate_direct_movement(behavior: String, target_group: String, arrival_dist: float, vel: float, accel: float, turn: float, face: bool, axis: String, lock_y: bool, terminate: bool) -> String:
	var lines: Array[String] = []
	
	# Find nearest target in the group
	lines.append("var _targets = get_tree().get_nodes_in_group(\"%s\")" % target_group)
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
	
	# Check arrival
	if terminate:
		lines.append("\t\tif _nearest_dist <= %.2f:" % arrival_dist)
		lines.append("\t\t\treturn  # Target reached, self-terminate")
	
	# Calculate movement direction
	lines.append("\t\tvar _to_target = _nearest_target.global_position - global_position")
	
	if behavior == "flee":
		lines.append("\t\tvar _move_dir = -_to_target.normalized()")
	else:
		lines.append("\t\tvar _move_dir = _to_target.normalized()")
	
	# Lock Y if needed
	if lock_y:
		lines.append("\t\t_move_dir.y = 0.0")
		lines.append("\t\t_move_dir = _move_dir.normalized()")
	
	# Apply velocity (with or without acceleration)
	if accel > 0.0:
		lines.append("\t\tvar _target_vel = _move_dir * %.2f" % vel)
		lines.append("\t\tvar _current_vel = Vector3.ZERO")
		lines.append("\t\tif self is CharacterBody3D:")
		lines.append("\t\t\t_current_vel = velocity")
		lines.append("\t\tvar _new_vel = _current_vel.move_toward(_target_vel, %.2f * delta)" % accel)
	else:
		lines.append("\t\tvar _new_vel = _move_dir * %.2f" % vel)
	
	# Face target if enabled
	if face:
		var face_code = _generate_look_at_code("_nearest_target.global_position" if behavior == "seek" else "global_position - _to_target", axis, turn)
		for line in face_code.split("\n"):
			lines.append("\t\t" + line)
	
	# Apply movement - use move_and_slide for CharacterBody3D, direct position for others
	lines.append("\t\tif self is CharacterBody3D:")
	lines.append("\t\t\tvelocity = _new_vel")
	lines.append("\t\t\tmove_and_slide()")
	lines.append("\t\telse:")
	lines.append("\t\t\tglobal_position += _new_vel * delta")
	
	return "\n".join(lines)


func _generate_pathfinding_movement(target_group: String, agent_name: String, arrival_dist: float, vel: float, accel: float, turn: float, face: bool, axis: String, use_normal: bool, lock_y: bool, terminate: bool) -> String:
	var lines: Array[String] = []
	
	# Get nav agent
	lines.append("var _nav_agent = (get_node_or_null(\"%s\") if has_node(\"%s\") else null)" % [agent_name, agent_name])
	lines.append("if _nav_agent:")
	
	# Find nearest target in the group
	lines.append("\tvar _targets = get_tree().get_nodes_in_group(\"%s\")" % target_group)
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
	
	# Update navigation target
	lines.append("\t\t\t_nav_agent.target_position = _nearest_target.global_position")
	
	# Check arrival
	if terminate:
		lines.append("\t\t\tif _nearest_dist <= %.2f:" % arrival_dist)
		lines.append("\t\t\t\treturn  # Target reached, self-terminate")
	
	# Get next position from navigation
	lines.append("\t\t\tif not _nav_agent.is_navigation_finished():")
	lines.append("\t\t\t\tvar _next_pos = _nav_agent.get_next_path_position()")
	lines.append("\t\t\t\tvar _move_dir = (_next_pos - global_position).normalized()")
	
	# Lock Y if needed
	if lock_y:
		lines.append("\t\t\t\t_move_dir.y = 0.0")
		lines.append("\t\t\t\t_move_dir = _move_dir.normalized()")
	
	# Apply velocity (with or without acceleration)
	if accel > 0.0:
		lines.append("\t\t\t\tvar _target_vel = _move_dir * %.2f" % vel)
		lines.append("\t\t\t\tvar _current_vel = Vector3.ZERO")
		lines.append("\t\t\t\tif self is CharacterBody3D:")
		lines.append("\t\t\t\t\t_current_vel = velocity")
		lines.append("\t\t\t\tvar _new_vel = _current_vel.move_toward(_target_vel, %.2f * delta)" % accel)
	else:
		lines.append("\t\t\t\tvar _new_vel = _move_dir * %.2f" % vel)
	
	# Face target if enabled
	if face:
		var face_code = _generate_look_at_code("_next_pos", axis, turn)
		for line in face_code.split("\n"):
			lines.append("\t\t\t\t" + line)
	
	# Apply movement - use move_and_slide for CharacterBody3D, direct position for others
	lines.append("\t\t\t\tif self is CharacterBody3D:")
	lines.append("\t\t\t\t\tvelocity = _new_vel")
	lines.append("\t\t\t\t\tmove_and_slide()")
	lines.append("\t\t\t\telse:")
	lines.append("\t\t\t\t\tglobal_position += _new_vel * delta")
	
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
	lines.append("if _look_dir.length() > 0.001:")
	
	if turn_speed > 0.0:
		# Gradual rotation
		lines.append("\tvar _target_basis = Basis.looking_at(_look_dir, Vector3.UP)")
		lines.append("\tvar _rotation_speed = deg_to_rad(%.2f)" % turn_speed)
		lines.append("\tglobal_transform.basis = global_transform.basis.slerp(_target_basis, _rotation_speed * delta).orthonormalized()")
	else:
		# Instant rotation
		lines.append("\tlook_at(global_position + _look_dir, Vector3.UP)")
	
	return "\n".join(lines)
