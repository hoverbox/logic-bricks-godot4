@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Steering actuator - reusable steering behaviors for game AI and movement.
## Internal file/class identifiers retain MoveTowards for backward compatibility.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Steering"


func _initialize_properties() -> void:
	properties = {
		"navigation_agent_node_name": "NavigationAgent3D",
		"behavior": "seek",                    # seek, flee, arrive, wander, maintain_distance, orbit, path_follow
		"target_mode": "group",                # "group", "node_name", "vector_variable"
		"target_name": "",                     # Group name or node name of target
		"target_variable": "",     # Vector3 variable target
		"arrival_distance": "1.0",               # Distance at which target is considered reached
		"slowing_distance": "5.0",               # Arrive: start slowing inside this distance
		"desired_distance": "5.0",               # Maintain Distance: preferred range
		"distance_tolerance": "0.5",             # Maintain Distance: no-move band
		"orbit_distance": "5.0",                 # Orbit: preferred radius
		"orbit_direction": "clockwise",          # clockwise / counterclockwise
		"wander_amount": "45.0",                 # Wander: max heading change in degrees
		"wander_frequency": "1.5",               # Wander: seconds between heading changes
		"velocity": "5.0",                       # Movement speed; accepts numbers, variables, or expressions
		"acceleration": "0.0",                   # Acceleration (0 = instant, >0 = gradual); accepts expressions
		"turn_speed": "0.0",                     # Turn speed in degrees/sec (0 = instant rotation); accepts expressions
		"face_target": false,                  # Whether to rotate toward target
		"facing_axis": "+z",                   # Which axis points toward target
		"use_navmesh_normal": false,           # Use navmesh surface normal for up direction
		"self_terminate": false,               # Stop executing when target reached
		"lock_y_velocity": true                # Lock Y axis velocity — keep true when paired with Character Actuator so jumps aren't cancelled
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "navigation_agent_node_name",
			"type": TYPE_STRING,
			"default": "NavigationAgent3D",
			"placeholder": "NavigationAgent3D node name"
		},
		{
			"name": "behavior",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Seek,Flee,Arrive,Wander,Maintain Distance,Orbit,Path Follow",
			"default": "seek"
		},
		{
			"name": "target_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Group,Node Name,Vector Variable",
			"default": "group"
		},
		{
			"name": "target_name", "required": true, "required_label": "a target group or node name", "required_if": {"target_mode": ["group", "node_name"]}, "required_unless": {"behavior": "wander"}, "group_picker": true, "group_picker_if": {"target_mode": "group"},
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "target_variable", "required": true, "required_label": "a Vector3 target variable", "required_if": {"target_mode": "vector_variable"}, "required_unless": {"behavior": "wander"},
			"type": TYPE_STRING,
			"default": "",
			"visible_if": {"target_mode": "vector_variable"}
		},
		{
			"name": "arrival_distance",
			"type": TYPE_STRING,
			"default": "1.0"
		},
		{
			"name": "slowing_distance",
			"type": TYPE_STRING,
			"default": "5.0"
		},
		{
			"name": "desired_distance",
			"type": TYPE_STRING,
			"default": "5.0"
		},
		{
			"name": "distance_tolerance",
			"type": TYPE_STRING,
			"default": "0.5"
		},
		{
			"name": "orbit_distance",
			"type": TYPE_STRING,
			"default": "5.0"
		},
		{
			"name": "orbit_direction",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Clockwise,Counterclockwise",
			"default": "clockwise"
		},
		{
			"name": "wander_amount",
			"type": TYPE_STRING,
			"default": "45.0"
		},
		{
			"name": "wander_frequency",
			"type": TYPE_STRING,
			"default": "1.5"
		},
		{
			"name": "velocity",
			"type": TYPE_STRING,
			"default": "5.0"
		},
		{
			"name": "acceleration",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "turn_speed",
			"type": TYPE_STRING,
			"default": "0.0"
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
			"default": true
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Steers a node using reusable movement behaviors.\nSeek: move toward a target\nFlee: move away\nArrive: slow as the target is reached\nWander: move with changing randomized headings\nMaintain Distance: approach or retreat to hold a range\nOrbit: circle a target\nPath Follow: use NavigationAgent3D for obstacle-aware movement.",
		"behavior": "Seek: move directly toward the target.\nFlee: move directly away.\nArrive: approach and smoothly slow near the target.\nWander: move without a target using randomized heading changes.\nMaintain Distance: move closer or farther to stay near a desired range.\nOrbit: circle the target while correcting toward an orbit radius.\nPath Follow: use NavigationAgent3D to navigate around obstacles.",
		"target_mode": "How to find the target:\nGroup: find the nearest node in the named group\nNode Name: find a node anywhere in the scene tree by name",
		"target_name": "Group name or node name to target.\nFor Group: the nearest node in this group will be used.\nFor Node Name: finds a node anywhere in the scene tree.",
		"target_variable": "Name of a local or GlobalVars Vector3 variable containing the destination position.",
		"arrival_distance": "Distance at which the target is considered reached. Accepts numbers, variable names, or math expressions.",
		"slowing_distance": "Arrive only. Begin reducing speed when inside this distance.",
		"desired_distance": "Maintain Distance only. Preferred distance from the target.",
		"distance_tolerance": "Maintain Distance only. Allowed distance above or below the preferred range before movement begins.",
		"orbit_distance": "Orbit only. Preferred radius around the target.",
		"orbit_direction": "Orbit only. Choose clockwise or counterclockwise movement.",
		"wander_amount": "Wander only. Maximum heading change, in degrees, each time a new wander direction is chosen.",
		"wander_frequency": "Wander only. Seconds between randomized heading changes.",
		"velocity": "Movement speed. Accepts numbers, variable names, or math expressions.",
		"acceleration": "Acceleration rate. 0 = instant full speed. Accepts numbers, variable names, or math expressions.",
		"turn_speed": "Rotation speed in degrees/sec. 0 = instant. Accepts numbers, variable names, or math expressions.",
		"face_target": "Rotate the node to face the target.",
		"facing_axis": "Which local axis points toward the target.",
		"use_navmesh_normal": "Align to navmesh surface normal (Path Follow only).",
		"self_terminate": "Stop executing when target is reached.",
		"lock_y_velocity": "Lock vertical (Y) velocity to zero when calculating movement direction.\nKeep ON (default) when paired with a Character Actuator — otherwise the target's height difference can bleed into the direction vector and fight gravity / jump velocity.\nTurn OFF only if you want the enemy to fly directly toward an airborne target.",
	}


## Convert a value to a code expression.
## If it's a number (or string of a number), returns the numeric literal.
## Otherwise returns it as-is (a variable name or expression).
## True only when the user entered a literal numeric value greater than zero.
## Variable/expression values are treated as potentially non-zero so generated code preserves them.

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var navigation_agent_node_name = str(properties.get("navigation_agent_node_name", "NavigationAgent3D")).strip_edges()
	var behavior = properties.get("behavior", "seek")
	var target_mode = properties.get("target_mode", "group")
	var target_name = properties.get("target_name", properties.get("target_group", ""))  # fallback for legacy
	var target_variable = _sanitize_identifier(str(properties.get("target_variable", "")))
	var arrival_distance = properties.get("arrival_distance", "1.0")
	var slowing_distance = properties.get("slowing_distance", "5.0")
	var desired_distance = properties.get("desired_distance", "5.0")
	var distance_tolerance = properties.get("distance_tolerance", "0.5")
	var orbit_distance = properties.get("orbit_distance", "5.0")
	var orbit_direction = properties.get("orbit_direction", "clockwise")
	var wander_amount = properties.get("wander_amount", "45.0")
	var wander_frequency = properties.get("wander_frequency", "1.5")
	var vel = properties.get("velocity", "5.0")
	var acceleration = properties.get("acceleration", "0.0")
	var turn_speed = properties.get("turn_speed", "0.0")
	var face_target = properties.get("face_target", false)
	var facing_axis = properties.get("facing_axis", "+z")
	var use_navmesh_normal = properties.get("use_navmesh_normal", false)
	var self_terminate = properties.get("self_terminate", false)
	var lock_y_velocity = properties.get("lock_y_velocity", true)

	# Normalize enums
	if typeof(behavior) == TYPE_STRING:
		behavior = behavior.to_lower().replace(" ", "_")
	if typeof(facing_axis) == TYPE_STRING:
		facing_axis = facing_axis.to_lower()
	if typeof(target_mode) == TYPE_STRING:
		target_mode = target_mode.to_lower().replace(" ", "_")
	if typeof(orbit_direction) == TYPE_STRING:
		orbit_direction = orbit_direction.to_lower().replace(" ", "_")

	var code_lines: Array[String] = []
	var member_vars: Array[String] = []

	# Early exit if the selected target source is empty
	if behavior != "wander":
		if target_mode == "vector_variable" and target_variable.is_empty():
			code_lines.append("push_warning(\"Steering Actuator: Vector Variable target mode requires a Vector3 variable name in this actuator.\")")
			return {"actuator_code": "\n".join(code_lines)}
		if target_mode != "vector_variable" and str(target_name).is_empty():
			code_lines.append("pass  # Steering: no target name set")
			return {"actuator_code": "\n".join(code_lines)}

	# For path_follow, add an @export for the NavigationAgent3D and stuck-detection state
	var nav_var = "_nav_agent_%s" % chain_name
	if behavior == "path_follow":
		member_vars.append("var %s: NavigationAgent3D = null" % nav_var)
		_append_find_node_helpers(member_vars)
		member_vars.append("var _mt_stuck_offset_%s: Vector3 = Vector3.ZERO" % nav_var)

	# Wander keeps its heading between physics frames.
	if behavior == "wander":
		member_vars.append("var _steer_wander_dir_%s: Vector3 = Vector3.ZERO" % chain_name)
		member_vars.append("var _steer_wander_timer_%s: float = 0.0" % chain_name)

	match behavior:
		"seek", "flee":
			if target_mode == "vector_variable":
				code_lines.append(_generate_vector_direct_movement(behavior, target_variable, arrival_distance, vel, acceleration, turn_speed, face_target, facing_axis, lock_y_velocity, self_terminate))
			else:
				code_lines.append(_generate_direct_movement(behavior, target_mode, target_name, arrival_distance, vel, acceleration, turn_speed, face_target, facing_axis, lock_y_velocity, self_terminate))

		"arrive", "maintain_distance", "orbit":
			if target_mode == "vector_variable":
				code_lines.append(_generate_vector_advanced_movement(behavior, target_variable, arrival_distance, slowing_distance, desired_distance, distance_tolerance, orbit_distance, orbit_direction, vel, acceleration, turn_speed, face_target, facing_axis, lock_y_velocity, self_terminate))
			else:
				code_lines.append(_generate_advanced_movement(behavior, target_mode, target_name, arrival_distance, slowing_distance, desired_distance, distance_tolerance, orbit_distance, orbit_direction, vel, acceleration, turn_speed, face_target, facing_axis, lock_y_velocity, self_terminate))

		"wander":
			code_lines.append(_generate_wander_movement(chain_name, wander_amount, wander_frequency, vel, acceleration, turn_speed, face_target, facing_axis, lock_y_velocity))

		"path_follow":
			if target_mode == "vector_variable":
				code_lines.append(_generate_vector_pathfinding_movement(chain_name, target_variable, nav_var, navigation_agent_node_name, arrival_distance, vel, acceleration, turn_speed, face_target, facing_axis, use_navmesh_normal, lock_y_velocity, self_terminate))
			else:
				code_lines.append(_generate_pathfinding_movement(chain_name, target_mode, target_name, nav_var, navigation_agent_node_name, arrival_distance, vel, acceleration, turn_speed, face_target, facing_axis, use_navmesh_normal, lock_y_velocity, self_terminate))

		_:
			code_lines.append("pass  # Unknown behavior")

	var result = {
		"actuator_code": "\n".join(code_lines)
	}
	if member_vars.size() > 0:
		result["member_vars"] = member_vars
	return result


func _generate_direct_movement(behavior: String, target_mode: String, target_name: String, arrival_dist, vel, accel, turn, face: bool, axis: String, lock_y: bool, terminate: bool) -> String:
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

	var arrival_expr = _numeric_expr(arrival_dist)
	var vel_expr = _numeric_expr(vel)
	var accel_expr = _numeric_expr(accel)

	# Check arrival / self-terminate
	if terminate:
		lines.append("%sif _nearest_dist <= (%s):" % [indent, arrival_expr])
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
	if _literal_gt_zero(accel):
		lines.append("%svar _target_vel = _move_dir * (%s)" % [indent, vel_expr])
		lines.append("%svar _current_vel = Vector3.ZERO" % indent)
		lines.append("%svar _cb3d = (self as Node) as CharacterBody3D" % indent)
		lines.append("%svar _rb3d = (self as Node) as RigidBody3D" % indent)
		lines.append("%sif _cb3d:" % indent)
		lines.append("%s\t_current_vel = Vector3(_cb3d.velocity.x, 0.0, _cb3d.velocity.z)" % indent)
		lines.append("%selif _rb3d:" % indent)
		lines.append("%s\t_current_vel = Vector3(_rb3d.linear_velocity.x, 0.0, _rb3d.linear_velocity.z)" % indent)
		lines.append("%svar _new_vel = _current_vel.move_toward(_target_vel, (%s) * _delta)" % [indent, accel_expr])
	else:
		lines.append("%svar _new_vel = _move_dir * (%s)" % [indent, vel_expr])

	# Face target if enabled
	if face:
		var face_target_pos = "_nearest_target.global_position" if behavior == "seek" else "global_position - _to_target"
		var face_code = _generate_look_at_code(face_target_pos, axis, turn)
		for line in face_code.split("\n"):
			lines.append(indent + line)

	# Apply movement
	if not _literal_gt_zero(accel):
		lines.append("%svar _cb3d = (self as Node) as CharacterBody3D" % indent)
		lines.append("%svar _rb3d = (self as Node) as RigidBody3D" % indent)
	lines.append("%sif _cb3d:" % indent)
	lines.append("%s\t_cb3d.velocity.x = _new_vel.x" % indent)
	lines.append("%s\t_cb3d.velocity.z = _new_vel.z" % indent)
	lines.append("%selif _rb3d:" % indent)
	if lock_y:
		lines.append("%s\t_rb3d.linear_velocity = Vector3(_new_vel.x, _rb3d.linear_velocity.y, _new_vel.z)" % indent)
	else:
		lines.append("%s\t_rb3d.linear_velocity = _new_vel" % indent)
	lines.append("%selse:" % indent)
	lines.append("%s\tglobal_position += _new_vel * _delta" % indent)

	return "\n".join(lines)


func _generate_pathfinding_movement(chain_name: String, target_mode: String, target_name: String, nav_var: String, nav_node_name: String, arrival_dist, vel, accel, turn, face: bool, axis: String, use_normal: bool, lock_y: bool, terminate: bool) -> String:
	var lines: Array[String] = []
	var escaped = target_name.replace("\"", "\\\"")

	# Resolve NavigationAgent3D by typed node name
	lines.append("var _nav_name_%s = \"%s\"" % [chain_name, _gd_string(nav_node_name)])
	lines.append("if _nav_name_%s.is_empty():" % chain_name)
	lines.append("\tpush_warning(\"Steering: No NavigationAgent3D node name set\")")
	lines.append("elif " + nav_var + " == null or " + nav_var + ".name != _nav_name_%s:" % chain_name)
	lines.append("\tvar _found_nav_%s = _lb_find_node_in_current_scene(_nav_name_%s)" % [chain_name, chain_name])
	lines.append("\tif _found_nav_%s is NavigationAgent3D:" % chain_name)
	lines.append("\t\t" + nav_var + " = _found_nav_%s" % chain_name)
	lines.append("\telif _found_nav_%s:" % chain_name)
	lines.append("\t\tpush_warning(\"Steering: node '\" + str(_nav_name_%s) + \"' is not a NavigationAgent3D\")" % chain_name)

	lines.append("if not %s:" % nav_var)
	lines.append("\tpush_warning(\"Steering: No NavigationAgent3D found for '%s'\")" % nav_var)
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

	var arrival_expr = _numeric_expr(arrival_dist)
	var vel_expr = _numeric_expr(vel)
	var accel_expr = _numeric_expr(accel)

	# Arrival check
	if terminate:
		lines.append("%sif _nearest_dist <= (%s):" % [indent, arrival_expr])
		lines.append("%s\treturn  # Target reached, self-terminate" % indent)

	lines.append("%s%s.target_position = _nearest_target.global_position + _mt_stuck_offset_%s" % [indent, nav_var, nav_var])
	lines.append("%sif not %s.is_navigation_finished():" % [indent, nav_var])
	lines.append("%s\tvar _next_pos = %s.get_next_path_position()" % [indent, nav_var])
	lines.append("%s\tvar _move_dir = (_next_pos - global_position).normalized()" % indent)

	if lock_y:
		lines.append("%s\t_move_dir.y = 0.0" % indent)
		lines.append("%s\t_move_dir = _move_dir.normalized()" % indent)

	if _literal_gt_zero(accel):
		lines.append("%s\tvar _target_vel = _move_dir * (%s)" % [indent, vel_expr])
		lines.append("%s\tvar _current_vel = Vector3.ZERO" % indent)
		lines.append("%s\tvar _cb3d = (self as Node) as CharacterBody3D" % indent)
		lines.append("%s\tvar _rb3d = (self as Node) as RigidBody3D" % indent)
		lines.append("%s\tif _cb3d:" % indent)
		lines.append("%s\t\t_current_vel = Vector3(_cb3d.velocity.x, 0.0, _cb3d.velocity.z)" % indent)
		lines.append("%s\telif _rb3d:" % indent)
		lines.append("%s\t\t_current_vel = Vector3(_rb3d.linear_velocity.x, 0.0, _rb3d.linear_velocity.z)" % indent)
		lines.append("%s\tvar _new_vel = _current_vel.move_toward(_target_vel, (%s) * _delta)" % [indent, accel_expr])
	else:
		lines.append("%s\tvar _new_vel = _move_dir * (%s)" % [indent, vel_expr])

	if face:
		var face_code = _generate_look_at_code("_next_pos", axis, turn)
		for line in face_code.split("\n"):
			lines.append("%s\t%s" % [indent, line])

	if not _literal_gt_zero(accel):
		lines.append("%s\tvar _cb3d = (self as Node) as CharacterBody3D" % indent)
		lines.append("%s\tvar _rb3d = (self as Node) as RigidBody3D" % indent)
	lines.append("%s\tif _cb3d:" % indent)
	lines.append("%s\t\t_cb3d.velocity.x = _new_vel.x" % indent)
	lines.append("%s\t\t_cb3d.velocity.z = _new_vel.z" % indent)
	lines.append("%s\telif _rb3d:" % indent)
	if lock_y:
		lines.append("%s\t\t_rb3d.linear_velocity = Vector3(_new_vel.x, _rb3d.linear_velocity.y, _new_vel.z)" % indent)
	else:
		lines.append("%s\t\t_rb3d.linear_velocity = _new_vel" % indent)
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



func _append_advanced_body(lines: Array[String], indent: String, behavior: String, target_expr: String, arrival_dist, slowing_dist, desired_dist, tolerance, orbit_dist, orbit_direction: String, vel, accel, turn, face: bool, axis: String, lock_y: bool, terminate: bool) -> void:
	var arrival_expr = _numeric_expr(arrival_dist)
	var slowing_expr = _numeric_expr(slowing_dist)
	var desired_expr = _numeric_expr(desired_dist)
	var tolerance_expr = _numeric_expr(tolerance)
	var orbit_expr = _numeric_expr(orbit_dist)
	var vel_expr = _numeric_expr(vel)
	var accel_expr = _numeric_expr(accel)
	lines.append("%svar _to_target = %s - global_position" % [indent, target_expr])
	if lock_y:
		lines.append("%s_to_target.y = 0.0" % indent)
	lines.append("%svar _nearest_dist = _to_target.length()" % indent)
	lines.append("%svar _move_dir = Vector3.ZERO" % indent)
	lines.append("%svar _steer_speed_factor = 1.0" % indent)
	match behavior:
		"arrive":
			lines.append("%sif _nearest_dist > (%s):" % [indent, arrival_expr])
			lines.append("%s\t_move_dir = _to_target.normalized()" % indent)
			lines.append("%s\tvar _slow_span = maxf((%s) - (%s), 0.001)" % [indent, slowing_expr, arrival_expr])
			lines.append("%s\t_steer_speed_factor = clampf((_nearest_dist - (%s)) / _slow_span, 0.0, 1.0)" % [indent, arrival_expr])
			if terminate:
				lines.append("%selif _nearest_dist <= (%s):" % [indent, arrival_expr])
				lines.append("%s\treturn" % indent)
		"maintain_distance":
			lines.append("%sif _nearest_dist > (%s) + (%s):" % [indent, desired_expr, tolerance_expr])
			lines.append("%s\t_move_dir = _to_target.normalized()" % indent)
			lines.append("%selif _nearest_dist < maxf((%s) - (%s), 0.0) and _nearest_dist > 0.001:" % [indent, desired_expr, tolerance_expr])
			lines.append("%s\t_move_dir = -_to_target.normalized()" % indent)
		"orbit":
			lines.append("%sif _nearest_dist > 0.001:" % indent)
			lines.append("%s\tvar _radial = _to_target.normalized()" % indent)
			var tangent_expr = "Vector3(-_radial.z, 0.0, _radial.x)" if orbit_direction == "clockwise" else "Vector3(_radial.z, 0.0, -_radial.x)"
			lines.append("%s\tvar _tangent = %s" % [indent, tangent_expr])
			lines.append("%s\tvar _radius_error = (_nearest_dist - (%s)) / maxf((%s), 0.001)" % [indent, orbit_expr, orbit_expr])
			lines.append("%s\t_move_dir = (_tangent + _radial * clampf(_radius_error, -1.0, 1.0)).normalized()" % indent)
	if lock_y:
		lines.append("%s_move_dir.y = 0.0" % indent)
		lines.append("%sif _move_dir.length_squared() > 0.000001:" % indent)
		lines.append("%s\t_move_dir = _move_dir.normalized()" % indent)
	if _literal_gt_zero(accel):
		lines.append("%svar _target_vel = _move_dir * (%s) * _steer_speed_factor" % [indent, vel_expr])
		lines.append("%svar _cb3d = (self as Node) as CharacterBody3D" % indent)
		lines.append("%svar _rb3d = (self as Node) as RigidBody3D" % indent)
		lines.append("%svar _current_vel = Vector3(_cb3d.velocity.x, 0.0, _cb3d.velocity.z) if _cb3d else (Vector3(_rb3d.linear_velocity.x, 0.0, _rb3d.linear_velocity.z) if _rb3d else Vector3.ZERO)" % indent)
		lines.append("%svar _new_vel = _current_vel.move_toward(_target_vel, (%s) * _delta)" % [indent, accel_expr])
	else:
		lines.append("%svar _new_vel = _move_dir * (%s) * _steer_speed_factor" % [indent, vel_expr])
		lines.append("%svar _cb3d = (self as Node) as CharacterBody3D" % indent)
		lines.append("%svar _rb3d = (self as Node) as RigidBody3D" % indent)
	if face:
		for line in _generate_look_at_code(target_expr, axis, turn).split("\n"):
			lines.append(indent + line)
	lines.append("%sif _cb3d:" % indent)
	lines.append("%s\t_cb3d.velocity.x = _new_vel.x" % indent)
	lines.append("%s\t_cb3d.velocity.z = _new_vel.z" % indent)
	lines.append("%selif _rb3d:" % indent)
	if lock_y:
		lines.append("%s\t_rb3d.linear_velocity = Vector3(_new_vel.x, _rb3d.linear_velocity.y, _new_vel.z)" % indent)
	else:
		lines.append("%s\t_rb3d.linear_velocity = _new_vel" % indent)
	lines.append("%selse:" % indent)
	lines.append("%s\tglobal_position += _new_vel * _delta" % indent)


func _generate_advanced_movement(behavior: String, target_mode: String, target_name: String, arrival_dist, slowing_dist, desired_dist, tolerance, orbit_dist, orbit_direction: String, vel, accel, turn, face: bool, axis: String, lock_y: bool, terminate: bool) -> String:
	var lines: Array[String] = []
	var escaped = target_name.replace("\"", "\\\"")
	if target_mode == "node_name":
		lines.append("var _nearest_target = get_tree().root.find_child(\"%s\", true, false)" % escaped)
		lines.append("if _nearest_target and _nearest_target is Node3D:")
		_append_advanced_body(lines, "\t", behavior, "_nearest_target.global_position", arrival_dist, slowing_dist, desired_dist, tolerance, orbit_dist, orbit_direction, vel, accel, turn, face, axis, lock_y, terminate)
	else:
		lines.append("var _targets = get_tree().get_nodes_in_group(\"%s\")" % escaped)
		lines.append("if _targets.size() > 0:")
		lines.append("\tvar _nearest_target = null")
		lines.append("\tvar _nearest_dist_pick = INF")
		lines.append("\tfor _t in _targets:")
		lines.append("\t\tif _t is Node3D and _t != self:")
		lines.append("\t\t\tvar _dist_pick = global_position.distance_squared_to(_t.global_position)")
		lines.append("\t\t\tif _dist_pick < _nearest_dist_pick:")
		lines.append("\t\t\t\t_nearest_dist_pick = _dist_pick")
		lines.append("\t\t\t\t_nearest_target = _t")
		lines.append("\tif _nearest_target:")
		_append_advanced_body(lines, "\t\t", behavior, "_nearest_target.global_position", arrival_dist, slowing_dist, desired_dist, tolerance, orbit_dist, orbit_direction, vel, accel, turn, face, axis, lock_y, terminate)
	return "\n".join(lines)


func _generate_vector_advanced_movement(behavior: String, variable_name: String, arrival_dist, slowing_dist, desired_dist, tolerance, orbit_dist, orbit_direction: String, vel, accel, turn, face: bool, axis: String, lock_y: bool, terminate: bool) -> String:
	var lines := _generate_vector_resolve_lines(variable_name, "_target_position")
	lines.append("if _target_position is Vector3:")
	_append_advanced_body(lines, "\t", behavior, "_target_position", arrival_dist, slowing_dist, desired_dist, tolerance, orbit_dist, orbit_direction, vel, accel, turn, face, axis, lock_y, terminate)
	lines.append("else:")
	lines.append("\tpush_warning(\"Steering: variable '%s' was not found or is not a Vector3\")" % variable_name)
	return "\n".join(lines)


func _generate_wander_movement(chain_name: String, amount, frequency, vel, accel, turn, face: bool, axis: String, lock_y: bool) -> String:
	var lines: Array[String] = []
	var amount_expr = _numeric_expr(amount)
	var frequency_expr = _numeric_expr(frequency)
	var vel_expr = _numeric_expr(vel)
	var accel_expr = _numeric_expr(accel)
	var dir_var = "_steer_wander_dir_%s" % chain_name
	var timer_var = "_steer_wander_timer_%s" % chain_name
	lines.append("%s -= _delta" % timer_var)
	lines.append("if %s.length_squared() < 0.000001:" % dir_var)
	lines.append("\tvar _wander_start_angle = randf_range(0.0, TAU)")
	lines.append("\t%s = Vector3(sin(_wander_start_angle), 0.0, cos(_wander_start_angle)).normalized()" % dir_var)
	lines.append("\t%s = 0.0" % timer_var)
	lines.append("if %s <= 0.0:" % timer_var)
	lines.append("\tvar _wander_turn = deg_to_rad(randf_range(-absf(float(%s)), absf(float(%s))))" % [amount_expr, amount_expr])
	lines.append("\t%s = %s.rotated(Vector3.UP, _wander_turn).normalized()" % [dir_var, dir_var])
	lines.append("\t%s = maxf(float(%s), 0.01)" % [timer_var, frequency_expr])
	lines.append("var _move_dir = %s" % dir_var)
	if lock_y:
		lines.append("_move_dir.y = 0.0")
		lines.append("_move_dir = _move_dir.normalized()")
	if _literal_gt_zero(accel):
		lines.append("var _target_vel = _move_dir * (%s)" % vel_expr)
		lines.append("var _cb3d = (self as Node) as CharacterBody3D")
		lines.append("var _rb3d = (self as Node) as RigidBody3D")
		lines.append("var _current_vel = Vector3(_cb3d.velocity.x, 0.0, _cb3d.velocity.z) if _cb3d else (Vector3(_rb3d.linear_velocity.x, 0.0, _rb3d.linear_velocity.z) if _rb3d else Vector3.ZERO)")
		lines.append("var _new_vel = _current_vel.move_toward(_target_vel, (%s) * _delta)" % accel_expr)
	else:
		lines.append("var _new_vel = _move_dir * (%s)" % vel_expr)
		lines.append("var _cb3d = (self as Node) as CharacterBody3D")
		lines.append("var _rb3d = (self as Node) as RigidBody3D")
	if face:
		for line in _generate_look_at_code("global_position + _move_dir", axis, turn).split("\n"):
			lines.append(line)
	lines.append("if _cb3d:")
	lines.append("\t_cb3d.velocity.x = _new_vel.x")
	lines.append("\t_cb3d.velocity.z = _new_vel.z")
	lines.append("elif _rb3d:")
	if lock_y:
		lines.append("\t_rb3d.linear_velocity = Vector3(_new_vel.x, _rb3d.linear_velocity.y, _new_vel.z)")
	else:
		lines.append("\t_rb3d.linear_velocity = _new_vel")
	lines.append("else:")
	lines.append("\tglobal_position += _new_vel * _delta")
	return "\n".join(lines)


func _generate_look_at_code(target_pos: String, axis: String, turn_speed) -> String:
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

	if _literal_gt_zero(turn_speed):
		# Gradual rotation
		var turn_expr = _numeric_expr(turn_speed)
		lines.append("\tvar _target_angle = atan2(_look_dir.x, _look_dir.z)")
		lines.append("\tvar _current_angle = rotation.y")
		lines.append("\trotation.y = lerp_angle(_current_angle, _target_angle, deg_to_rad(%s) * _delta)" % turn_expr)
	else:
		# Instant rotation
		lines.append("\tlook_at(global_position + _look_dir, Vector3.UP)")

	return "\n".join(lines)


func _generate_vector_resolve_lines(variable_name: String, value_name: String, indent: String = "") -> Array[String]:
	var lines: Array[String] = []
	lines.append("%svar %s = null" % [indent, value_name])
	lines.append("%sif \"%s\" in self:" % [indent, variable_name])
	lines.append("%s\t%s = get(\"%s\")" % [indent, value_name, variable_name])
	lines.append("%selse:" % indent)
	lines.append("%s\tvar _move_globals = get_node_or_null(\"/root/GlobalVars\")" % indent)
	lines.append("%s\tif _move_globals and \"%s\" in _move_globals:" % [indent, variable_name])
	lines.append("%s\t\t%s = _move_globals.get(\"%s\")" % [indent, value_name, variable_name])
	return lines


func _generate_vector_direct_movement(behavior: String, variable_name: String, arrival_dist, vel, accel, turn, face: bool, axis: String, lock_y: bool, terminate: bool) -> String:
	var lines := _generate_vector_resolve_lines(variable_name, "_target_position")
	lines.append("if _target_position is Vector3:")
	var indent := "\t"
	var arrival_expr = _numeric_expr(arrival_dist)
	var vel_expr = _numeric_expr(vel)
	var accel_expr = _numeric_expr(accel)
	lines.append("%svar _nearest_dist = global_position.distance_to(_target_position)" % indent)
	if terminate:
		lines.append("%sif _nearest_dist <= (%s):" % [indent, arrival_expr])
		lines.append("%s\treturn" % indent)
	lines.append("%svar _to_target = _target_position - global_position" % indent)
	lines.append("%svar _move_dir = %s_to_target.normalized()" % [indent, "-" if behavior == "flee" else ""])
	if lock_y:
		lines.append("%s_move_dir.y = 0.0" % indent)
		lines.append("%s_move_dir = _move_dir.normalized()" % indent)
	if _literal_gt_zero(accel):
		lines.append("%svar _target_vel = _move_dir * (%s)" % [indent, vel_expr])
		lines.append("%svar _current_vel = Vector3.ZERO" % indent)
		lines.append("%svar _cb3d = (self as Node) as CharacterBody3D" % indent)
		lines.append("%svar _rb3d = (self as Node) as RigidBody3D" % indent)
		lines.append("%sif _cb3d:" % indent)
		lines.append("%s\t_current_vel = Vector3(_cb3d.velocity.x, 0.0, _cb3d.velocity.z)" % indent)
		lines.append("%selif _rb3d:" % indent)
		lines.append("%s\t_current_vel = Vector3(_rb3d.linear_velocity.x, 0.0, _rb3d.linear_velocity.z)" % indent)
		lines.append("%svar _new_vel = _current_vel.move_toward(_target_vel, (%s) * _delta)" % [indent, accel_expr])
	else:
		lines.append("%svar _new_vel = _move_dir * (%s)" % [indent, vel_expr])
	if face:
		var face_pos = "_target_position" if behavior == "seek" else "global_position - _to_target"
		for line in _generate_look_at_code(face_pos, axis, turn).split("\n"):
			lines.append(indent + line)
	if not _literal_gt_zero(accel):
		lines.append("%svar _cb3d = (self as Node) as CharacterBody3D" % indent)
		lines.append("%svar _rb3d = (self as Node) as RigidBody3D" % indent)
	lines.append("%sif _cb3d:" % indent)
	lines.append("%s\t_cb3d.velocity.x = _new_vel.x" % indent)
	lines.append("%s\t_cb3d.velocity.z = _new_vel.z" % indent)
	lines.append("%selif _rb3d:" % indent)
	if lock_y:
		lines.append("%s\t_rb3d.linear_velocity = Vector3(_new_vel.x, _rb3d.linear_velocity.y, _new_vel.z)" % indent)
	else:
		lines.append("%s\t_rb3d.linear_velocity = _new_vel" % indent)
	lines.append("%selse:" % indent)
	lines.append("%s\tglobal_position += _new_vel * _delta" % indent)
	lines.append("else:")
	lines.append("\tpush_warning(\"Steering: variable '%s' was not found or is not a Vector3\")" % variable_name)
	return "\n".join(lines)


func _generate_vector_pathfinding_movement(chain_name: String, variable_name: String, nav_var: String, nav_node_name: String, arrival_dist, vel, accel, turn, face: bool, axis: String, use_normal: bool, lock_y: bool, terminate: bool) -> String:
	var lines: Array[String] = []
	lines.append("var _nav_name_%s = \"%s\"" % [chain_name, _gd_string(nav_node_name)])
	lines.append("if %s == null or %s.name != _nav_name_%s:" % [nav_var, nav_var, chain_name])
	lines.append("\tvar _found_nav_%s = _lb_find_node_in_current_scene(_nav_name_%s)" % [chain_name, chain_name])
	lines.append("\tif _found_nav_%s is NavigationAgent3D:" % chain_name)
	lines.append("\t\t%s = _found_nav_%s" % [nav_var, chain_name])
	lines.append_array(_generate_vector_resolve_lines(variable_name, "_target_position"))
	lines.append("if %s and _target_position is Vector3:" % nav_var)
	var indent := "\t"
	var arrival_expr = _numeric_expr(arrival_dist)
	var vel_expr = _numeric_expr(vel)
	var accel_expr = _numeric_expr(accel)
	if terminate:
		lines.append("%sif global_position.distance_to(_target_position) <= (%s):" % [indent, arrival_expr])
		lines.append("%s\treturn" % indent)
	lines.append("%s%s.target_position = _target_position + _mt_stuck_offset_%s" % [indent, nav_var, nav_var])
	lines.append("%sif not %s.is_navigation_finished():" % [indent, nav_var])
	lines.append("%s\tvar _next_pos = %s.get_next_path_position()" % [indent, nav_var])
	lines.append("%s\tvar _move_dir = (_next_pos - global_position).normalized()" % indent)
	if lock_y:
		lines.append("%s\t_move_dir.y = 0.0" % indent)
		lines.append("%s\t_move_dir = _move_dir.normalized()" % indent)
	if _literal_gt_zero(accel):
		lines.append("%s\tvar _target_vel = _move_dir * (%s)" % [indent, vel_expr])
		lines.append("%s\tvar _cb3d = (self as Node) as CharacterBody3D" % indent)
		lines.append("%s\tvar _rb3d = (self as Node) as RigidBody3D" % indent)
		lines.append("%s\tvar _current_vel = _cb3d.velocity if _cb3d else (_rb3d.linear_velocity if _rb3d else Vector3.ZERO)" % indent)
		lines.append("%s\tvar _new_vel = _current_vel.move_toward(_target_vel, (%s) * _delta)" % [indent, accel_expr])
	else:
		lines.append("%s\tvar _new_vel = _move_dir * (%s)" % [indent, vel_expr])
		lines.append("%s\tvar _cb3d = (self as Node) as CharacterBody3D" % indent)
		lines.append("%s\tvar _rb3d = (self as Node) as RigidBody3D" % indent)
	if face:
		for line in _generate_look_at_code("_next_pos", axis, turn).split("\n"):
			lines.append("%s\t%s" % [indent, line])
	lines.append("%s\tif _cb3d:" % indent)
	lines.append("%s\t\t_cb3d.velocity.x = _new_vel.x" % indent)
	lines.append("%s\t\t_cb3d.velocity.z = _new_vel.z" % indent)
	lines.append("%s\telif _rb3d:" % indent)
	if lock_y:
		lines.append("%s\t\t_rb3d.linear_velocity = Vector3(_new_vel.x, _rb3d.linear_velocity.y, _new_vel.z)" % indent)
	else:
		lines.append("%s\t\t_rb3d.linear_velocity = _new_vel" % indent)
	lines.append("%s\telse:" % indent)
	lines.append("%s\t\tglobal_position += _new_vel * _delta" % indent)
	lines.append("else:")
	lines.append("\tpush_warning(\"Steering: NavigationAgent3D or Vector3 variable '%s' is unavailable\")" % variable_name)
	return "\n".join(lines)
