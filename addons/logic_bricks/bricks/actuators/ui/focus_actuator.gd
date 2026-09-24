@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Focus"

func get_brick_info() -> Dictionary:
	return {
		"class": "UIFocusActuator",
		"name": "Focus",
		"type": "actuator",
		"category": "UI",
		"description": "Grabs or releases keyboard/gamepad focus on a Control node.",
		"menu_order": 200,
		"domain": "ui"
	}

func _initialize_properties() -> void:
	properties = {"target_node_name": "self", "action": "grab_focus"}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "self", "placeholder": "self or Control node name"},
		{"name": "action", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Grab Focus,Release Focus", "default": "grab_focus"},
	]

func get_tooltip_definitions() -> Dictionary:
	return {"_description": "Grabs or releases UI focus on a Control node.", "target_node_name": "Use self or type the Control node name.", "action": "Grab Focus selects the control for keyboard/gamepad navigation. Release Focus clears it."}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "self")).strip_edges()
	var action = str(properties.get("action", "grab_focus")).to_lower().replace(" ", "_")
	var label = _runtime_unique_label(chain_name)
	var var_name = "_%s" % label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = ["# Focus Actuator"]
	code_lines.append("var %s: Node = null" % var_name)
	_append_target_lookup(code_lines, label, target_node_name, var_name)
	code_lines.append("if %s is Control:" % var_name)
	if action == "release_focus":
		code_lines.append("\t%s.release_focus()" % var_name)
	else:
		code_lines.append("\t%s.grab_focus()" % var_name)
	code_lines.append("elif %s:" % var_name)
	code_lines.append("\tpush_warning(\"Focus Actuator: target is not a Control node\")")
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Focus Actuator: could not find target node\")")
	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}
