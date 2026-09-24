@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Gravity Actuator - Applies custom gravity to physics-based objects.
## RigidBody3D stores the result in constant_force so a one-shot trigger persists.
## SoftBody3D has no constant_force/gravity_scale, so custom gravity is applied as
## a central force while this brick is active.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Gravity"


func get_compatibility_error(node: Node) -> String:
	return "" if node is RigidBody3D or node is SoftBody3D else "Requires RigidBody3D or SoftBody3D"


func _initialize_properties() -> void:
	properties = {
		"gravity_strength": "9.8",  # Acceleration in units/sec^2; accepts numbers, variables, or expressions
		"direction_x": "0.0",
		"direction_y": "-1.0",
		"direction_z": "0.0",
		"use_mass": true,              # true = realistic acceleration; false = raw force
		"override_world_gravity": true # SoftBody3D cancels project-default gravity only
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


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Applies custom gravity to RigidBody3D or SoftBody3D. Soft bodies receive a central force while the brick is active.",
		"gravity_strength": "Gravity acceleration/force strength. Accepts a number, variable, or expression.",
		"direction_x": "Gravity direction X component.",
		"direction_y": "Gravity direction Y component.",
		"direction_z": "Gravity direction Z component.",
		"use_mass": "When enabled, multiply by body mass so the value behaves like acceleration. SoftBody3D uses total_mass.",
		"override_world_gravity": "RigidBody3D disables gravity_scale. SoftBody3D cancels the project default gravity; Area3D gravity overrides cannot be read back reliably.",
	}


## Convert a value to a code expression.
## If it's a number (or string of a number), returns the numeric literal.
## Otherwise returns it as-is (a variable name or expression).
func generate_code(node: Node, chain_name: String) -> Dictionary:
	var gravity_strength = properties.get("gravity_strength", "9.8")
	var direction_x = properties.get("direction_x", "0.0")
	var direction_y = properties.get("direction_y", "-1.0")
	var direction_z = properties.get("direction_z", "0.0")
	var use_mass = properties.get("use_mass", true)
	var override_world_gravity = properties.get("override_world_gravity", true)

	var gravity_expr = _numeric_expr(gravity_strength)
	var dx_expr = _numeric_expr(direction_x)
	var dy_expr = _numeric_expr(direction_y)
	var dz_expr = _numeric_expr(direction_z)

	var code_lines: Array[String] = []

	if not (node is RigidBody3D or node is SoftBody3D):
		code_lines.append("# WARNING: Gravity actuator requires RigidBody3D or SoftBody3D.")
		code_lines.append("push_warning(\"Gravity actuator requires RigidBody3D or SoftBody3D, but node '%s' is %s\")" % [node.name, node.get_class()])
		return {"actuator_code": "\n".join(code_lines)}

	if node is RigidBody3D:
		code_lines.append("# Apply persistent custom gravity to this RigidBody3D")
		if override_world_gravity:
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
	else:
		code_lines.append("# Apply custom gravity force to this SoftBody3D")
		if override_world_gravity:
			code_lines.append("var _logic_brick_default_gravity = float(ProjectSettings.get_setting(\"physics/3d/default_gravity\", 9.8))")
			code_lines.append("var _logic_brick_default_gravity_dir = ProjectSettings.get_setting(\"physics/3d/default_gravity_vector\", Vector3.DOWN)")
			code_lines.append("if _logic_brick_default_gravity_dir.length() > 0.0:")
			code_lines.append("\t_logic_brick_default_gravity_dir = _logic_brick_default_gravity_dir.normalized()")
		code_lines.append("var _logic_brick_gravity_dir = Vector3(%s, %s, %s)" % [dx_expr, dy_expr, dz_expr])
		code_lines.append("if _logic_brick_gravity_dir.length() > 0.0:")
		code_lines.append("\t_logic_brick_gravity_dir = _logic_brick_gravity_dir.normalized()")
		if use_mass:
			code_lines.append("\tvar _logic_brick_soft_gravity_force = _logic_brick_gravity_dir * (%s) * total_mass" % gravity_expr)
		else:
			code_lines.append("\tvar _logic_brick_soft_gravity_force = _logic_brick_gravity_dir * (%s)" % gravity_expr)
		if override_world_gravity:
			code_lines.append("\t_logic_brick_soft_gravity_force -= _logic_brick_default_gravity_dir * _logic_brick_default_gravity * total_mass")
		code_lines.append("\tapply_central_force(_logic_brick_soft_gravity_force)")
		code_lines.append("else:")
		if override_world_gravity:
			code_lines.append("\tapply_central_force(-_logic_brick_default_gravity_dir * _logic_brick_default_gravity * total_mass)")
		else:
			code_lines.append("\tpass")

	return {
		"actuator_code": "\n".join(code_lines)
	}
