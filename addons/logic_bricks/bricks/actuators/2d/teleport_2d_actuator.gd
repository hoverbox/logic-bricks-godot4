@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Teleport 2D Actuator - Instantly sets position to a target node or coordinates
## Useful for respawning, portals, checkpoints, and warping
## The target node is found by typed node name


func get_brick_info() -> Dictionary:
	return {
		"class": "Teleport2DActuator",
		"name": "Teleport 2D",
		"type": "actuator",
		"category": "Motion",
		"domain": "2d",
		"menu_order": 180
	}


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Teleport 2D"


func _initialize_properties() -> void:
	properties = {
		"target_node_name": "Target",
		"mode": "target_node", # target_node, coordinates, vector_variable
		"x": 0.0,
		"y": 0.0,
		"vector_variable": "",
		"clear_velocity": true,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_node_name",
			"type": TYPE_STRING,
			"default": "Target",
			"placeholder": "Target Node2D node name"
		},
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Target Node,Coordinates,Vector Variable",
			"default": "target_node"
		},
		{
			"name": "x",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "y",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "vector_variable",
			"type": TYPE_STRING,
			"default": "",
			"visible_if": {"mode": "vector_variable"}
		},
		{
			"name": "clear_velocity",
			"type": TYPE_BOOL,
			"default": true
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Instantly sets position to a target Node2D or coordinates.\nUseful for respawning, portals, checkpoints, and spawn points.",
		"target_node_name": "The name of the Node2D to teleport to when using Target Node mode.",
		"mode": "Target Node: teleport to another Node2D's position\nCoordinates: teleport to specific X/Y values",
		"clear_velocity": "Clears velocity and linear_velocity after teleporting so the object does not carry momentum through the teleport."
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "Target")).strip_edges()
	var mode = properties.get("mode", "target_node")
	var x = float(properties.get("x", 0.0))
	var y = float(properties.get("y", 0.0))
	var vector_variable = _sanitize_identifier(str(properties.get("vector_variable", "")))
	var clear_velocity = properties.get("clear_velocity", true)

	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")

	# Use instance name if set, otherwise use brick name, sanitized for use as a variable
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name

	var teleport_target_var = "_%s" % _export_label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	match mode:
		"target_node":
			member_vars.append("var %s: Node2D = null" % teleport_target_var)
			_append_find_node_helpers(member_vars)

			code_lines.append("# Teleport 2D to target node")
			code_lines.append("var _node_name_%s = \"%s\"" % [chain_name, _gd_string(target_node_name)])
			code_lines.append("if _node_name_%s.is_empty():" % chain_name)
			code_lines.append("\tpush_warning(\"Teleport 2D Actuator: No node name set\")")
			code_lines.append("\t" + teleport_target_var + " = null")
			code_lines.append("elif " + teleport_target_var + " == null or " + teleport_target_var + ".name != _node_name_%s:" % chain_name)
			code_lines.append("\tvar _found_node_%s = _lb_find_node_in_current_scene(_node_name_%s)" % [chain_name, chain_name])
			code_lines.append("\tif _found_node_%s is Node2D:" % chain_name)
			code_lines.append("\t\t" + teleport_target_var + " = _found_node_%s" % chain_name)
			code_lines.append("\telif _found_node_%s:" % chain_name)
			code_lines.append("\t\tpush_warning(\"Teleport 2D Actuator: node '\" + str(_node_name_%s) + \"' is not a Node2D\")" % chain_name)
			code_lines.append("if %s:" % teleport_target_var)
			code_lines.append("\tglobal_position = %s.global_position" % teleport_target_var)
			if clear_velocity:
				_append_clear_velocity_code(code_lines, "\t")
			code_lines.append("else:")
			code_lines.append("\tpush_warning(\"Teleport 2D Actuator: No target node found for '%s'\")" % teleport_target_var)

		"coordinates":
			code_lines.append("# Teleport 2D to coordinates")
			code_lines.append("global_position = Vector2(%.3f, %.3f)" % [x, y])
			if clear_velocity:
				_append_clear_velocity_code(code_lines)

		"vector_variable":
			if vector_variable.is_empty():
				code_lines.append("push_warning(\"Teleport 2D Actuator: Vector Variable mode requires a Vector2 variable name in this actuator.\")")
				return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}
			code_lines.append("# Teleport 2D to a Vector2 variable")
			code_lines.append("var _teleport_value = null")
			code_lines.append("if \"%s\" in self:" % vector_variable)
			code_lines.append("\t_teleport_value = get(\"%s\")" % vector_variable)
			code_lines.append("else:")
			code_lines.append("\tvar _teleport_globals = get_node_or_null(\"/root/GlobalVars\")")
			code_lines.append("\tif _teleport_globals and \"%s\" in _teleport_globals:" % vector_variable)
			code_lines.append("\t\t_teleport_value = _teleport_globals.get(\"%s\")" % vector_variable)
			code_lines.append("if _teleport_value is Vector2:")
			code_lines.append("\tglobal_position = _teleport_value")
			if clear_velocity:
				_append_clear_velocity_code(code_lines, "\t")
			code_lines.append("else:")
			code_lines.append("\tpush_warning(\"Teleport 2D Actuator: variable '%s' was not found or is not a Vector2\")" % vector_variable)

		_:
			code_lines.append("pass  # Unknown teleport 2D mode")

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}


func _append_clear_velocity_code(code_lines: Array[String], indent: String = "") -> void:
	code_lines.append(indent + "if get(\"velocity\") is Vector2:")
	code_lines.append(indent + "\tset(\"velocity\", Vector2.ZERO)")
	code_lines.append(indent + "if get(\"linear_velocity\") is Vector2:")
	code_lines.append(indent + "\tset(\"linear_velocity\", Vector2.ZERO)")


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


func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")


func _sanitize_identifier(value: String) -> String:
	var sanitized := value.strip_edges().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	sanitized = regex.sub(sanitized, "", true)
	if sanitized.is_empty():
		return ""
	if sanitized.substr(0, 1).is_valid_int():
		sanitized = "var_" + sanitized
	return sanitized
