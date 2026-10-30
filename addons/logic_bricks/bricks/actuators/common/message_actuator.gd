@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Signal Send Action - Send signals to other objects
## Broadcasts a named signal to nodes with a Signal Receive Trigger
## Previously saved group/body settings remain supported for older projects


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Signal Send"


func _initialize_properties() -> void:
	properties = {
		"signal_name": ""
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "signal_name",
			"required": true,
			"required_label": "a signal name",
			"type": TYPE_STRING,
			"default": ""
		}
	]


func renamed_properties() -> Dictionary:
	return {"subject": "signal_name"}


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Sends a named signal to other nodes.\nReceiving nodes need a Signal Receive Trigger with a matching Signal name.",
		"signal_name": "Signal name (must match the Signal Receive Trigger's Signal Name).",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	# Honor legacy saved settings; new bricks only store the signal name.
	var target_group = properties.get("target_group", "")
	var signal_name = properties.get("signal_name", "")
	var body = properties.get("body", "")

	if signal_name.is_empty():
		return {"actuator_code": "pass  # Signal Send: signal name not set"}

	var code_lines: Array[String] = []
	var body_str = "\"%s\"" % _gd_string(str(body)) if not body.is_empty() else "\"\""

	if target_group.is_empty():
		# Broadcast to ALL nodes in the scene tree that have the handler
		code_lines.append("# Broadcast signal to all nodes with a message handler")
		code_lines.append("for _target in get_tree().get_nodes_in_group(\"_logic_bricks_message_listeners\"):")
		code_lines.append("\tif _target.has_method(\"_on_message_received\"):")
		code_lines.append("\t\t_target._on_message_received(\"%s\", %s, self)" % [_gd_string(str(signal_name)), body_str])
	else:
		# Send to specific group
		code_lines.append("var _msg_targets = get_tree().get_nodes_in_group(\"%s\")" % _gd_string(str(target_group)))
		code_lines.append("for _target in _msg_targets:")
		code_lines.append("\tif _target.has_method(\"_on_message_received\"):")
		code_lines.append("\t\t_target._on_message_received(\"%s\", %s, self)" % [_gd_string(str(signal_name)), body_str])

	return {
		"actuator_code": "\n".join(code_lines)
	}
