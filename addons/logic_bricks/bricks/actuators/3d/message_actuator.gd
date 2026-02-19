@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Message Actuator - Send messages to other objects
## Calls a message handler on all nodes in a target group


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Message"


func _initialize_properties() -> void:
	properties = {
		"target_group": "",      # Group to send message to
		"subject": "",           # Message subject/name
		"body": ""               # Optional message body/data
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_group",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "subject",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "body",
			"type": TYPE_STRING,
			"default": ""
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_group = properties.get("target_group", "")
	var subject = properties.get("subject", "")
	var body = properties.get("body", "")
	
	if target_group.is_empty() or subject.is_empty():
		return {"actuator_code": "pass # Message actuator: target_group or subject not set"}
	
	var code_lines: Array[String] = []
	
	# Get all nodes in the target group
	code_lines.append("var _msg_targets = get_tree().get_nodes_in_group(\"%s\")" % target_group)
	code_lines.append("for _target in _msg_targets:")
	
	# Call the message handler method on each target
	# The handler is expected to be: _on_message_received(subject: String, body: String, sender: Node)
	if body.is_empty():
		code_lines.append("\tif _target.has_method(\"_on_message_received\"):")
		code_lines.append("\t\t_target._on_message_received(\"%s\", \"\", self)" % subject)
	else:
		code_lines.append("\tif _target.has_method(\"_on_message_received\"):")
		code_lines.append("\t\t_target._on_message_received(\"%s\", \"%s\", self)" % [subject, body])
	
	return {
		"actuator_code": "\n".join(code_lines)
	}
