@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Modulate Actuator - Set or lerp the color/alpha of a CanvasItem found by node name

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Modulate"


func get_brick_info() -> Dictionary:
	return {
		"class": "UIModulateActuator",
		"name": "Modulate",
		"type": "actuator",
		"category": "UI",
		"description": "Sets or transitions color/alpha on a Control or CanvasItem node.",
		"menu_order": 120,
		"domain": "ui"
	}

func _initialize_properties() -> void:
	properties = {
		"target_node_name": "",
		"node_name_source": "literal",
		"export_node_name": false,
		"target_modulate": "self_modulate",
		"color": Color(1, 1, 1, 1),
		"transition": false,
		"transition_speed": "5.0",
	}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": ""},
		{"name": "node_name_source", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Literal Node Name,String Variable", "default": "literal"},
		{"name": "export_node_name", "type": TYPE_BOOL, "default": false},
		{"name": "target_modulate", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Self Modulate,Modulate", "default": "self_modulate"},
		{"name": "color", "type": TYPE_COLOR, "default": Color(1, 1, 1, 1)},
		{"name": "transition", "type": TYPE_BOOL, "default": false},
		{"name": "transition_speed", "type": TYPE_STRING, "default": "5.0"},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Sets or smoothly transitions the color/alpha of a UI or 2D node found by name anywhere in the current scene tree.",
		"target_node_name": "Literal Node Name: type the CanvasItem node name.\nString Variable: type the name of a String variable that stores the node name.",
		"node_name_source": "Literal Node Name: use Target Node Name directly.\nString Variable: treat Target Node Name as a variable name and read that String at runtime.",
		"export_node_name": "Literal mode only. Adds an @export String to the generated script so the node name can be edited in the Inspector without exposing a node reference.",
		"target_modulate": "Self Modulate: affects only this node, not children.\nModulate: affects this node and all children.",
		"color": "Target color. Set alpha to 0 for fade out, 1 for fade in.",
		"transition": "Smoothly lerp to the target color each frame.",
		"transition_speed": "Lerp speed. Higher = faster. Accepts a number or variable.",
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "")).strip_edges()
	var node_name_source = str(properties.get("node_name_source", "literal")).to_lower().replace(" ", "_")
	var export_node_name = properties.get("export_node_name", false)
	var target = properties.get("target_modulate", "self_modulate")
	var color = properties.get("color", Color(1, 1, 1, 1))
	var transition = properties.get("transition", false)
	var speed = _to_expr(properties.get("transition_speed", "5.0"))
	if typeof(target) == TYPE_STRING:
		target = target.to_lower().replace(" ", "_")
	if typeof(color) != TYPE_COLOR:
		color = Color(1, 1, 1, 1)

	var label = _unique_label(chain_name)
	var node_var = "_%s" % label
	var node_name_var = "_%s_node_name" % label
	var color_str = "Color(%.4f, %.4f, %.4f, %.4f)" % [color.r, color.g, color.b, color.a]
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []
	member_vars.append("var %s: CanvasItem = null" % node_var)
	if export_node_name and node_name_source != "string_variable":
		member_vars.append("@export var %s: String = \"%s\"" % [node_name_var, _gd_string(target_node_name)])
	_append_find_node_helpers(member_vars)

	var name_expr = "\"%s\"" % _gd_string(target_node_name)
	if node_name_source == "string_variable" and not target_node_name.is_empty():
		name_expr = "str(%s)" % target_node_name
	elif export_node_name and node_name_source != "string_variable":
		name_expr = node_name_var
	_append_resolve_code(code_lines, node_var, label, name_expr, "CanvasItem", "Modulate Actuator")

	if transition:
		var target_var = "_%s_target_color" % label
		member_vars.append("var %s: Color = Color(1.0000, 1.0000, 1.0000, 1.0000)" % target_var)
		code_lines.append("if %s:" % node_var)
		code_lines.append("\t%s = %s" % [target_var, color_str])
		code_lines.append("else:")
		code_lines.append("\tpush_warning(\"Modulate Actuator: could not find CanvasItem named '\" + str(_target_name_%s) + \"'\")" % label)
		var post_line = "if %s: %s.%s = %s.%s.lerp(%s, %s * delta)" % [node_var, node_var, target, node_var, target, target_var, speed]
		return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars, "post_process_code": [post_line]}
	else:
		code_lines.append("if %s:" % node_var)
		code_lines.append("\t%s.%s = %s" % [node_var, target, color_str])
		code_lines.append("else:")
		code_lines.append("\tpush_warning(\"Modulate Actuator: could not find CanvasItem named '\" + str(_target_name_%s) + \"'\")" % label)
		return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}

func _append_resolve_code(code_lines: Array[String], node_var: String, label: String, name_expr: String, expected_type: String, actuator_name: String) -> void:
	code_lines.append("# %s" % actuator_name)
	code_lines.append("var _target_name_%s = %s" % [label, name_expr])
	code_lines.append("if %s == null or %s.name != _target_name_%s:" % [node_var, node_var, label])
	code_lines.append("\tvar _found_%s = _lb_find_node_in_current_scene(_target_name_%s)" % [label, label])
	code_lines.append("\tif _found_%s is %s:" % [label, expected_type])
	code_lines.append("\t\t%s = _found_%s" % [node_var, label])
	code_lines.append("\telse:")
	code_lines.append("\t\t%s = null" % node_var)

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
	if s.is_empty(): return "5.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
