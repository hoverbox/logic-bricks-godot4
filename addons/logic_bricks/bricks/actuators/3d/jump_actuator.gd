@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Jump Actuator - Applies a jump impulse to CharacterBody3D
## Pair with an InputMap Sensor (e.g., "jump", Just Pressed) to trigger
## Works with the Gravity Actuator which resets jump count when grounded
## ground_groups should match the Gravity Actuator's ground_groups setting


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Jump"


func _initialize_properties() -> void:
	properties = {
		"jump_height": 4.5,       # Desired jump height in units
		"gravity_strength": 9.8,  # Must match Gravity Actuator (used to calculate impulse)
		"max_jumps": 1,           # 1 = single jump, 2 = double jump, etc.
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "jump_height",
			"type": TYPE_FLOAT,
			"default": 4.5
		},
		{
			"name": "gravity_strength",
			"type": TYPE_FLOAT,
			"default": 9.8
		},
		{
			"name": "max_jumps",
			"type": TYPE_INT,
			"default": 1
		},
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var jump_height = properties.get("jump_height", 4.5)
	var gravity_strength = properties.get("gravity_strength", 9.8)
	var max_jumps = properties.get("max_jumps", 1)

	var member_vars: Array[String] = []
	var ready_lines: Array[String] = []
	var code_lines: Array[String] = []

	# Declare shared variables (may be deduplicated if Gravity Actuator also declares them)
	member_vars.append("var _jumps_remaining: int = 0")
	member_vars.append("var _max_jumps: int = 0")
	member_vars.append("var _on_ground: bool = false")

	# Set the actual max_jumps value in _ready() — this always runs and overrides the default
	ready_lines.append("# Jump Actuator: configure max jumps")
	ready_lines.append("_max_jumps = %d" % max_jumps)
	ready_lines.append("_jumps_remaining = %d" % max_jumps)

	code_lines.append("# Jump — apply upward impulse if jumps remaining")
	code_lines.append("if _jumps_remaining > 0:")
	code_lines.append("\t# Calculate jump velocity: v = sqrt(2 * gravity * height)")
	code_lines.append("\tvar _jump_velocity = sqrt(2.0 * %.3f * %.3f)" % [gravity_strength, jump_height])
	code_lines.append("\tvelocity.y = _jump_velocity")
	code_lines.append("\t_jumps_remaining -= 1")

	var result = {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}

	if ready_lines.size() > 0:
		result["ready_code"] = ready_lines

	return result
