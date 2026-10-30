@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Camera Zoom Actuator - Change FOV (Camera3D) or zoom size (Camera2D/OrthographicCamera)
## Camera is found by typed node name


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Camera Zoom"


func _initialize_properties() -> void:
	properties = {
		"camera_node_name": "Camera3D",
		"camera_type": "camera_3d",  # camera_3d, camera_2d
		"fov":         "75.0",
		"zoom":        "1.0",
		"transition":  true,
		"transition_speed": "3.0",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "camera_node_name", "required": true, "required_label": "a camera node name",
			"type": TYPE_STRING,
			"default": "Camera3D",
			"placeholder": "Camera3D or Camera2D node name"
		},
		{
			"name": "camera_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Camera 3D,Camera 2D",
			"default": "camera_3d"
		},
		{
			"name": "fov",
			"type": TYPE_STRING,
			"default": "75.0"
		},
		{
			"name": "zoom",
			"type": TYPE_STRING,
			"default": "1.0"
		},
		{
			"name": "transition",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "transition_speed",
			"type": TYPE_STRING,
			"default": "3.0"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Changes a camera's FOV (3D) or zoom (2D).\nChoose the camera by name; it is found anywhere in the current scene.",
		"camera_type":  "Camera 3D: adjusts Field of View in degrees.\nCamera 2D: adjusts zoom multiplier.",
		"fov":          "Target FOV in degrees (Camera 3D only).\nDefault is 75.0. Lower = more zoomed in.",
		"zoom":         "Target zoom (Camera 2D only).\n1.0 = normal, 2.0 = zoomed in, 0.5 = zoomed out.",
		"transition":   "Smoothly lerp to the target value.",
		"transition_speed": "Lerp speed. Accepts a number or variable.",
	}


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var camera_type = properties.get("camera_type", "camera_3d")
	if typeof(camera_type) == TYPE_STRING:
		camera_type = camera_type.to_lower().replace(" ", "_")
	var transition = properties.get("transition", true)
	for child in _get_field_names():
		if true:
			var prop_name = child
			match prop_name:
				"fov":
					shown[child] = (camera_type == "camera_3d")
				"zoom":
					shown[child] = (camera_type == "camera_2d")
				"transition_speed":
					shown[child] = transition
	return shown


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var camera_node_name = str(properties.get("camera_node_name", "Camera3D")).strip_edges()
	var camera_type = properties.get("camera_type", "camera_3d")
	var fov         = _expr(properties.get("fov",   "75.0"))
	var zoom        = _expr(properties.get("zoom",  "1.0"))
	var transition  = properties.get("transition", true)
	var speed       = _expr(properties.get("transition_speed", "3.0"))

	if typeof(camera_type) == TYPE_STRING:
		camera_type = camera_type.to_lower().replace(" ", "_")


	# Use instance name if set, otherwise use brick name, sanitized for use as a variable
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name
	var cam_var = "_%s" % _export_label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	if camera_type == "camera_3d":
		member_vars.append("var %s: Camera3D = null" % cam_var)
		_append_find_node_helpers(member_vars)
		code_lines.append("var _node_name_%s = \"%s\"" % [chain_name, _gd_string(camera_node_name)])
		code_lines.append("if _node_name_%s.is_empty():" % chain_name)
		code_lines.append("\tpush_warning(\"Camera Zoom Actuator: No node name set\")")
		code_lines.append("\t" + cam_var + " = null")
		code_lines.append("elif " + cam_var + " == null or " + cam_var + ".name != _node_name_%s:" % chain_name)
		code_lines.append("\tvar _found_node_%s = _lb_find_node_in_current_scene(_node_name_%s)" % [chain_name, chain_name])
		code_lines.append("\tif _found_node_%s is Camera3D:" % chain_name)
		code_lines.append("\t\t" + cam_var + " = _found_node_%s" % chain_name)
		code_lines.append("\telif _found_node_%s:" % chain_name)
		code_lines.append("\t\tpush_warning(\"Camera Zoom Actuator: node '\" + str(_node_name_%s) + \"' is not a Camera3D\")" % chain_name)

		code_lines.append("# Camera Zoom Actuator (3D)")
		code_lines.append("if %s:" % cam_var)
		if transition:
			code_lines.append("\t%s.fov = lerpf(%s.fov, %s, %s * _delta)" % [cam_var, cam_var, fov, speed])
		else:
			code_lines.append("\t%s.fov = %s" % [cam_var, fov])
		code_lines.append("else:")
		code_lines.append("\tpush_warning(\"Camera Zoom Actuator: No Camera3D assigned to '%s'\")" % cam_var)
	else:
		member_vars.append("var %s: Camera2D = null" % cam_var)
		_append_find_node_helpers(member_vars)
		code_lines.append("var _node_name_%s = \"%s\"" % [chain_name, _gd_string(camera_node_name)])
		code_lines.append("if _node_name_%s.is_empty():" % chain_name)
		code_lines.append("\tpush_warning(\"Camera Zoom Actuator: No node name set\")")
		code_lines.append("\t" + cam_var + " = null")
		code_lines.append("elif " + cam_var + " == null or " + cam_var + ".name != _node_name_%s:" % chain_name)
		code_lines.append("\tvar _found_node_%s = _lb_find_node_in_current_scene(_node_name_%s)" % [chain_name, chain_name])
		code_lines.append("\tif _found_node_%s is Camera2D:" % chain_name)
		code_lines.append("\t\t" + cam_var + " = _found_node_%s" % chain_name)
		code_lines.append("\telif _found_node_%s:" % chain_name)
		code_lines.append("\t\tpush_warning(\"Camera Zoom Actuator: node '\" + str(_node_name_%s) + \"' is not a Camera2D\")" % chain_name)

		code_lines.append("# Camera Zoom Actuator (2D)")
		code_lines.append("if %s:" % cam_var)
		if transition:
			code_lines.append("\t%s.zoom = %s.zoom.lerp(Vector2.ONE * %s, %s * _delta)" % [cam_var, cam_var, zoom, speed])
		else:
			code_lines.append("\t%s.zoom = Vector2.ONE * %s" % [cam_var, zoom])
		code_lines.append("else:")
		code_lines.append("\tpush_warning(\"Camera Zoom Actuator: No Camera2D assigned to '%s'\")" % cam_var)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}


