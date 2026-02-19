@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Detects keyboard input via Input Map actions or direct key codes


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Keyboard Sensor"


func _initialize_properties() -> void:
	properties = {
		"input_type": "action",  # "action" or "key_code"
		"action_name": "ui_accept",  # Input map action name
		"key_code": KEY_SPACE,  # Fallback for key_code mode
		"input_mode": "pressed"  # "pressed", "just_pressed", "just_released"
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "input_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Input Action,Key Code",
			"default": "action"
		},
		{
			"name": "action_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"hint_string": "",
			"default": "ui_accept"
		},
		{
			"name": "key_code",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": _get_key_enum_string(),
			"default": KEY_SPACE
		},
		{
			"name": "input_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Pressed,Just Pressed,Just Released",
			"default": "pressed"
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var input_type = properties.get("input_type", "action")
	var action_name = properties.get("action_name", "ui_accept")
	var key_code = properties.get("key_code", KEY_SPACE)
	var input_mode = properties.get("input_mode", "pressed")
	
	var code = ""
	
	if input_type == "action":
		# Use Input Map action
		match input_mode:
			"pressed":
				code = "var sensor_active = Input.is_action_pressed(\"%s\")" % action_name
			"just_pressed":
				code = "var sensor_active = Input.is_action_just_pressed(\"%s\")" % action_name
			"just_released":
				code = "var sensor_active = Input.is_action_just_released(\"%s\")" % action_name
	else:
		# Use direct key code (legacy mode)
		match input_mode:
			"pressed":
				code = "var sensor_active = Input.is_key_pressed(%d)" % key_code
			"just_pressed":
				code = "var sensor_active = Input.is_physical_key_pressed(%d) and not Input.is_physical_key_pressed(%d)" % [key_code, key_code]
				# Note: Just pressed detection needs proper state tracking
				# This is a simplified version - real implementation would use Input.is_key_pressed with frame tracking
			"just_released":
				code = "var sensor_active = not Input.is_key_pressed(%d)" % key_code
	
	return {
		"sensor_code": code
	}


func _get_key_enum_string() -> String:
	# Common keys for the enum (only used in key_code mode)
	return "Space:32,Enter:4194309,Escape:4194305,W:87,A:65,S:83,D:68,Up:4194320,Down:4194322,Left:4194319,Right:4194321,Shift:4194304,Ctrl:4194326,Alt:4194328"
