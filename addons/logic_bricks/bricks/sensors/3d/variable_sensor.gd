@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Variable Sensor - Check variable values
## Compares a logic brick variable against a value
## Works with local, exported, and global variables
## Automatically checks GlobalVars autoload if variable isn't found locally


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Compare Variable"


func _initialize_properties() -> void:
	properties = {
		"variable_name": "",           # Name of the variable to check
		"evaluation_type": "equal",    # How to compare
		"value": "",                   # Value to compare against
		"min_value": "",               # Minimum value for interval mode
		"max_value": ""                # Maximum value for interval mode
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "variable_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "evaluation_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Equal,Not Equal,Interval,Changed,Greater Than,Less Than,Greater or Equal,Less or Equal",
			"default": "equal"
		},
		{
			"name": "value",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "min_value",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "max_value",
			"type": TYPE_STRING,
			"default": ""
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Compares a variable's value.\nWorks with local, exported, and global variables.\nAutomatically checks GlobalVars if not found locally.",
		"variable_name": "Name of the variable to check.\nCan be a local variable or a global variable.",
		"evaluation_type": "How to compare the variable.",
		"value": "Value to compare against.\nAccepts numbers, booleans, strings, or variable names.",
		"min_value": "Minimum value (for Interval mode).",
		"max_value": "Maximum value (for Interval mode).",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var var_name = properties.get("variable_name", "")
	var eval_type = properties.get("evaluation_type", "equal")
	var value = properties.get("value", "")
	var min_val = properties.get("min_value", "")
	var max_val = properties.get("max_value", "")
	
	# Normalize evaluation type
	if typeof(eval_type) == TYPE_STRING:
		eval_type = eval_type.to_lower().replace(" ", "_")
	
	if var_name.is_empty():
		return {"sensor_code": "var sensor_active = false  # Variable sensor: no variable name"}
	
	# Sanitize variable name
	var sanitized_name = var_name.strip_edges().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	sanitized_name = regex.sub(sanitized_name, "", true)
	
	var code_lines: Array[String] = []
	var member_vars: Array[String] = []
	
	# Generate a helper to get the variable value
	# Checks local first (covers both local vars and global proxies), then GlobalVars fallback
	var val_expr = "_vs_%s" % sanitized_name
	code_lines.append("# Get variable '%s' (local or global)" % sanitized_name)
	code_lines.append("var %s" % val_expr)
	code_lines.append("if \"%s\" in self:" % sanitized_name)
	code_lines.append("\t%s = self.get(\"%s\")" % [val_expr, sanitized_name])
	code_lines.append("elif Engine.has_singleton(\"GlobalVars\") or get_node_or_null(\"/root/GlobalVars\"):")
	code_lines.append("\tvar _gv = get_node_or_null(\"/root/GlobalVars\")")
	code_lines.append("\tif _gv and \"%s\" in _gv:" % sanitized_name)
	code_lines.append("\t\t%s = _gv.get(\"%s\")" % [val_expr, sanitized_name])
	code_lines.append("\telse:")
	code_lines.append("\t\t%s = null" % val_expr)
	code_lines.append("else:")
	code_lines.append("\t%s = null" % val_expr)
	
	match eval_type:
		"equal":
			if value.is_empty():
				code_lines.append("var sensor_active = false  # No comparison value set")
			else:
				var compare_value = _parse_value(value)
				code_lines.append("var sensor_active = (%s != null and %s == %s)" % [val_expr, val_expr, compare_value])
		
		"not_equal":
			if value.is_empty():
				code_lines.append("var sensor_active = false  # No comparison value set")
			else:
				var compare_value = _parse_value(value)
				code_lines.append("var sensor_active = (%s != null and %s != %s)" % [val_expr, val_expr, compare_value])
		
		"greater_than", "greater":
			if value.is_empty():
				code_lines.append("var sensor_active = false  # No comparison value set")
			else:
				var compare_value = _parse_value(value)
				code_lines.append("var sensor_active = (%s != null and %s > %s)" % [val_expr, val_expr, compare_value])
		
		"less_than", "less":
			if value.is_empty():
				code_lines.append("var sensor_active = false  # No comparison value set")
			else:
				var compare_value = _parse_value(value)
				code_lines.append("var sensor_active = (%s != null and %s < %s)" % [val_expr, val_expr, compare_value])
		
		"greater_or_equal", "greater_equal":
			if value.is_empty():
				code_lines.append("var sensor_active = false  # No comparison value set")
			else:
				var compare_value = _parse_value(value)
				code_lines.append("var sensor_active = (%s != null and %s >= %s)" % [val_expr, val_expr, compare_value])
		
		"less_or_equal", "less_equal":
			if value.is_empty():
				code_lines.append("var sensor_active = false  # No comparison value set")
			else:
				var compare_value = _parse_value(value)
				code_lines.append("var sensor_active = (%s != null and %s <= %s)" % [val_expr, val_expr, compare_value])
		
		"interval":
			if min_val.is_empty() or max_val.is_empty():
				code_lines.append("var sensor_active = false  # Interval values not set")
			else:
				var min_compare = _parse_value(min_val)
				var max_compare = _parse_value(max_val)
				code_lines.append("var sensor_active = (%s != null and %s >= %s and %s <= %s)" % [val_expr, val_expr, min_compare, val_expr, max_compare])
		
		"changed":
			var prev_var_name = "_prev_%s_%s" % [sanitized_name, chain_name]
			member_vars.append("var %s = null" % prev_var_name)
			code_lines.append("var _changed = (%s != %s)" % [prev_var_name, val_expr])
			code_lines.append("%s = %s" % [prev_var_name, val_expr])
			code_lines.append("var sensor_active = _changed")
		
		_:
			code_lines.append("var sensor_active = false  # Unknown evaluation type")
	
	var result = {
		"sensor_code": "\n".join(code_lines)
	}
	
	if member_vars.size() > 0:
		result["member_vars"] = member_vars
	
	return result


func _parse_value(value_str: String) -> String:
	value_str = value_str.strip_edges()
	
	# Boolean
	if value_str.to_lower() == "true":
		return "true"
	if value_str.to_lower() == "false":
		return "false"
	
	# Number
	if value_str.is_valid_float():
		return value_str
	
	# Vector2/Vector3
	if value_str.begins_with("Vector2(") or value_str.begins_with("Vector3("):
		return value_str
	
	# Variable name
	if value_str.is_valid_identifier():
		return value_str
	
	# Default: treat as string
	return "\"%s\"" % value_str.replace("\"", "\\\"")
