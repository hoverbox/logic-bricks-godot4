@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Rotation 2D Actuator - Rotates a Node2D.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Rotation 2D"

func get_brick_info() -> Dictionary:
	return {
		"class": "Rotation2DActuator",
		"name": "Rotation 2D",
		"type": "actuator",
		"category": "Motion",
		"description": "Rotates a 2D object.",
		"menu_order": 40,
		"domain": "2d"
	}

func _initialize_properties() -> void:
	properties = {
		"target_node_name": "",
		"degrees": "0.0",
		"space": "local"
	}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "", "placeholder": "blank = self, or child/node name"},
		{"name": "degrees", "type": TYPE_STRING, "default": "0.0"},
		{"name": "space", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Local,Global", "default": "local"}
	]


func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	if _validation_all_numeric_zero(["degrees"]):
		warnings.append("Put a Value or Variable in Rotation")
	return warnings

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Rotates a 2D object by a number of degrees.",
		"target_node_name": "Leave blank to rotate this node, or enter a child/node name.",
		"degrees": "Degrees to rotate. Positive values rotate clockwise in Godot's 2D coordinate system.",
		"space": "Local changes local rotation. Global changes global rotation."
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var lines: Array[String] = []
	var members: Array[String] = []
	var target := _build_target(lines, members, chain_name)
	var degrees_expr := _value_expression(properties.get("degrees", "0.0"), "0.0")
	if str(properties.get("space", "local")).to_lower() == "global":
		lines.append("\t%s.global_rotation += deg_to_rad(%s)" % [target, degrees_expr])
	else:
		lines.append("\t%s.rotation += deg_to_rad(%s)" % [target, degrees_expr])
	return {"actuator_code": "\n".join(lines), "member_vars": members}

func _build_target(lines: Array[String], members: Array[String], chain_name: String) -> String:
	var target_name := str(properties.get("target_node_name", "")).strip_edges()
	if target_name.is_empty():
		lines.append("if not (self is Node2D):")
		lines.append("\tpush_warning(\"Rotation 2D: self is not a Node2D\")")
		lines.append("else:")
		return "self"
	var label := _unique_label(chain_name)
	var target_var := "_rotation2d_target_%s" % label
	members.append("var %s = null" % target_var)
	lines.append("var _rotation2d_name_%s = \"%s\"" % [label, _escape_string(target_name)])
	lines.append("if %s == null or %s.name != _rotation2d_name_%s:" % [target_var, target_var, label])
	lines.append("\t%s = find_child(_rotation2d_name_%s, true, false)" % [target_var, label])
	lines.append("\tif %s == null and get_tree().current_scene:" % target_var)
	lines.append("\t\t%s = get_tree().current_scene.find_child(_rotation2d_name_%s, true, false)" % [target_var, label])
	lines.append("if not (%s is Node2D):" % target_var)
	lines.append("\tpush_warning(\"Rotation 2D target is missing or is not Node2D\")")
	lines.append("else:")
	return target_var

func _value_expression(value, fallback: String) -> String:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return str(value)
	var text := str(value).strip_edges()
	return fallback if text.is_empty() else text

func _unique_label(chain_name: String) -> String:
	return str(abs((chain_name + str(properties)).hash()))

func _escape_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")
