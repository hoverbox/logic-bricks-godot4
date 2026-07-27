@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## State Actuator - Set the active named state


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "State"


func _initialize_properties() -> void:
	properties = {
		"state_id": ""
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "state_id",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "__STATE_LIST__",
			"default": ""
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var state_id = str(properties.get("state_id", "")).strip_edges()

	var code_lines: Array[String] = []
	if state_id.is_empty():
		code_lines.append("push_warning(\"State Actuator requires a state selection.\")")
	else:
		code_lines.append("# Set logic brick state")
		code_lines.append("_logic_brick_set_state(%s)" % _gdscript_string_literal(state_id))

	return {
		"actuator_code": "\n".join(code_lines)
	}


func _gdscript_string_literal(value: String) -> String:
	return '"%s"' % value.c_escape()
