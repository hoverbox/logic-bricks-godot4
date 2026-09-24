@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Slider"

func get_brick_info() -> Dictionary:
	return {
		"class": "UISliderActuator",
		"name": "Slider",
		"type": "actuator",
		"category": "UI",
		"description": "Sets or adds to a Slider or Range value.",
		"menu_order": 250,
		"domain": "ui"
	}

func _initialize_properties() -> void:
	properties = {"target_node_name": "self", "mode": "set", "value": "0.0"}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "self", "placeholder": "Slider node name"},
		{"name": "mode", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Set,Add", "default": "set"},
		{"name": "value", "type": TYPE_STRING, "default": "0.0"},
	]

func get_tooltip_definitions() -> Dictionary:
	return {"_description": "Changes the value of HSlider, VSlider, ProgressBar, SpinBox, or another Range node.", "target_node_name": "Use self or type the Range/Slider node name.", "mode": "Set replaces the value. Add changes it relative to the current value.", "value": "Value or amount. Can be a number or variable expression."}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "self")).strip_edges()
	var mode = str(properties.get("mode", "set")).to_lower()
	var value = str(properties.get("value", "0.0"))
	var label = _runtime_unique_label(chain_name)
	var var_name = "_%s" % label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = ["# Slider Actuator"]
	code_lines.append("var %s: Node = null" % var_name)
	_append_target_lookup(code_lines, label, target_node_name, var_name)
	code_lines.append("if %s is Range:" % var_name)
	if mode == "add":
		code_lines.append("\t%s.value += float(%s)" % [var_name, value])
	else:
		code_lines.append("\t%s.value = float(%s)" % [var_name, value])
	code_lines.append("elif %s:" % var_name)
	code_lines.append("\tpush_warning(\"Slider Actuator: target is not a Range/Slider node\")")
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Slider Actuator: could not find target node\")")
	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}
