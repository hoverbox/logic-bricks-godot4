@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Delay Sensor - Waits, activates for a duration, then either repeats or stops


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Delay"


func _initialize_properties() -> void:
	properties = {
		"delay": "0.0",    # Time in seconds before activating (float or variable name)
		"duration": "0.0", # How long to stay active (0 = one frame) (float or variable name)
		"repeat": false    # Keep repeating the delay + duration cycle
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "delay",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "duration",
			"type": TYPE_STRING,
			"default": "0.0"
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
		"delay":    "Seconds to wait before becoming active.\nAccepts a number (1.5) or a variable name (my_delay).",
		"duration": "Seconds to stay active once triggered.\n0 = active for one frame only.\nAccepts a number (1.5) or a variable name (my_duration).",
		"repeat":   "When enabled, restarts the delay after the duration ends.",
	}


## Convert a value to a code expression (mirrors motion_actuator._to_expr).
## Numbers become float literals; anything else is passed through as a variable/expression.
func _to_expr(val) -> String:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return "%.4f" % val
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.4f" % float(s)
	return s


## Returns true only when the value is a literal zero (not a variable name).
func _is_literal_zero(val) -> bool:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return val == 0.0
	var s = str(val).strip_edges()
	if s.is_empty():
		return true
	if s.is_valid_float() or s.is_valid_int():
		return float(s) == 0.0
	# It's a variable name — can't know at code-gen time, treat as non-zero
	return false


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var delay_val    = properties.get("delay", "0.0")
	var duration_val = properties.get("duration", "0.0")
	var repeat       = properties.get("repeat", false)

	var delay_expr    = _to_expr(delay_val)
	var duration_expr = _to_expr(duration_val)

	# duration_is_zero is only true when we KNOW it's zero at code-gen time.
	# If it's a variable name we must emit the runtime branch (duration > 0 path).
	var duration_is_zero = _is_literal_zero(duration_val)

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
	code_lines.append("\t\tif %s >= %s:" % [elapsed_var, delay_expr])
	code_lines.append("\t\t\t%s = 0.0" % elapsed_var)
	if duration_is_zero:
		# Zero duration — active for exactly one frame then done/repeat
		code_lines.append("\t\t\tsensor_active = true")
		if repeat:
			code_lines.append("\t\t\t%s = 0.0" % elapsed_var)
			code_lines.append("\t\t\t# phase stays 0 — repeat immediately")
		else:
			code_lines.append("\t\t\t%s = 2  # Done" % phase_var)
	else:
		code_lines.append("\t\t\t%s = 1  # Enter active window" % phase_var)
		code_lines.append("\t\t\tsensor_active = true")

	if not duration_is_zero:
		# Phase 1: active window
		code_lines.append("\t1:")
		code_lines.append("\t\tsensor_active = true")
		code_lines.append("\t\tif %s >= %s:" % [elapsed_var, duration_expr])
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
