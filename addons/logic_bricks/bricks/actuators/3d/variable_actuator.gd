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
		"value": "",                # Value to assign/add
		"source_variable": ""       # For copy mode: source variable name
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "variable_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Assign,Add,Copy,Toggle",
			"default": "assign"
		},
		{
			"name": "value",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "source_variable",
			"type": TYPE_STRING,
			"default": ""
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Modifies a variable's value.\nWorks with local and global variables.\nAutomatically uses GlobalVars if not found locally.",
		"variable_name": "Name of the variable to modify.",
		"mode": "Assign: set to value\nAdd: add value to current\nCopy: copy from another variable\nToggle: flip a boolean",
		"value": "Value to assign or add.\nAccepts numbers, booleans, strings, or expressions.",
		"source_variable": "Source variable name (Copy mode only).",
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
	
	# Normalize mode
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")
	
	if var_name.is_empty():
		return {"actuator_code": "pass  # Variable actuator: no variable name specified"}
	
	var sanitized_name = _sanitize_name(var_name)
	var code_lines: Array[String] = []
	
	# Add resolve block
	code_lines.append_array(_generate_resolve_code(sanitized_name))
	code_lines.append("if _target:")
	
	match mode:
		"assign":
			if value.is_empty():
				code_lines.append("\tpass  # No value to assign")
			else:
				var parsed_value = _parse_value(value)
				code_lines.append("\t_target.set(\"%s\", %s)" % [sanitized_name, parsed_value])
		
		"add":
			if value.is_empty():
				code_lines.append("\tpass  # No value to add")
			else:
				var parsed_value = _parse_value(value)
				code_lines.append("\t_target.set(\"%s\", _target.get(\"%s\") + %s)" % [sanitized_name, sanitized_name, parsed_value])
		
		"copy":
			if source_var.is_empty():
				code_lines.append("\tpass  # No source variable specified")
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
				code_lines.append("\t\t_target.set(\"%s\", _src_val)" % sanitized_name)
		
		"toggle":
			code_lines.append("\tvar _cur = _target.get(\"%s\")" % sanitized_name)
			code_lines.append("\tif typeof(_cur) == TYPE_BOOL:")
			code_lines.append("\t\t_target.set(\"%s\", not _cur)" % sanitized_name)
	
	return {
		"actuator_code": "\n".join(code_lines)
	}


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
	
	# Could be a variable name or expression
	if value_str.is_valid_identifier():
		return value_str
	
	# Default: string
	return "\"%s\"" % value_str.replace("\"", "\\\"")
