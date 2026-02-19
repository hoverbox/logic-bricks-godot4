@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Raycast Sensor - Detects objects along a ray from this node
## Assign a RayCast3D node via @export (drag and drop in inspector)
## Supports group filtering — only detect objects in specific groups
## The RayCast3D's direction and length are configured in the inspector


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Raycast"


func _initialize_properties() -> void:
	properties = {
		"detect_mode": "any",       # any, group
		"group_filter": "",         # Comma-separated groups (group mode)
		"invert": false,            # Invert result (true when ray hits nothing)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "detect_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Any,Group",
			"default": "any"
		},
		{
			"name": "group_filter",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "invert",
			"type": TYPE_BOOL,
			"default": false
		},
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var detect_mode = properties.get("detect_mode", "any")
	var group_filter = properties.get("group_filter", "")
	var invert = properties.get("invert", false)

	if typeof(detect_mode) == TYPE_STRING:
		detect_mode = detect_mode.to_lower()

	# Parse groups
	var groups: Array[String] = []
	if typeof(group_filter) == TYPE_STRING and not group_filter.strip_edges().is_empty():
		for g in group_filter.split(","):
			var trimmed = g.strip_edges()
			if not trimmed.is_empty():
				groups.append(trimmed)

	var raycast_var = "_raycast_%s" % chain_name
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("@export var %s: RayCast3D" % raycast_var)

	code_lines.append("# Raycast sensor")
	code_lines.append("var sensor_active = false")
	code_lines.append("if %s:" % raycast_var)
	code_lines.append("\t%s.force_raycast_update()" % raycast_var)

	match detect_mode:
		"group":
			if groups.size() > 0:
				code_lines.append("\tif %s.is_colliding():" % raycast_var)
				code_lines.append("\t\tvar _ray_collider = %s.get_collider()" % raycast_var)

				var group_checks: Array[String] = []
				for g in groups:
					group_checks.append("_ray_collider.is_in_group(\"%s\")" % g)
				var condition = " or ".join(group_checks)

				if invert:
					code_lines.append("\t\tsensor_active = not (%s)" % condition)
				else:
					code_lines.append("\t\tsensor_active = %s" % condition)
				code_lines.append("\telse:")
				if invert:
					code_lines.append("\t\tsensor_active = true")
				else:
					code_lines.append("\t\tsensor_active = false")
			else:
				# Group mode with no groups specified — always false
				code_lines.append("\tsensor_active = %s" % ("true" if invert else "false"))

		_:  # "any"
			if invert:
				code_lines.append("\tsensor_active = not %s.is_colliding()" % raycast_var)
			else:
				code_lines.append("\tsensor_active = %s.is_colliding()" % raycast_var)

	code_lines.append("else:")
	code_lines.append("\tsensor_active = false")
	code_lines.append("\tpush_warning(\"Raycast Sensor: No RayCast3D assigned to '%s'\")" % raycast_var)

	return {
		"sensor_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
