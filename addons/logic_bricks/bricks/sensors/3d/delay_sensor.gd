@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Delay Sensor - Waits, activates for a duration, then either repeats or stops


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Delay"


func _initialize_properties() -> void:
	properties = {
		"delay": 0.0,      # Time in seconds before activating
		"duration": 0.0,   # How long to stay active (0 = one frame)
		"repeat": false    # Keep repeating the delay + duration cycle
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "delay",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "duration",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "repeat",
			"type": TYPE_BOOL,
			"default": false
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Waits for Delay seconds, then stays active for Duration seconds.\nRepeat cycles the whole sequence.",
		"delay":    "Seconds to wait before becoming active.",
		"duration": "Seconds to stay active once triggered.\n0 = active for one frame only.",
		"repeat":   "When enabled, restarts the delay after the duration ends.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var delay    = float(properties.get("delay", 0.0))
	var duration = float(properties.get("duration", 0.0))
	var repeat   = properties.get("repeat", false)

	var elapsed_var = "_delay_elapsed_%s" % chain_name
	var phase_var   = "_delay_phase_%s" % chain_name
	# phase: 0 = counting down, 1 = active window, 2 = done (no-repeat only)

	var member_vars: Array[String] = [
		"var %s: float = 0.0" % elapsed_var,
		"var %s: int = 0" % phase_var,
	]

	var code_lines: Array[String] = []
	code_lines.append("# Delay sensor")
	code_lines.append("var sensor_active = false")
	code_lines.append("%s += _delta" % elapsed_var)
	code_lines.append("match %s:" % phase_var)

	# Phase 0: waiting for delay
	code_lines.append("\t0:")
	code_lines.append("\t\tif %s >= %.4f:" % [elapsed_var, delay])
	code_lines.append("\t\t\t%s = 0.0" % elapsed_var)
	if duration > 0.0:
		code_lines.append("\t\t\t%s = 1  # Enter active window" % phase_var)
		code_lines.append("\t\t\tsensor_active = true")
	else:
		# Zero duration — active for exactly one frame then done/repeat
		code_lines.append("\t\t\tsensor_active = true")
		if repeat:
			code_lines.append("\t\t\t%s = 0.0" % elapsed_var)
			code_lines.append("\t\t\t# phase stays 0 — repeat immediately")
		else:
			code_lines.append("\t\t\t%s = 2  # Done" % phase_var)

	if duration > 0.0:
		# Phase 1: active window
		code_lines.append("\t1:")
		code_lines.append("\t\tsensor_active = true")
		code_lines.append("\t\tif %s >= %.4f:" % [elapsed_var, duration])
		code_lines.append("\t\t\t%s = 0.0" % elapsed_var)
		if repeat:
			code_lines.append("\t\t\t%s = 0  # Repeat: back to delay phase" % phase_var)
		else:
			code_lines.append("\t\t\t%s = 2  # Done" % phase_var)

	# Phase 2: done — sensor stays inactive forever (no-repeat)
	code_lines.append("\t2:")
	code_lines.append("\t\tpass  # Done, no repeat")

	return {
		"sensor_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
