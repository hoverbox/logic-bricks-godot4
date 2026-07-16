@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Popup"

func get_brick_info() -> Dictionary:
	return {
		"class": "UIPopupActuator",
		"name": "Popup",
		"type": "actuator",
		"category": "UI",
		"description": "Shows, hides, toggles, or centers a Popup/Window-like UI node.",
		"menu_order": 220,
		"domain": "ui"
	}

func _initialize_properties() -> void:
	properties = {"target_node_name": "self", "action": "show"}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "self", "placeholder": "Popup node name"},
		{"name": "action", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Show,Hide,Toggle,Popup Centered", "default": "show"},
	]

func get_tooltip_definitions() -> Dictionary:
	return {"_description": "Controls a Popup, PopupPanel, AcceptDialog, Window, or visible Control.", "target_node_name": "Use self or type the popup/control node name.", "action": "Show/Hide/Toggle visibility, or Popup Centered when the target supports it."}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "self")).strip_edges()
	var action = str(properties.get("action", "show")).to_lower().replace(" ", "_")
	var label = _unique_label(chain_name)
	var var_name = "_%s" % label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = ["# Popup Actuator"]
	code_lines.append("var %s: Node = null" % var_name)
	_append_target_lookup(code_lines, label, target_node_name, var_name)
	code_lines.append("if %s:" % var_name)
	if action == "hide":
		code_lines.append("\t%s.hide()" % var_name)
	elif action == "toggle":
		code_lines.append("\t%s.visible = not %s.visible" % [var_name, var_name])
	elif action == "popup_centered":
		code_lines.append("\tif %s.has_method(\"popup_centered\"):" % var_name)
		code_lines.append("\t\t%s.popup_centered()" % var_name)
		code_lines.append("\telse:")
		code_lines.append("\t\t%s.show()" % var_name)
	else:
		code_lines.append("\t%s.show()" % var_name)
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Popup Actuator: could not find target node\")")
	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}


func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")

func _unique_label(chain_name: String) -> String:
	var base := ""
	for i in range(chain_name.length()):
		var ch := chain_name.substr(i, 1)
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_":
			base += ch
		else:
			base += "_"
	while base.begins_with("_"):
		base = base.substr(1)
	while base.ends_with("_") and not base.is_empty():
		base = base.substr(0, base.length() - 1)
	if base.is_empty():
		base = "chain"
	return "lb_%s_%d" % [base, abs(get_instance_id())]

func _append_target_lookup(code_lines: Array[String], label: String, target_node_name: String, var_name: String) -> void:
	code_lines.append("var _target_name_%s = \"%s\"" % [label, _gd_string(target_node_name)])
	code_lines.append("if _target_name_%s.strip_edges().to_lower() == \"self\":" % label)
	code_lines.append("\t%s = self" % var_name)
	code_lines.append("else:")
	code_lines.append("\tvar _scene_%s = get_tree().current_scene" % label)
	code_lines.append("\tif _scene_%s:" % label)
	code_lines.append("\t\t%s = _scene_%s.find_child(_target_name_%s, true, false)" % [var_name, label, label])
	code_lines.append("\tif %s == null:" % var_name)
	code_lines.append("\t\t%s = get_tree().root.find_child(_target_name_%s, true, false)" % [var_name, label])
