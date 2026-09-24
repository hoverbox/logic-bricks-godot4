@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Force Actuator - Apply continuous central force to RigidBody3D or SoftBody3D.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Force"


func get_compatibility_error(node: Node) -> String:
	return "" if node is RigidBody3D or node is SoftBody3D else "Requires RigidBody3D or SoftBody3D"


func _initialize_properties() -> void:
	properties = {
		"x": "0.0",
		"y": "0.0",
		"z": "0.0",
		"max_force": "0.0",  # Maximum force magnitude (0 = unlimited)
		"space": "local"     # "local" or "global"
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "x",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "y",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "z",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "max_force",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "space",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Local,Global",
			"default": "local"
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Applies continuous central force to a RigidBody3D or SoftBody3D. On a SoftBody3D the force is distributed across all simulated points.",
		"x": "X component. Accepts a number, variable, or expression.",
		"y": "Y component. Accepts a number, variable, or expression.",
		"z": "Z component. Accepts a number, variable, or expression.",
		"max_force": "Optional maximum force magnitude. 0 means unlimited.",
		"space": "Local uses the node's orientation. Global uses world axes.",
	}


## Check if a value is a literal zero

func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	if _validation_all_numeric_zero(["x", "y", "z"]):
		warnings.append("Put a Value or Variable in X,Y, or Z")
	return warnings


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var x = properties.get("x", "0.0")
	var y = properties.get("y", "0.0")
	var z = properties.get("z", "0.0")
	var max_force = properties.get("max_force", "0.0")
	var space = properties.get("space", "local")

	# Normalize space (enum values come as lowercase with underscores)
	if typeof(space) == TYPE_STRING:
		space = space.to_lower().replace(" ", "_")

	var vx = _numeric_expr(x)
	var vy = _numeric_expr(y)
	var vz = _numeric_expr(z)
	var vmax = _numeric_expr(max_force)

	var code_lines: Array[String] = []

	if not (node is RigidBody3D or node is SoftBody3D):
		code_lines.append("# WARNING: Force actuator only works with RigidBody3D or SoftBody3D!")
		code_lines.append("# Current node type: %s" % node.get_class())
		code_lines.append("push_warning(\"Force actuator requires RigidBody3D or SoftBody3D, but node '%s' is %s\")" % [node.name, node.get_class()])
		code_lines.append("# Force NOT applied")
		return {"actuator_code": "\n".join(code_lines)}

	# Build force vector, optionally clamped.
	if not _is_literal_zero(max_force):
		code_lines.append("# Build and clamp force vector")
		if space == "local":
			code_lines.append("var _force = global_transform.basis.orthonormalized() * Vector3(%s, %s, %s)" % [vx, vy, vz])
		else:
			code_lines.append("var _force = Vector3(%s, %s, %s)" % [vx, vy, vz])
		code_lines.append("if _force.length() > %s:" % vmax)
		code_lines.append("\t_force = _force.normalized() * %s" % vmax)
		code_lines.append("apply_central_force(_force)")
	else:
		if space == "local":
			code_lines.append("# Apply central force in local space")
			code_lines.append("apply_central_force(global_transform.basis.orthonormalized() * Vector3(%s, %s, %s))" % [vx, vy, vz])
		else:
			code_lines.append("# Apply central force in global space")
			code_lines.append("apply_central_force(Vector3(%s, %s, %s))" % [vx, vy, vz])

	return {
		"actuator_code": "\n".join(code_lines)
	}
