@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Character Actuator - Unified character controller for CharacterBody3D
## Handles gravity, jumping, and ground detection in one brick
## Pair with an Always Sensor so it runs every frame
## Horizontal movement is handled by separate Motion Actuators
##
## Execution order (guaranteed):
##   1. Pre-process: reset horizontal velocity
##   2. This chain: apply gravity, detect ground, handle jump input
##   3. Other chains: motion actuators set velocity.x / velocity.z
##   4. Post-process: move_and_slide()


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Character"


func _initialize_properties() -> void:
	properties = {
		# Gravity
		"gravity_strength": 9.8,
		"max_fall_speed": 50.0,
		# Jump
		"jump_action": "",           # InputMap action name (e.g., "jump"). Empty = no jump.
		"jump_height": 4.5,
		"max_jumps": 1,              # 1 = single, 2 = double, etc.
		# Ground detection
		"ground_groups": "",         # Comma-separated groups (empty = any floor)
		"platform_groups": "",       # Comma-separated moving platform groups (empty = disabled)
		"inherit_platform_velocity_on_jump": true, # Keep horizontal platform momentum when jumping
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "gravity_strength",
			"type": TYPE_FLOAT,
			"default": 9.8
		},
		{
			"name": "max_fall_speed",
			"type": TYPE_FLOAT,
			"default": 50.0
		},
		{
			"name": "jump_action",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "jump_height",
			"type": TYPE_FLOAT,
			"default": 4.5
		},
		{
			"name": "max_jumps",
			"type": TYPE_INT,
			"default": 1
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


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var gravity_strength = properties.get("gravity_strength", 9.8)
	var max_fall_speed = properties.get("max_fall_speed", 50.0)
	var jump_action = properties.get("jump_action", "")
	var jump_height = properties.get("jump_height", 4.5)
	var max_jumps = properties.get("max_jumps", 1)
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
	var has_jump = typeof(jump_action) == TYPE_STRING and not jump_action.strip_edges().is_empty()

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []
	var pre_process: Array[String] = []
	var post_process: Array[String] = []

	# Member variables
	member_vars.append("var _on_ground: bool = false")
	member_vars.append("var _moving_platform_delta: Vector3 = Vector3.ZERO")
	member_vars.append("var _moving_platform_velocity: Vector3 = Vector3.ZERO")
	member_vars.append("var _moving_platform_last_positions: Dictionary = {}")
	member_vars.append("var _moving_platform_current_id: int = 0")
	member_vars.append("var _moving_platform_current_node: Node3D = null")
	member_vars.append("var _inherited_platform_velocity: Vector3 = Vector3.ZERO")
	member_vars.append("var _logic_brick_external_motion_delta: Vector3 = Vector3.ZERO")
	member_vars.append("var _logic_brick_external_motion_total: Vector3 = Vector3.ZERO")
	member_vars.append("var _jumps_remaining: int = %d" % max_jumps)
	member_vars.append("var _max_jumps: int = %d" % max_jumps)

	# Pre-process: reset horizontal velocity before any chains run
	pre_process.append("# Reset horizontal velocity (motion actuators re-apply when active)")
	pre_process.append("velocity.x = 0.0")
	pre_process.append("velocity.z = 0.0")

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
	code_lines.append("\tvelocity.y -= %.3f * _delta" % gravity_strength)
	code_lines.append("\tif velocity.y < -%.3f:" % max_fall_speed)
	code_lines.append("\t\tvelocity.y = -%.3f" % max_fall_speed)

	# --- Jump ---
	if has_jump:
		code_lines.append("")
		code_lines.append("# Jump")
		code_lines.append("if Input.is_action_just_pressed(\"%s\"):" % jump_action.strip_edges())
		code_lines.append("\tif _jumps_remaining > 0:")
		if inherit_platform_velocity_on_jump and has_platform_filter:
			code_lines.append("\t\tif _on_ground:")
			code_lines.append("\t\t\t_inherited_platform_velocity = Vector3(_moving_platform_velocity.x, 0.0, _moving_platform_velocity.z)")
		code_lines.append("\t\tvelocity.y = sqrt(2.0 * %.3f * %.3f)" % [gravity_strength, jump_height])
		code_lines.append("\t\t_jumps_remaining -= 1")

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
	post_process.append("move_and_slide()")

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars,
		"pre_process_code": pre_process,
		"post_process_code": post_process,
	}
