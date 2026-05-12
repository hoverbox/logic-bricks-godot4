@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Gravity Actuator - Applies gravity and manages grounded state
## Pair with an Always Sensor so it runs every frame
## Works with CharacterBody3D — modifies velocity.y
## Uses pre/post process hooks to ensure correct execution order:
##   1. Pre-process: reset horizontal velocity
##   2. Chains run: motion actuators set velocity axes
##   3. Post-process: move_and_slide()


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Gravity"


func _initialize_properties() -> void:
	properties = {
		"gravity_strength": 9.8,       # Gravity force (units per second squared)
		"max_fall_speed": 50.0,        # Terminal velocity
		"ground_groups": "",           # Comma-separated groups that count as ground (empty = any floor)
		"platform_groups": "",         # Comma-separated moving platform groups (empty = disabled)
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
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var gravity_strength = properties.get("gravity_strength", 9.8)
	var max_fall_speed = properties.get("max_fall_speed", 50.0)
	var ground_groups = properties.get("ground_groups", "")
	var platform_groups = properties.get("platform_groups", "")

	# Parse comma-separated groups
	var groups: Array[String] = []
	if typeof(ground_groups) == TYPE_STRING and not ground_groups.strip_edges().is_empty():
		for g in ground_groups.split(","):
			var trimmed = g.strip_edges()
			if not trimmed.is_empty():
				groups.append(trimmed)

	# Parse comma-separated moving platform groups
	var platform_group_list: Array[String] = []
	if typeof(platform_groups) == TYPE_STRING and not platform_groups.strip_edges().is_empty():
		for g in platform_groups.split(","):
			var trimmed = g.strip_edges()
			if not trimmed.is_empty():
				platform_group_list.append(trimmed)

	var has_group_filter = groups.size() > 0
	var has_platform_filter = platform_group_list.size() > 0

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []
	var pre_process: Array[String] = []
	var post_process: Array[String] = []

	# Shared jump tracking variables — Jump Actuator sets _max_jumps via _ready()
	member_vars.append("var _jumps_remaining: int = 0")
	member_vars.append("var _max_jumps: int = 0")
	member_vars.append("var _on_ground: bool = false")
	member_vars.append("var _moving_platform_delta: Vector3 = Vector3.ZERO")
	member_vars.append("var _moving_platform_last_positions: Dictionary = {}")
	member_vars.append("var _logic_brick_external_motion_delta: Vector3 = Vector3.ZERO")
	member_vars.append("var _logic_brick_external_motion_total: Vector3 = Vector3.ZERO")

	# Pre-process: reset horizontal velocity before any chains run
	pre_process.append("# Reset horizontal velocity (motion actuators re-apply when active)")
	pre_process.append("velocity.x = 0.0")
	pre_process.append("velocity.z = 0.0")

	# Chain code: apply gravity and manage grounded state
	code_lines.append("# Apply gravity and detect ground")
	code_lines.append("_moving_platform_delta = Vector3.ZERO")

	if has_group_filter:
		# Group-based ground detection — check slide collisions for matching groups
		code_lines.append("_on_ground = false")
		code_lines.append("if is_on_floor():")
		code_lines.append("\tfor _i in get_slide_collision_count():")
		code_lines.append("\t\tvar _col = get_slide_collision(_i)")
		code_lines.append("\t\tvar _collider = _col.get_collider()")
		code_lines.append("\t\tif _collider:")

		# Build group check
		var group_checks: Array[String] = []
		for g in groups:
			group_checks.append("_collider.is_in_group(\"%s\")" % g)
		var condition = " or ".join(group_checks)

		code_lines.append("\t\t\tif %s:" % condition)
		code_lines.append("\t\t\t\t_on_ground = true")
		code_lines.append("\t\t\t\tbreak")
	else:
		# No group filter — any floor counts as ground
		code_lines.append("_on_ground = is_on_floor()")

	# Moving platform displacement
	code_lines.append("")
	code_lines.append("# Moving platform support")
	if has_platform_filter:
		var platform_checks: Array[String] = []
		for g in platform_group_list:
			platform_checks.append("_platform_search_node.is_in_group(\"%s\")" % g)
		var platform_condition = " or ".join(platform_checks)
		code_lines.append("_moving_platform_delta = Vector3.ZERO")
		code_lines.append("if _on_ground:")
		code_lines.append("\tvar _floor_col: KinematicCollision3D = null")
		code_lines.append("\tfor _col_i in range(get_slide_collision_count()):")
		code_lines.append("\t\tvar _test_col := get_slide_collision(_col_i)")
		code_lines.append("\t\tif _test_col and _test_col.get_normal().dot(up_direction) > cos(floor_max_angle):")
		code_lines.append("\t\t\t_floor_col = _test_col")
		code_lines.append("\t\t\tbreak")
		code_lines.append("\tif _floor_col:")
		code_lines.append("\t\tvar _platform_collider = _floor_col.get_collider()")
		code_lines.append("\t\tvar _platform_search_node: Node = _platform_collider")
		code_lines.append("\t\tvar _matched_platform: Node3D = null")
		code_lines.append("\t\twhile _platform_search_node:")
		code_lines.append("\t\t\tif %s:" % platform_condition)
		code_lines.append("\t\t\t\tif _platform_search_node is Node3D:")
		code_lines.append("\t\t\t\t\t_matched_platform = _platform_search_node")
		code_lines.append("\t\t\t\tbreak")
		code_lines.append("\t\t\t_platform_search_node = _platform_search_node.get_parent()")
		code_lines.append("\t\tif _matched_platform:")
		code_lines.append("\t\t\tvar _platform_id = _matched_platform.get_instance_id()")
		code_lines.append("\t\t\tvar _platform_pos = _matched_platform.global_position")
		code_lines.append("\t\t\tif _moving_platform_last_positions.has(_platform_id):")
		code_lines.append("\t\t\t\t_moving_platform_delta = _platform_pos - _moving_platform_last_positions[_platform_id]")
		code_lines.append("\t\t\t_moving_platform_last_positions[_platform_id] = _platform_pos")
	else:
		code_lines.append("# No platform group configured; using normal CharacterBody3D floor behavior")

	code_lines.append("")
	code_lines.append("if _on_ground:")
	code_lines.append("\t# Grounded — reset jump count (only if not jumping upward)")
	code_lines.append("\tif velocity.y <= 0.0:")
	code_lines.append("\t\t_jumps_remaining = _max_jumps")
	code_lines.append("\t# Snap to floor")
	code_lines.append("\tif velocity.y < 0.0:")
	code_lines.append("\t\tvelocity.y = 0.0")
	code_lines.append("else:")
	code_lines.append("\t# Airborne — apply gravity")
	code_lines.append("\tvelocity.y -= %.3f * _delta" % gravity_strength)
	code_lines.append("\t# Clamp to terminal velocity")
	code_lines.append("\tif velocity.y < -%.3f:" % max_fall_speed)
	code_lines.append("\t\tvelocity.y = -%.3f" % max_fall_speed)

	# Post-process: move_and_slide after all chains have set their velocity
	post_process.append("# Move with the platform before the character movement step")
	post_process.append("_logic_brick_external_motion_delta = Vector3.ZERO")
	post_process.append("if _on_ground and _moving_platform_delta != Vector3.ZERO:")
	post_process.append("\tglobal_position += _moving_platform_delta")
	post_process.append("\t_logic_brick_external_motion_delta += _moving_platform_delta")
	post_process.append("\t_logic_brick_external_motion_total += _moving_platform_delta")
	post_process.append("# Move after all velocity changes are applied")
	post_process.append("move_and_slide()")

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars,
		"pre_process_code": pre_process,
		"post_process_code": post_process,
	}
