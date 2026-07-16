@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Mouse 2D Actuator - cursor visibility, mouse-look rotation, look at mouse, and mouse movement for Node2D/CharacterBody2D.

func get_brick_info() -> Dictionary:
	return {
		"class": "Mouse2DActuator",
		"name": "Mouse",
		"type": "actuator",
		"category": "Motion",
		"domain": "2d",
		"menu_order": 190,
	}

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Mouse"

func _initialize_properties() -> void:
	properties = {
		"mode": "cursor_visibility", # cursor_visibility, mouse_look, look_towards, move_towards_cursor, move_to_mouse_click
		"cursor_visible": false,
		"use_x_axis": true,
		"use_y_axis": false,
		"x_target": "self",
		"y_target": "self",
		"x_sensitivity": 0.1,
		"y_sensitivity": 0.1,
		"x_invert": false,
		"y_invert": false,
		"x_threshold": 0.0,
		"y_threshold": 0.0,
		"x_min_degrees": 0.0,
		"x_max_degrees": 0.0,
		"y_min_degrees": 0.0,
		"y_max_degrees": 0.0,
		"recenter_cursor": true,
		"mouse_target": "self",
		"mouse_velocity": "250.0",
		"mouse_acceleration": "0.0",
		"mouse_turn_speed": "0.0",
		"mouse_arrival_distance": "4.0",
		"mouse_facing_axis": "+x",
		"click_button": "left"
	}

func get_property_definitions() -> Array:
	return [
		{"name":"mode","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Cursor Visibility,Mouse Look,Look Towards,Move Towards Cursor,Move To Mouse Click","default":"cursor_visibility"},
		{"name":"cursor_visible","type":TYPE_BOOL,"default":false},
		{"name":"use_x_axis","type":TYPE_BOOL,"default":true},
		{"name":"use_y_axis","type":TYPE_BOOL,"default":false},
		{"name":"x_target","type":TYPE_STRING,"default":"self"},
		{"name":"y_target","type":TYPE_STRING,"default":"self"},
		{"name":"x_sensitivity","type":TYPE_FLOAT,"default":0.1},
		{"name":"y_sensitivity","type":TYPE_FLOAT,"default":0.1},
		{"name":"x_invert","type":TYPE_BOOL,"default":false},
		{"name":"y_invert","type":TYPE_BOOL,"default":false},
		{"name":"x_threshold","type":TYPE_FLOAT,"default":0.0},
		{"name":"y_threshold","type":TYPE_FLOAT,"default":0.0},
		{"name":"x_min_degrees","type":TYPE_FLOAT,"default":0.0},
		{"name":"x_max_degrees","type":TYPE_FLOAT,"default":0.0},
		{"name":"y_min_degrees","type":TYPE_FLOAT,"default":0.0},
		{"name":"y_max_degrees","type":TYPE_FLOAT,"default":0.0},
		{"name":"recenter_cursor","type":TYPE_BOOL,"default":true},
		{"name":"mouse_target","type":TYPE_STRING,"default":"self"},
		{"name":"mouse_velocity","type":TYPE_STRING,"default":"250.0"},
		{"name":"mouse_acceleration","type":TYPE_STRING,"default":"0.0"},
		{"name":"mouse_turn_speed","type":TYPE_STRING,"default":"0.0"},
		{"name":"mouse_arrival_distance","type":TYPE_STRING,"default":"4.0"},
		{"name":"mouse_facing_axis","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"+X,-X,+Y,-Y","default":"+x"},
		{"name":"click_button","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Left,Right,Middle","default":"left"},
	]

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "cursor_visibility")
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")
	var mouse_facing_axis = str(properties.get("mouse_facing_axis", "+x")).to_lower()
	var click_button = str(properties.get("click_button", "left")).to_lower()
	var label = _safe_var_suffix(instance_name if not instance_name.is_empty() else chain_name)
	var code_lines: Array[String] = []
	match mode:
		"cursor_visibility":
			code_lines.append("# Set cursor visibility")
			if properties.get("cursor_visible", false):
				code_lines.append("Input.mouse_mode = Input.MOUSE_MODE_VISIBLE")
			else:
				code_lines.append("Input.mouse_mode = Input.MOUSE_MODE_HIDDEN")
		"mouse_look":
			code_lines.append("# Mouse look rotation 2D")
			code_lines.append("var _viewport = get_viewport()")
			code_lines.append("var _viewport_size = _viewport.get_visible_rect().size")
			code_lines.append("var _mouse_pos = _viewport.get_mouse_position()")
			code_lines.append("var _center = _viewport_size / 2.0")
			code_lines.append("var _mouse_delta = _mouse_pos - _center")
			if properties.get("use_x_axis", true):
				for line in _generate_mouse_look_axis_code("x", str(properties.get("x_target", "self")), float(properties.get("x_sensitivity", 0.1)), bool(properties.get("x_invert", false)), float(properties.get("x_threshold", 0.0)), float(properties.get("x_min_degrees", 0.0)), float(properties.get("x_max_degrees", 0.0))).split("\n"):
					code_lines.append(line)
			if properties.get("use_y_axis", false):
				for line in _generate_mouse_look_axis_code("y", str(properties.get("y_target", "self")), float(properties.get("y_sensitivity", 0.1)), bool(properties.get("y_invert", false)), float(properties.get("y_threshold", 0.0)), float(properties.get("y_min_degrees", 0.0)), float(properties.get("y_max_degrees", 0.0))).split("\n"):
					code_lines.append(line)
			if properties.get("recenter_cursor", true):
				code_lines.append("# Recenter cursor")
				code_lines.append("_viewport.warp_mouse(_center)")
		"look_towards":
			code_lines.append("var _mouse_world_pos_%s = _logic_bricks_get_global_mouse_position_2d()" % label)
			for line in _generate_mouse_target_ref(str(properties.get("mouse_target", "self"))).split("\n"):
				code_lines.append(line)
			for line in _generate_look_at_code("_mouse_world_pos_%s" % label, mouse_facing_axis, properties.get("mouse_turn_speed", "0.0"), "_mouse_node").split("\n"):
				code_lines.append(line)
		"move_towards_cursor":
			code_lines.append("var _mouse_world_pos_%s = _logic_bricks_get_global_mouse_position_2d()" % label)
			for line in _generate_mouse_target_ref(str(properties.get("mouse_target", "self"))).split("\n"):
				code_lines.append(line)
			for line in _generate_move_to_point_code("_mouse_world_pos_%s" % label, properties.get("mouse_velocity", "250.0"), properties.get("mouse_acceleration", "0.0"), properties.get("mouse_arrival_distance", "4.0"), "_mouse_node").split("\n"):
				code_lines.append(line)
		"move_to_mouse_click":
			var click_pos_var = "_mouse_2d_click_target_%s" % label
			var click_has_var = "_mouse_2d_click_has_target_%s" % label
			var click_pressed_var = "_mouse_2d_click_pressed_%s" % label
			code_lines.append("var _mouse_click_now = Input.is_mouse_button_pressed(%s)" % _mouse_button_code(click_button))
			code_lines.append("if _mouse_click_now and not %s:" % click_pressed_var)
			code_lines.append("\t%s = _logic_bricks_get_global_mouse_position_2d()" % click_pos_var)
			code_lines.append("\t%s = true" % click_has_var)
			code_lines.append("%s = _mouse_click_now" % click_pressed_var)
			code_lines.append("if %s:" % click_has_var)
			for line in _generate_mouse_target_ref(str(properties.get("mouse_target", "self"))).split("\n"):
				code_lines.append("\t" + line)
			for line in _generate_move_to_point_code(click_pos_var, properties.get("mouse_velocity", "250.0"), properties.get("mouse_acceleration", "0.0"), properties.get("mouse_arrival_distance", "4.0"), "_mouse_node").split("\n"):
				code_lines.append("\t" + line)
			code_lines.append("\tif _mouse_node and _mouse_node.global_position.distance_to(%s) <= (%s):" % [click_pos_var, _to_expr(properties.get("mouse_arrival_distance", "4.0"))])
			code_lines.append("\t\t%s = false" % click_has_var)
	var result = {"actuator_code":"\n".join(code_lines)}
	if mode in ["look_towards", "move_towards_cursor", "move_to_mouse_click"]:
		result["methods"] = [_generate_global_mouse_helper()]
	if mode == "move_to_mouse_click":
		result["member_vars"] = [
			"var _mouse_2d_click_target_%s: Vector2 = Vector2.ZERO" % label,
			"var _mouse_2d_click_has_target_%s: bool = false" % label,
			"var _mouse_2d_click_pressed_%s: bool = false" % label,
		]
	return result

func _generate_mouse_look_axis_code(axis_name: String, target_name: String, sensitivity: float, invert: bool, threshold: float, min_degrees: float, max_degrees: float) -> String:
	var lines: Array[String] = []
	var indent = ""
	var delta_prop = "x" if axis_name == "x" else "y"
	if target_name != "self" and not target_name.strip_edges().is_empty():
		lines.append("var _%s_target = get_node_or_null(\"%s\")" % [axis_name, target_name.replace("\"", "\\\"")])
		lines.append("if _%s_target and _%s_target is Node2D:" % [axis_name, axis_name])
		indent = "\t"
	else:
		lines.append("var _%s_target = self" % axis_name)
		lines.append("if _%s_target and _%s_target is Node2D:" % [axis_name, axis_name])
		indent = "\t"
	lines.append("%sif abs(_mouse_delta.%s) > %.3f:" % [indent, delta_prop, threshold])
	var mult = -1.0 if invert else 1.0
	lines.append("%s\tvar _%s_rotation = _mouse_delta.%s * %.3f * %.1f" % [indent, axis_name, delta_prop, sensitivity, mult])
	if min_degrees != 0.0 or max_degrees != 0.0:
		lines.append("%s\tvar _current_rot = _%s_target.global_rotation_degrees" % [indent, axis_name])
		lines.append("%s\tvar _new_rot = _current_rot + _%s_rotation" % [indent, axis_name])
		if min_degrees != 0.0 and max_degrees != 0.0:
			lines.append("%s\t_new_rot = clamp(_new_rot, %.2f, %.2f)" % [indent, min_degrees, max_degrees])
		elif min_degrees != 0.0:
			lines.append("%s\t_new_rot = max(_new_rot, %.2f)" % [indent, min_degrees])
		else:
			lines.append("%s\t_new_rot = min(_new_rot, %.2f)" % [indent, max_degrees])
		lines.append("%s\t_%s_rotation = _new_rot - _current_rot" % [indent, axis_name])
	lines.append("%s\t_%s_target.global_rotation_degrees += _%s_rotation" % [indent, axis_name, axis_name])
	return "\n".join(lines)

func _generate_mouse_target_ref(target_name: String) -> String:
	var lines: Array[String] = []
	if target_name == "self" or target_name.strip_edges().is_empty():
		lines.append("var _mouse_node = self")
	else:
		lines.append("var _mouse_node = get_node_or_null(\"%s\")" % target_name.replace("\"", "\\\""))
	lines.append("if _mouse_node and _mouse_node is Node2D:")
	return "\n".join(lines)

func _generate_look_at_code(target_pos: String, axis: String, turn_speed, node_ref: String) -> String:
	var lines: Array[String] = []
	var turn_expr = _to_expr(turn_speed)
	lines.append("\tvar _look_dir = %s - %s.global_position" % [target_pos, node_ref])
	lines.append("\tif _look_dir.length() > 0.001:")
	lines.append("\t\tvar _target_angle = _look_dir.angle()")
	match axis:
		"-x": lines.append("\t\t_target_angle += PI")
		"+y": lines.append("\t\t_target_angle -= PI * 0.5")
		"-y": lines.append("\t\t_target_angle += PI * 0.5")
		_: pass
	if _literal_gt_zero(turn_speed):
		lines.append("\t\t%s.global_rotation = lerp_angle(%s.global_rotation, _target_angle, clamp((%s) * _delta, 0.0, 1.0))" % [node_ref, node_ref, turn_expr])
	else:
		lines.append("\t\t%s.global_rotation = _target_angle" % node_ref)
	return "\n".join(lines)

func _generate_move_to_point_code(target_pos: String, velocity, acceleration, arrival_distance, node_ref: String) -> String:
	var lines: Array[String] = []
	var arrival_expr = _to_expr(arrival_distance)
	var velocity_expr = _to_expr(velocity)
	var accel_expr = _to_expr(acceleration)
	lines.append("\tvar _to_mouse_target = %s - %s.global_position" % [target_pos, node_ref])
	lines.append("\tvar _mouse_dist = _to_mouse_target.length()")
	lines.append("\tif _mouse_dist > (%s):" % arrival_expr)
	lines.append("\t\tvar _move_dir = _to_mouse_target.normalized()")
	if _literal_gt_zero(acceleration):
		lines.append("\t\tvar _target_vel = _move_dir * (%s)" % velocity_expr)
		lines.append("\t\tvar _current_vel = Vector2.ZERO")
		lines.append("\t\tvar _cb2d = (%s as Node) as CharacterBody2D" % node_ref)
		lines.append("\t\tif _cb2d:")
		lines.append("\t\t\t_current_vel = _cb2d.velocity")
		lines.append("\t\tvar _new_vel = _current_vel.move_toward(_target_vel, (%s) * _delta)" % accel_expr)
	else:
		lines.append("\t\tvar _new_vel = _move_dir * (%s)" % velocity_expr)
		lines.append("\t\tvar _cb2d = (%s as Node) as CharacterBody2D" % node_ref)
	lines.append("\t\tif _cb2d:")
	lines.append("\t\t\t_cb2d.velocity = _new_vel")
	lines.append("\t\telse:")
	lines.append("\t\t\t%s.global_position += _new_vel * _delta" % node_ref)
	return "\n".join(lines)

func _generate_global_mouse_helper() -> String:
	return """
func _logic_bricks_get_global_mouse_position_2d() -> Vector2:
	if self is CanvasItem:
		return (self as CanvasItem).get_global_mouse_position()
	var _viewport := get_viewport()
	if _viewport:
		return _viewport.get_canvas_transform().affine_inverse() * _viewport.get_mouse_position()
	return Vector2.ZERO
""".strip_edges()

func _mouse_button_code(button: String) -> String:
	match button:
		"right": return "MOUSE_BUTTON_RIGHT"
		"middle": return "MOUSE_BUTTON_MIDDLE"
		_: return "MOUSE_BUTTON_LEFT"

func _to_expr(val) -> String:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return "%.3f" % val
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s

func _literal_gt_zero(val) -> bool:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return float(val) > 0.0
	var s = str(val).strip_edges()
	if s.is_valid_float() or s.is_valid_int():
		return float(s) > 0.0
	return true

func _safe_var_suffix(raw_value) -> String:
	var suffix = str(raw_value).strip_edges()
	if suffix.is_empty():
		return "default"
	return suffix.replace(" ", "_").replace("-", "_").replace(".", "_").replace("/", "_").replace(":", "_")
