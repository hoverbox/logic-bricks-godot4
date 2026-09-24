@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Rotation Actuator
## A dedicated single-purpose actuator that only rotates a Node3D.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Rotation"

func get_brick_info() -> Dictionary:
	return {
		"class": "RotationActuator",
		"name": "Rotation",
		"type": "actuator",
		"category": "Motion",
		"description": "Rotates a 3D object around its X, Y, and Z axes.",
		"menu_order": 40,
		"domain": "3d"
	}

func _initialize_properties() -> void:
	properties = {
		"target_node_name": "",
		"x": "0.0",
		"y": "0.0",
		"z": "0.0",
		"space": "local"
	}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "", "placeholder": "blank = self, or child/node name"},
		{"name": "x", "type": TYPE_STRING, "default": "0.0"},
		{"name": "y", "type": TYPE_STRING, "default": "0.0"},
		{"name": "z", "type": TYPE_STRING, "default": "0.0"},
		{"name": "space", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Local,Global", "default": "local"}
	]

func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	if _is_numeric_zero(properties.get("x", "0.0")) and _is_numeric_zero(properties.get("y", "0.0")) and _is_numeric_zero(properties.get("z", "0.0")):
		warnings.append("Put a Value or Variable in X,Y, or Z")
	return warnings


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Rotates a 3D object. This actuator controls rotation only.",
		"target_node_name": "Leave blank to rotate this node, or enter a child/node name.",
		"x": "Rotation around the X axis in degrees.",
		"y": "Rotation around the Y axis in degrees.",
		"z": "Rotation around the Z axis in degrees.",
		"space": "Local rotates around the object's own axes. Global rotates around world axes."
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var lines: Array[String] = []
	var members: Array[String] = []
	var target := _build_target(lines, members, chain_name)
	var x_expr := _value_expression(properties.get("x", "0.0"), "0.0")
	var y_expr := _value_expression(properties.get("y", "0.0"), "0.0")
	var z_expr := _value_expression(properties.get("z", "0.0"), "0.0")
	var space := str(properties.get("space", "local")).to_lower()

	if space == "global":
		lines.append("\t%s.global_rotation += Vector3(deg_to_rad(%s), deg_to_rad(%s), deg_to_rad(%s))" % [target, x_expr, y_expr, z_expr])
	else:
		var wrote_rotation := false
		if not _is_numeric_zero(properties.get("x", "0.0")):
			lines.append("\t%s.rotate_x(deg_to_rad(%s))" % [target, x_expr])
			wrote_rotation = true
		if not _is_numeric_zero(properties.get("y", "0.0")):
			lines.append("\t%s.rotate_y(deg_to_rad(%s))" % [target, y_expr])
			wrote_rotation = true
		if not _is_numeric_zero(properties.get("z", "0.0")):
			lines.append("\t%s.rotate_z(deg_to_rad(%s))" % [target, z_expr])
			wrote_rotation = true
		if not wrote_rotation:
			lines.append("\tpass")

	return {"actuator_code": "\n".join(lines), "member_vars": members}

func _build_target(lines: Array[String], members: Array[String], chain_name: String) -> String:
	var target_name := str(properties.get("target_node_name", "")).strip_edges()
	if target_name.is_empty():
		lines.append("if not (self is Node3D):")
		lines.append("\tpush_warning(\"Rotation Actuator: self is not a Node3D\")")
		lines.append("else:")
		return "self"

	var label := _unique_label(chain_name)
	var target_var := "_rotation_target_%s" % label
	members.append("var %s = null" % target_var)
	lines.append("var _rotation_target_name_%s = \"%s\"" % [label, _gd_string(target_name)])
	lines.append("if %s == null or %s.name != _rotation_target_name_%s:" % [target_var, target_var, label])
	lines.append("\t%s = find_child(_rotation_target_name_%s, true, false)" % [target_var, label])
	lines.append("\tif %s == null and get_tree().current_scene:" % target_var)
	lines.append("\t\t%s = get_tree().current_scene.find_child(_rotation_target_name_%s, true, false)" % [target_var, label])
	lines.append("if %s == null:" % target_var)
	lines.append("\tpush_warning(\"Rotation Actuator: target node was not found\")")
	lines.append("elif not (%s is Node3D):" % target_var)
	lines.append("\tpush_warning(\"Rotation Actuator: target is not a Node3D\")")
	lines.append("else:")
	return target_var

func _value_expression(value, fallback: String) -> String:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return str(value)
	var text := str(value).strip_edges()
	if text.is_empty():
		return fallback
	return text

func _is_numeric_zero(value) -> bool:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value) == 0.0
	var text := str(value).strip_edges()
	if text.is_empty():
		return true
	if text.is_valid_float() or text.is_valid_int():
		return float(text) == 0.0
	return false

func _unique_label(chain_name: String) -> String:
	var raw := "%s_%s" % [chain_name, str(abs(str(properties).hash()))]
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	return regex.sub(raw, "", true)
