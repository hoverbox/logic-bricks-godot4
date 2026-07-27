@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Applies torque (rotational force) to RigidBody3D objects


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Torque"


func _initialize_properties() -> void:
	properties = {
		"x": "0.0",
		"y": "0.0",
		"z": "0.0",
		"max_torque": "0.0",  # Maximum torque magnitude (0 = unlimited)
		"space": "local"      # "local" or "global"
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
			"name": "max_torque",
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


## Convert a value to a code expression.
## If it's a number (or string of a number), returns the float literal.
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


## Check if a value is a literal zero
func _is_zero(val) -> bool:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return val == 0.0
	var s = str(val).strip_edges()
	if s.is_empty():
		return true
	if s.is_valid_float() or s.is_valid_int():
		return float(s) == 0.0
	# It's a variable name — not zero
	return false


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var x = properties.get("x", "0.0")
	var y = properties.get("y", "0.0")
	var z = properties.get("z", "0.0")
	var max_torque = properties.get("max_torque", "0.0")
	var space = properties.get("space", "local")

	var vx = _to_expr(x)
	var vy = _to_expr(y)
	var vz = _to_expr(z)
	var vmax = _to_expr(max_torque)

	var code_lines: Array[String] = []

	# Torque only works on RigidBody3D
	if not (node is RigidBody3D):
		code_lines.append("# Torque requires RigidBody3D")
		code_lines.append("pass")
		return {"actuator_code": "\n".join(code_lines)}

	if not _is_zero(max_torque):
		# Build, clamp, then apply
		code_lines.append("# Build and clamp torque vector")
		if space == "local":
			code_lines.append("var _torque = global_transform.basis * Vector3(%s, %s, %s)" % [vx, vy, vz])
		else:
			code_lines.append("var _torque = Vector3(%s, %s, %s)" % [vx, vy, vz])
		code_lines.append("if _torque.length() > %s:" % vmax)
		code_lines.append("\t_torque = _torque.normalized() * %s" % vmax)
		code_lines.append("apply_torque(_torque)")
	else:
		if space == "local":
			code_lines.append("apply_torque(global_transform.basis * Vector3(%s, %s, %s))" % [vx, vy, vz])
		else:
			code_lines.append("apply_torque(Vector3(%s, %s, %s))" % [vx, vy, vz])

	return {
		"actuator_code": "\n".join(code_lines)
	}
