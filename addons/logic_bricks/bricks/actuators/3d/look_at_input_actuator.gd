@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Rotates a node to face the combined Input Map direction.
## This uses the player's requested direction, not the body's actual velocity.
## Useful for slippery/icy movement where the character can face right while sliding left.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Look At Input"


func _initialize_properties() -> void:
	properties = {
		"target_node_name": "MeshInstance3D",
		"forward_action": "",
		"backward_action": "",
		"left_action": "",
		"right_action": "",
		"forward_axis": "-z",
		"smoothing": 0.1,
		"camera_relative": false,
		"camera_name": "",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_node_name",
			"type": TYPE_STRING,
			"default": "MeshInstance3D",
			"placeholder": "Node3D node name",
			"node_reference": true,
			"accepted_node_types": ["Node3D"]
		},
		{
			"name": "forward_action",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Input Map action",
			"input_action_picker": true
		},
		{
			"name": "backward_action",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Input Map action",
			"input_action_picker": true
		},
		{
			"name": "left_action",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Input Map action",
			"input_action_picker": true
		},
		{
			"name": "right_action",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Input Map action",
			"input_action_picker": true
		},
		{
			"name": "forward_axis",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "-Z (Godot Default),+Z,+X,-X",
			"default": "-z"
		},
		{
			"name": "smoothing",
			"type": TYPE_FLOAT,
			"default": 0.1
		},
		{
			"name": "camera_relative",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "camera_name",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Optional camera node name",
			"node_reference": true,
			"accepted_node_types": ["Camera3D"]
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Rotates a Node3D to face the combined Input Map direction instead of the movement/slide direction. Named targets are searched across the current scene.",
		"target_node_name": "The Node3D to rotate, such as PlayerMesh or CharacterModel. Named targets are searched across the current scene.",
		"forward_action": "Input Map action for forward/up input.",
		"backward_action": "Input Map action for backward/down input.",
		"left_action": "Input Map action for left input.",
		"right_action": "Input Map action for right input.",
		"forward_axis": "Which direction the mesh considers forward. -Z is Godot's default forward direction.",
		"smoothing": "How smoothly to rotate. 0 = instant, higher = smoother.",
		"camera_relative": "When enabled, the input direction is rotated by the camera yaw, matching camera-relative movement.",
		"camera_name": "Optional Camera3D node name. If blank, uses the active viewport camera. Named cameras are searched across the current scene.",
	}


func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	var input_count := 0
	for property_name in ["forward_action", "backward_action", "left_action", "right_action"]:
		if not str(properties.get(property_name, "")).strip_edges().is_empty():
			input_count += 1
	if input_count < 2:
		warnings.append("Select or enter at least two Input actions.")
	return warnings


func _action_strength_expression(action_name) -> String:
	var action := str(action_name).strip_edges()
	if action.is_empty():
		return "0.0"
	return "Input.get_action_strength(%s)" % _quote_action(action)


func _quote_action(action_name) -> String:
	var s = str(action_name).strip_edges()
	return '"%s"' % s.c_escape()


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "MeshInstance3D")).strip_edges()
	var forward_action = properties.get("forward_action", "")
	var backward_action = properties.get("backward_action", "")
	var left_action = properties.get("left_action", "")
	var right_action = properties.get("right_action", "")
	var forward_axis = properties.get("forward_axis", "-z")
	var smoothing = properties.get("smoothing", 0.1)
	var camera_relative = properties.get("camera_relative", false)
	var camera_name = str(properties.get("camera_name", "")).strip_edges()

	if typeof(forward_axis) == TYPE_STRING:
		forward_axis = forward_axis.to_lower().replace(" ", "_")

	# look_at()/atan2 convention points -Z at the target, so offset for mesh forward direction.
	var y_offset = "0.0"
	match forward_axis:
		"-z", "-z_(godot_default)":
			y_offset = "0.0"
		"+z":
			y_offset = "PI"
		"+x":
			y_offset = "-PI / 2.0"
		"-x":
			y_offset = "PI / 2.0"

	var label = _unique_label(chain_name)
	var target_var = "_%s_target_node" % label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("var %s: Node3D = null" % target_var)

	code_lines.append("# Rotate target node to face combined Input Map direction")
	code_lines.append("var _target_name_%s = \"%s\"" % [label, _gd_string(target_node_name)])
	code_lines.append("if _target_name_%s.is_empty():" % label)
	code_lines.append("\tpush_warning(\"Look At Input: No target node name set\")")
	code_lines.append("\t%s = null" % target_var)
	code_lines.append("elif %s == null or %s.name != _target_name_%s:" % [target_var, target_var, label])
	code_lines.append("\tvar _found_target_%s = find_child(_target_name_%s, true, false)" % [label, label])
	code_lines.append("\tif _found_target_%s == null and get_tree().current_scene:" % label)
	code_lines.append("\t\t_found_target_%s = get_tree().current_scene.find_child(_target_name_%s, true, false)" % [label, label])
	code_lines.append("\tif _found_target_%s == null:" % label)
	code_lines.append("\t\t_found_target_%s = get_tree().root.find_child(_target_name_%s, true, false)" % [label, label])
	code_lines.append("\tif _found_target_%s is Node3D:" % label)
	code_lines.append("\t\t%s = _found_target_%s" % [target_var, label])
	code_lines.append("\telif _found_target_%s:" % label)
	code_lines.append("\t\tpush_warning(\"Look At Input: node '\" + str(_target_name_%s) + \"' is not a Node3D\")" % label)
	code_lines.append("if not %s:" % target_var)
	code_lines.append("\tpush_warning(\"Look At Input: could not find Node3D named '\" + str(_target_name_%s) + \"'\")" % label)
	code_lines.append("else:")
	code_lines.append("\tvar _input_x = %s - %s" % [_action_strength_expression(right_action), _action_strength_expression(left_action)])
	code_lines.append("\tvar _input_z = %s - %s" % [_action_strength_expression(backward_action), _action_strength_expression(forward_action)])
	code_lines.append("\tvar _input_dir = Vector3(_input_x, 0.0, _input_z)")
	code_lines.append("\tif _input_dir.length_squared() > 1.0:")
	code_lines.append("\t\t_input_dir = _input_dir.normalized()")
	if camera_relative:
		if not camera_name.is_empty():
			code_lines.append("\tvar _look_input_cam = find_child(\"%s\", true, false)" % camera_name.c_escape())
			code_lines.append("\tif _look_input_cam == null and get_tree().current_scene:")
			code_lines.append("\t\t_look_input_cam = get_tree().current_scene.find_child(\"%s\", true, false)" % camera_name.c_escape())
			code_lines.append("\tif _look_input_cam == null:")
			code_lines.append("\t\t_look_input_cam = get_tree().root.find_child(\"%s\", true, false)" % camera_name.c_escape())
		else:
			code_lines.append("\tvar _look_input_cam = get_viewport().get_camera_3d()")
		code_lines.append("\tif _look_input_cam:")
		code_lines.append("\t\tvar _look_input_cam_basis = Basis(Vector3.UP, _look_input_cam.global_rotation.y)")
		code_lines.append("\t\t_input_dir = _look_input_cam_basis * _input_dir")
	code_lines.append("\tif _input_dir.length_squared() > 0.0001:")
	if smoothing > 0.001:
		code_lines.append("\t\tvar _target_angle = atan2(_input_dir.x, _input_dir.z) + %s" % y_offset)
		code_lines.append("\t\tvar _current_y = %s.global_rotation.y" % target_var)
		code_lines.append("\t\t%s.global_rotation.y = lerp_angle(_current_y, _target_angle, %f)" % [target_var, smoothing])
	else:
		code_lines.append("\t\t%s.global_rotation.y = atan2(_input_dir.x, _input_dir.z) + %s" % [target_var, y_offset])

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}


