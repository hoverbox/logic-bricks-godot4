@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Rotates the object around its axes


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Rotation"


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
	
	var code_lines = []
	
	if space == "local":
		# Only add rotation for non-zero values
		if x != 0.0:
			code_lines.append("rotate_x(deg_to_rad(%.2f))" % x)
		if y != 0.0:
			code_lines.append("rotate_y(deg_to_rad(%.2f))" % y)
		if z != 0.0:
			code_lines.append("rotate_z(deg_to_rad(%.2f))" % z)
	else:
		# Global rotation - only if at least one axis is non-zero
		if x != 0.0 or y != 0.0 or z != 0.0:
			code_lines.append("global_rotation += Vector3(deg_to_rad(%.2f), deg_to_rad(%.2f), deg_to_rad(%.2f))" % [x, y, z])
	
	# Join lines or return pass if no rotation
	var code = "\n".join(code_lines) if code_lines.size() > 0 else "pass"
	
	return {
		"actuator_code": code
	}
