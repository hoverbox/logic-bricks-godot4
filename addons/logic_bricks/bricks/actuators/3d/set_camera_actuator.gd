@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Set Camera Actuator
## Makes the assigned Camera3D the active camera for the current viewport.
## Assign your Camera3D via the @export in the Inspector.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Set Camera"


func _initialize_properties() -> void:
	properties = {}


func get_property_definitions() -> Array:
	return []


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Makes the assigned Camera3D the active camera.\nUse a one-shot sensor (e.g. Delay or a state transition) to avoid\ncalling make_current() every frame unnecessarily.\n\n⚠ Adds an @export in the Inspector — assign your Camera3D there.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	# instance_name IS the variable name — falls back to "set_camera" when unnamed.
	var camera_var = instance_name.to_lower().replace(" ", "_") if not instance_name.is_empty() else "set_camera"
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("@export var %s: Camera3D" % camera_var)

	code_lines.append("# Set camera as active")
	code_lines.append("if %s:" % camera_var)
	code_lines.append("\t%s.make_current()" % camera_var)
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Set Camera Actuator: No Camera3D assigned to '%s' — drag one into the inspector\")" % camera_var)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
