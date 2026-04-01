@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Teleport Actuator - Instantly sets position to a target node or coordinates
## Useful for respawning, portals, checkpoints, and warping
## The target node is assigned via @export (drag and drop in inspector)


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Teleport"


func _initialize_properties() -> void:
	properties = {
		"mode": "target_node",     # target_node, coordinates
		"x": 0.0,
		"y": 0.0,
		"z": 0.0,
		"copy_rotation": false,    # Also copy the target's rotation (target_node mode)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Target Node,Coordinates",
			"default": "target_node"
		},
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
			"name": "copy_rotation",
			"type": TYPE_BOOL,
			"default": false
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Instantly sets position to a target node or coordinates.\nUseful for respawning, portals, checkpoints.\n\n⚠ Target Node mode adds an @export in the Inspector — assign the destination node there.",
		"mode": "Target Node: teleport to another node's position\nCoordinates: teleport to specific X/Y/Z values",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "target_node")
	var x = float(properties.get("x", 0.0))
	var y = float(properties.get("y", 0.0))
	var z = float(properties.get("z", 0.0))
	var copy_rotation = properties.get("copy_rotation", false)

	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")

	# Use instance name if set, otherwise use brick name, sanitized for use as a variable
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name

	var teleport_target_var = "_%s" % _export_label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	match mode:
		"target_node":
			member_vars.append("@export var %s: Node3D" % teleport_target_var)

			code_lines.append("# Teleport to target node")
			code_lines.append("if %s:" % teleport_target_var)
			code_lines.append("\tglobal_position = %s.global_position" % teleport_target_var)
			if copy_rotation:
				code_lines.append("\tglobal_rotation = %s.global_rotation" % teleport_target_var)
			# Reset velocity to prevent carrying momentum through teleport
			code_lines.append("\tif 'velocity' in self:")
			code_lines.append("\t\tset('velocity', Vector3.ZERO)")
			code_lines.append("else:")
			code_lines.append("\tpush_warning(\"Teleport Actuator: No target node assigned to '%s'\")" % teleport_target_var)

		"coordinates":
			code_lines.append("# Teleport to coordinates")
			code_lines.append("global_position = Vector3(%.3f, %.3f, %.3f)" % [x, y, z])
			# Reset velocity
			code_lines.append("if 'velocity' in self:")
			code_lines.append("\tset('velocity', Vector3.ZERO)")

		_:
			code_lines.append("pass  # Unknown teleport mode")

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
