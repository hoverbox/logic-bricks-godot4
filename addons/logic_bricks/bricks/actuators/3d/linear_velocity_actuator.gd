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
		"velocity_x": 0.0,          # Velocity on X axis
		"velocity_y": 0.0,          # Velocity on Y axis
		"velocity_z": 0.0,          # Velocity on Z axis
		"local": true,              # Use local or global coordinates
		"mode": "set"               # set, add, or average
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
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "velocity_y",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "velocity_z",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "local",
			"type": TYPE_BOOL,
			"default": true
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var velocity_x = properties.get("velocity_x", 0.0)
	var velocity_y = properties.get("velocity_y", 0.0)
	var velocity_z = properties.get("velocity_z", 0.0)
	var local = properties.get("local", true)
	var mode = properties.get("mode", "set")
	
	# Normalize mode
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower()
	
	var code_lines: Array[String] = []
	
	# Check if this is a RigidBody3D or CharacterBody3D
	code_lines.append("# Linear Velocity Actuator")
	code_lines.append("if \"linear_velocity\" in self:")  # RigidBody3D has linear_velocity
	
	# Calculate velocity vector
	if local:
		code_lines.append("\t# Local velocity")
		code_lines.append("\tvar _velocity = global_transform.basis * Vector3(%.2f, %.2f, %.2f)" % [velocity_x, velocity_y, velocity_z])
	else:
		code_lines.append("\t# Global velocity")
		code_lines.append("\tvar _velocity = Vector3(%.2f, %.2f, %.2f)" % [velocity_x, velocity_y, velocity_z])
	
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
	
	code_lines.append("elif \"velocity\" in self:")  # CharacterBody3D has velocity
	code_lines.append("\t# For CharacterBody3D, set velocity directly")
	if local:
		code_lines.append("\tset(\"velocity\", global_transform.basis * Vector3(%.2f, %.2f, %.2f))" % [velocity_x, velocity_y, velocity_z])
	else:
		code_lines.append("\tset(\"velocity\", Vector3(%.2f, %.2f, %.2f))" % [velocity_x, velocity_y, velocity_z])
	code_lines.append("\tcall(\"move_and_slide\")")
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Linear Velocity Actuator: Node must be RigidBody3D or CharacterBody3D\")")
	
	return {
		"actuator_code": "\n".join(code_lines)
	}
