@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Motion 2D Actuator
## For CharacterBody2D movement, this only requests/accumulates velocity for the frame.
## Character 2D Physics should be used once on the character to apply friction, gravity,
## diagonal normalization, and move_and_slide().

func get_brick_info() -> Dictionary:
	return {
		"class": "Motion2DActuator",
		"name": "Motion 2D",
		"type": "actuator",
		"category": "Motion",
		"domain": "2d",
		"menu_order": 100,
	}

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Motion 2D"

func _initialize_properties() -> void:
	properties = {
		"target_node_name": "",
		"motion_type": "location",
		"movement_method": "character_velocity",
		"x": "0.0",
		"y": "0.0",
		"space": "local",
		"call_move_and_slide": false,
	}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "", "placeholder": "blank = self, or child/node name"},
		{"name": "motion_type", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Location,Rotation", "default": "location"},
		{"name": "movement_method", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Character Velocity,Translate,Position", "default": "character_velocity"},
		{"name": "x", "type": TYPE_STRING, "default": "0.0"},
		{"name": "y", "type": TYPE_STRING, "default": "0.0"},
		{"name": "space", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Local,Global", "default": "local"},
	]

func _to_expr(val) -> String:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return "%.3f" % val
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s

func _safe_label(text: String) -> String:
	var result = text.to_lower().replace(" ", "_")
	result = result.replace("-", "_").replace(".", "_")
	if result.is_empty():
		result = "motion2d"
	return result

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var motion_type = str(properties.get("motion_type", "location")).to_lower()
	var movement_method = str(properties.get("movement_method", "character_velocity")).to_lower().replace(" ", "_")
	var space = str(properties.get("space", "local")).to_lower()
	var x_expr = _to_expr(properties.get("x", "0.0"))
	var y_expr = _to_expr(properties.get("y", "0.0"))
	var label = _safe_label(instance_name if not instance_name.is_empty() else chain_name)
	var target_var = "_motion2d_target_" + label
	var target_name = str(properties.get("target_node_name", "")).replace("\\", "\\\\").replace("\"", "\\\"")

	var member_vars: Array[String] = []
	member_vars.append("var %s = null" % target_var)
	# Shared with Character 2D Physics. Dedup keeps only one declaration.
	member_vars.append("var _logic_brick_character_2d_motion_active: bool = false")
	member_vars.append("var _logic_brick_character_2d_target_velocity: Vector2 = Vector2.ZERO")

	var code_lines: Array[String] = []
	code_lines.append("var _motion2d_name_%s = \"%s\"" % [label, target_name])
	code_lines.append("if _motion2d_name_%s.is_empty():" % label)
	code_lines.append("\t%s = self" % target_var)
	code_lines.append("elif %s == null or %s.name != _motion2d_name_%s:" % [target_var, target_var, label])
	code_lines.append("\t%s = find_child(_motion2d_name_%s, true, false)" % [target_var, label])
	code_lines.append("\tif %s == null and get_tree().current_scene:" % target_var)
	code_lines.append("\t\t%s = get_tree().current_scene.find_child(_motion2d_name_%s, true, false)" % [target_var, label])
	code_lines.append("if not (%s is Node2D):" % target_var)
	code_lines.append("\tpush_warning(\"Motion 2D target is missing or is not Node2D\")")
	code_lines.append("else:")

	if motion_type == "rotation":
		code_lines.append("\t%s.rotation += deg_to_rad(%s)" % [target_var, x_expr])
	else:
		var vec_expr = "Vector2(%s, %s)" % [x_expr, y_expr]
		if movement_method == "translate":
			if space == "local":
				code_lines.append("\t%s.translate((%s) * _delta)" % [target_var, vec_expr])
			else:
				code_lines.append("\t%s.global_position += (%s) * _delta" % [target_var, vec_expr])
		elif movement_method == "position":
			if space == "local":
				code_lines.append("\t%s.position = %s" % [target_var, vec_expr])
			else:
				code_lines.append("\t%s.global_position = %s" % [target_var, vec_expr])
		else:
			code_lines.append("\tvar _motion2d_vec_%s := %s" % [label, vec_expr])
			code_lines.append("\tif %s is CharacterBody2D:" % target_var)
			code_lines.append("\t\tif str(%s.get_path()) == str(self.get_path()):" % target_var)
			if space == "local":
				code_lines.append("\t\t\t_motion2d_vec_%s = _motion2d_vec_%s.rotated(rotation)" % [label, label])
			code_lines.append("\t\t\t_logic_brick_character_2d_motion_active = true")
			code_lines.append("\t\t\t_logic_brick_character_2d_target_velocity += _motion2d_vec_%s" % label)
			code_lines.append("\t\telse:")
			code_lines.append("\t\t\t%s.velocity = _motion2d_vec_%s" % [target_var, label])
			code_lines.append("\telse:")
			if space == "local":
				code_lines.append("\t\t%s.translate(_motion2d_vec_%s * _delta)" % [target_var, label])
			else:
				code_lines.append("\t\t%s.global_position += _motion2d_vec_%s * _delta" % [target_var, label])

	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}
