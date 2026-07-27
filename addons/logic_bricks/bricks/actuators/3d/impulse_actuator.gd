@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Impulse Actuator - Apply a one-shot impulse to a RigidBody3D
## Unlike Force (continuous), an impulse is applied once per activation


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Impulse"


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


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Applies a one-shot impulse to a RigidBody3D.\nFires once per activation — does not accumulate each frame.",
		"impulse_type": "Central: applied at the center of mass.\nPositional: applied at an offset point (creates spin).\nTorque: rotational impulse only.",
		"x": "X component. Accepts a number or variable.",
		"y": "Y component. Accepts a number or variable.",
		"z": "Z component. Accepts a number or variable.",
		"pos_x": "X offset from center (Positional mode only).",
		"pos_y": "Y offset from center (Positional mode only).",
		"pos_z": "Z offset from center (Positional mode only).",
		"space": "Local: relative to node's rotation.\nGlobal: world axes.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var impulse_type = properties.get("impulse_type", "central")
	var space = properties.get("space", "local")

	if typeof(impulse_type) == TYPE_STRING:
		impulse_type = impulse_type.to_lower()
	if typeof(space) == TYPE_STRING:
		space = space.to_lower()

	var vx = _to_expr(properties.get("x", "0.0"))
	var vy = _to_expr(properties.get("y", "0.0"))
	var vz = _to_expr(properties.get("z", "0.0"))
	var vec = "Vector3(%s, %s, %s)" % [vx, vy, vz]
	if space == "local":
		vec = "global_transform.basis * Vector3(%s, %s, %s)" % [vx, vy, vz]

	var code_lines: Array[String] = []

	if not node is RigidBody3D:
		code_lines.append("# WARNING: Impulse actuator only works with RigidBody3D!")
		code_lines.append("push_warning(\"Impulse actuator requires RigidBody3D, but node is %s\")" % node.get_class())
		return {"actuator_code": "\n".join(code_lines)}

	match impulse_type:
		"central":
			code_lines.append("# Apply central impulse")
			code_lines.append("apply_central_impulse(%s)" % vec)
		"positional":
			var px = _to_expr(properties.get("pos_x", "0.0"))
			var py = _to_expr(properties.get("pos_y", "0.0"))
			var pz = _to_expr(properties.get("pos_z", "0.0"))
			var pos = "Vector3(%s, %s, %s)" % [px, py, pz]
			code_lines.append("# Apply positional impulse")
			code_lines.append("apply_impulse(%s, %s)" % [vec, pos])
		"torque":
			code_lines.append("# Apply torque impulse")
			code_lines.append("apply_torque_impulse(%s)" % vec)

	return {"actuator_code": "\n".join(code_lines)}


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
