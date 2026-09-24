@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Linear Velocity Actuator - Set/add velocity on rigid/character bodies.
## SoftBody3D supports Add mode by converting the requested delta-v into a central impulse.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Linear Velocity"


func get_compatibility_error(node: Node) -> String:
	if node is SoftBody3D:
		var mode := str(properties.get("mode", "set")).to_lower()
		return "" if mode == "add" else "SoftBody3D supports Add mode only"
	return "" if node is RigidBody3D or node is CharacterBody3D else "Requires RigidBody3D, CharacterBody3D, or SoftBody3D"


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


## Check if a value is a literal zero (skips code generation for that axis).

func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	if _validation_all_numeric_zero(["velocity_x", "velocity_y", "velocity_z"]):
		warnings.append("Put a Value or Variable in X,Y, or Z")
	if node is SoftBody3D:
		var mode := str(properties.get("mode", "set")).to_lower()
		if mode != "add":
			warnings.append("SoftBody3D supports Add mode only; it is implemented as a central impulse (mass x velocity change).")
		if not _is_literal_zero(properties.get("max_speed", "0.0")):
			warnings.append("Max Speed cannot be enforced on SoftBody3D because it does not expose a backend-independent linear velocity property.")
	return warnings

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

	var vx = _numeric_expr(velocity_x)
	var vy = _numeric_expr(velocity_y)
	var vz = _numeric_expr(velocity_z)
	var ms = _numeric_expr(max_speed)
	var use_max_speed = not _is_literal_zero(max_speed)

	var code_lines: Array[String] = []

	# SoftBody3D has no backend-independent writable linear_velocity.
	# Add mode maps cleanly to delta-v: impulse = total_mass * velocity_change.
	if node is SoftBody3D:
		if mode != "add":
			code_lines.append("push_warning(\"Linear Velocity on SoftBody3D supports Add mode only\")")
			return {"actuator_code": "\n".join(code_lines)}
		if local:
			code_lines.append("var _velocity = global_transform.basis.orthonormalized() * Vector3(%s, %s, %s)" % [vx, vy, vz])
		else:
			code_lines.append("var _velocity = Vector3(%s, %s, %s)" % [vx, vy, vz])
		code_lines.append("apply_central_impulse(_velocity * total_mass)")
		return {"actuator_code": "\n".join(code_lines)}

	# Check if this is a RigidBody3D or CharacterBody3D
	code_lines.append("# Linear Velocity Actuator")
	code_lines.append("if \"linear_velocity\" in self:")  # RigidBody3D has linear_velocity

	# Calculate velocity vector
	if local:
		code_lines.append("\t# Local velocity")
		code_lines.append("\tvar _velocity = global_transform.basis.orthonormalized() * Vector3(%s, %s, %s)" % [vx, vy, vz])
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
		code_lines.append("\tvar _velocity = global_transform.basis.orthonormalized() * Vector3(%s, %s, %s)" % [vx, vy, vz])
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
