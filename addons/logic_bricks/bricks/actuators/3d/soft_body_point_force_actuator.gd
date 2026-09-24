@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Applies continuous force to one simulated point of a SoftBody3D mesh.


func get_brick_info() -> Dictionary:
	return {
		"class": "SoftBodyPointForceActuator",
		"name": "Soft Body Point Force",
		"type": "actuator",
		"category": "Physics",
		"domain": "3d",
		"menu_order": 430,
		"description": "Applies continuous force to one simulated point of a SoftBody3D mesh.",
	}


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Soft Body Point Force"


func get_compatibility_error(node: Node) -> String:
	return "" if node is SoftBody3D else "Requires SoftBody3D"


func _initialize_properties() -> void:
	properties = {
		"point_index": "0",
		"x": "0.0",
		"y": "0.0",
		"z": "0.0",
		"max_force": "0.0",
		"space": "global",
	}


func get_property_definitions() -> Array:
	return [
		{"name": "point_index", "type": TYPE_STRING, "default": "0"},
		{"name": "x", "type": TYPE_STRING, "default": "0.0"},
		{"name": "y", "type": TYPE_STRING, "default": "0.0"},
		{"name": "z", "type": TYPE_STRING, "default": "0.0"},
		{"name": "max_force", "type": TYPE_STRING, "default": "0.0"},
		{"name": "space", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Global,Local", "default": "global"},
	]


func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	if _validation_all_numeric_zero(["x", "y", "z"]):
		warnings.append("Put a Value or Variable in X,Y, or Z")
	return warnings


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Applies continuous force to one SoftBody3D mesh point. Point indices refer to the soft body's simulated mesh points.",
		"point_index": "Index of the simulated SoftBody3D mesh point. Accepts an integer or variable.",
		"x": "X force component.",
		"y": "Y force component.",
		"z": "Z force component.",
		"max_force": "Optional maximum force magnitude. 0 means unlimited.",
		"space": "Global uses world axes. Local rotates the force by the SoftBody3D orientation.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	if not node is SoftBody3D:
		return {"actuator_code": "# WARNING: Soft Body Point Force requires SoftBody3D\npush_warning(\"Soft Body Point Force requires SoftBody3D\")"}

	var point_expr := _expr(properties.get("point_index", "0"), "0")
	var force_expr := "Vector3(%s, %s, %s)" % [
		_expr(properties.get("x", "0.0")),
		_expr(properties.get("y", "0.0")),
		_expr(properties.get("z", "0.0")),
	]
	if str(properties.get("space", "global")).to_lower() == "local":
		force_expr = "global_transform.basis.orthonormalized() * %s" % force_expr

	var lines: Array[String] = ["# Soft Body Point Force"]
	var max_force := properties.get("max_force", "0.0")
	if _is_literal_zero(max_force):
		lines.append("apply_force(int(%s), %s)" % [point_expr, force_expr])
	else:
		var max_expr := _expr(max_force, "0.0")
		lines.append("apply_force(int(%s), (%s).limit_length(%s))" % [point_expr, force_expr, max_expr])
	return {"actuator_code": "\n".join(lines)}

