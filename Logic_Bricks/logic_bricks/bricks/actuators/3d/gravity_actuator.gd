@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Gravity Actuator - Applies custom gravity to physics-based objects.
## Use this with RigidBody3D objects. CharacterBody3D gravity belongs in the Character Actuator.
##
## This actuator writes to RigidBody3D.constant_force instead of using apply_central_force().
## That makes gravity keep working after a one-shot trigger such as a Delay sensor.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Gravity"


func _initialize_properties() -> void:
	properties = {
		"gravity_strength": "9.8",  # Acceleration in units/sec^2; accepts numbers, variables, or expressions
		"direction_x": "0.0",
		"direction_y": "-1.0",
		"direction_z": "0.0",
		"use_mass": true,             # true = realistic acceleration; false = raw force
		"override_world_gravity": true # true = disables built-in RigidBody3D gravity for this body
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "gravity_strength",
			"type": TYPE_STRING,
			"default": "9.8"
		},
		{
			"name": "direction_x",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "direction_y",
			"type": TYPE_STRING,
			"default": "-1.0"
		},
		{
			"name": "direction_z",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "use_mass",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "override_world_gravity",
			"type": TYPE_BOOL,
			"default": true
		},
	]


## Convert a value to a code expression.
## If it's a number (or string of a number), returns the numeric literal.
## Otherwise returns it as-is (a variable name or expression).
func _to_expr(val) -> String:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return "%.3f" % val
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var gravity_strength = properties.get("gravity_strength", "9.8")
	var direction_x = properties.get("direction_x", "0.0")
	var direction_y = properties.get("direction_y", "-1.0")
	var direction_z = properties.get("direction_z", "0.0")
	var use_mass = properties.get("use_mass", true)
	var override_world_gravity = properties.get("override_world_gravity", true)

	var gravity_expr = _to_expr(gravity_strength)
	var dx_expr = _to_expr(direction_x)
	var dy_expr = _to_expr(direction_y)
	var dz_expr = _to_expr(direction_z)

	var code_lines: Array[String] = []

	if not (node is RigidBody3D):
		code_lines.append("# WARNING: Gravity actuator only works with RigidBody3D physics objects.")
		code_lines.append("# CharacterBody3D gravity is controlled by the Character Actuator.")
		code_lines.append("push_warning(\"Gravity actuator requires RigidBody3D, but node '%s' is %s\")" % [node.name, node.get_class()])
		return {"actuator_code": "\n".join(code_lines)}

	code_lines.append("# Apply persistent custom gravity to this RigidBody3D")
	if override_world_gravity:
		code_lines.append("# Disable the body's built-in world gravity so the custom direction is not mixed with it")
		code_lines.append("gravity_scale = 0.0")
	code_lines.append("var _logic_brick_gravity_dir = Vector3(%s, %s, %s)" % [dx_expr, dy_expr, dz_expr])
	code_lines.append("if _logic_brick_gravity_dir.length() > 0.0:")
	code_lines.append("\t_logic_brick_gravity_dir = _logic_brick_gravity_dir.normalized()")
	if use_mass:
		code_lines.append("\tconstant_force = _logic_brick_gravity_dir * (%s) * mass" % gravity_expr)
	else:
		code_lines.append("\tconstant_force = _logic_brick_gravity_dir * (%s)" % gravity_expr)
	code_lines.append("else:")
	code_lines.append("\tconstant_force = Vector3.ZERO")

	return {
		"actuator_code": "\n".join(code_lines)
	}
