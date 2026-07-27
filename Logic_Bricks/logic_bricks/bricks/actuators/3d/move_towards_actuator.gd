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
		"navigation_agent_node_name": "NavigationAgent3D",
		"behavior": "seek",                    # "seek", "flee", "path_follow"
		"target_mode": "group",                # "group", "node_name", "vector_variable"
		"target_name": "",                     # Group name or node name of target
		"target_variable": "",     # Vector3 variable target
		"arrival_distance": "1.0",               # Distance at which target is considered reached
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
			"hint_string": "Seek,Flee,Path Follow",
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
			"name": "target_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "target_variable",
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
		"_description": "Moves toward or away from a target.\nSeek: move directly toward target\nFlee: move away from target\nPath Follow: use NavigationAgent3D to pathfind toward target.\n\n⚠ Path Follow finds the NavigationAgent3D by typed node name.",
		"behavior": "Seek: move directly toward nearest target\nFlee: move directly away from nearest target\nPath Follow: use NavigationAgent3D to navigate around obstacles",
		"target_mode": "How to find the target:\nGroup: find the nearest node in the named group\nNode Name: find a node anywhere in the scene tree by name",
		"target_name": "Group name or node name to target.\nFor Group: the nearest node in this group will be used.\nFor Node Name: finds a node anywhere in the scene tree.",
		"target_variable": "Name of a local or GlobalVars Vector3 variable containing the destination position.",
		"arrival_distance": "Distance at which the target is considered reached. Accepts numbers, variable names, or math expressions.",
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
func _to_expr(val) -> String:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return "%.3f" % val
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s


## True only when the user entered a literal numeric value greater than zero.
## Variable/expression values are treated as potentially non-zero so generated code preserves them.
func _literal_gt_zero(val) -> bool:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return float(val) > 0.0
	var s = str(val).strip_edges()
	if s.is_valid_float() or s.is_valid_int():
		return float(s) > 0.0
	return true


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var navigation_agent_node_name = str(properties.get("navigation_agent_node_name", "NavigationAgent3D")).strip_edges()
	var behavior = properties.get("behavior", "seek")
	var target_mode = properties.get("target_mode", "group")
	var target_name = properties.get("target_name", properties.get("target_group", ""))  # fallback for legacy
	var target_variable = _sanitize_identifier(str(properties.get("target_variable", "")))
	var arrival_distance = properties.get("arrival_distance", "1.0")
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

	var code_lines: Array[String] = []
	var member_vars: Array[String] = []

	# Early exit if the selected target source is empty
	if target_mode == "vector_variable" and target_variable.is_empty():
		code_lines.append("push_warning(\"Move Towards Actuator: Vector Variable target mode requires a Vector3 variable name in this actuator.\")")
		return {"actuator_code": "\n".join(code_lines)}
	if target_mode != "vector_variable" and str(target_name).is_empty():
		code_lines.append("pass  # No target name set")
		return {"actuator_code": "\n".join(code_lines)}

	# For path_follow, add an @export for the NavigationAgent3D and stuck-detection state
	var nav_var = "_nav_agent_%s" % chain_name
	if behavior == "path_follow":
		member_vars.append("var %s: NavigationAgent3D = null" % nav_var)
		_append_find_node_helpers(member_vars)
		member_vars.append("var _mt_stuck_offset_%s: Vector3 = Vector3.ZERO" % nav_var)

	# Get instance name for arrived flag — empty string means no flag written
	var inst_name = get_instance_name()

	match behavior:
		"seek", "flee":
			if target_mode == "vector_variable":
				code_lines.append(_generate_vector_direct_movement(behavior, target_variable, arrival_distance, vel, acceleration, turn_speed, face_target, facing_axis, lock_y_velocity, self_terminate))
			else:
				code_lines.append(_generate_direct_movement(behavior, target_mode, target_name, arrival_distance, vel, acceleration, turn_speed, face_target, facing_axis, lock_y_velocity, self_terminate))

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

	var arrival_expr = _to_expr(arrival_dist)
	var vel_expr = _to_expr(vel)
	var accel_expr = _to_expr(accel)

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
		lines.append("%sif _cb3d:" % indent)
		lines.append("%s\t_current_vel = Vector3(_cb3d.velocity.x, 0.0, _cb3d.velocity.z)" % indent)
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
	lines.append("%sif _cb3d:" % indent)
	lines.append("%s\t_cb3d.velocity.x = _new_vel.x" % indent)
	lines.append("%s\t_cb3d.velocity.z = _new_vel.z" % indent)
	lines.append("%selse:" % indent)
	lines.append("%s\tglobal_position += _new_vel * _delta" % indent)

	return "\n".join(lines)


func _generate_pathfinding_movement(chain_name: String, target_mode: String, target_name: String, nav_var: String, nav_node_name: String, arrival_dist, vel, accel, turn, face: bool, axis: String, use_normal: bool, lock_y: bool, terminate: bool) -> String:
	var lines: Array[String] = []
	var escaped = target_name.replace("\"", "\\\"")

	# Resolve NavigationAgent3D by typed node name
	lines.append("var _nav_name_%s = \"%s\"" % [chain_name, _gd_string(nav_node_name)])
	lines.append("if _nav_name_%s.is_empty():" % chain_name)
	lines.append("\tpush_warning(\"Move Towards: No NavigationAgent3D node name set\")")
	lines.append("elif " + nav_var + " == null or " + nav_var + ".name != _nav_name_%s:" % chain_name)
	lines.append("\tvar _found_nav_%s = _lb_find_node_in_current_scene(_nav_name_%s)" % [chain_name, chain_name])
	lines.append("\tif _found_nav_%s is NavigationAgent3D:" % chain_name)
	lines.append("\t\t" + nav_var + " = _found_nav_%s" % chain_name)
	lines.append("\telif _found_nav_%s:" % chain_name)
	lines.append("\t\tpush_warning(\"Move Towards: node '\" + str(_nav_name_%s) + \"' is not a NavigationAgent3D\")" % chain_name)

	lines.append("if not %s:" % nav_var)
	lines.append("\tpush_warning(\"Move Towards: No NavigationAgent3D found for '%s'\")" % nav_var)
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

	var arrival_expr = _to_expr(arrival_dist)
	var vel_expr = _to_expr(vel)
	var accel_expr = _to_expr(accel)

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
		lines.append("%s\tif _cb3d:" % indent)
		lines.append("%s\t\t_current_vel = Vector3(_cb3d.velocity.x, 0.0, _cb3d.velocity.z)" % indent)
		lines.append("%s\tvar _new_vel = _current_vel.move_toward(_target_vel, (%s) * _delta)" % [indent, accel_expr])
	else:
		lines.append("%s\tvar _new_vel = _move_dir * (%s)" % [indent, vel_expr])

	if face:
		var face_code = _generate_look_at_code("_next_pos", axis, turn)
		for line in face_code.split("\n"):
			lines.append("%s\t%s" % [indent, line])

	if not _literal_gt_zero(accel):
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
		var turn_expr = _to_expr(turn_speed)
		lines.append("\tvar _target_angle = atan2(_look_dir.x, _look_dir.z)")
		lines.append("\tvar _current_angle = rotation.y")
		lines.append("\trotation.y = lerp_angle(_current_angle, _target_angle, deg_to_rad(%s) * _delta)" % turn_expr)
	else:
		# Instant rotation
		lines.append("\tlook_at(global_position + _look_dir, Vector3.UP)")

	return "\n".join(lines)


func _append_find_node_helpers(member_vars: Array[String]) -> void:
	member_vars.append("")
	member_vars.append("func _lb_find_node_by_name_recursive(node: Node, target_name: String) -> Node:")
	member_vars.append("\tif node == null or target_name.is_empty():")
	member_vars.append("\t\treturn null")
	member_vars.append("\tif node.name == target_name:")
	member_vars.append("\t\treturn node")
	member_vars.append("\tfor child in node.get_children():")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(child, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn null")
	member_vars.append("")
	member_vars.append("func _lb_find_node_in_current_scene(target_name: String) -> Node:")
	member_vars.append("\tvar scene_root = get_tree().current_scene")
	member_vars.append("\tif scene_root:")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(scene_root, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn _lb_find_node_by_name_recursive(get_tree().root, target_name)")

func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")


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
	var arrival_expr = _to_expr(arrival_dist)
	var vel_expr = _to_expr(vel)
	var accel_expr = _to_expr(accel)
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
		lines.append("%sif _cb3d:" % indent)
		lines.append("%s\t_current_vel = Vector3(_cb3d.velocity.x, 0.0, _cb3d.velocity.z)" % indent)
		lines.append("%svar _new_vel = _current_vel.move_toward(_target_vel, (%s) * _delta)" % [indent, accel_expr])
	else:
		lines.append("%svar _new_vel = _move_dir * (%s)" % [indent, vel_expr])
	if face:
		var face_pos = "_target_position" if behavior == "seek" else "global_position - _to_target"
		for line in _generate_look_at_code(face_pos, axis, turn).split("\n"):
			lines.append(indent + line)
	if not _literal_gt_zero(accel):
		lines.append("%svar _cb3d = (self as Node) as CharacterBody3D" % indent)
	lines.append("%sif _cb3d:" % indent)
	lines.append("%s\t_cb3d.velocity.x = _new_vel.x" % indent)
	lines.append("%s\t_cb3d.velocity.z = _new_vel.z" % indent)
	lines.append("%selse:" % indent)
	lines.append("%s\tglobal_position += _new_vel * _delta" % indent)
	lines.append("else:")
	lines.append("\tpush_warning(\"Move Towards: variable '%s' was not found or is not a Vector3\")" % variable_name)
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
	var arrival_expr = _to_expr(arrival_dist)
	var vel_expr = _to_expr(vel)
	var accel_expr = _to_expr(accel)
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
		lines.append("%s\tvar _current_vel = _cb3d.velocity if _cb3d else Vector3.ZERO" % indent)
		lines.append("%s\tvar _new_vel = _current_vel.move_toward(_target_vel, (%s) * _delta)" % [indent, accel_expr])
	else:
		lines.append("%s\tvar _new_vel = _move_dir * (%s)" % [indent, vel_expr])
		lines.append("%s\tvar _cb3d = (self as Node) as CharacterBody3D" % indent)
	if face:
		for line in _generate_look_at_code("_next_pos", axis, turn).split("\n"):
			lines.append("%s\t%s" % [indent, line])
	lines.append("%s\tif _cb3d:" % indent)
	lines.append("%s\t\t_cb3d.velocity.x = _new_vel.x" % indent)
	lines.append("%s\t\t_cb3d.velocity.z = _new_vel.z" % indent)
	lines.append("%s\telse:" % indent)
	lines.append("%s\t\tglobal_position += _new_vel * _delta" % indent)
	lines.append("else:")
	lines.append("\tpush_warning(\"Move Towards: NavigationAgent3D or Vector3 variable '%s' is unavailable\")" % variable_name)
	return "\n".join(lines)


func _sanitize_identifier(value: String) -> String:
	var sanitized := value.strip_edges().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	sanitized = regex.sub(sanitized, "", true)
	if sanitized.is_empty():
		return ""
	if sanitized.substr(0, 1).is_valid_int():
		sanitized = "var_" + sanitized
	return sanitized
