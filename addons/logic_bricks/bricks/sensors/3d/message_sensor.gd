@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Message Sensor - Detect messages sent by Message Actuator
## Listens for messages with a specific subject
## Automatically adds the node to the broadcast listener group


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Message"


func _initialize_properties() -> void:
	properties = {
		"subject": "",           # Message subject to listen for
		"match_mode": "exact",   # exact, contains, starts_with
		"response_delay": 0.0    # Seconds to wait after receiving before activating (0 = immediate)
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
		},
		{
			"name": "response_delay",
			"type": TYPE_FLOAT,
			"default": 0.0
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Detects messages sent by a Message Actuator.\nListens for a specific subject.",
		"subject": "Message subject to listen for.\nMust match what the Message Actuator sends.",
		"match_mode": "Exact: subject must match exactly\nContains: subject contains the text\nStarts With: subject starts with the text",
		"response_delay": "Seconds to wait after receiving the message before activating.\n0 = activate immediately on the same frame the message arrives.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var subject = properties.get("subject", "")
	var match_mode = properties.get("match_mode", "exact")
	var response_delay = float(properties.get("response_delay", 0.0))

	# Normalize match_mode
	if typeof(match_mode) == TYPE_STRING:
		match_mode = match_mode.to_lower().replace(" ", "_")

	if subject.is_empty():
		return {
			"sensor_code": "var sensor_active = false  # Message sensor: no subject specified"
		}

	var code_lines: Array[String] = []
	var member_vars: Array[String] = []

	# Core message tracking vars
	var msg_received_var = "_msg_received_%s" % chain_name
	var msg_subject_var  = "_msg_subject_%s" % chain_name
	var msg_body_var     = "_msg_body_%s" % chain_name
	var msg_sender_var   = "_msg_sender_%s" % chain_name

	member_vars.append("var %s: bool = false" % msg_received_var)
	member_vars.append("var %s: String = \"\"" % msg_subject_var)
	member_vars.append("var %s: String = \"\"" % msg_body_var)
	member_vars.append("var %s: Node = null" % msg_sender_var)

	if response_delay > 0.0:
		# Delay path: handler sets a pending flag, sensor counts down then fires once
		var msg_pending_var = "_msg_pending_%s" % chain_name
		var msg_timer_var   = "_msg_timer_%s" % chain_name
		member_vars.append("var %s: bool = false" % msg_pending_var)
		member_vars.append("var %s: float = 0.0" % msg_timer_var)

		code_lines.append("var sensor_active = false")
		code_lines.append("if %s:" % msg_pending_var)
		code_lines.append("\t%s += _delta" % msg_timer_var)
		code_lines.append("\tif %s >= %.4f:" % [msg_timer_var, response_delay])
		code_lines.append("\t\tsensor_active = true")
		code_lines.append("\t\t%s = false" % msg_pending_var)
		code_lines.append("\t\t%s = 0.0" % msg_timer_var)
	else:
		# Immediate path: latch true once message received, stays true each frame
		code_lines.append("var sensor_active = %s" % msg_received_var)

	# Generate the message handler method
	var handler_code: Array[String] = []
	handler_code.append("")
	handler_code.append("# Message handler method (called by Message Actuator)")
	handler_code.append("func _on_message_received(subject: String, body: String, sender: Node) -> void:")

	match match_mode:
		"exact":
			handler_code.append("\tif subject == \"%s\":" % subject)
		"contains":
			handler_code.append("\tif \"%s\" in subject:" % subject)
		"starts_with":
			handler_code.append("\tif subject.begins_with(\"%s\"):" % subject)

	if response_delay > 0.0:
		var msg_pending_var = "_msg_pending_%s" % chain_name
		var msg_timer_var   = "_msg_timer_%s" % chain_name
		handler_code.append("\t\t%s = true" % msg_pending_var)
		handler_code.append("\t\t%s = 0.0  # Reset timer on each new message" % msg_timer_var)
	else:
		handler_code.append("\t\t%s = true" % msg_received_var)

	handler_code.append("\t\t%s = subject" % msg_subject_var)
	handler_code.append("\t\t%s = body" % msg_body_var)
	handler_code.append("\t\t%s = sender" % msg_sender_var)

	# Add node to broadcast listener group via ready code
	var ready_code: Array[String] = []
	ready_code.append("add_to_group(\"_logic_bricks_message_listeners\")")

	var result = {
		"sensor_code": "\n".join(code_lines),
		"methods": ["\n".join(handler_code)],
		"ready_code": ready_code
	}

	if member_vars.size() > 0:
		result["member_vars"] = member_vars

	return result
