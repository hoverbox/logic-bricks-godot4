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
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var gravity_strength = properties.get("gravity_strength", 9.8)
	var max_fall_speed = properties.get("max_fall_speed", 50.0)
	var jump_action = properties.get("jump_action", "")
	var jump_height = properties.get("jump_height", 4.5)
	var max_jumps = properties.get("max_jumps", 1)
	var ground_groups = properties.get("ground_groups", "")

	# Parse ground groups
	var groups: Array[String] = []
	if typeof(ground_groups) == TYPE_STRING and not ground_groups.strip_edges().is_empty():
		for g in ground_groups.split(","):
			var trimmed = g.strip_edges()
			if not trimmed.is_empty():
				groups.append(trimmed)

	var has_group_filter = groups.size() > 0
	var has_jump = typeof(jump_action) == TYPE_STRING and not jump_action.strip_edges().is_empty()

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []
	var pre_process: Array[String] = []
	var post_process: Array[String] = []

	# Member variables
	member_vars.append("var _on_ground: bool = false")
	member_vars.append("var _jumps_remaining: int = %d" % max_jumps)
	member_vars.append("var _max_jumps: int = %d" % max_jumps)

	# Pre-process: reset horizontal velocity before any chains run
	pre_process.append("# Reset horizontal velocity (motion actuators re-apply when active)")
	pre_process.append("velocity.x = 0.0")
	pre_process.append("velocity.z = 0.0")

	# --- Ground detection ---
	code_lines.append("# Ground detection")
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

	# --- Gravity ---
	code_lines.append("")
	code_lines.append("# Gravity")
	code_lines.append("if _on_ground:")
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
		code_lines.append("\t\tvelocity.y = sqrt(2.0 * %.3f * %.3f)" % [gravity_strength, jump_height])
		code_lines.append("\t\t_jumps_remaining -= 1")

	# Post-process: move_and_slide after all chains
	post_process.append("# Move after all velocity changes are applied")
	post_process.append("move_and_slide()")

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars,
		"pre_process_code": pre_process,
		"post_process_code": post_process,
	}
