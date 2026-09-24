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
	var label = _runtime_unique_label(chain_name)
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
