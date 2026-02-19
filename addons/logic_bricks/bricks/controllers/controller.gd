@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Controller - Logic gate that determines when actuators fire
## AND: all connected sensors must be active
## OR: any connected sensor must be active
## NAND: NOT all sensors active (fires unless all are true)
## NOR: NO sensors active (fires only when all are false)
## XOR: exactly one sensor is active


func _init() -> void:
	super._init()
	brick_type = BrickType.CONTROLLER
	brick_name = "Controller"


func _initialize_properties() -> void:
	properties = {
		"logic_mode": "and",  # and, or, nand, nor, xor
		"state": 1  # Which state this chain belongs to (1-30)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "logic_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "AND,OR,NAND,NOR,XOR",
			"default": "and"
		},
		{
			"name": "state",
			"type": TYPE_INT,
			"default": 1,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1,30,1"
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	# Logic is handled by the manager based on the logic_mode property
	return {
		"controller_code": ""
	}
