@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Set Camera Actuator
## Makes the assigned Camera3D the active camera for the current viewport.
## Type your Camera3D node name.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Set Camera"


func _initialize_properties() -> void:
	properties = {
		"camera_node_name": "Camera3D",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "camera_node_name",
			"type": TYPE_STRING,
			"default": "Camera3D",
			"placeholder": "Camera3D node name"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Makes the assigned Camera3D the active camera.\nUse a one-shot sensor (e.g. Delay or a state transition) to avoid\ncalling make_current() every frame unnecessarily.\n\n⚠ Adds an @export in the Inspector — assign your Camera3D there.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	# instance_name IS the variable name — falls back to "set_camera" when unnamed.
	var camera_node_name = str(properties.get("camera_node_name", "Camera3D")).strip_edges()
	var camera_var = instance_name.to_lower().replace(" ", "_") if not instance_name.is_empty() else "set_camera"
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("var %s: Camera3D = null" % camera_var)
	_append_find_node_helpers(member_vars)

	code_lines.append("# Set camera as active")
	code_lines.append("var _node_name_%s = \"%s\"" % [chain_name, _gd_string(camera_node_name)])
	code_lines.append("if _node_name_%s.is_empty():" % chain_name)
	code_lines.append("\tpush_warning(\"Set Camera Actuator: No node name set\")")
	code_lines.append("\t" + camera_var + " = null")
	code_lines.append("elif " + camera_var + " == null or " + camera_var + ".name != _node_name_%s:" % chain_name)
	code_lines.append("\tvar _found_node_%s = _lb_find_node_in_current_scene(_node_name_%s)" % [chain_name, chain_name])
	code_lines.append("\tif _found_node_%s is Camera3D:" % chain_name)
	code_lines.append("\t\t" + camera_var + " = _found_node_%s" % chain_name)
	code_lines.append("\telif _found_node_%s:" % chain_name)
	code_lines.append("\t\tpush_warning(\"Set Camera Actuator: node '\" + str(_node_name_%s) + \"' is not a Camera3D\")" % chain_name)
	code_lines.append("if %s:" % camera_var)
	code_lines.append("\t%s.make_current()" % camera_var)
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Set Camera Actuator: No Camera3D assigned to '%s' — drag one into the inspector\")" % camera_var)

	return {
		"actuator_code": "\n".join(code_lines),
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
