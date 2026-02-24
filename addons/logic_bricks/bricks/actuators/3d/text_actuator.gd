@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Text Actuator - Updates a Label or Label3D node with variable values or static text
## The text node is assigned via @export variable in the inspector (drag and drop)
## Modes: Variable (display a logic brick variable), Static (set fixed text)


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Text"


func _initialize_properties() -> void:
	properties = {
		"mode": "variable",        # variable, static
		"variable_name": "",       # Name of the variable to display
		"prefix": "",              # Text before the value (e.g., "Score: ")
		"suffix": "",              # Text after the value (e.g., " pts")
		"static_text": "",         # Text to display in static mode
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Variable,Static",
			"default": "variable"
		},
		{
			"name": "variable_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "prefix",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "suffix",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "static_text",
			"type": TYPE_STRING,
			"default": ""
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Updates a Label, Label3D, or RichTextLabel with text.\nCan display variable values or static text.\nWorks with local and global variables.\n\n⚠ Adds an @export in the Inspector — assign your text node there.",
		"mode": "Variable: display a variable's value\nStatic: display fixed text",
		"variable_name": "Name of the variable to display.\nWorks with local and global variables.",
		"prefix": "Text before the value (e.g. 'Score: ').",
		"suffix": "Text after the value (e.g. ' pts').",
		"static_text": "Fixed text to display (Static mode only).",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "variable")
	var variable_name = properties.get("variable_name", "")
	var prefix = properties.get("prefix", "")
	var suffix = properties.get("suffix", "")
	var static_text = properties.get("static_text", "")

	# Normalize
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower()

	var text_node_var = "_text_node_%s" % chain_name

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("@export var %s: Node" % text_node_var)

	code_lines.append("# Update text display")
	code_lines.append("if %s:" % text_node_var)

	match mode:
		"variable":
			if variable_name.is_empty():
				code_lines.append("\tpush_warning(\"Text Actuator: No variable name specified\")")
			else:
				# Direct variable access — works with local vars, @export vars, 
				# and global proxy vars (getter reads from GlobalVars automatically)
				code_lines.append("\tvar _value = str(%s)" % variable_name)

				if not prefix.is_empty() and not suffix.is_empty():
					code_lines.append("\tvar _display_text = \"%s\" + _value + \"%s\"" % [prefix, suffix])
				elif not prefix.is_empty():
					code_lines.append("\tvar _display_text = \"%s\" + _value" % prefix)
				elif not suffix.is_empty():
					code_lines.append("\tvar _display_text = _value + \"%s\"" % suffix)
				else:
					code_lines.append("\tvar _display_text = _value")

				_append_set_text_code(code_lines, text_node_var, "_display_text")

		"static":
			code_lines.append("\t# Set static text")
			_append_set_text_code(code_lines, text_node_var, "\"%s\"" % static_text)

		_:
			code_lines.append("\tpass  # Unknown mode")

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}


func _append_set_text_code(code_lines: Array, text_node_var: String, value_expr: String) -> void:
	code_lines.append("\tif %s is Label or %s is Label3D:" % [text_node_var, text_node_var])
	code_lines.append("\t\t%s.text = %s" % [text_node_var, value_expr])
	code_lines.append("\telif %s is RichTextLabel:" % text_node_var)
	code_lines.append("\t\t%s.text = %s" % [text_node_var, value_expr])
