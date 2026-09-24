@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Tab"

func get_brick_info() -> Dictionary:
	return {
		"class": "UITabActuator",
		"name": "Tab",
		"type": "actuator",
		"category": "UI",
		"description": "Changes the active tab on a TabContainer.",
		"menu_order": 240,
		"domain": "ui"
	}

func _initialize_properties() -> void:
	properties = {"target_node_name": "self", "action": "set", "tab_index": "0"}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "self", "placeholder": "TabContainer node name"},
		{"name": "action", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Set,Next,Previous", "default": "set"},
		{"name": "tab_index", "type": TYPE_STRING, "default": "0"},
	]

func get_tooltip_definitions() -> Dictionary:
	return {"_description": "Sets, advances, or reverses the active TabContainer tab.", "target_node_name": "Use self or type the TabContainer node name.", "action": "Set uses Tab Index. Next/Previous cycle through tabs.", "tab_index": "Tab index to activate when Action is Set."}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "self")).strip_edges()
	var action = str(properties.get("action", "set")).to_lower()
	var tab_index = str(properties.get("tab_index", "0"))
	var label = _runtime_unique_label(chain_name)
	var var_name = "_%s" % label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = ["# Tab Actuator"]
	code_lines.append("var %s: Node = null" % var_name)
	_append_target_lookup(code_lines, label, target_node_name, var_name)
	code_lines.append("if %s is TabContainer:" % var_name)
	if action == "next":
		code_lines.append("\t%s.current_tab = (%s.current_tab + 1) % max(1, %s.get_tab_count())" % [var_name, var_name, var_name])
	elif action == "previous":
		code_lines.append("\t%s.current_tab = (%s.current_tab - 1 + max(1, %s.get_tab_count())) % max(1, %s.get_tab_count())" % [var_name, var_name, var_name, var_name])
	else:
		code_lines.append("\t%s.current_tab = clampi(int(%s), 0, max(0, %s.get_tab_count() - 1))" % [var_name, tab_index, var_name])
	code_lines.append("elif %s:" % var_name)
	code_lines.append("\tpush_warning(\"Tab Actuator: target is not a TabContainer\")")
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Tab Actuator: could not find target node\")")
	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}
