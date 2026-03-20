@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Rumble Actuator - Controller haptic vibration
## Uses Input.start_joy_vibration() — works on gamepads
## Silently does nothing if no gamepad is connected


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Rumble"


func _initialize_properties() -> void:
	properties = {
		"action":        "vibrate",   # vibrate, stop
		"device":        "0",
		"weak_motor":    "0.5",
		"strong_motor":  "0.0",
		"duration":      "0.3",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Vibrate,Stop",
			"default": "vibrate"
		},
		{
			"name": "device",
			"type": TYPE_STRING,
			"default": "0"
		},
		{
			"name": "weak_motor",
			"type": TYPE_STRING,
			"default": "0.5"
		},
		{
			"name": "strong_motor",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "duration",
			"type": TYPE_STRING,
			"default": "0.3"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Triggers controller haptic vibration.\nSilently ignored if no gamepad is connected.",
		"action":       "Vibrate: start vibration for the given duration.\nStop: immediately stop all vibration.",
		"device":       "Gamepad device index. 0 = first controller.",
		"weak_motor":   "High-frequency motor intensity (0.0 - 1.0).\nGood for light taps and UI feedback.",
		"strong_motor": "Low-frequency motor intensity (0.0 - 1.0).\nGood for heavy impacts.",
		"duration":     "Vibration duration in seconds.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var action       = properties.get("action", "vibrate")
	var device       = _to_expr(properties.get("device",       "0"))
	var weak_motor   = _to_expr(properties.get("weak_motor",   "0.5"))
	var strong_motor = _to_expr(properties.get("strong_motor", "0.0"))
	var duration     = _to_expr(properties.get("duration",     "0.3"))

	if typeof(action) == TYPE_STRING:
		action = action.to_lower()

	var code_lines: Array[String] = []
	code_lines.append("# Rumble Actuator")

	match action:
		"vibrate":
			code_lines.append("Input.start_joy_vibration(%s, %s, %s, %s)" % [device, weak_motor, strong_motor, duration])
		"stop":
			code_lines.append("Input.stop_joy_vibration(%s)" % device)

	return {"actuator_code": "\n".join(code_lines)}


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
