@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Text Actuator - Updates a Label, Label3D, or RichTextLabel by node name
## Searches the whole current scene tree. The name can be literal, exported as a String,
## or read from a String variable on the generated script.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Text"


func get_brick_info() -> Dictionary:
	return {
		"class": "Text2DActuator",
		"name": "Text",
		"type": "actuator",
		"category": "UI",
		"description": "Updates a Label, RichTextLabel, or other text UI node.",
		"menu_order": 100,
		"domain": "2d"
	}

func _initialize_properties() -> void:
	properties = {
		"target_node_name": "Label",
		"node_name_source": "literal",
		"export_node_name": false,
		"mode": "variable",
		"variable_name": "",
		"prefix": "",
		"suffix": "",
		"static_text": "",
	}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "required": true, "required_label": "a text node or String variable name", "type": TYPE_STRING, "default": "Label"},
		{"name": "node_name_source", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Literal Node Name,String Variable", "default": "literal"},
		{"name": "export_node_name", "type": TYPE_BOOL, "default": false},
		{"name": "mode", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Variable,Static", "default": "variable"},
		{"name": "variable_name", "required": true, "required_label": "a variable name", "required_if": {"mode": "variable"}, "type": TYPE_STRING, "default": ""},
		{"name": "prefix", "type": TYPE_STRING, "default": ""},
		{"name": "suffix", "type": TYPE_STRING, "default": ""},
		{"name": "static_text", "type": TYPE_STRING, "default": ""},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Updates a Label, Label3D, or RichTextLabel by node name. Searches the whole current scene tree, so this brick can live on any node.",
		"target_node_name": "Literal Node Name: type the UI node name, such as ScoreLabel.\nString Variable: type the name of a String variable that stores the node name.",
		"node_name_source": "Literal Node Name: use Target Node Name directly.\nString Variable: treat Target Node Name as a variable name and read that String at runtime.",
		"export_node_name": "Literal mode only. Adds an @export String to the generated script so the node name can be edited in the Inspector without exposing a node reference.",
		"mode": "Variable: display a variable's value\nStatic: display fixed text",
		"variable_name": "Name of the variable to display. Works with local and global variables.",
		"prefix": "Text before the value, e.g. Score: ",
		"suffix": "Text after the value, e.g. pts.",
		"static_text": "Fixed text to display in Static mode only.",
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "Label")).strip_edges()
	var node_name_source = str(properties.get("node_name_source", "literal")).to_lower().replace(" ", "_")
	var export_node_name = properties.get("export_node_name", false)
	var mode = properties.get("mode", "variable")
	var variable_name = properties.get("variable_name", "")
	var prefix = properties.get("prefix", "")
	var suffix = properties.get("suffix", "")
	var static_text = properties.get("static_text", "")
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower()

	var label = _unique_label(chain_name)
	var text_node_var = "_%s" % label
	var node_name_var = "_%s_node_name" % label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("var %s: Node = null" % text_node_var)
	if export_node_name and node_name_source != "string_variable":
		member_vars.append("@export var %s: String = \"%s\"" % [node_name_var, _gd_string(target_node_name)])
	_append_find_node_helpers(member_vars)

	var name_expr = "\"%s\"" % _gd_string(target_node_name)
	if node_name_source == "string_variable" and not target_node_name.is_empty():
		name_expr = "str(%s)" % target_node_name
	elif export_node_name and node_name_source != "string_variable":
		name_expr = node_name_var

	code_lines.append("# Text Actuator")
	code_lines.append("var _target_name_%s = %s" % [label, name_expr])
	code_lines.append("if %s == null or %s.name != _target_name_%s:" % [text_node_var, text_node_var, label])
	code_lines.append("\t%s = _lb_find_node_in_current_scene(_target_name_%s)" % [text_node_var, label])
	code_lines.append("if %s:" % text_node_var)
	match mode:
		"variable":
			if variable_name.is_empty():
				code_lines.append("\tpush_warning(\"Text Actuator: No variable name specified\")")
			else:
				code_lines.append("\tvar _value = str(%s)" % variable_name)
				if not prefix.is_empty() and not suffix.is_empty():
					code_lines.append("\tvar _display_text = \"%s\" + _value + \"%s\"" % [_gd_string(prefix), _gd_string(suffix)])
				elif not prefix.is_empty():
					code_lines.append("\tvar _display_text = \"%s\" + _value" % _gd_string(prefix))
				elif not suffix.is_empty():
					code_lines.append("\tvar _display_text = _value + \"%s\"" % _gd_string(suffix))
				else:
					code_lines.append("\tvar _display_text = _value")
				_append_set_text_code(code_lines, text_node_var, "_display_text")
		"static":
			_append_set_text_code(code_lines, text_node_var, "\"%s\"" % _gd_string(static_text))
		_:
			code_lines.append("\tpass")
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Text Actuator: could not find text node named '\" + str(_target_name_%s) + \"'\")" % label)
	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}
