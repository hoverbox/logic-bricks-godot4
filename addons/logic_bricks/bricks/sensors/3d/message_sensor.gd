@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Message Sensor - Detect messages sent by Message Actuator
## Listens for messages with a specific subject


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Message"


func _initialize_properties() -> void:
	properties = {
		"subject": "",           # Message subject to listen for
		"match_mode": "exact"    # exact, contains, starts_with
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "subject",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "match_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Exact,Contains,Starts With",
			"default": "exact"
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var subject = properties.get("subject", "")
	var match_mode = properties.get("match_mode", "exact")
	
	# Normalize match_mode
	if typeof(match_mode) == TYPE_STRING:
		match_mode = match_mode.to_lower().replace(" ", "_")
	
	if subject.is_empty():
		return {
			"sensor_code": "var sensor_active = false # Message sensor: no subject specified"
		}
	
	var code_lines: Array[String] = []
	var member_vars: Array[String] = []
	
	# Member variables to track received messages
	var msg_received_var = "_msg_received_%s" % chain_name
	var msg_subject_var = "_msg_subject_%s" % chain_name
	var msg_body_var = "_msg_body_%s" % chain_name
	var msg_sender_var = "_msg_sender_%s" % chain_name
	
	member_vars.append("var %s: bool = false" % msg_received_var)
	member_vars.append("var %s: String = \"\"" % msg_subject_var)
	member_vars.append("var %s: String = \"\"" % msg_body_var)
	member_vars.append("var %s: Node = null" % msg_sender_var)
	
	# Sensor code - check if message was received
	code_lines.append("var sensor_active = %s" % msg_received_var)
	code_lines.append("# Reset flag after checking (one-shot)")
	code_lines.append("%s = false" % msg_received_var)
	
	# Generate the message handler method
	var handler_code: Array[String] = []
	handler_code.append("")
	handler_code.append("# Message handler method (called by Message Actuator)")
	handler_code.append("func _on_message_received(subject: String, body: String, sender: Node) -> void:")
	
	# Match based on mode
	match match_mode:
		"exact":
			handler_code.append("\tif subject == \"%s\":" % subject)
		"contains":
			handler_code.append("\tif \"%s\" in subject:" % subject)
		"starts_with":
			handler_code.append("\tif subject.begins_with(\"%s\"):" % subject)
	
	handler_code.append("\t\t%s = true" % msg_received_var)
	handler_code.append("\t\t%s = subject" % msg_subject_var)
	handler_code.append("\t\t%s = body" % msg_body_var)
	handler_code.append("\t\t%s = sender" % msg_sender_var)
	
	var result = {
		"sensor_code": "\n".join(code_lines),
		"methods": ["\n".join(handler_code)]
	}
	
	if member_vars.size() > 0:
		result["member_vars"] = member_vars
	
	return result
