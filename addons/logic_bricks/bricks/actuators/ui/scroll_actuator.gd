@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Scroll"

func get_brick_info() -> Dictionary:
	return {
		"class": "UIScrollActuator",
		"name": "Scroll",
		"type": "actuator",
		"category": "UI",
		"description": "Sets or adds to a ScrollContainer scroll position.",
		"menu_order": 230,
		"domain": "ui"
	}

func _initialize_properties() -> void:
	properties = {"target_node_name": "self", "mode": "set", "axis": "vertical", "x": "0", "y": "0"}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "self", "placeholder": "ScrollContainer node name"},
		{"name": "mode", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Set,Add", "default": "set"},
		{"name": "axis", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Vertical,Horizontal,Both", "default": "vertical"},
		{"name": "x", "type": TYPE_STRING, "default": "0"},
		{"name": "y", "type": TYPE_STRING, "default": "0"},
	]

func get_tooltip_definitions() -> Dictionary:
	return {"_description": "Moves a ScrollContainer by setting or adding to its scroll position.", "target_node_name": "Use self or type the ScrollContainer node name.", "mode": "Set replaces the scroll value. Add changes it relative to the current scroll.", "axis": "Choose which scroll axis to affect.", "x": "Horizontal scroll value or amount.", "y": "Vertical scroll value or amount."}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "self")).strip_edges()
	var mode = str(properties.get("mode", "set")).to_lower()
	var axis = str(properties.get("axis", "vertical")).to_lower()
	var x = str(properties.get("x", "0"))
	var y = str(properties.get("y", "0"))
	var label = _runtime_unique_label(chain_name)
	var var_name = "_%s" % label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = ["# Scroll Actuator"]
	code_lines.append("var %s: Node = null" % var_name)
	_append_target_lookup(code_lines, label, target_node_name, var_name)
	code_lines.append("if %s is ScrollContainer:" % var_name)
	if axis in ["horizontal", "both"]:
		code_lines.append("\t%s.scroll_horizontal %s int(%s)" % [var_name, "+=" if mode == "add" else "=", x])
	if axis in ["vertical", "both"]:
		code_lines.append("\t%s.scroll_vertical %s int(%s)" % [var_name, "+=" if mode == "add" else "=", y])
	code_lines.append("elif %s:" % var_name)
	code_lines.append("\tpush_warning(\"Scroll Actuator: target is not a ScrollContainer\")")
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Scroll Actuator: could not find target node\")")
	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}
