@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Physics Actuator - Control physics properties and behavior.
## Shared actions use the closest native equivalent on SoftBody3D.


const SOFT_BODY_ACTIONS := [
	"set_soft_body_drag",
	"set_soft_body_stiffness",
	"set_soft_body_pressure",
	"set_soft_body_shrinking",
	"set_soft_body_simulation_precision",
]


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Physics"


func _normalized_action() -> String:
	return str(properties.get("physics_action", "suspend_physics")).to_lower().replace(" ", "_")


func get_compatibility_error(node: Node) -> String:
	var action := _normalized_action()
	if action in ["suspend_physics", "resume_physics", "suspend", "resume"]:
		return "" if node is RigidBody3D or node is CharacterBody3D else "Suspend/Resume requires RigidBody3D or CharacterBody3D"
	if action in ["set_mass", "set_linear_damping"]:
		return "" if node is RigidBody3D or node is SoftBody3D else "Requires RigidBody3D or SoftBody3D"
	if action in SOFT_BODY_ACTIONS:
		return "" if node is SoftBody3D else "This action requires SoftBody3D"
	return "" if node is RigidBody3D else "This Physics action requires RigidBody3D"


func _initialize_properties() -> void:
	properties = {
		"physics_action": "suspend_physics",
		"mass": 1.0,
		"gravity_scale": 1.0,
		"linear_damp": 0.0,
		"angular_damp": 0.0,
		"soft_body_drag": 0.0,
		"soft_body_stiffness": 0.5,
		"soft_body_pressure": 0.0,
		"soft_body_shrinking": 0.0,
		"soft_body_simulation_precision": 5,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "physics_action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Suspend Physics,Resume Physics,Set Mass,Set Gravity Scale,Set Linear Damping,Set Angular Damping,Enable Contact Monitor,Disable Contact Monitor,Set Soft Body Drag,Set Soft Body Stiffness,Set Soft Body Pressure,Set Soft Body Shrinking,Set Soft Body Simulation Precision",
			"default": "suspend_physics"
		},
		{"name": "mass", "type": TYPE_FLOAT, "default": 1.0},
		{"name": "gravity_scale", "type": TYPE_FLOAT, "default": 1.0},
		{"name": "linear_damp", "type": TYPE_FLOAT, "default": 0.0},
		{"name": "angular_damp", "type": TYPE_FLOAT, "default": 0.0},
		{"name": "soft_body_drag", "type": TYPE_FLOAT, "default": 0.0},
		{"name": "soft_body_stiffness", "type": TYPE_FLOAT, "default": 0.5},
		{"name": "soft_body_pressure", "type": TYPE_FLOAT, "default": 0.0},
		{"name": "soft_body_shrinking", "type": TYPE_FLOAT, "default": 0.0},
		{"name": "soft_body_simulation_precision", "type": TYPE_INT, "default": 5},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Controls physics properties. Mass and Linear Damping support RigidBody3D and SoftBody3D; Soft Body actions expose native SoftBody3D properties.",
		"physics_action": "Choose the physics operation. Rigid-body-only actions remain unavailable on SoftBody3D.",
		"mass": "RigidBody3D mass or SoftBody3D total mass.",
		"gravity_scale": "RigidBody3D only.",
		"linear_damp": "RigidBody3D linear_damp or SoftBody3D damping_coefficient.",
		"angular_damp": "RigidBody3D only; soft bodies do not have rigid angular damping.",
		"soft_body_drag": "SoftBody3D air resistance coefficient.",
		"soft_body_stiffness": "SoftBody3D linear stiffness, normally 0 to 1.",
		"soft_body_pressure": "SoftBody3D internal pressure coefficient.",
		"soft_body_shrinking": "SoftBody3D rest-length shrinking/expansion factor.",
		"soft_body_simulation_precision": "SoftBody3D solver precision. Higher values cost more performance.",
	}


func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	if not (node is SoftBody3D):
		return warnings
	var action := _normalized_action()
	if action in ["suspend_physics", "resume_physics", "suspend", "resume", "set_gravity_scale", "set_angular_damping", "enable_contact_monitor", "disable_contact_monitor"]:
		warnings.append("SoftBody3D does not expose a reliable equivalent for this Physics action.")
	return warnings


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var physics_action := _normalized_action()
	var code_lines: Array[String] = []

	if not (node is RigidBody3D or node is CharacterBody3D or node is SoftBody3D):
		code_lines.append("# WARNING: Physics actuator requires RigidBody3D, CharacterBody3D, or SoftBody3D")
		code_lines.append("pass")
		return {"actuator_code": "\n".join(code_lines)}

	match physics_action:
		"suspend_physics":
			if node is RigidBody3D:
				code_lines.append("freeze = true")
			elif node is CharacterBody3D:
				code_lines.append("set_physics_process(false)")
			else:
				code_lines.append("push_warning(\"SoftBody3D does not expose backend-independent Suspend Physics support\")")

		"resume_physics":
			if node is RigidBody3D:
				code_lines.append("freeze = false")
			elif node is CharacterBody3D:
				code_lines.append("set_physics_process(true)")
			else:
				code_lines.append("push_warning(\"SoftBody3D does not expose backend-independent Resume Physics support\")")

		"set_mass":
			var mass_value = properties.get("mass", 1.0)
			if node is RigidBody3D:
				code_lines.append("mass = %.3f" % mass_value)
			elif node is SoftBody3D:
				code_lines.append("total_mass = %.3f" % mass_value)
			else:
				code_lines.append("pass  # CharacterBody3D does not have mass")

		"set_gravity_scale":
			if node is RigidBody3D:
				code_lines.append("gravity_scale = %.3f" % properties.get("gravity_scale", 1.0))
			else:
				code_lines.append("push_warning(\"Gravity Scale is only available on RigidBody3D; use the Gravity action for SoftBody3D\")")

		"set_linear_damping":
			var damping_value = properties.get("linear_damp", 0.0)
			if node is RigidBody3D:
				code_lines.append("linear_damp = %.3f" % damping_value)
			elif node is SoftBody3D:
				code_lines.append("damping_coefficient = %.3f" % damping_value)
			else:
				code_lines.append("pass  # CharacterBody3D does not have linear damping")

		"set_angular_damping":
			if node is RigidBody3D:
				code_lines.append("angular_damp = %.3f" % properties.get("angular_damp", 0.0))
			else:
				code_lines.append("push_warning(\"Angular Damping is only available on RigidBody3D\")")

		"enable_contact_monitor":
			if node is RigidBody3D:
				code_lines.append("contact_monitor = true")
				code_lines.append("max_contacts_reported = 4")
			else:
				code_lines.append("push_warning(\"Contact Monitor is only available on RigidBody3D\")")

		"disable_contact_monitor":
			if node is RigidBody3D:
				code_lines.append("contact_monitor = false")
			else:
				code_lines.append("push_warning(\"Contact Monitor is only available on RigidBody3D\")")

		"set_soft_body_drag":
			if node is SoftBody3D:
				code_lines.append("drag_coefficient = %.3f" % properties.get("soft_body_drag", 0.0))
			else:
				code_lines.append("pass  # SoftBody3D only")

		"set_soft_body_stiffness":
			if node is SoftBody3D:
				code_lines.append("linear_stiffness = %.3f" % properties.get("soft_body_stiffness", 0.5))
			else:
				code_lines.append("pass  # SoftBody3D only")

		"set_soft_body_pressure":
			if node is SoftBody3D:
				code_lines.append("pressure_coefficient = %.3f" % properties.get("soft_body_pressure", 0.0))
			else:
				code_lines.append("pass  # SoftBody3D only")

		"set_soft_body_shrinking":
			if node is SoftBody3D:
				code_lines.append("shrinking_factor = %.3f" % properties.get("soft_body_shrinking", 0.0))
			else:
				code_lines.append("pass  # SoftBody3D only")

		"set_soft_body_simulation_precision":
			if node is SoftBody3D:
				code_lines.append("simulation_precision = %d" % int(properties.get("soft_body_simulation_precision", 5)))
			else:
				code_lines.append("pass  # SoftBody3D only")

		_:
			code_lines.append("# Unknown physics action: %s" % physics_action)
			code_lines.append("pass")

	return {"actuator_code": "\n".join(code_lines)}
