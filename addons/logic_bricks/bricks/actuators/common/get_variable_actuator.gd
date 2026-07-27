@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Get Variable Actuator - Reads a variable/property from another node, self, or GlobalVars
## and stores it as a local variable on the generated Logic Bricks script.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Get Variable"


func get_brick_info() -> Dictionary:
	return {
		"class": "GetVariableActuator",
		"name": "Get Variable",
		"type": "actuator",
		"category": "Logic",
		"description": "Reads a variable from self, another node, or GlobalVars and stores it for later bricks.",
		"menu_order": 355,
		"domain": "common"
	}


func _initialize_properties() -> void:
	properties = {
		"source": "node_name",
		"source_node_name": "",
		"variable_name": "",
		"store_as": "",
		"fallback_value": ""
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "source",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Self,Node Name,GlobalVars",
			"default": "node_name"
		},
		{
			"name": "source_node_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "variable_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "store_as",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "fallback_value",
			"type": TYPE_STRING,
			"default": ""
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Reads a variable/property from self, another node, or GlobalVars, then stores it as a local variable that later bricks can use. Useful for UI health bars, ammo labels, score text, and timers.",
		"source": "Self: read from this node.\nNode Name: search the current scene for a node with this name.\nGlobalVars: read from the GlobalVars autoload.",
		"source_node_name": "The name of the node to read from when Source is Node Name. Example: Player.",
		"variable_name": "The variable/property to read from the source. Example: health, ammo, score.",
		"store_as": "The local variable name to store the value in. Later bricks can use this name. Example: current_health.",
		"fallback_value": "Optional value to use if the source or variable cannot be found. Leave blank to keep the previous value."
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var source := str(properties.get("source", "node_name")).to_lower().replace(" ", "_")
	var source_node_name := str(properties.get("source_node_name", "")).strip_edges()
	var variable_name := str(properties.get("variable_name", "")).strip_edges()
	var store_as := _sanitize_identifier(str(properties.get("store_as", "")).strip_edges())
	var fallback_value := str(properties.get("fallback_value", "")).strip_edges()

	var validation_errors: Array[String] = []
	if source == "node_name" and source_node_name.is_empty():
		validation_errors.append("Source Node is empty")
	if variable_name.is_empty():
		validation_errors.append("Variable Name is empty")
	if store_as.is_empty():
		validation_errors.append("Store As is empty")
	if not validation_errors.is_empty():
		return {"actuator_code": "push_warning(\"Get Variable: %s. Open the brick and fill in the missing field(s).\")" % ", ".join(validation_errors)}

	var label := _unique_label(chain_name)
	var source_var := "_%s_source" % label
	var value_var := "_%s_value" % label
	var found_var := "_%s_found" % label
	var member_vars: Array[String] = []
	if not _node_has_logic_variable(node, store_as):
		member_vars.append("var %s = null" % store_as)
	var code_lines: Array[String] = []

	code_lines.append("# Get Variable Actuator")
	code_lines.append("var %s: Node = null" % source_var)

	match source:
		"self":
			code_lines.append("%s = self" % source_var)
		"globalvars":
			code_lines.append("%s = get_node_or_null(\"/root/GlobalVars\")" % source_var)
		_:
			if source_node_name.is_empty():
				code_lines.append("push_warning(\"Get Variable: Source is Node Name, but no source node name is set\")")
			else:
				var safe_node_name := _gd_string(source_node_name)
				code_lines.append("var _%s_node_name := \"%s\"" % [label, safe_node_name])
				code_lines.append("var _%s_scene_root := get_tree().current_scene" % label)
				code_lines.append("if _%s_scene_root:" % label)
				code_lines.append("\t%s = _%s_scene_root.find_child(_%s_node_name, true, false)" % [source_var, label, label])
				code_lines.append("if %s == null:" % source_var)
				code_lines.append("\t%s = get_tree().root.find_child(_%s_node_name, true, false)" % [source_var, label])

	code_lines.append("if %s:" % source_var)
	code_lines.append("\tvar %s = null" % value_var)
	code_lines.append("\tvar %s := false" % found_var)
	code_lines.append("\tif \"%s\" in %s:" % [_gd_string(variable_name), source_var])
	code_lines.append("\t\t%s = %s.get(\"%s\")" % [value_var, source_var, _gd_string(variable_name)])
	code_lines.append("\t\t%s = true" % found_var)
	code_lines.append("\tif %s:" % found_var)
	code_lines.append("\t\t%s = %s" % [store_as, value_var])
	code_lines.append("\telse:")
	if fallback_value.is_empty():
		code_lines.append("\t\tpush_warning(\"Get Variable: variable '%s' was not found on the source node\")" % _gd_string(variable_name))
	else:
		code_lines.append("\t\t%s = %s" % [store_as, _parse_value(fallback_value)])
		code_lines.append("\t\tpush_warning(\"Get Variable: variable '%s' was not found; using fallback value\")" % _gd_string(variable_name))
	code_lines.append("else:")
	if fallback_value.is_empty():
		code_lines.append("\tpush_warning(\"Get Variable: source node was not found\")")
	else:
		code_lines.append("\t%s = %s" % [store_as, _parse_value(fallback_value)])
		code_lines.append("\tpush_warning(\"Get Variable: source node was not found; using fallback value\")")

	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}


func _node_has_logic_variable(node: Node, variable_name: String) -> bool:
	if node == null or variable_name.is_empty():
		return false
	if not node.has_meta("logic_bricks_variables"):
		return false
	var variables_data = node.get_meta("logic_bricks_variables")
	if not (variables_data is Array):
		return false
	for var_data in variables_data:
		if var_data is Dictionary and str(var_data.get("name", "")).strip_edges() == variable_name:
			return true
	return false


func _sanitize_identifier(value: String) -> String:
	var sanitized := value.replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	sanitized = regex.sub(sanitized, "", true)
	if sanitized.is_empty():
		return ""
	var first := sanitized.substr(0, 1)
	if first.is_valid_int():
		sanitized = "var_" + sanitized
	return sanitized


func _unique_label(chain_name: String) -> String:
	var label := instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	label = label.to_lower().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	return label if not label.is_empty() else "get_variable"


func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")


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
	return "\"%s\"" % _gd_string(value_str)
