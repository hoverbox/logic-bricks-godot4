@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Gravity 2D Actuator
## Applies persistent directional gravity to a RigidBody2D.
## Uses constant_force so a one-shot sensor can establish gravity that continues
## after the activation frame. World gravity is disabled by default so the custom
## direction is not mixed with the project's downward gravity.


func get_brick_info() -> Dictionary:
	return {
		"class": "Gravity2DActuator",
		"name": "Gravity",
		"type": "actuator",
		"category": "Physics",
		"domain": "2d",
		"menu_order": 405,
	}


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Gravity"


func _initialize_properties() -> void:
	properties = {
		"strength": "1.0",
		"direction_x": "0.0",
		"direction_y": "1.0",
		"use_mass": true,
		"override_world_gravity": true,
		"reset_velocity_on_direction_change": true,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "strength",
			"type": TYPE_STRING,
			"default": "1.0",
		},
		{
			"name": "direction_x",
			"type": TYPE_STRING,
			"default": "0.0",
		},
		{
			"name": "direction_y",
			"type": TYPE_STRING,
			"default": "1.0",
		},
		{
			"name": "use_mass",
			"type": TYPE_BOOL,
			"default": true,
		},
		{
			"name": "override_world_gravity",
			"type": TYPE_BOOL,
			"default": true,
		},
		{
			"name": "reset_velocity_on_direction_change",
			"type": TYPE_BOOL,
			"default": true,
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Sets persistent directional gravity on a RigidBody2D.",
		"strength": "Gravity multiplier. A value of 1 uses normal project gravity, 2 doubles it, and 10 applies ten times normal gravity.",
		"direction_x": "Horizontal gravity direction. Positive pulls right; negative pulls left.",
		"direction_y": "Vertical gravity direction. Positive pulls down; negative pulls up.",
		"use_mass": "Multiply by body mass so the value behaves like acceleration.",
		"override_world_gravity": "Disable the body's built-in project gravity so only this custom direction affects it.",
		"reset_velocity_on_direction_change": "Clear existing momentum once when gravity changes direction, so the new direction takes effect immediately.",
	}


func _to_expr(value) -> String:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return "%.3f" % float(value)
	var expression := str(value).strip_edges()
	if expression.is_empty():
		return "0.0"
	if expression.is_valid_float() or expression.is_valid_int():
		return "%.3f" % float(expression)
	return expression


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var strength_expr := _to_expr(properties.get("strength", "1.0"))
	var direction_x_expr := _to_expr(properties.get("direction_x", "0.0"))
	var direction_y_expr := _to_expr(properties.get("direction_y", "1.0"))
	var use_mass: bool = properties.get("use_mass", true)
	var override_world_gravity: bool = properties.get("override_world_gravity", true)
	var reset_velocity_on_direction_change: bool = properties.get("reset_velocity_on_direction_change", true)

	var code_lines: Array[String] = []

	if not (node is RigidBody2D):
		code_lines.append("push_warning(\"Gravity requires RigidBody2D\")")
		return {"actuator_code": "\n".join(code_lines)}

	if override_world_gravity:
		code_lines.append("gravity_scale = 0.0")

	code_lines.append("var _logic_brick_gravity_direction = Vector2(%s, %s)" % [direction_x_expr, direction_y_expr])
	code_lines.append("if _logic_brick_gravity_direction.length_squared() > 0.0:")
	code_lines.append("\t_logic_brick_gravity_direction = _logic_brick_gravity_direction.normalized()")
	if reset_velocity_on_direction_change:
		code_lines.append("\tvar _logic_brick_previous_gravity_direction = get_meta(\"_logic_brick_2d_gravity_direction\", Vector2.INF)")
		code_lines.append("\tif not (_logic_brick_previous_gravity_direction is Vector2) or not _logic_brick_previous_gravity_direction.is_equal_approx(_logic_brick_gravity_direction):")
		code_lines.append("\t\tlinear_velocity = Vector2.ZERO")
	code_lines.append("\tset_meta(\"_logic_brick_2d_gravity_direction\", _logic_brick_gravity_direction)")
	code_lines.append("\tsleeping = false")
	code_lines.append("\tvar _logic_brick_project_gravity = float(ProjectSettings.get_setting(\"physics/2d/default_gravity\", 980.0))")
	code_lines.append("\tvar _logic_brick_gravity_acceleration = _logic_brick_project_gravity * (%s)" % strength_expr)
	if use_mass:
		code_lines.append("\tconstant_force = _logic_brick_gravity_direction * _logic_brick_gravity_acceleration * mass")
	else:
		code_lines.append("\tconstant_force = _logic_brick_gravity_direction * _logic_brick_gravity_acceleration")
	code_lines.append("else:")
	code_lines.append("\tconstant_force = Vector2.ZERO")
	code_lines.append("\tset_meta(\"_logic_brick_2d_gravity_direction\", Vector2.ZERO)")

	return {"actuator_code": "\n".join(code_lines)}
