@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Character 2D Physics Actuator
## Finalizes CharacterBody2D movement once per physics frame.
## Motion 2D bricks add requested movement; this brick applies gravity,
## friction, acceleration, snapping, slope limits, bounce, and move_and_slide().

func get_brick_info() -> Dictionary:
	return {
		"class": "Character2DActuator",
		"name": "Character 2D Physics",
		"type": "actuator",
		"category": "Motion",
		"domain": "2d",
		"menu_order": 110,
		"aliases": ["Character2DPhysicsActuator"]
	}

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Character 2D Physics"

func _initialize_properties() -> void:
	properties = {
		"gravity_strength": "980.0",
		"max_fall_speed": "1000.0",
		"floor_snap_length": "1.0",
		"slope_limit": "45.0",
		"use_acceleration": false,
		"acceleration": "1.0",
		"friction": "1.0",
		"bounce": "0.0",
		"ground_groups": "",
		"platform_groups": "",
		"inherit_platform_velocity_on_jump": true
	}

func get_property_definitions() -> Array:
	return [
		{"name": "gravity_strength", "type": TYPE_STRING, "default": "980.0"},
		{"name": "max_fall_speed", "type": TYPE_STRING, "default": "1000.0"},
		{"name": "floor_snap_length", "type": TYPE_STRING, "default": "1.0"},
		{"name": "slope_limit", "type": TYPE_STRING, "default": "45.0"},
		{"name": "use_acceleration", "type": TYPE_BOOL, "default": false},
		{"name": "acceleration", "type": TYPE_STRING, "default": "1.0"},
		{"name": "friction", "type": TYPE_STRING, "default": "1.0"},
		{"name": "bounce", "type": TYPE_STRING, "default": "0.0"},
		{"name": "ground_groups", "type": TYPE_STRING, "default": "", "placeholder": "Enter ground groups"},
		{"name": "platform_groups", "type": TYPE_STRING, "default": "", "placeholder": "Enter platform groups"},
		{"name": "inherit_platform_velocity_on_jump", "type": TYPE_BOOL, "default": true}
	]

func _to_expr(value) -> String:
	var text := str(value).strip_edges()
	if text.is_empty():
		return "0.0"
	if text.is_valid_float() or text.is_valid_int():
		return "%.3f" % float(text)
	return text

func _bool_text(value) -> String:
	return "true" if value == true else "false"

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var gravity_expr := _to_expr(properties.get("gravity_strength", "980.0"))
	var max_fall_expr := _to_expr(properties.get("max_fall_speed", "1000.0"))
	var floor_snap_expr := _to_expr(properties.get("floor_snap_length", "1.0"))
	var slope_limit_expr := _to_expr(properties.get("slope_limit", "45.0"))
	var acceleration_expr := _to_expr(properties.get("acceleration", "1.0"))
	var friction_expr := _to_expr(properties.get("friction", "1.0"))
	var bounce_expr := _to_expr(properties.get("bounce", "0.0"))
	var use_acceleration: bool = bool(properties.get("use_acceleration", false))
	var inherit_platform_velocity := _bool_text(properties.get("inherit_platform_velocity_on_jump", true))

	var member_vars := []
	member_vars.append("var _on_ground: bool = false")
	member_vars.append("var _jumps_remaining: int = 0")
	member_vars.append("var _max_jumps: int = 0")
	member_vars.append("var _logic_brick_character_2d_motion_active: bool = false")
	member_vars.append("var _logic_brick_character_2d_target_velocity: Vector2 = Vector2.ZERO")
	member_vars.append("var _logic_brick_pre_slide_velocity_2d: Vector2 = Vector2.ZERO")
	member_vars.append("var _moving_platform_velocity_2d: Vector2 = Vector2.ZERO")
	member_vars.append("var _inherited_platform_velocity_2d: Vector2 = Vector2.ZERO")

	var pre_process := []
	pre_process.append("# Character 2D Physics: clear requested movement before Motion 2D bricks run")
	pre_process.append("_logic_brick_character_2d_motion_active = false")
	pre_process.append("_logic_brick_character_2d_target_velocity = Vector2.ZERO")

	var actuator_code := []
	actuator_code.append("if not (self is CharacterBody2D):")
	actuator_code.append("\tpush_warning(\"Character 2D Physics requires CharacterBody2D\")")
	actuator_code.append("else:")
	actuator_code.append("\tfloor_snap_length = maxf(0.0, float(%s))" % floor_snap_expr)
	actuator_code.append("\tfloor_max_angle = deg_to_rad(maxf(0.0, float(%s)))" % slope_limit_expr)
	actuator_code.append("\t_on_ground = is_on_floor()")
	actuator_code.append("\t_moving_platform_velocity_2d = Vector2.ZERO")
	actuator_code.append("\tif absf(float(%s)) > 0.0001:" % gravity_expr)
	actuator_code.append("\t\tif _on_ground:")
	actuator_code.append("\t\t\t_inherited_platform_velocity_2d = Vector2.ZERO")
	actuator_code.append("\t\t\tif velocity.y >= 0.0:")
	actuator_code.append("\t\t\t\t_jumps_remaining = _max_jumps")
	actuator_code.append("\t\t\tif velocity.y > 0.0:")
	actuator_code.append("\t\t\t\tvelocity.y = 0.0")
	actuator_code.append("\t\telse:")
	actuator_code.append("\t\t\tvelocity.y += float(%s) * _delta" % gravity_expr)
	actuator_code.append("\t\t\tvelocity.y = minf(velocity.y, float(%s))" % max_fall_expr)
	actuator_code.append("\telse:")
	actuator_code.append("\t\tif _on_ground:")
	actuator_code.append("\t\t\t_jumps_remaining = _max_jumps")

	var post_process := []
	post_process.append("# Character 2D Physics: apply requested movement once, after all Motion 2D bricks")
	post_process.append("if self is CharacterBody2D:")
	post_process.append("\tvar _logic_brick_2d_gravity_active := absf(float(%s)) > 0.0001" % gravity_expr)
	post_process.append("\tvar _logic_brick_2d_friction := clampf(float(%s), 0.0, 1.0)" % friction_expr)
	post_process.append("\tvar _logic_brick_2d_target := _logic_brick_character_2d_target_velocity")
	post_process.append("\tif _logic_brick_2d_target.length() > 0.001:")
	post_process.append("\t\tvar _logic_brick_2d_speed := maxf(absf(_logic_brick_2d_target.x), absf(_logic_brick_2d_target.y))")
	post_process.append("\t\tif _logic_brick_2d_speed > 0.0 and _logic_brick_2d_target.length() > _logic_brick_2d_speed:")
	post_process.append("\t\t\t_logic_brick_2d_target = _logic_brick_2d_target.normalized() * _logic_brick_2d_speed")
	post_process.append("\tif _logic_brick_character_2d_motion_active:")
	if use_acceleration:
		post_process.append("\t\tvar _logic_brick_2d_accel_step := maxf(_logic_brick_2d_target.length(), 1.0) * clampf(float(%s), 0.0, 1.0) * 12.0 * delta" % acceleration_expr)
		post_process.append("\t\tif _logic_brick_2d_gravity_active:")
		post_process.append("\t\t\tvelocity.x = move_toward(velocity.x, _logic_brick_2d_target.x, _logic_brick_2d_accel_step)")
		post_process.append("\t\telse:")
		post_process.append("\t\t\tvelocity = velocity.move_toward(_logic_brick_2d_target, _logic_brick_2d_accel_step)")
	else:
		post_process.append("\t\tif _logic_brick_2d_gravity_active:")
		post_process.append("\t\t\tvelocity.x = _logic_brick_2d_target.x")
		post_process.append("\t\telse:")
		post_process.append("\t\t\tvelocity = _logic_brick_2d_target")
	post_process.append("\telse:")
	post_process.append("\t\tif _logic_brick_2d_friction > 0.0:")
	post_process.append("\t\t\tif _logic_brick_2d_gravity_active:")
	post_process.append("\t\t\t\tvar _logic_brick_2d_x_step := maxf(absf(velocity.x) * _logic_brick_2d_friction * 12.0, _logic_brick_2d_friction * 0.1) * delta")
	post_process.append("\t\t\t\tvelocity.x = move_toward(velocity.x, 0.0, _logic_brick_2d_x_step)")
	post_process.append("\t\t\telse:")
	post_process.append("\t\t\t\tvar _logic_brick_2d_stop_step := maxf(velocity.length() * _logic_brick_2d_friction * 12.0, _logic_brick_2d_friction * 0.1) * delta")
	post_process.append("\t\t\t\tvelocity = velocity.move_toward(Vector2.ZERO, _logic_brick_2d_stop_step)")
	post_process.append("\tif absf(velocity.x) < 0.01:")
	post_process.append("\t\tvelocity.x = 0.0")
	post_process.append("\tif not _logic_brick_2d_gravity_active and absf(velocity.y) < 0.01:")
	post_process.append("\t\tvelocity.y = 0.0")
	post_process.append("\tif bool(%s) and not _on_ground and _inherited_platform_velocity_2d != Vector2.ZERO:" % inherit_platform_velocity)
	post_process.append("\t\tvelocity.x += _inherited_platform_velocity_2d.x")
	post_process.append("\t_logic_brick_pre_slide_velocity_2d = velocity")
	post_process.append("\tmove_and_slide()")
	post_process.append("\tvar _logic_brick_2d_bounce := clampf(float(%s), 0.0, 1.0)" % bounce_expr)
	post_process.append("\tif _logic_brick_2d_bounce > 0.0 and _logic_brick_pre_slide_velocity_2d.y > 0.08:")
	post_process.append("\t\tfor _logic_brick_col_i in range(get_slide_collision_count()):")
	post_process.append("\t\t\tvar _logic_brick_col = get_slide_collision(_logic_brick_col_i)")
	post_process.append("\t\t\tif _logic_brick_col:")
	post_process.append("\t\t\t\tvar _logic_brick_normal = _logic_brick_col.get_normal()")
	post_process.append("\t\t\t\tvar _logic_brick_impact_speed = -_logic_brick_pre_slide_velocity_2d.dot(_logic_brick_normal)")
	post_process.append("\t\t\t\tif _logic_brick_normal.dot(up_direction) > cos(floor_max_angle) and _logic_brick_impact_speed > 0.08:")
	post_process.append("\t\t\t\t\tvelocity.y = -_logic_brick_impact_speed * _logic_brick_2d_bounce")
	post_process.append("\t\t\t\t\tbreak")

	return {
		"actuator_code": "\n".join(actuator_code),
		"member_vars": member_vars,
		"pre_process_code": pre_process,
		"post_process_code": post_process
	}
