@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Impulse Actuator - Apply a one-shot impulse to a RigidBody3D or SoftBody3D.
## SoftBody3D supports Central here; point impulses use Soft Body Point Impulse.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Impulse"


func _normalized_impulse_type() -> String:
	return str(properties.get("impulse_type", "central")).strip_edges().to_lower().replace(" ", "_")


func get_compatibility_error(node: Node) -> String:
	if node is RigidBody3D:
		return ""
	if node is SoftBody3D:
		return "" if _normalized_impulse_type() == "central" else "SoftBody3D supports Central only here; use Soft Body Point Impulse for a mesh point"
	return "Requires RigidBody3D or SoftBody3D"


func _initialize_properties() -> void:
	properties = {
		"impulse_type": "central",  # central, positional, torque
		"x": "0.0",
		"y": "0.0",
		"z": "0.0",
		"pos_x": "0.0",  # offset for positional impulse
		"pos_y": "0.0",
		"pos_z": "0.0",
		"space": "local",  # local, global
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "impulse_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Central,Positional,Torque",
			"default": "central"
		},
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
			"name": "pos_x",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "pos_y",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "pos_z",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "space",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Local,Global",
			"default": "local"
		},
	]


func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	if _validation_all_numeric_zero(["x", "y", "z"]):
		warnings.append("Put a Value or Variable in X,Y, or Z")
	if node is SoftBody3D and _normalized_impulse_type() != "central":
		warnings.append("SoftBody3D supports Central impulse in this brick. Use Soft Body Point Impulse to affect one simulated mesh point.")
	return warnings


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Applies a one-shot impulse. RigidBody3D supports Central, Positional, and Torque. SoftBody3D supports Central; use Soft Body Point Impulse for a specific mesh point.",
		"impulse_type": "Central: applied at the center/all soft-body points. Positional: rigid-body offset impulse. Torque: rigid-body rotational impulse.",
		"x": "X component. Accepts a number or variable.",
		"y": "Y component. Accepts a number or variable.",
		"z": "Z component. Accepts a number or variable.",
		"pos_x": "RigidBody3D only: X offset from center for Positional mode.",
		"pos_y": "RigidBody3D only: Y offset from center for Positional mode.",
		"pos_z": "RigidBody3D only: Z offset from center for Positional mode.",
		"space": "Local: relative to node rotation. Global: world axes.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var impulse_type = _normalized_impulse_type()
	var space = str(properties.get("space", "local")).to_lower()

	var vx = _expr(properties.get("x", "0.0"))
	var vy = _expr(properties.get("y", "0.0"))
	var vz = _expr(properties.get("z", "0.0"))
	var vec = "Vector3(%s, %s, %s)" % [vx, vy, vz]
	if space == "local":
		vec = "global_transform.basis.orthonormalized() * Vector3(%s, %s, %s)" % [vx, vy, vz]

	var code_lines: Array[String] = []

	if not (node is RigidBody3D or node is SoftBody3D):
		code_lines.append("# WARNING: Impulse actuator only works with RigidBody3D or SoftBody3D!")
		code_lines.append("push_warning(\"Impulse actuator requires RigidBody3D or SoftBody3D, but node is %s\")" % node.get_class())
		return {"actuator_code": "\n".join(code_lines)}

	if node is SoftBody3D:
		if impulse_type == "central":
			code_lines.append("# Apply central impulse to all SoftBody3D points")
			code_lines.append("apply_central_impulse(%s)" % vec)
		else:
			code_lines.append("# WARNING: SoftBody3D supports only Central mode in the Impulse actuator")
			code_lines.append("push_warning(\"SoftBody3D Impulse supports Central mode only. Use Soft Body Point Impulse for one mesh point.\")")
		return {"actuator_code": "\n".join(code_lines)}

	match impulse_type:
		"central":
			code_lines.append("# Apply central impulse")
			code_lines.append("apply_central_impulse(%s)" % vec)
		"positional":
			var px = _expr(properties.get("pos_x", "0.0"))
			var py = _expr(properties.get("pos_y", "0.0"))
			var pz = _expr(properties.get("pos_z", "0.0"))
			var pos = "Vector3(%s, %s, %s)" % [px, py, pz]
			code_lines.append("# Apply positional impulse")
			code_lines.append("apply_impulse(%s, %s)" % [vec, pos])
		"torque":
			code_lines.append("# Apply torque impulse")
			code_lines.append("apply_torque_impulse(%s)" % vec)

	return {"actuator_code": "\n".join(code_lines)}


