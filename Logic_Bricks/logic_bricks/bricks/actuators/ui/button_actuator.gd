@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Button"

func get_brick_info() -> Dictionary:
	return {
		"class": "UIButtonActuator",
		"name": "Button",
		"type": "actuator",
		"category": "UI",
		"description": "Triggers, toggles, presses, or releases a Button node.",
		"menu_order": 210,
		"domain": "ui"
	}

func _initialize_properties() -> void:
	properties = {"target_node_name": "self", "action": "emit_pressed"}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "self", "placeholder": "self or Button node name"},
		{"name": "action", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Emit Pressed,Press,Release,Toggle", "default": "emit_pressed"},
	]

func get_tooltip_definitions() -> Dictionary:
	return {"_description": "Controls a BaseButton such as Button, CheckBox, or TextureButton.", "target_node_name": "Use self or type the Button node name.", "action": "Emit Pressed fires the pressed signal. Press/Release set button_pressed. Toggle flips button_pressed."}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "self")).strip_edges()
	var action = str(properties.get("action", "emit_pressed")).to_lower().replace(" ", "_")
	var label = _unique_label(chain_name)
	var var_name = "_%s" % label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = ["# Button Actuator"]
	code_lines.append("var %s: Node = null" % var_name)
	_append_target_lookup(code_lines, label, target_node_name, var_name)
	code_lines.append("if %s is BaseButton:" % var_name)
	match action:
		"press": code_lines.append("\t%s.button_pressed = true" % var_name)
		"release": code_lines.append("\t%s.button_pressed = false" % var_name)
		"toggle": code_lines.append("\t%s.button_pressed = not %s.button_pressed" % [var_name, var_name])
		_: code_lines.append("\t%s.emit_signal(\"pressed\")" % var_name)
	code_lines.append("elif %s:" % var_name)
	code_lines.append("\tpush_warning(\"Button Actuator: target is not a BaseButton\")")
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Button Actuator: could not find target node\")")
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
