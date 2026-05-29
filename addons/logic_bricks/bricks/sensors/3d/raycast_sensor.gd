@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Raycast Sensor - Detects objects along a ray from this node
## Type the RayCast3D node name
## Supports group filtering — only detect objects in specific groups
## The RayCast3D's direction and length are configured in the inspector


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Raycast"


func _initialize_properties() -> void:
	properties = {
		"raycast_node_name": "RayCast3D",
		"detect_mode": "any",       # any, group
		"group_filter": "",         # Comma-separated groups (group mode)
		"invert": false,            # Invert result (true when ray hits nothing)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "raycast_node_name",
			"type": TYPE_STRING,
			"default": "RayCast3D",
			"placeholder": "RayCast3D node name"
		},
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


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Detects objects along a ray from this node.\nAssign a RayCast3D via the inspector (drag and drop).\nThe ray's direction and length are set on the RayCast3D node itself.",
		"detect_mode": "Any: active when the ray hits anything\nGroup: active when the ray hits an object in the specified group(s).",
		"group_filter": "Comma-separated list of group names to filter by.\nExample: 'enemy, obstacle'\nOnly used in Group mode.",
		"invert": "Invert the result.\nAny mode: active when the ray hits nothing.\nGroup mode: active when the hit object is NOT in the group.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var raycast_node_name = str(properties.get("raycast_node_name", "RayCast3D")).strip_edges()
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

	member_vars.append("var %s: RayCast3D = null" % raycast_var)
	_append_find_node_helpers(member_vars)

	code_lines.append("# Raycast sensor")
	code_lines.append("var sensor_active = false")
	code_lines.append("var _node_name_%s = \"%s\"" % [chain_name, _gd_string(raycast_node_name)])
	code_lines.append("if _node_name_%s.is_empty():" % chain_name)
	code_lines.append("\tpush_warning(\"Raycast Sensor: No node name set\")")
	code_lines.append("\t" + raycast_var + " = null")
	code_lines.append("elif " + raycast_var + " == null or " + raycast_var + ".name != _node_name_%s:" % chain_name)
	code_lines.append("\tvar _found_node_%s = _lb_find_node_in_current_scene(_node_name_%s)" % [chain_name, chain_name])
	code_lines.append("\tif _found_node_%s is RayCast3D:" % chain_name)
	code_lines.append("\t\t" + raycast_var + " = _found_node_%s" % chain_name)
	code_lines.append("\telif _found_node_%s:" % chain_name)
	code_lines.append("\t\tpush_warning(\"Raycast Sensor: node '\" + str(_node_name_%s) + \"' is not a RayCast3D\")" % chain_name)
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


func _append_find_node_helpers(member_vars: Array[String]) -> void:
	member_vars.append("")
	member_vars.append("func _lb_find_node_by_name_recursive(node: Node, target_name: String) -> Node:")
	member_vars.append("\tif node == null or target_name.is_empty():")
	member_vars.append("\t\treturn null")
	member_vars.append("\tif node.name == target_name:")
	member_vars.append("\t\treturn node")
	member_vars.append("\tfor child in node.get_children():")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(child, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn null")
	member_vars.append("")
	member_vars.append("func _lb_find_node_in_current_scene(target_name: String) -> Node:")
	member_vars.append("\tvar scene_root = get_tree().current_scene")
	member_vars.append("\tif scene_root:")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(scene_root, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn _lb_find_node_by_name_recursive(get_tree().root, target_name)")

func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")
