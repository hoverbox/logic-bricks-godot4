@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Character Actuator - Unified character controller for CharacterBody3D
## Handles gravity, ground detection, and move_and_slide() in one brick.
## Jumping is handled by the separate Jump Actuator.
## Pair with an Always Sensor so it runs every frame.
## Horizontal movement is handled by separate Motion / Move Towards Actuators.
##
## Execution order (guaranteed):
##   1. Pre-process: reset horizontal velocity
##   2. This chain: apply gravity, detect ground
##   3. Other chains: motion actuators set velocity.x / velocity.z; Jump Actuator sets velocity.y
##   4. Post-process: move_and_slide()


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Character"


func _initialize_properties() -> void:
	properties = {
		# Gravity
		"gravity_strength": "9.8",
		"max_fall_speed": "50.0",
		# Grounding
		"floor_snap_length": "0.1",  # Stick to floor / small steps while grounded
		"slope_limit": "45.0",       # Degrees; converted to floor_max_angle
		# Character body surface response
		"use_acceleration": false,    # Off = Motion actuators set speed immediately; On = ease toward requested speed
		"acceleration": "1.0",       # 0..1 acceleration strength when enabled
		"friction": "1.0",           # 0..1 slowdown after input release; 0 = icy, 1 = quick stop
		"bounce": "0.0",             # 0 = no bounce, 1 = full rebound
		# Ground detection
		"ground_groups": "",         # Comma-separated groups (empty = any floor)
		"platform_groups": "",       # Comma-separated moving platform groups (empty = disabled)
		"inherit_platform_velocity_on_jump": true, # Keep horizontal platform momentum when jumping
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "gravity_strength",
			"type": TYPE_STRING,
			"default": "9.8"
		},
		{
			"name": "max_fall_speed",
			"type": TYPE_STRING,
			"default": "50.0"
		},
		{
			"name": "floor_snap_length",
			"type": TYPE_STRING,
			"default": "0.1"
		},
		{
			"name": "slope_limit",
			"type": TYPE_STRING,
			"default": "45.0"
		},
		{
			"name": "use_acceleration",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "acceleration",
			"type": TYPE_STRING,
			"default": "1.0"
		},
		{
			"name": "friction",
			"type": TYPE_STRING,
			"default": "1.0"
		},
		{
			"name": "bounce",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "ground_groups",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "platform_groups",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "e.g. moving_platform"
		},
		{
			"name": "inherit_platform_velocity_on_jump",
			"type": TYPE_BOOL,
			"default": true
		},
	]


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


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var gravity_strength = properties.get("gravity_strength", "9.8")
	var max_fall_speed = properties.get("max_fall_speed", "50.0")
	var floor_snap_length = properties.get("floor_snap_length", "0.1")
	var slope_limit = properties.get("slope_limit", "45.0")
	var use_acceleration = properties.get("use_acceleration", false)
	var acceleration = properties.get("acceleration", "1.0")
	var friction = properties.get("friction", "1.0")
	var bounce = properties.get("bounce", "0.0")
	var ground_groups = properties.get("ground_groups", "")
	var platform_groups = properties.get("platform_groups", "")
	var inherit_platform_velocity_on_jump = properties.get("inherit_platform_velocity_on_jump", true)

	# Parse ground groups
	var groups: Array[String] = []
	if typeof(ground_groups) == TYPE_STRING and not ground_groups.strip_edges().is_empty():
		for g in ground_groups.split(","):
			var trimmed = g.strip_edges()
			if not trimmed.is_empty():
				groups.append(trimmed)

	# Parse moving platform groups
	var platform_group_list: Array[String] = []
	if typeof(platform_groups) == TYPE_STRING and not platform_groups.strip_edges().is_empty():
		for g in platform_groups.split(","):
			var trimmed = g.strip_edges()
			if not trimmed.is_empty():
				platform_group_list.append(trimmed)

	var has_group_filter = groups.size() > 0
	var has_platform_filter = platform_group_list.size() > 0
	var gravity_expr = _to_expr(gravity_strength)
	var max_fall_expr = _to_expr(max_fall_speed)
	var floor_snap_expr = _to_expr(floor_snap_length)
	var slope_limit_expr = _to_expr(slope_limit)
	var acceleration_expr = _to_expr(acceleration)
	var friction_expr = _to_expr(friction)
	var bounce_expr = _to_expr(bounce)

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []
	var pre_process: Array[String] = []
	var post_process: Array[String] = []

	# Member variables — _jumps_remaining/_max_jumps are declared here so that
	# the Jump Actuator (which deduplicates member vars) can share them safely.
	member_vars.append("var _on_ground: bool = false")
	member_vars.append("var _moving_platform_delta: Vector3 = Vector3.ZERO")
	member_vars.append("var _moving_platform_velocity: Vector3 = Vector3.ZERO")
	member_vars.append("var _moving_platform_last_positions: Dictionary = {}")
	member_vars.append("var _moving_platform_current_id: int = 0")
	member_vars.append("var _moving_platform_current_node: Node3D = null")
	member_vars.append("var _inherited_platform_velocity: Vector3 = Vector3.ZERO")
	member_vars.append("var _logic_brick_external_motion_delta: Vector3 = Vector3.ZERO")
	member_vars.append("var _logic_brick_external_motion_total: Vector3 = Vector3.ZERO")
	member_vars.append("var _logic_brick_pre_slide_velocity: Vector3 = Vector3.ZERO")
	member_vars.append("var _logic_brick_character_use_acceleration: bool = false")
	member_vars.append("var _logic_brick_character_acceleration: float = 1.0")
	member_vars.append("var _logic_brick_character_motion_frame_prepared: bool = false")
	member_vars.append("var _logic_brick_character_motion_active: bool = false")
	member_vars.append("var _logic_brick_character_target_velocity: Vector3 = Vector3.ZERO")
	# Shared with Jump Actuator — dedup keeps only one declaration
	member_vars.append("var _jumps_remaining: int = 0")
	member_vars.append("var _max_jumps: int = 0")

	# Pre-process: apply normalized character friction before any motion actuators run.
	# Motion actuators mark themselves active later in the frame.
	pre_process.append("# Character motion state")
	pre_process.append("_logic_brick_character_use_acceleration = %s" % ("true" if use_acceleration else "false"))
	pre_process.append("_logic_brick_character_acceleration = clampf(float(%s), 0.0, 1.0)" % acceleration_expr)
	pre_process.append("_logic_brick_character_motion_frame_prepared = false")
	pre_process.append("_logic_brick_character_motion_active = false")
	pre_process.append("_logic_brick_character_target_velocity = Vector3.ZERO")
	pre_process.append("# Friction is normalized: 0 = no slowdown, 1 = quick stop")
	pre_process.append("var _logic_brick_friction = clampf(float(%s), 0.0, 1.0)" % friction_expr)
	pre_process.append("if _logic_brick_friction > 0.0:")
	pre_process.append("	var _logic_brick_hvel = Vector2(velocity.x, velocity.z)")
	pre_process.append("	var _logic_brick_friction_step = maxf(_logic_brick_hvel.length() * _logic_brick_friction * 12.0, _logic_brick_friction * 0.1) * delta")
	pre_process.append("	_logic_brick_hvel = _logic_brick_hvel.move_toward(Vector2.ZERO, _logic_brick_friction_step)")
	pre_process.append("	if _logic_brick_hvel.length() < 0.01:")
	pre_process.append("		_logic_brick_hvel = Vector2.ZERO")
	pre_process.append("	velocity.x = _logic_brick_hvel.x")
	pre_process.append("	velocity.z = _logic_brick_hvel.y")

	# --- CharacterBody3D grounding properties ---
	code_lines.append("# CharacterBody3D grounding settings")
	code_lines.append("floor_snap_length = maxf(0.0, float(%s))" % floor_snap_expr)
	code_lines.append("floor_max_angle = deg_to_rad(maxf(0.0, float(%s)))" % slope_limit_expr)
	code_lines.append("")

	# --- Ground detection ---
	code_lines.append("# Ground detection")
	code_lines.append("_moving_platform_delta = Vector3.ZERO")
	code_lines.append("_moving_platform_velocity = Vector3.ZERO")
	if has_group_filter:
		code_lines.append("_on_ground = false")
		code_lines.append("if is_on_floor():")
		code_lines.append("\tfor _i in get_slide_collision_count():")
		code_lines.append("\t\tvar _col = get_slide_collision(_i)")
		code_lines.append("\t\tvar _collider = _col.get_collider()")
		code_lines.append("\t\tif _collider:")

		var group_checks: Array[String] = []
		for g in groups:
			group_checks.append("_collider.is_in_group(\"%s\")" % g)
		var condition = " or ".join(group_checks)

		code_lines.append("\t\t\tif %s:" % condition)
		code_lines.append("\t\t\t\t_on_ground = true")
		code_lines.append("\t\t\t\tbreak")
	else:
		code_lines.append("_on_ground = is_on_floor()")

	# --- Moving platform displacement ---
	code_lines.append("")
	code_lines.append("# Moving platform support")
	if has_platform_filter:
		var platform_checks: Array[String] = []
		for g in platform_group_list:
			platform_checks.append("_platform_search_node.is_in_group(\"%s\")" % g)
		var platform_condition = " or ".join(platform_checks)
		code_lines.append("_moving_platform_delta = Vector3.ZERO")
		code_lines.append("_moving_platform_velocity = Vector3.ZERO")
		code_lines.append("var _matched_platform: Node3D = null")
		code_lines.append("var _found_floor_collision := false")
		code_lines.append("if _on_ground:")
		code_lines.append("\tfor _col_i in range(get_slide_collision_count()):")
		code_lines.append("\t\tvar _test_col := get_slide_collision(_col_i)")
		code_lines.append("\t\tif _test_col and _test_col.get_normal().dot(up_direction) > cos(floor_max_angle):")
		code_lines.append("\t\t\t_found_floor_collision = true")
		code_lines.append("\t\t\tvar _platform_collider = _test_col.get_collider()")
		code_lines.append("\t\t\tvar _platform_search_node: Node = _platform_collider")
		code_lines.append("\t\t\twhile _platform_search_node:")
		code_lines.append("\t\t\t\tif %s:" % platform_condition)
		code_lines.append("\t\t\t\t\tif _platform_search_node is Node3D:")
		code_lines.append("\t\t\t\t\t\t_matched_platform = _platform_search_node")
		code_lines.append("\t\t\t\t\tbreak")
		code_lines.append("\t\t\t\t_platform_search_node = _platform_search_node.get_parent()")
		code_lines.append("\t\t\tbreak")
		code_lines.append("\t# When walking, Godot may not keep a usable floor collision in the slide list every frame.")
		code_lines.append("\t# If no floor collision was reported but we are still on the floor, keep riding the same platform.")
		code_lines.append("\tif _matched_platform == null and not _found_floor_collision and _moving_platform_current_node != null:")
		code_lines.append("\t\t_matched_platform = _moving_platform_current_node")
		code_lines.append("if _on_ground and _matched_platform:")
		code_lines.append("\tvar _platform_id = _matched_platform.get_instance_id()")
		code_lines.append("\tvar _platform_pos = _matched_platform.global_position")
		code_lines.append("\tif _moving_platform_current_id == _platform_id and _moving_platform_last_positions.has(_platform_id):")
		code_lines.append("\t\t_moving_platform_delta = _platform_pos - _moving_platform_last_positions[_platform_id]")
		code_lines.append("\t\tif _delta > 0.0:")
		code_lines.append("\t\t\t_moving_platform_velocity = _moving_platform_delta / _delta")
		code_lines.append("\t_moving_platform_last_positions[_platform_id] = _platform_pos")
		code_lines.append("\t_moving_platform_current_id = _platform_id")
		code_lines.append("\t_moving_platform_current_node = _matched_platform")
		code_lines.append("else:")
		code_lines.append("\t_moving_platform_current_id = 0")
		code_lines.append("\t_moving_platform_current_node = null")
	else:
		code_lines.append("# No platform group configured; using normal CharacterBody3D floor behavior")

	# --- Gravity ---
	code_lines.append("")
	code_lines.append("# Gravity")
	code_lines.append("if _on_ground:")
	code_lines.append("\t_inherited_platform_velocity = Vector3.ZERO")
	code_lines.append("\tif velocity.y <= 0.0:")
	code_lines.append("\t\t_jumps_remaining = _max_jumps")
	code_lines.append("\tif velocity.y < 0.0:")
	code_lines.append("\t\tvelocity.y = 0.0")
	code_lines.append("else:")
	code_lines.append("\tvelocity.y -= (%s) * _delta" % gravity_expr)
	code_lines.append("\tif velocity.y < -(%s):" % max_fall_expr)
	code_lines.append("\t\tvelocity.y = -(%s)" % max_fall_expr)

	# Jump is now handled by the separate Jump Actuator.

	# Post-process: carry by platform displacement first, then run the player's move_and_slide.
	# The platform displacement is not stored in CharacterBody3D.velocity, so it cannot accumulate
	# or fight the slide solver when input starts/stops.
	post_process.append("# Track externally-applied platform motion so look/movement sensors can ignore it next frame")
	post_process.append("_logic_brick_external_motion_delta = Vector3.ZERO")
	post_process.append("# Carry character with moving platform before applying player velocity")
	post_process.append("if _on_ground and _moving_platform_delta != Vector3.ZERO:")
	post_process.append("\tglobal_position += _moving_platform_delta")
	post_process.append("\t_logic_brick_external_motion_delta += _moving_platform_delta")
	post_process.append("\t_logic_brick_external_motion_total += _moving_platform_delta")
	post_process.append("# Optional acceleration: ease toward the motion actuators' requested horizontal velocity")
	post_process.append("if _logic_brick_character_use_acceleration and _logic_brick_character_motion_active:")
	post_process.append("	var _logic_brick_current_hvel = Vector2(velocity.x, velocity.z)")
	post_process.append("	var _logic_brick_target_hvel = Vector2(_logic_brick_character_target_velocity.x, _logic_brick_character_target_velocity.z)")
	post_process.append("	var _logic_brick_accel_step = maxf(_logic_brick_target_hvel.length(), _logic_brick_current_hvel.length()) * _logic_brick_character_acceleration * 12.0 * delta")
	post_process.append("	_logic_brick_current_hvel = _logic_brick_current_hvel.move_toward(_logic_brick_target_hvel, _logic_brick_accel_step)")
	post_process.append("	velocity.x = _logic_brick_current_hvel.x")
	post_process.append("	velocity.z = _logic_brick_current_hvel.y")
	post_process.append("# Normalize diagonal movement (prevent faster diagonal speed)")
	post_process.append("var _h_vel = Vector2(velocity.x, velocity.z)")
	post_process.append("var _max_axis = maxf(absf(velocity.x), absf(velocity.z))")
	post_process.append("if _h_vel.length() > _max_axis and _max_axis > 0.0:")
	post_process.append("\t_h_vel = _h_vel.normalized() * _max_axis")
	post_process.append("\tvelocity.x = _h_vel.x")
	post_process.append("\tvelocity.z = _h_vel.y")
	post_process.append("# Add inherited platform momentum while airborne, after player speed normalization")
	post_process.append("if not _on_ground and _inherited_platform_velocity != Vector3.ZERO:")
	post_process.append("\tvelocity.x += _inherited_platform_velocity.x")
	post_process.append("\tvelocity.z += _inherited_platform_velocity.z")
	post_process.append("\t_logic_brick_external_motion_delta += _inherited_platform_velocity * delta")
	post_process.append("\t_logic_brick_external_motion_total += _inherited_platform_velocity * delta")
	post_process.append("# Move after all velocity changes are applied")
	post_process.append("_logic_brick_pre_slide_velocity = velocity")
	post_process.append("move_and_slide()")
	post_process.append("# Optional character bounce. 0 = no bounce, 1 = full rebound.")
	post_process.append("# Bounce is limited to real downward floor impacts so it does not steal normal jumps.")
	post_process.append("var _logic_brick_bounce = clampf(float(%s), 0.0, 1.0)" % bounce_expr)
	post_process.append("if _logic_brick_bounce > 0.0 and _logic_brick_pre_slide_velocity.y < -0.08:")
	post_process.append("	for _logic_brick_col_i in range(get_slide_collision_count()):")
	post_process.append("		var _logic_brick_col := get_slide_collision(_logic_brick_col_i)")
	post_process.append("		if _logic_brick_col:")
	post_process.append("			var _logic_brick_normal = _logic_brick_col.get_normal()")
	post_process.append("			var _logic_brick_floor_hit = _logic_brick_normal.dot(up_direction) > cos(floor_max_angle)")
	post_process.append("			var _logic_brick_impact_speed = -_logic_brick_pre_slide_velocity.dot(_logic_brick_normal)")
	post_process.append("			if _logic_brick_floor_hit and _logic_brick_impact_speed > 0.08:")
	post_process.append("				var _logic_brick_rebound_y = _logic_brick_impact_speed * _logic_brick_bounce")
	post_process.append("				if _logic_brick_rebound_y < 0.12:")
	post_process.append("					velocity.y = 0.0")
	post_process.append("					_on_ground = true")
	post_process.append("					_jumps_remaining = _max_jumps")
	post_process.append("				else:")
	post_process.append("					velocity.y = _logic_brick_rebound_y")
	post_process.append("					_on_ground = false")
	post_process.append("				break")

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars,
		"pre_process_code": pre_process,
		"post_process_code": post_process,
	}
