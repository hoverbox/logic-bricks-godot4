@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Input Map Sensor - Detects input via Godot's Input Map actions
## Works with keyboard, gamepad, mouse buttons, or any device mapped to actions
## Configure actions in Project > Project Settings > Input Map
##
## Modes:
##   Pressed/Just Pressed/Just Released: Boolean input (button-style)
##   Axis: Reads two opposing actions as a -1 to 1 value and stores it in a variable


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Input Map"


func _initialize_properties() -> void:
	properties = {
		"input_mode": "pressed",     # pressed, just_pressed, just_released, axis
		"action_name": "ui_accept",  # Button modes: Input Map action name
		"negative_action": "",       # Axis mode: action for -1 direction
		"positive_action": "",       # Axis mode: action for +1 direction
		"invert": false,             # Flip the axis value
		"store_in": "",              # Variable name to store the value (-1 to 1)
		"deadzone": 0.1,             # Ignore values smaller than this
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "input_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Pressed,Just Pressed,Just Released,Axis",
			"default": "pressed"
		},
		{
			"name": "action_name",
			"type": TYPE_STRING,
			"default": "ui_accept"
		},
		{
			"name": "negative_action",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "positive_action",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "invert",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "store_in",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "deadzone",
			"type": TYPE_FLOAT,
			"default": 0.1
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Detects input actions from Project > Input Map.\nSupports button presses and analog joystick axis input.",
		"input_mode": "Pressed: active while held\nJust Pressed: one frame on press\nJust Released: one frame on release\nAxis: joystick/WASD axis value (-1 to 1)",
		"action_name": "Input Map action name (e.g. 'jump', 'ui_accept').",
		"negative_action": "Input Map action for the -1 direction.\nExample: 'move_left', 'move_forward', 'look_down'\nMust match an action in Project > Input Map.",
		"positive_action": "Input Map action for the +1 direction.\nExample: 'move_right', 'move_back', 'look_up'\nMust match an action in Project > Input Map.",
		"invert": "Flip the axis value.\nUseful when the direction feels backwards.",
		"store_in": "Variable name to store the axis value (-1.0 to 1.0).\nCreate this variable in the Variables tab.\nThen use it in a Motion actuator field (e.g. 'up * speed').",
		"deadzone": "Ignore stick values smaller than this.\nPrevents drift from loose joysticks.\n0.1 is a good default.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var input_mode = properties.get("input_mode", "pressed")

	# Normalize input_mode
	if typeof(input_mode) == TYPE_STRING:
		input_mode = input_mode.to_lower().replace(" ", "_")

	match input_mode:
		"pressed", "just_pressed", "just_released":
			return _generate_button_code(input_mode)
		"axis":
			return _generate_axis_code()
		_:
			return _generate_button_code("pressed")


func _generate_button_code(input_mode: String) -> Dictionary:
	var action_name = properties.get("action_name", "ui_accept")
	var code = ""

	match input_mode:
		"pressed":
			code = "var sensor_active = Input.is_action_pressed(\"%s\")" % action_name
		"just_pressed":
			code = "var sensor_active = Input.is_action_just_pressed(\"%s\")" % action_name
		"just_released":
			code = "var sensor_active = Input.is_action_just_released(\"%s\")" % action_name
		_:
			code = "var sensor_active = Input.is_action_pressed(\"%s\")" % action_name

	return {"sensor_code": code}


func _generate_axis_code() -> Dictionary:
	var neg_action = str(properties.get("negative_action", "")).strip_edges()
	var pos_action = str(properties.get("positive_action", "")).strip_edges()
	var store_var = str(properties.get("store_in", "")).strip_edges()
	var invert = properties.get("invert", false)
	var deadzone = properties.get("deadzone", 0.1)
	if typeof(deadzone) == TYPE_STRING:
		deadzone = float(deadzone) if str(deadzone).is_valid_float() else 0.1

	if neg_action.is_empty() or pos_action.is_empty():
		return {"sensor_code": "var sensor_active = false  # Axis: actions not set"}

	var code_lines: Array[String] = []
	code_lines.append("var _axis_val = Input.get_axis(\"%s\", \"%s\")" % [neg_action, pos_action])

	if invert:
		code_lines.append("_axis_val = -_axis_val")

	# Store in variable if specified
	if not store_var.is_empty():
		code_lines.append("%s = _axis_val" % store_var)

	# Active when past deadzone
	code_lines.append("var sensor_active = absf(_axis_val) > %.3f" % deadzone)

	return {"sensor_code": "\n".join(code_lines)}
