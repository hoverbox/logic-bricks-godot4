@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Signal Actuator - Send signals to other objects
## Calls a message handler on all nodes in a target group
## If no group is specified, broadcasts to ALL nodes with a message handler


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Signal"


func _initialize_properties() -> void:
	properties = {
		"target_group": "",      # Group to send signal to (empty = broadcast to all)
		"subject": "",           # Signal name/name
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


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Sends a signal to other nodes.\nReceiving nodes need a Signal Sensor listening for the subject.",
		"target_group": "Group name to send to.\nLeave empty to broadcast to ALL nodes with a Signal Sensor.",
		"subject": "Signal name (must match the Signal Sensor's subject).",
		"body": "Optional data to send with the message.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_group = properties.get("target_group", "")
	var subject = properties.get("subject", "")
	var body = properties.get("body", "")

	if subject.is_empty():
		return {"actuator_code": "pass  # Message actuator: subject not set"}

	var code_lines: Array[String] = []
	var body_str = "\"%s\"" % body if not body.is_empty() else "\"\""

	if target_group.is_empty():
		# Broadcast to ALL nodes in the scene tree that have the handler
		code_lines.append("# Broadcast signal to all nodes with a message handler")
		code_lines.append("for _target in get_tree().get_nodes_in_group(\"_logic_bricks_message_listeners\"):")
		code_lines.append("\tif _target.has_method(\"_on_message_received\"):")
		code_lines.append("\t\t_target._on_message_received(\"%s\", %s, self)" % [subject, body_str])
	else:
		# Send to specific group
		code_lines.append("var _msg_targets = get_tree().get_nodes_in_group(\"%s\")" % target_group)
		code_lines.append("for _target in _msg_targets:")
		code_lines.append("\tif _target.has_method(\"_on_message_received\"):")
		code_lines.append("\t\t_target._on_message_received(\"%s\", %s, self)" % [subject, body_str])

	return {
		"actuator_code": "\n".join(code_lines)
	}
