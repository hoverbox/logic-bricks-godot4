@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Applies torque (rotational force) to RigidBody3D objects


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Torque"


func _initialize_properties() -> void:
	properties = {
		"x": 0.0,
		"y": 0.0,
		"z": 0.0,
		"space": "local"  # "local" or "global"
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "x",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "y",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "z",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "space",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Local,Global",
			"default": "local"
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var x = properties.get("x", 0.0)
	var y = properties.get("y", 0.0)
	var z = properties.get("z", 0.0)
	var space = properties.get("space", "local")
	
	var code = ""
	
	# Torque only works on RigidBody3D
	if node is RigidBody3D:
		if space == "local":
			code = "apply_torque(global_transform.basis * Vector3(%f, %f, %f))" % [x, y, z]
		else:
			code = "apply_torque(Vector3(%f, %f, %f))" % [x, y, z]
	else:
		code = "# Torque requires RigidBody3D\n\tpass"
	
	return {
		"actuator_code": code
	}
