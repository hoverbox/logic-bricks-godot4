@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Physics Actuator - Control physics properties and behavior
## Suspend/Resume physics, change mass, gravity, damping, etc.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Physics"


func _initialize_properties() -> void:
	properties = {
		"physics_action": "suspend_physics",  # Default matches normalized enum value
		"mass": 1.0,
		"gravity_scale": 1.0,
		"linear_damp": 0.0,
		"angular_damp": 0.0
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "physics_action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Suspend Physics,Resume Physics,Set Mass,Set Gravity Scale,Set Linear Damping,Set Angular Damping,Enable Contact Monitor,Disable Contact Monitor",
			"default": "suspend_physics"
		},
		{
			"name": "mass",
			"type": TYPE_FLOAT,
			"default": 1.0
		},
		{
			"name": "gravity_scale",
			"type": TYPE_FLOAT,
			"default": 1.0
		},
		{
			"name": "linear_damp",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "angular_damp",
			"type": TYPE_FLOAT,
			"default": 0.0
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var physics_action = properties.get("physics_action", "suspend")
	
	# Normalize action
	if typeof(physics_action) == TYPE_STRING:
		physics_action = physics_action.to_lower().replace(" ", "_")
	
	var code_lines: Array[String] = []
	
	# Check if node supports physics
	if not (node is RigidBody3D or node is CharacterBody3D):
		code_lines.append("# WARNING: Physics actuator only works with RigidBody3D or CharacterBody3D!")
		code_lines.append("# Current node type: %s" % node.get_class())
		code_lines.append("pass  # No action - node type not supported")
		return {"actuator_code": "\n".join(code_lines)}
	
	match physics_action:
		"suspend_physics":
			if node is RigidBody3D:
				code_lines.append("# Suspend physics simulation")
				code_lines.append("freeze = true")
			elif node is CharacterBody3D:
				code_lines.append("# Disable CharacterBody3D physics processing")
				code_lines.append("set_physics_process(false)")
		
		"resume_physics":
			if node is RigidBody3D:
				code_lines.append("# Resume physics simulation")
				code_lines.append("freeze = false")
			elif node is CharacterBody3D:
				code_lines.append("# Enable CharacterBody3D physics processing")
				code_lines.append("set_physics_process(true)")
		
		"set_mass":
			if node is RigidBody3D:
				var mass = properties.get("mass", 1.0)
				code_lines.append("# Set mass")
				code_lines.append("mass = %.3f" % mass)
			else:
				code_lines.append("pass  # CharacterBody3D does not have mass property")
		
		"set_gravity_scale":
			if node is RigidBody3D:
				var gravity_scale = properties.get("gravity_scale", 1.0)
				code_lines.append("# Set gravity scale")
				code_lines.append("gravity_scale = %.3f" % gravity_scale)
			else:
				code_lines.append("pass  # CharacterBody3D does not have gravity_scale property")
		
		"set_linear_damping":
			if node is RigidBody3D:
				var linear_damp = properties.get("linear_damp", 0.0)
				code_lines.append("# Set linear damping")
				code_lines.append("linear_damp = %.3f" % linear_damp)
			else:
				code_lines.append("pass  # CharacterBody3D does not have linear_damp property")
		
		"set_angular_damping":
			if node is RigidBody3D:
				var angular_damp = properties.get("angular_damp", 0.0)
				code_lines.append("# Set angular damping")
				code_lines.append("angular_damp = %.3f" % angular_damp)
			else:
				code_lines.append("pass  # CharacterBody3D does not have angular_damp property")
		
		"enable_contact_monitor":
			if node is RigidBody3D:
				code_lines.append("# Enable contact monitoring")
				code_lines.append("contact_monitor = true")
				code_lines.append("max_contacts_reported = 4  # Set reasonable default")
			else:
				code_lines.append("pass  # CharacterBody3D does not have contact_monitor property")
		
		"disable_contact_monitor":
			if node is RigidBody3D:
				code_lines.append("# Disable contact monitoring")
				code_lines.append("contact_monitor = false")
			else:
				code_lines.append("pass  # CharacterBody3D does not have contact_monitor property")
		
		_:
			code_lines.append("# Unknown physics action: %s" % physics_action)
			code_lines.append("pass  # No action taken")
	
	return {"actuator_code": "\n".join(code_lines)}
