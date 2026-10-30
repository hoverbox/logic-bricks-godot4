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
		"logic_mode": "and",
		"all_states": false,
		"state_id": ""
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
			"name": "all_states",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "state_id",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "__STATE_LIST__",
			"default": ""
		}
	]


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var all_states = properties.get("all_states", false)
	for child in _get_field_names():
		if true:
			var prop_name = child
			if prop_name == "state_id":
				shown[child] = not all_states
	return shown


func generate_code(node: Node, chain_name: String) -> Dictionary:
	return {
		"controller_code": ""
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Logic gate that combines Trigger inputs.\nAND: all Triggers must be active. OR: any Trigger active.\nNAND/NOR/XOR: inverted and exclusive logic.",
		"logic_mode": "Logic gate type:\n• AND: All connected Triggers must be active\n• OR: At least one Trigger must be active\n• NAND: NOT AND — active when not all Triggers are active\n• NOR: NOT OR — active only when no Triggers are active\n• XOR: Exclusive OR — active when exactly one Trigger is active",
	}
