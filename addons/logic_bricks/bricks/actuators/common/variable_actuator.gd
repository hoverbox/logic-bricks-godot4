@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Variable Actuator - Modify variable values
## Works with local, exported, and global variables
## Automatically uses GlobalVars if variable isn't found locally


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Modify Variable"


func _initialize_properties() -> void:
	properties = {
		"variable_name": "",        # Name of the variable to modify
		"mode": "assign",           # assign, add, copy, toggle
		"value": "",                # Value to assign/adjust/replace/append/prepend
		"source_variable": "",      # For copy mode: source variable name
		"item_type": "String",        # Array item type
		"index": "0"                 # Array item index
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "variable_name", "required": true, "required_label": "a variable name",
			"type": TYPE_STRING,
			"variable_picker": true,
			"default": ""
		},
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Assign:assign,Adjust By:add,Copy:copy,Toggle:toggle",
			"default": "assign"
		},
		{
			"name": "value", "required": true, "required_label": "a value", "required_if": {"mode": ["assign", "add", "replace", "prepend", "append"]},
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "source_variable", "required": true, "required_label": "a source variable", "required_if": {"mode": "copy"},
			"type": TYPE_STRING,
			"variable_picker": true,
			"default": ""
		},
		{
			"name": "item_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "bool,int,float,String,Vector2,Vector3",
			"default": "String"
		},
		{
			"name": "index",
			"type": TYPE_STRING,
			"default": "0"
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Modifies a variable's value.\nWorks with local and global variables.\nAutomatically uses GlobalVars if not found locally.",
		"variable_name": "Name of the variable to modify. Type a name or choose an existing local/global variable from the dropdown.",
		"mode": "Number: Assign, Adjust By, Copy, Toggle\nString: Replace, Add Before, Add After, Copy\nArray: item operations, Assign, Copy",
		"value": "Value used by the selected operation. String values are plain text — do not add quotation marks. Numeric values can use variables or math expressions (for example: MinSpeed * 2).",
		"source_variable": "Source variable name (Copy mode only). Type a name or choose an existing variable from the dropdown.",
	}


## Generate a helper block that resolves a variable to either local or GlobalVars
## Returns the object that owns the variable and whether it was found
func _generate_resolve_code(sanitized_name: String, indent: String = "") -> Array[String]:
	var lines: Array[String] = []
	lines.append("%s# Resolve variable (local or global)" % indent)
	lines.append("%svar _target = self" % indent)
	lines.append("%sif not (\"%s\" in self):" % [indent, sanitized_name])
	lines.append("%s\tvar _gv = get_node_or_null(\"/root/GlobalVars\")" % indent)
	lines.append("%s\tif _gv and \"%s\" in _gv:" % [indent, sanitized_name])
	lines.append("%s\t\t_target = _gv" % indent)
	lines.append("%s\telse:" % indent)
	lines.append("%s\t\tpush_warning(\"Modify Variable: '%s' not found locally or in GlobalVars\")" % [indent, sanitized_name])
	lines.append("%s\t\t_target = null" % indent)
	return lines


func _sanitize_name(name: String) -> String:
	var sanitized = name.strip_edges().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	return regex.sub(sanitized, "", true)


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var var_name = properties.get("variable_name", "")
	var mode = properties.get("mode", "assign")
	var value = properties.get("value", "")
	var source_var = properties.get("source_variable", "")
	var item_type = str(properties.get("item_type", "String"))
	var index_value = str(properties.get("index", "0")).strip_edges()

	# Normalize mode
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")
		# Keep the existing Add behavior while using the clearer Adjust By label.
		if mode == "adjust_by":
			mode = "add"

	if var_name.is_empty():
		return {"actuator_code": "push_warning(\"Modify Variable: No variable name set — open the brick and enter a variable name\")"}

	var sanitized_name = _sanitize_name(var_name)
	var code_lines: Array[String] = []

	# Add resolve block
	code_lines.append_array(_generate_resolve_code(sanitized_name))
	code_lines.append("if _target:")

	match mode:
		"assign":
			if value.is_empty():
				code_lines.append("\tpush_warning(\"Modify Variable: No value set for '%s' — open the brick and enter a value\")" % sanitized_name)
			else:
				var parsed_value = _parse_value(value)
				code_lines.append("\t_target.set(\"%s\", %s)" % [sanitized_name, parsed_value])

		"add":
			if value.is_empty():
				code_lines.append("\tpush_warning(\"Modify Variable: No value set for '%s' — open the brick and enter a value\")" % sanitized_name)
			else:
				var parsed_value = _parse_value(value)
				code_lines.append("\t_target.set(\"%s\", _target.get(\"%s\") + %s)" % [sanitized_name, sanitized_name, parsed_value])

		"replace", "prepend", "append":
			if value.is_empty():
				code_lines.append("\tpush_warning(\"Modify Variable: No text set for '%s' — open the brick and enter text\")" % sanitized_name)
			else:
				var string_value := _quote_string(value)
				if mode == "replace":
					code_lines.append("\t_target.set(\"%s\", %s)" % [sanitized_name, string_value])
				elif mode == "prepend":
					code_lines.append("\t_target.set(\"%s\", %s + str(_target.get(\"%s\")))" % [sanitized_name, string_value, sanitized_name])
				else:
					code_lines.append("\t_target.set(\"%s\", str(_target.get(\"%s\")) + %s)" % [sanitized_name, sanitized_name, string_value])

		"copy":
			if source_var.is_empty():
				code_lines.append("\tpush_warning(\"Modify Variable: No source variable set for Copy mode — open the brick and enter a source variable name\")")
			else:
				var sanitized_source = _sanitize_name(source_var)
				# Resolve source variable too
				code_lines.append("\t# Resolve source variable")
				code_lines.append("\tvar _src_val = null")
				code_lines.append("\tif \"%s\" in self:" % sanitized_source)
				code_lines.append("\t\t_src_val = self.get(\"%s\")" % sanitized_source)
				code_lines.append("\telse:")
				code_lines.append("\t\tvar _gv_src = get_node_or_null(\"/root/GlobalVars\")")
				code_lines.append("\t\tif _gv_src and \"%s\" in _gv_src:" % sanitized_source)
				code_lines.append("\t\t\t_src_val = _gv_src.get(\"%s\")" % sanitized_source)
				code_lines.append("\tif _src_val != null:")
				code_lines.append("\t\t_target.set(\"%s\", _src_val.duplicate(true) if _src_val is Array else _src_val)" % sanitized_name)

		"add_item", "remove_item":
			if value.is_empty():
				code_lines.append("\tpush_warning(\"Modify Variable: Array item value is empty for '%s'\")" % sanitized_name)
			else:
				var parsed_item = _parse_typed_value(value, item_type)
				code_lines.append("\tvar _arr = _target.get(\"%s\")" % sanitized_name)
				code_lines.append("\tif _arr is Array:")
				if mode == "add_item":
					code_lines.append("\t\t_arr.append(%s)" % parsed_item)
				else:
					code_lines.append("\t\t_arr.erase(%s)" % parsed_item)

		"remove_at_index":
			if not index_value.is_valid_int():
				code_lines.append("\tpush_warning(\"Modify Variable: Remove At Index requires an integer index\")")
			else:
				code_lines.append("\tvar _arr = _target.get(\"%s\")" % sanitized_name)
				code_lines.append("\tvar _idx = %s" % index_value)
				code_lines.append("\tif _arr is Array and _idx >= 0 and _idx < _arr.size():")
				code_lines.append("\t\t_arr.remove_at(_idx)")
				code_lines.append("\telse:")
				code_lines.append("\t\tpush_warning(\"Modify Variable: Array index out of range\")")

		"set_item_at_index":
			if not index_value.is_valid_int() or value.is_empty():
				code_lines.append("\tpush_warning(\"Modify Variable: Set Item At Index requires an integer index and value\")")
			else:
				var parsed_item = _parse_typed_value(value, item_type)
				code_lines.append("\tvar _arr = _target.get(\"%s\")" % sanitized_name)
				code_lines.append("\tvar _idx = %s" % index_value)
				code_lines.append("\tif _arr is Array and _idx >= 0 and _idx < _arr.size():")
				code_lines.append("\t\t_arr[_idx] = %s" % parsed_item)
				code_lines.append("\telse:")
				code_lines.append("\t\tpush_warning(\"Modify Variable: Array index out of range\")")

		"clear":
			code_lines.append("\tvar _arr = _target.get(\"%s\")" % sanitized_name)
			code_lines.append("\tif _arr is Array:")
			code_lines.append("\t\t_arr.clear()")

		"toggle":
			code_lines.append("\tvar _cur = _target.get(\"%s\")" % sanitized_name)
			code_lines.append("\tif typeof(_cur) == TYPE_BOOL:")
			code_lines.append("\t\t_target.set(\"%s\", not _cur)" % sanitized_name)

	return {
		"actuator_code": "\n".join(code_lines)
	}


func _quote_string(value_str: String) -> String:
	var text := value_str.strip_edges()
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		text = text.substr(1, text.length() - 2)
	return "\"%s\"" % text.replace("\\", "\\\\").replace("\"", "\\\"")


func _parse_value(value_str: String) -> String:
	value_str = value_str.strip_edges()

	if value_str.to_lower() == "true":
		return "true"
	if value_str.to_lower() == "false":
		return "false"

	if value_str.is_valid_float():
		return value_str

	if value_str.begins_with("Vector2(") or value_str.begins_with("Vector3("):
		return value_str

	if value_str.begins_with("Color(") and value_str.ends_with(")"):
		return value_str

	if value_str.begins_with("[") and value_str.ends_with("]"):
		return value_str

	# A single variable name can be emitted directly.
	if value_str.is_valid_identifier():
		return value_str

	# Preserve explicitly quoted strings.
	if value_str.length() >= 2 and value_str.begins_with("\"") and value_str.ends_with("\""):
		return value_str

	# Math expressions such as MinSpeed * 2 should be emitted as code, not text.
	# Keep this intentionally limited to arithmetic so ordinary text with spaces
	# still behaves like a String value.
	if _is_math_expression(value_str):
		return value_str

	# Default: string
	return "\"%s\"" % value_str.replace("\"", "\\\"")


func _is_math_expression(value_str: String) -> bool:
	var has_operator := false
	for operator in ["+", "-", "*", "/", "%"]:
		if value_str.contains(operator):
			has_operator = true
			break
	if not has_operator:
		return false

	var regex := RegEx.new()
	regex.compile("^[a-zA-Z0-9_+\\-*/%(). \t]+$")
	return regex.search(value_str) != null


func _parse_typed_value(value_str: String, type_name: String) -> String:
	var text := value_str.strip_edges()
	match type_name:
		"bool": return "true" if text.to_lower() in ["true", "1", "yes", "on"] else "false"
		"int": return str(text.to_int()) if text.is_valid_int() else "0"
		"float": return text if text.is_valid_float() else "0.0"
		"Vector2", "Vector3": return text if text.begins_with(type_name + "(") else type_name + ".ZERO"
		_: return '"%s"' % text.replace('\"', '\\"')
