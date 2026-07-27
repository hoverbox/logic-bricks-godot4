@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Rumble Actuator
## Trigger controller haptic vibration with manual control or preset patterns.
## Patterns run to completion independently — the sensor only needs to fire once
## to start a pattern; it plays out fully even if the sensor stops firing.
## Requires a joypad/gamepad connected — silently does nothing on keyboard/mouse.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Rumble"


func _initialize_properties() -> void:
	properties = {
		"action":       "pattern",
		"weak_motor":   0.5,
		"strong_motor": 0.5,
		"duration":     0.5,
		"pattern":      "single_pulse",
		"intensity":    1.0,
		"device":       0,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Vibrate,Stop,Pattern",
			"default": "pattern"
		},
		{
			"name": "weak_motor",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0",
			"default": 0.5
		},
		{
			"name": "strong_motor",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0",
			"default": 0.5
		},
		{
			"name": "duration",
			"type": TYPE_FLOAT,
			"default": 0.5
		},
		{
			"name": "pattern",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Single Pulse,Double Pulse,Sustained,Ramp Up,Ramp Down,Heartbeat",
			"default": "single_pulse"
		},
		{
			"name": "intensity",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0",
			"default": 1.0
		},
		{
			"name": "device",
			"type": TYPE_INT,
			"default": 0
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Trigger controller haptic vibration.\nVibrate: manual motor control for a set duration.\nStop: immediately stop all vibration.\nPattern: built-in presets that play to completion.\nThe sensor only needs to fire once — the pattern finishes even if the sensor stops.",
		"action": "Vibrate: set both motors directly for a fixed duration.\nStop: cut vibration immediately.\nPattern: choose a preset animation that runs to completion.",
		"weak_motor": "High-frequency motor (0–1). Used for light surface feedback.",
		"strong_motor": "Low-frequency motor (0–1). Used for heavy impact feedback.",
		"duration": "How long to vibrate in seconds (Vibrate mode only).",
		"pattern": "Single Pulse: one short hit — landing, collecting item.\nDouble Pulse: two quick hits — double jump, confirmation.\nSustained: constant rumble — engine, taking damage.\nRamp Up: builds from weak to strong — charging attack.\nRamp Down: strong to weak — explosion aftershock.\nHeartbeat: rhythmic pulse — low health warning.",
		"intensity": "Overall strength multiplier for the pattern (0–1).",
		"device": "Joypad device index. 0 = first connected controller.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var action       = str(properties.get("action",       "pattern")).to_lower().replace(" ", "_")
	var weak_motor   = float(properties.get("weak_motor",   0.5))
	var strong_motor = float(properties.get("strong_motor", 0.5))
	var duration     = float(properties.get("duration",     0.5))
	var pattern      = str(properties.get("pattern",        "single_pulse")).to_lower().replace(" ", "_")
	var intensity    = float(properties.get("intensity",    1.0))
	var device       = int(properties.get("device",         0))

	var member_vars:      Array[String] = []
	var code_lines:       Array[String] = []
	var post_process:     Array[String] = []
	var extra_methods:    Array[String] = []

	match action:
		"vibrate":
			code_lines.append("# Rumble: manual vibrate")
			code_lines.append("Input.start_joy_vibration(%d, %.3f, %.3f, %.3f)" % [device, weak_motor, strong_motor, duration])

		"stop":
			code_lines.append("# Rumble: stop vibration")
			code_lines.append("Input.stop_joy_vibration(%d)" % device)

		"pattern", _:
			# State vars — unique per chain instance so multiple rumble actuators coexist
			var timer_var   = "_rumble_t_%s"      % chain_name
			var dur_var     = "_rumble_dur_%s"    % chain_name
			var active_var  = "_rumble_active_%s" % chain_name
			var update_func = "_rumble_update_%s" % chain_name

			member_vars.append("var %s: float = 0.0"   % timer_var)
			member_vars.append("var %s: float = 0.0"   % dur_var)
			member_vars.append("var %s: bool  = false" % active_var)

			# Natural duration for each pattern
			var pat_duration: float
			match pattern:
				"single_pulse": pat_duration = 0.15
				"double_pulse": pat_duration = 0.40
				"sustained":    pat_duration = 0.80
				"ramp_up":      pat_duration = 0.60
				"ramp_down":    pat_duration = 0.60
				"heartbeat":    pat_duration = 1.20
				_:              pat_duration = 0.50

			# actuator_code: fires inside "if controller_active:" — starts the pattern.
			# Only starts if not already running so a held sensor doesn't restart it.
			code_lines.append("# Rumble pattern: start %s (runs to completion independently)" % pattern)
			code_lines.append("if not %s:" % active_var)
			code_lines.append("\t%s = true"  % active_var)
			code_lines.append("\t%s = 0.0"   % timer_var)
			code_lines.append("\t%s = %.3f"  % [dur_var, pat_duration])

			# post_process_code: calls the update method every frame regardless of sensor.
			# The unique method name means no dedup collisions across multiple instances.
			post_process.append("%s(delta)" % update_func)

			# The update method: advances the timer and drives the motors.
			# Lives outside all chain functions so it always runs to completion.
			var m: Array[String] = []
			m.append("func %s(_dt: float) -> void:" % update_func)
			m.append("\tif not %s:" % active_var)
			m.append("\t\treturn")
			m.append("\t%s += _dt" % timer_var)
			m.append("\tvar _t = clampf(%s / %s, 0.0, 1.0)" % [timer_var, dur_var])
			m.append("\tvar _w: float = 0.0")
			m.append("\tvar _s: float = 0.0")

			match pattern:
				"single_pulse":
					m.append("\t_s = (1.0 - _t) * %.3f" % intensity)
					m.append("\t_w = _s * 0.4")
				"double_pulse":
					m.append("\tvar _p1 = exp(-pow((_t - 0.1) / 0.08, 2.0))")
					m.append("\tvar _p2 = exp(-pow((_t - 0.6) / 0.08, 2.0))")
					m.append("\t_s = maxf(_p1, _p2) * %.3f" % intensity)
					m.append("\t_w = _s * 0.5")
				"sustained":
					m.append("\t_s = %.3f" % (intensity * strong_motor))
					m.append("\t_w = %.3f" % (intensity * weak_motor))
				"ramp_up":
					m.append("\t_s = _t * %.3f" % intensity)
					m.append("\t_w = _t * %.3f * 0.5" % intensity)
				"ramp_down":
					m.append("\t_s = (1.0 - _t) * %.3f" % intensity)
					m.append("\t_w = (1.0 - _t) * %.3f * 0.5" % intensity)
				"heartbeat":
					m.append("\tvar _beat = fmod(%s / %.3f, 1.0)" % [timer_var, pat_duration])
					m.append("\tvar _b1 = exp(-pow((_beat - 0.0)  / 0.06, 2.0))")
					m.append("\tvar _b2 = exp(-pow((_beat - 0.18) / 0.06, 2.0))")
					m.append("\t_s = maxf(_b1, _b2) * %.3f" % intensity)
					m.append("\t_w = _s * 0.3")

			m.append("\tInput.start_joy_vibration(%d, _w, _s, 0.05)" % device)
			m.append("\tif %s >= %s:" % [timer_var, dur_var])
			m.append("\t\tInput.stop_joy_vibration(%d)" % device)
			m.append("\t\t%s = false" % active_var)
			m.append("\t\t%s = 0.0"  % timer_var)

			extra_methods.append("\n".join(m))

	var result: Dictionary = {
		"actuator_code": "\n".join(code_lines),
		"member_vars":   member_vars
	}
	if post_process.size() > 0:
		result["post_process_code"] = post_process
	if extra_methods.size() > 0:
		result["methods"] = extra_methods
	return result
