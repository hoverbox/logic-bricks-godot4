@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Force Actuator - Apply force to RigidBody3D
## NOTE: Only works with RigidBody3D, not CharacterBody3D


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Force"


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
	
	# Normalize space (enum values come as lowercase with underscores)
	if typeof(space) == TYPE_STRING:
		space = space.to_lower().replace(" ", "_")
	
	var code_lines: Array[String] = []
	
	# Check if node is compatible (only RigidBody3D supports forces)
	if not (node is RigidBody3D):
		# Generate a warning for incompatible node types
		code_lines.append("# WARNING: Force actuator only works with RigidBody3D!")
		code_lines.append("# Current node type: %s" % node.get_class())
		code_lines.append("push_warning(\"Force actuator requires RigidBody3D, but node '%s' is %s\")" % [node.name, node.get_class()])
		code_lines.append("# Force NOT applied")
		
		return {"actuator_code": "\n".join(code_lines)}
	
	# Generate force application code for RigidBody3D
	if space == "local":
		# Apply force in local space (relative to object's rotation)
		code_lines.append("# Apply force in local space")
		code_lines.append("apply_central_force(global_transform.basis * Vector3(%.3f, %.3f, %.3f))" % [x, y, z])
	else:
		# Apply force in global space (world coordinates)
		code_lines.append("# Apply force in global space")
		code_lines.append("apply_central_force(Vector3(%.3f, %.3f, %.3f))" % [x, y, z])
	
	return {
		"actuator_code": "\n".join(code_lines)
	}
