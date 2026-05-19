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
		"forward_action": "move_forward",
		"backward_action": "move_backward",
		"left_action": "move_left",
		"right_action": "move_right",
		"forward_axis": "-z",
		"smoothing": 0.1,
		"camera_relative": false,
		"camera_name": "",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "forward_action",
			"type": TYPE_STRING,
			"default": "move_forward",
			"placeholder": "Input Map action"
		},
		{
			"name": "backward_action",
			"type": TYPE_STRING,
			"default": "move_backward",
			"placeholder": "Input Map action"
		},
		{
			"name": "left_action",
			"type": TYPE_STRING,
			"default": "move_left",
			"placeholder": "Input Map action"
		},
		{
			"name": "right_action",
			"type": TYPE_STRING,
			"default": "move_right",
			"placeholder": "Input Map action"
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
			"placeholder": "Optional camera node name"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Rotates a node to face the combined Input Map direction instead of the movement/slide direction.\n\nAdds an @export in the Inspector - assign the mesh/Node3D to rotate.",
		"forward_action": "Input Map action for forward/up input.",
		"backward_action": "Input Map action for backward/down input.",
		"left_action": "Input Map action for left input.",
		"right_action": "Input Map action for right input.",
		"forward_axis": "Which direction the mesh considers forward. -Z is Godot's default forward direction.",
		"smoothing": "How smoothly to rotate. 0 = instant, higher = smoother.",
		"camera_relative": "When enabled, the input direction is rotated by the camera yaw, matching camera-relative movement.",
		"camera_name": "Optional camera node name. If blank, uses the active viewport camera.",
	}


func _quote_action(action_name) -> String:
	var s = str(action_name).strip_edges()
	return '"%s"' % s.c_escape()


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var forward_action = properties.get("forward_action", "move_forward")
	var backward_action = properties.get("backward_action", "move_backward")
	var left_action = properties.get("left_action", "move_left")
	var right_action = properties.get("right_action", "move_right")
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

	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name

	var target_var = "_%s" % _export_label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("@export var %s: Node3D" % target_var)

	code_lines.append("# Rotate target node to face combined Input Map direction")
	code_lines.append("if not %s:" % target_var)
	code_lines.append("\tpush_warning(\"Look At Input: No Node3D assigned to '%s' - drag one into the inspector\")" % target_var)
	code_lines.append("else:")
	code_lines.append("\tvar _input_x = Input.get_action_strength(%s) - Input.get_action_strength(%s)" % [_quote_action(right_action), _quote_action(left_action)])
	code_lines.append("\tvar _input_z = Input.get_action_strength(%s) - Input.get_action_strength(%s)" % [_quote_action(backward_action), _quote_action(forward_action)])
	code_lines.append("\tvar _input_dir = Vector3(_input_x, 0.0, _input_z)")
	code_lines.append("\tif _input_dir.length_squared() > 1.0:")
	code_lines.append("\t\t_input_dir = _input_dir.normalized()")
	if camera_relative:
		if not camera_name.is_empty():
			code_lines.append("\tvar _look_input_cam = get_tree().root.find_child(\"%s\", true, false)" % camera_name.c_escape())
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
