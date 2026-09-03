@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Set Camera 2D Actuator
## Makes the named Camera2D the active camera for the current viewport.

func get_brick_info() -> Dictionary:
	return {"class":"SetCamera2DActuator","name":"Set Camera","type":"actuator","category":"Camera","domain":"2d","menu_order":300}

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Set Camera"

func _initialize_properties() -> void:
	properties = {
		"camera_node_name": "Camera2D",
	}

func get_property_definitions() -> Array:
	return [
		{"name":"camera_node_name", "required": true, "required_label": "a Camera2D node name","type":TYPE_STRING,"default":"Camera2D","placeholder":"Camera2D node name"},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Makes the named Camera2D the active camera. Use a one-shot sensor when possible so make_current() is not called every frame.",
		"camera_node_name": "Name of the Camera2D node to make current.",
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var camera_node_name = str(properties.get("camera_node_name", "Camera2D")).strip_edges()
	var camera_var = instance_name.to_lower().replace(" ", "_") if not instance_name.is_empty() else "set_camera_2d"
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []
	member_vars.append("var %s: Camera2D = null" % camera_var)
	_append_find_node_helpers(member_vars)
	code_lines.append("# Set Camera 2D as active")
	code_lines.append("var _node_name_%s = \"%s\"" % [chain_name, _gd_string(camera_node_name)])
	code_lines.append("if _node_name_%s.is_empty():" % chain_name)
	code_lines.append("\tpush_warning(\"Set Camera 2D Actuator: No node name set\")")
	code_lines.append("\t" + camera_var + " = null")
	code_lines.append("elif " + camera_var + " == null or " + camera_var + ".name != _node_name_%s:" % chain_name)
	code_lines.append("\tvar _found_node_%s = _lb_find_node_in_current_scene(_node_name_%s)" % [chain_name, chain_name])
	code_lines.append("\tif _found_node_%s is Camera2D:" % chain_name)
	code_lines.append("\t\t" + camera_var + " = _found_node_%s" % chain_name)
	code_lines.append("\telif _found_node_%s:" % chain_name)
	code_lines.append("\t\tpush_warning(\"Set Camera 2D Actuator: node '\" + str(_node_name_%s) + \"' is not a Camera2D\")" % chain_name)
	code_lines.append("if %s:" % camera_var)
	code_lines.append("\t%s.make_current()" % camera_var)
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Set Camera 2D Actuator: No Camera2D assigned to '%s'\")" % camera_var)
	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}


