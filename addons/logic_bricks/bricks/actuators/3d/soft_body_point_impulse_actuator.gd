@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Applies a one-shot impulse to one simulated point of a SoftBody3D mesh.


func get_brick_info() -> Dictionary:
	return {
		"class": "SoftBodyPointImpulseActuator",
		"name": "Soft Body Point Impulse",
		"type": "actuator",
		"category": "Physics",
		"domain": "3d",
		"menu_order": 440,
		"description": "Applies a one-shot impulse to one simulated point of a SoftBody3D mesh.",
	}


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Soft Body Point Impulse"


func get_compatibility_error(node: Node) -> String:
	return "" if node is SoftBody3D else "Requires SoftBody3D"


func _initialize_properties() -> void:
	properties = {
		"point_index": "0",
		"x": "0.0",
		"y": "0.0",
		"z": "0.0",
		"space": "global",
	}


func get_property_definitions() -> Array:
	return [
		{"name": "point_index", "type": TYPE_STRING, "default": "0"},
		{"name": "x", "type": TYPE_STRING, "default": "0.0"},
		{"name": "y", "type": TYPE_STRING, "default": "0.0"},
		{"name": "z", "type": TYPE_STRING, "default": "0.0"},
		{"name": "space", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Global,Local", "default": "global"},
	]


func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	if _validation_all_numeric_zero(["x", "y", "z"]):
		warnings.append("Put a Value or Variable in X,Y, or Z")
	return warnings


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Applies a one-shot impulse to one SoftBody3D mesh point. Use this for localized impacts and deformation.",
		"point_index": "Index of the simulated SoftBody3D mesh point. Accepts an integer or variable.",
		"x": "X impulse component.",
		"y": "Y impulse component.",
		"z": "Z impulse component.",
		"space": "Global uses world axes. Local rotates the impulse by the SoftBody3D orientation.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	if not node is SoftBody3D:
		return {"actuator_code": "# WARNING: Soft Body Point Impulse requires SoftBody3D\npush_warning(\"Soft Body Point Impulse requires SoftBody3D\")"}

	var point_expr := _expr(properties.get("point_index", "0"), "0")
	var impulse_expr := "Vector3(%s, %s, %s)" % [
		_expr(properties.get("x", "0.0")),
		_expr(properties.get("y", "0.0")),
		_expr(properties.get("z", "0.0")),
	]
	if str(properties.get("space", "global")).to_lower() == "local":
		impulse_expr = "global_transform.basis.orthonormalized() * %s" % impulse_expr

	return {
		"actuator_code": "# Soft Body Point Impulse\napply_impulse(int(%s), %s)" % [point_expr, impulse_expr]
	}


