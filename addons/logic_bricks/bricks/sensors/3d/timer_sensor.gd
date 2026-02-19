@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Timer Sensor - Fires after a set duration, optionally repeating
## Useful for timed events, spawn waves, cooldowns, and periodic actions
## Resets automatically when re-entering a state (so the countdown starts fresh)


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Timer"


func _initialize_properties() -> void:
	properties = {
		"duration": 1.0,        # Seconds before firing
		"repeat": false,        # Fire once or repeat
		"start_on_ready": true, # Start counting immediately
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "duration",
			"type": TYPE_FLOAT,
			"default": 1.0
		},
		{
			"name": "repeat",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "start_on_ready",
			"type": TYPE_BOOL,
			"default": true
		},
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var duration = properties.get("duration", 1.0)
	var repeat = properties.get("repeat", false)
	var start_on_ready = properties.get("start_on_ready", true)

	var elapsed_var = "_timer_elapsed_%s" % chain_name
	var active_var = "_timer_active_%s" % chain_name
	var last_state_var = "_timer_last_state_%s" % chain_name

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("var %s: float = 0.0" % elapsed_var)
	member_vars.append("var %s: bool = %s" % [active_var, "true" if start_on_ready else "false"])
	member_vars.append("var %s: int = -1" % last_state_var)

	# Reset timer when state changes (so countdown starts fresh on state entry)
	code_lines.append("# Timer sensor")
	code_lines.append("if %s != _logic_brick_state:" % last_state_var)
	code_lines.append("\t%s = _logic_brick_state" % last_state_var)
	code_lines.append("\t%s = 0.0" % elapsed_var)
	code_lines.append("\t%s = %s" % [active_var, "true" if start_on_ready else "false"])
	code_lines.append("")
	code_lines.append("var sensor_active = false")
	code_lines.append("if %s:" % active_var)
	code_lines.append("\t%s += _delta" % elapsed_var)
	code_lines.append("\tif %s >= %.3f:" % [elapsed_var, duration])
	code_lines.append("\t\tsensor_active = true")

	if repeat:
		code_lines.append("\t\t%s -= %.3f" % [elapsed_var, duration])
	else:
		code_lines.append("\t\t%s = false" % active_var)
		code_lines.append("\t\t%s = 0.0" % elapsed_var)

	return {
		"sensor_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
