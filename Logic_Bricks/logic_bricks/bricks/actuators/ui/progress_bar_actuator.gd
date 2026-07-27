@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Progress Bar Actuator - Control a Range node found by name anywhere in the scene

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Progress Bar"


func get_brick_info() -> Dictionary:
	return {
		"class": "UIProgressBarActuator",
		"name": "Progress Bar",
		"type": "actuator",
		"category": "UI",
		"description": "Sets the value, min, or max of a ProgressBar, Slider, or Range UI node.",
		"menu_order": 110,
		"domain": "ui"
	}

func _initialize_properties() -> void:
	properties = {
		"target_node_name": "ProgressBar",
		"node_name_source": "literal",
		"export_node_name": false,
		"set_value": true,
		"value": "100.0",
		"set_min": false,
		"min_value": "0.0",
		"set_max": false,
		"max_value": "100.0",
		"transition": false,
		"transition_speed": "5.0",
	}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "ProgressBar"},
		{"name": "node_name_source", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Literal Node Name,String Variable", "default": "literal"},
		{"name": "export_node_name", "type": TYPE_BOOL, "default": false},
		{"name": "set_value", "type": TYPE_BOOL, "default": true},
		{"name": "value", "type": TYPE_STRING, "default": "100.0"},
		{"name": "set_min", "type": TYPE_BOOL, "default": false},
		{"name": "min_value", "type": TYPE_STRING, "default": "0.0"},
		{"name": "set_max", "type": TYPE_BOOL, "default": false},
		{"name": "max_value", "type": TYPE_STRING, "default": "100.0"},
		{"name": "transition", "type": TYPE_BOOL, "default": false},
		{"name": "transition_speed", "type": TYPE_STRING, "default": "5.0"},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Sets the value, min, or max of a ProgressBar, HSlider, VSlider, or any Range node found by name anywhere in the current scene tree.",
		"target_node_name": "Literal Node Name: type the Range node name.\nString Variable: type the name of a String variable that stores the node name.",
		"node_name_source": "Literal Node Name: use Target Node Name directly.\nString Variable: treat Target Node Name as a variable name and read that String at runtime.",
		"export_node_name": "Literal mode only. Adds an @export String to the generated script so the node name can be edited in the Inspector without exposing a node reference.",
		"set_value": "Enable to set the current value.",
		"value": "The value to set. Accepts a number or variable name.",
		"set_min": "Enable to set the minimum value.",
		"min_value": "Minimum value. Accepts a number or variable name.",
		"set_max": "Enable to set the maximum value.",
		"max_value": "Maximum value. Accepts a number or variable name.",
		"transition": "Smoothly lerp the value to the target each frame. Only applies to value, not min/max.",
		"transition_speed": "Lerp speed. Higher = faster. Accepts a number or variable.",
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "ProgressBar")).strip_edges()
	var node_name_source = str(properties.get("node_name_source", "literal")).to_lower().replace(" ", "_")
	var export_node_name = properties.get("export_node_name", false)
	var set_value = properties.get("set_value", true)
	var value = _to_expr(properties.get("value", "100.0"))
	var set_min = properties.get("set_min", false)
	var min_value = _to_expr(properties.get("min_value", "0.0"))
	var set_max = properties.get("set_max", false)
	var max_value = _to_expr(properties.get("max_value", "100.0"))
	var transition = properties.get("transition", false)
	var speed = _to_expr(properties.get("transition_speed", "5.0"))

	var label = _unique_label(chain_name)
	var bar_var = "_%s" % label
	var node_name_var = "_%s_node_name" % label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []
	member_vars.append("var %s: Range = null" % bar_var)
	if export_node_name and node_name_source != "string_variable":
		member_vars.append("@export var %s: String = \"%s\"" % [node_name_var, _gd_string(target_node_name)])
	_append_find_node_helpers(member_vars)

	var name_expr = "\"%s\"" % _gd_string(target_node_name)
	if node_name_source == "string_variable" and not target_node_name.is_empty():
		name_expr = "str(%s)" % target_node_name
	elif export_node_name and node_name_source != "string_variable":
		name_expr = node_name_var

	code_lines.append("# Progress Bar Actuator")
	code_lines.append("var _target_name_%s = %s" % [label, name_expr])
	code_lines.append("if %s == null or %s.name != _target_name_%s:" % [bar_var, bar_var, label])
	code_lines.append("\tvar _found_%s = _lb_find_node_in_current_scene(_target_name_%s)" % [label, label])
	code_lines.append("\tif _found_%s is Range:" % label)
	code_lines.append("\t\t%s = _found_%s" % [bar_var, label])
	code_lines.append("\telse:")
	code_lines.append("\t\t%s = null" % bar_var)
	code_lines.append("if %s:" % bar_var)
	if set_min:
		code_lines.append("\t%s.min_value = %s" % [bar_var, min_value])
	if set_max:
		code_lines.append("\t%s.max_value = %s" % [bar_var, max_value])
	if set_value:
		if transition:
			code_lines.append("\t%s.value = lerpf(%s.value, %s, %s * _delta)" % [bar_var, bar_var, value, speed])
		else:
			code_lines.append("\t%s.value = %s" % [bar_var, value])
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Progress Bar Actuator: could not find Range node named '\" + str(_target_name_%s) + \"'\")" % label)
	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}

func _append_find_node_helpers(member_vars: Array[String]) -> void:
	member_vars.append("")
	member_vars.append("func _lb_find_node_by_name_recursive(node: Node, target_name: String) -> Node:")
	member_vars.append("\tif node == null or target_name.is_empty():")
	member_vars.append("\t\treturn null")
	member_vars.append("\tif node.name == target_name:")
	member_vars.append("\t\treturn node")
	member_vars.append("\tfor child in node.get_children():")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(child, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn null")
	member_vars.append("")
	member_vars.append("func _lb_find_node_in_current_scene(target_name: String) -> Node:")
	member_vars.append("\tvar scene_root = get_tree().current_scene")
	member_vars.append("\tif scene_root:")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(scene_root, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn _lb_find_node_by_name_recursive(get_tree().root, target_name)")

func _unique_label(chain_name: String) -> String:
	var label = instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	label = label.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	return label if not label.is_empty() else chain_name

func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")

func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
