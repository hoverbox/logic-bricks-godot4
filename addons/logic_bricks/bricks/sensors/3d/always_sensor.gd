@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Always active sensor - triggers every frame (like onUpdate)


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Always Sensor"


func _initialize_properties() -> void:
	properties = {
		"enabled": true  # Can be used to toggle on/off
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "enabled",
			"type": TYPE_BOOL,
			"default": true
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var enabled = properties.get("enabled", true)
	
	# Always sensor is just always true (when enabled)
	var code = ""
	if enabled:
		code = "var sensor_active = true"
	else:
		code = "var sensor_active = false"
	
	return {
		"sensor_code": code
	}
