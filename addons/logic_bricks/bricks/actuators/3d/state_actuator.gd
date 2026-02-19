@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## State Actuator - Change the active logic brick state
## Similar to UPBGE's State actuator


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "State"


func _initialize_properties() -> void:
	properties = {
		"operation": "set",     # set, add, remove
		"state": 1              # State number to set/add/remove (1-30)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "operation",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Set,Add,Remove",
			"default": "set"
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
	var operation = properties.get("operation", "set")
	var state = properties.get("state", 1)
	
	# Normalize operation
	if typeof(operation) == TYPE_STRING:
		operation = operation.to_lower()
	
	var code_lines: Array[String] = []
	
	match operation:
		"set":
			code_lines.append("# Set logic brick state to %d" % state)
			code_lines.append("_logic_brick_state = %d" % state)
		
		"add":
			code_lines.append("# Add state %d (bitwise OR for multiple active states)" % state)
			code_lines.append("_logic_brick_state |= (1 << (%d - 1))" % state)
		
		"remove":
			code_lines.append("# Remove state %d (bitwise AND NOT)" % state)
			code_lines.append("_logic_brick_state &= ~(1 << (%d - 1))" % state)
	
	return {
		"actuator_code": "\n".join(code_lines)
	}
