@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Get Transforms Actuator - Reads position, rotation, and/or scale from a Node2D or Node3D.
## A target can be found by node name or by the nearest member of a group.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Get Transforms"


func get_brick_info() -> Dictionary:
	return {
		"class": "GetTransformsActuator",
		"name": "Get Transforms",
		"type": "actuator",
		"category": "Object",
		"description": "Gets position, rotation, and scale from a node or the nearest member of a group and stores the values as variables.",
		"menu_order": 235,
		"domain": "common"
	}


func _initialize_properties() -> void:
	properties = {
		"target_mode": "node_name",
		"target_name": "",
		"get_position": true,
		"position_variable": "",
		"get_rotation": false,
		"rotation_variable": "",
		"get_scale": false,
		"scale_variable": ""
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Node Name,Group",
			"default": "node_name"
		},
		{
			"name": "target_name",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Node or group name"
		},
		{
			"name": "get_position",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "position_variable",
			"type": TYPE_STRING,
			"default": "",
			"visible_if": {"get_position": true}
		},
		{
			"name": "get_rotation",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "rotation_variable",
			"type": TYPE_STRING,
			"default": "",
			"visible_if": {"get_rotation": true}
		},
		{
			"name": "get_scale",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "scale_variable",
			"type": TYPE_STRING,
			"default": "",
			"visible_if": {"get_scale": true}
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Gets transform data from a Node2D or Node3D and stores each selected value as a variable for later bricks.",
		"target_mode": "Node Name: finds the first node with this name in the current scene.\nGroup: finds the closest compatible member of the named group.",
		"target_name": "The node name or group name to search for.",
		"get_position": "Store the target's global position. Returns Vector2 for Node2D or Vector3 for Node3D.",
		"position_variable": "Variable name used to store the target's global position.",
		"get_rotation": "Store the target's global rotation. Returns a float in radians for Node2D or Vector3 radians for Node3D.",
		"rotation_variable": "Variable name used to store the target's global rotation.",
		"get_scale": "Store the target's global scale. Returns Vector2 for Node2D or Vector3 for Node3D.",
		"scale_variable": "Variable name used to store the target's global scale."
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_mode := str(properties.get("target_mode", "node_name")).to_lower().replace(" ", "_")
	var target_name := str(properties.get("target_name", "")).strip_edges()
	var get_position := bool(properties.get("get_position", true))
	var get_rotation := bool(properties.get("get_rotation", false))
	var get_scale := bool(properties.get("get_scale", false))
	var position_variable := _sanitize_identifier(str(properties.get("position_variable", "")))
	var rotation_variable := _sanitize_identifier(str(properties.get("rotation_variable", "")))
	var scale_variable := _sanitize_identifier(str(properties.get("scale_variable", "")))

	var errors: Array[String] = []
	if target_name.is_empty():
		errors.append("Target Name is empty")
	if not get_position and not get_rotation and not get_scale:
		errors.append("no transform values are selected")
	if get_position and position_variable.is_empty():
		errors.append("Position is selected but Position Variable is empty")
	if get_rotation and rotation_variable.is_empty():
		errors.append("Rotation is selected but Rotation Variable is empty")
	if get_scale and scale_variable.is_empty():
		errors.append("Scale is selected but Scale Variable is empty")
	if not errors.is_empty():
		return {"actuator_code": "push_warning(\"Get Transforms: %s.\")" % ", ".join(errors)}

	var label := _unique_label(chain_name)
	var target_var := "_%s_target" % label
	var candidates_var := "_%s_candidates" % label
	var best_distance_var := "_%s_best_distance" % label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = ["# Get Transforms Actuator", "var %s: Node = null" % target_var]

	if get_position and not _node_has_logic_variable(node, position_variable):
		member_vars.append("var %s = null" % position_variable)
	if get_rotation and not _node_has_logic_variable(node, rotation_variable):
		member_vars.append("var %s = null" % rotation_variable)
	if get_scale and not _node_has_logic_variable(node, scale_variable):
		member_vars.append("var %s = null" % scale_variable)

	var safe_target := _gd_string(target_name)
	if target_mode == "group":
		code_lines.append("var %s = get_tree().get_nodes_in_group(\"%s\")" % [candidates_var, safe_target])
		code_lines.append("var %s := INF" % best_distance_var)
		code_lines.append("for _candidate in %s:" % candidates_var)
		code_lines.append("\tif self is Node2D and _candidate is Node2D:")
		code_lines.append("\t\tvar _candidate_distance := global_position.distance_squared_to(_candidate.global_position)")
		code_lines.append("\t\tif _candidate_distance < %s:" % best_distance_var)
		code_lines.append("\t\t\t%s = _candidate_distance" % best_distance_var)
		code_lines.append("\t\t\t%s = _candidate" % target_var)
		code_lines.append("\telif self is Node3D and _candidate is Node3D:")
		code_lines.append("\t\tvar _candidate_distance := global_position.distance_squared_to(_candidate.global_position)")
		code_lines.append("\t\tif _candidate_distance < %s:" % best_distance_var)
		code_lines.append("\t\t\t%s = _candidate_distance" % best_distance_var)
		code_lines.append("\t\t\t%s = _candidate" % target_var)
	else:
		code_lines.append("var _%s_scene_root := get_tree().current_scene" % label)
		code_lines.append("if _%s_scene_root:" % label)
		code_lines.append("\t%s = _%s_scene_root.find_child(\"%s\", true, false)" % [target_var, label, safe_target])
		code_lines.append("if %s == null:" % target_var)
		code_lines.append("\t%s = get_tree().root.find_child(\"%s\", true, false)" % [target_var, safe_target])

	code_lines.append("if %s is Node2D:" % target_var)
	if get_position:
		code_lines.append("\t%s = %s.global_position" % [position_variable, target_var])
	if get_rotation:
		code_lines.append("\t%s = %s.global_rotation" % [rotation_variable, target_var])
	if get_scale:
		code_lines.append("\t%s = %s.global_scale" % [scale_variable, target_var])
	code_lines.append("elif %s is Node3D:" % target_var)
	if get_position:
		code_lines.append("\t%s = %s.global_position" % [position_variable, target_var])
	if get_rotation:
		code_lines.append("\t%s = %s.global_rotation" % [rotation_variable, target_var])
	if get_scale:
		code_lines.append("\t%s = %s.global_basis.get_scale()" % [scale_variable, target_var])
	code_lines.append("elif %s:" % target_var)
	code_lines.append("\tpush_warning(\"Get Transforms: target '%s' is not a Node2D or Node3D\")" % safe_target)
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Get Transforms: no compatible target found for '%s'\")" % safe_target)

	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}


func _node_has_logic_variable(node: Node, variable_name: String) -> bool:
	if node == null or variable_name.is_empty() or not node.has_meta("logic_bricks_variables"):
		return false
	var variables_data = node.get_meta("logic_bricks_variables")
	if not (variables_data is Array):
		return false
	for var_data in variables_data:
		if var_data is Dictionary and str(var_data.get("name", "")).strip_edges() == variable_name:
			return true
	return false


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


func _unique_label(chain_name: String) -> String:
	var label := instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	label = label.to_lower().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	return label if not label.is_empty() else "get_transforms"


func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")
