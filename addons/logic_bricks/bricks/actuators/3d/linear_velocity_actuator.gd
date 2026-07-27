@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Linear Velocity Actuator - Apply constant velocity to RigidBody3D
## Similar to UPBGE's Linear Velocity actuator


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Linear Velocity"


func _initialize_properties() -> void:
	properties = {
		"velocity_x": "0.0",       # Velocity on X axis
		"velocity_y": "0.0",       # Velocity on Y axis
		"velocity_z": "0.0",       # Velocity on Z axis
		"max_speed": "0.0",        # Max linear speed (0 = no limit)
		"local": true,             # Use local or global coordinates
		"mode": "set"              # set, add, or average
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Set,Add,Average",
			"default": "set"
		},
		{
			"name": "velocity_x",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "velocity_y",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "velocity_z",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "max_speed",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "local",
			"type": TYPE_BOOL,
			"default": true
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


## Check if a value is a literal zero (skips code generation for that axis).
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
	var velocity_x = properties.get("velocity_x", "0.0")
	var velocity_y = properties.get("velocity_y", "0.0")
	var velocity_z = properties.get("velocity_z", "0.0")
	var max_speed  = properties.get("max_speed", "0.0")
	var local      = properties.get("local", true)
	var mode       = properties.get("mode", "set")

	# Normalize mode
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower()

	var vx = _to_expr(velocity_x)
	var vy = _to_expr(velocity_y)
	var vz = _to_expr(velocity_z)
	var ms = _to_expr(max_speed)
	var use_max_speed = not _is_zero(max_speed)

	var code_lines: Array[String] = []

	# Check if this is a RigidBody3D or CharacterBody3D
	code_lines.append("# Linear Velocity Actuator")
	code_lines.append("if \"linear_velocity\" in self:")  # RigidBody3D has linear_velocity

	# Calculate velocity vector
	if local:
		code_lines.append("\t# Local velocity")
		code_lines.append("\tvar _velocity = global_transform.basis * Vector3(%s, %s, %s)" % [vx, vy, vz])
	else:
		code_lines.append("\t# Global velocity")
		code_lines.append("\tvar _velocity = Vector3(%s, %s, %s)" % [vx, vy, vz])

	# Apply velocity based on mode
	match mode:
		"set":
			code_lines.append("\t# Set velocity (replace current)")
			code_lines.append("\tset(\"linear_velocity\", _velocity)")

		"add":
			code_lines.append("\t# Add velocity (impulse)")
			code_lines.append("\tset(\"linear_velocity\", get(\"linear_velocity\") + _velocity)")

		"average":
			code_lines.append("\t# Average velocity (blend)")
			code_lines.append("\tset(\"linear_velocity\", (get(\"linear_velocity\") + _velocity) / 2.0)")

	# Clamp to max speed if set
	if use_max_speed:
		code_lines.append("\t# Clamp to max speed")
		code_lines.append("\tvar _lv = get(\"linear_velocity\")")
		code_lines.append("\tif _lv.length() > %s:" % ms)
		code_lines.append("\t\tset(\"linear_velocity\", _lv.normalized() * %s)" % ms)

	code_lines.append("elif \"velocity\" in self:")  # CharacterBody3D has velocity
	code_lines.append("\t# For CharacterBody3D, set velocity directly")
	if local:
		code_lines.append("\tvar _velocity = global_transform.basis * Vector3(%s, %s, %s)" % [vx, vy, vz])
	else:
		code_lines.append("\tvar _velocity = Vector3(%s, %s, %s)" % [vx, vy, vz])
	code_lines.append("\tset(\"velocity\", _velocity)")

	# Clamp to max speed for CharacterBody3D too
	if use_max_speed:
		code_lines.append("\t# Clamp to max speed")
		code_lines.append("\tvar _cv = get(\"velocity\")")
		code_lines.append("\tif _cv.length() > %s:" % ms)
		code_lines.append("\t\tset(\"velocity\", _cv.normalized() * %s)" % ms)

	code_lines.append("\tcall(\"move_and_slide\")")
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Linear Velocity Actuator: Node must be RigidBody3D or CharacterBody3D\")")

	return {
		"actuator_code": "\n".join(code_lines)
	}
