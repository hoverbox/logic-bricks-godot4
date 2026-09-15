@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Jump Actuator - Applies a jump impulse to a CharacterBody3D
##
## Designed to work alongside the Character Actuator.
## The Character Actuator manages gravity and resets _jumps_remaining when grounded.
## This actuator fires the jump impulse whenever its sensor chain activates —
## so you can trigger it from an InputMap Sensor, a Proximity Sensor, a Message Sensor,
## or any other sensor without needing a jump_action on the Character Actuator.
##
## Usage:
##   Chain 1 (Always): Character Actuator  — gravity + ground detection + move_and_slide
##   Chain 2 (InputMap "jump", Just Pressed): Jump Actuator  — player jump
##   Chain 3 (Proximity / Message / etc.):   Jump Actuator  — AI / scripted jump


func get_brick_info() -> Dictionary:
	return {
		"class": "JumpActuator",
		"name": "Character Jump",
		"type": "actuator",
		"category": "Motion",
		"description": "Applies a jump impulse to a CharacterBody3D. Pair with Character Physics for gravity and ground detection.",
		"menu_order": 20,
		"domain": "3d"
	}


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Character Jump"


func get_compatibility_error(node: Node) -> String:
	return "" if node is CharacterBody3D else "Requires CharacterBody3D"


func _initialize_properties() -> void:
	properties = {
		"jump_height": "4.5",              # Desired jump height in units; accepts numbers, variables, or expressions
		"gravity_strength": "9.8",         # Must match Character Actuator; accepts numbers, variables, or expressions
		"max_jumps": "1",                  # 1 = single jump, 2 = double jump, etc.; accepts numbers, variables, or expressions
		"inherit_platform_velocity": true, # Carry horizontal platform velocity on jump
		"ignore_jump_limit": false,       # Force jump without using the shared jump counter
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "jump_height",
			"type": TYPE_STRING,
			"default": "4.5"
		},
		{
			"name": "gravity_strength",
			"type": TYPE_STRING,
			"default": "9.8"
		},
		{
			"name": "max_jumps",
			"type": TYPE_STRING,
			"default": "1"
		},
		{
			"name": "inherit_platform_velocity",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "ignore_jump_limit",
			"type": TYPE_BOOL,
			"default": false
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Applies a jump impulse to a CharacterBody3D.\n\nPair with any sensor — InputMap, Proximity, Message, etc.\nThe Character Actuator handles gravity and resets the jump counter when grounded.\nBoth actuators share _jumps_remaining and _on_ground automatically.",
		"jump_height": "Target jump height in world units. Accepts numbers, variable names, or math expressions.",
		"gravity_strength": "Must match the gravity_strength set on the Character Actuator. Accepts numbers, variable names, or math expressions.",
		"max_jumps": "How many jumps are allowed before landing. Accepts numbers, variable names, or integer expressions. 1 = single, 2 = double jump, etc.",
		"inherit_platform_velocity": "Carry horizontal moving-platform velocity when jumping from a platform.",
		"ignore_jump_limit": "Jump even when no normal jumps remain. Useful for enemy stomps, bounce pads, knockback launches, and other forced jumps. Does not consume the normal jump counter.",
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


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var jump_height = properties.get("jump_height", "4.5")
	var gravity_strength = properties.get("gravity_strength", "9.8")
	var max_jumps = properties.get("max_jumps", "1")
	var inherit_platform_velocity = properties.get("inherit_platform_velocity", true)
	var ignore_jump_limit = properties.get("ignore_jump_limit", false)

	var member_vars: Array[String] = []
	var ready_lines: Array[String] = []
	var code_lines: Array[String] = []

	# Declare shared variables — the manager deduplicates these, so it is safe
	# if the Character Actuator also declares them. The ready_lines below always
	# run and set the authoritative values.
	member_vars.append("var _jumps_remaining: int = 0")
	member_vars.append("var _max_jumps: int = 0")
	member_vars.append("var _on_ground: bool = false")
	member_vars.append("var _moving_platform_velocity: Vector3 = Vector3.ZERO")
	member_vars.append("var _inherited_platform_velocity: Vector3 = Vector3.ZERO")

	var jump_height_expr = _to_expr(jump_height)
	var gravity_expr = _to_expr(gravity_strength)
	var max_jumps_expr = _to_expr(max_jumps)

	# _ready: configure max jumps (runs after all member-var initialisers)
	ready_lines.append("# Jump Actuator: set max_jumps")
	ready_lines.append("_max_jumps = int(%s)" % max_jumps_expr)
	ready_lines.append("_jumps_remaining = int(%s)" % max_jumps_expr)

	# Actuator body — runs when the sensor chain fires.
	# Re-sync max_jumps here instead of relying only on _ready(). This protects the
	# counter from stale generated scripts, state changes, or another shared jump
	# actuator value overwriting _max_jumps. Preserve jumps already consumed so
	# changing 1 -> 2 grants exactly one additional airborne jump, not a full refill.
	code_lines.append("# Jump — keep the configured jump count synchronized")
	code_lines.append("var _configured_max_jumps := maxi(0, int(%s))" % max_jumps_expr)
	code_lines.append("if _configured_max_jumps != _max_jumps:")
	code_lines.append("\tvar _used_jumps := maxi(0, _max_jumps - _jumps_remaining)")
	code_lines.append("\t_max_jumps = _configured_max_jumps")
	code_lines.append("\t_jumps_remaining = maxi(0, _max_jumps - _used_jumps)")
	code_lines.append("# Refresh only while truly grounded and not already moving upward")
	code_lines.append("if is_on_floor() and velocity.y <= 0.0:")
	code_lines.append("\t_jumps_remaining = _max_jumps")
	if ignore_jump_limit:
		code_lines.append("# Forced jump — ignore and preserve the normal jump counter")
		if inherit_platform_velocity:
			code_lines.append("if _on_ground and _moving_platform_velocity != Vector3.ZERO:")
			code_lines.append("\t_inherited_platform_velocity = Vector3(_moving_platform_velocity.x, 0.0, _moving_platform_velocity.z)")
		code_lines.append("velocity.y = sqrt(2.0 * (%s) * (%s))" % [gravity_expr, jump_height_expr])
	else:
		code_lines.append("if _jumps_remaining > 0:")
		if inherit_platform_velocity:
			code_lines.append("\tif _on_ground and _moving_platform_velocity != Vector3.ZERO:")
			code_lines.append("\t\t_inherited_platform_velocity = Vector3(_moving_platform_velocity.x, 0.0, _moving_platform_velocity.z)")
		code_lines.append("\t# v = sqrt(2 * gravity * height)")
		code_lines.append("\tvelocity.y = sqrt(2.0 * (%s) * (%s))" % [gravity_expr, jump_height_expr])
		code_lines.append("\t_jumps_remaining -= 1")

	var result = {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars,
	}

	if ready_lines.size() > 0:
		result["ready_code"] = ready_lines

	return result
