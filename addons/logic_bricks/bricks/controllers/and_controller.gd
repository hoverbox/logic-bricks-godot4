@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## AND logic gate controller (passes through sensor result in v1.0)
## Supports state-based logic


func _init() -> void:
	super._init()
	brick_type = BrickType.CONTROLLER
	brick_name = "AND Controller"


func _initialize_properties() -> void:
	properties = {
		"state": 1  # Which state this chain belongs to (1-30)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "state",
			"type": TYPE_INT,
			"default": 1,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1,30,1"
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	# Simple pass-through for v1.0
	var code = "var controller_active = sensor_active"
	
	return {
		"controller_code": code
	}
