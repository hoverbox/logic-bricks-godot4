@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Window"

func get_brick_info() -> Dictionary:
	return {
		"class": "UIWindowActuator",
		"name": "Window",
		"type": "actuator",
		"category": "UI",
		"description": "Shows, hides, toggles, or centers a Window node.",
		"menu_order": 260,
		"domain": "ui"
	}

func _initialize_properties() -> void:
	properties = {"target_node_name": "self", "action": "show"}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "self", "placeholder": "Window node name"},
		{"name": "action", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Show,Hide,Toggle,Popup Centered", "default": "show"},
	]

func get_tooltip_definitions() -> Dictionary:
	return {"_description": "Controls a Godot Window node, such as a settings or dialog window.", "target_node_name": "Use self or type the Window node name.", "action": "Show/Hide/Toggle visibility, or Popup Centered when available."}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "self")).strip_edges()
	var action = str(properties.get("action", "show")).to_lower().replace(" ", "_")
	var label = _runtime_unique_label(chain_name)
	var var_name = "_%s" % label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = ["# Window Actuator"]
	code_lines.append("var %s: Node = null" % var_name)
	_append_target_lookup(code_lines, label, target_node_name, var_name)
	code_lines.append("if %s is Window:" % var_name)
	if action == "hide":
		code_lines.append("\t%s.hide()" % var_name)
	elif action == "toggle":
		code_lines.append("\t%s.visible = not %s.visible" % [var_name, var_name])
	elif action == "popup_centered":
		code_lines.append("\t%s.popup_centered()" % var_name)
	else:
		code_lines.append("\t%s.show()" % var_name)
	code_lines.append("elif %s:" % var_name)
	code_lines.append("\tpush_warning(\"Window Actuator: target is not a Window node\")")
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Window Actuator: could not find target node\")")
	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}
