@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Camera Zoom Actuator - Change FOV (Camera3D) or zoom size (Camera2D/OrthographicCamera)
## Assign a Camera3D or Camera2D via @export


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Camera Zoom"


func _initialize_properties() -> void:
	properties = {
		"camera_type": "camera_3d",  # camera_3d, camera_2d
		"fov":         "75.0",
		"zoom":        "1.0",
		"transition":  true,
		"transition_speed": "3.0",
	}


func get_property_definitions() -> Array:
	return [
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
		"_description": "Changes camera FOV (3D) or zoom (2D).\nDrag your camera into the inspector slot.",
		"camera_type":  "Camera 3D: adjusts Field of View in degrees.\nCamera 2D: adjusts zoom multiplier.",
		"fov":          "Target FOV in degrees (Camera 3D only).\nDefault is 75.0. Lower = more zoomed in.",
		"zoom":         "Target zoom (Camera 2D only).\n1.0 = normal, 2.0 = zoomed in, 0.5 = zoomed out.",
		"transition":   "Smoothly lerp to the target value.",
		"transition_speed": "Lerp speed. Accepts a number or variable.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var camera_type = properties.get("camera_type", "camera_3d")
	var fov         = _to_expr(properties.get("fov",   "75.0"))
	var zoom        = _to_expr(properties.get("zoom",  "1.0"))
	var transition  = properties.get("transition", true)
	var speed       = _to_expr(properties.get("transition_speed", "3.0"))

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
		member_vars.append("@export var %s: Camera3D" % cam_var)
		code_lines.append("# Camera Zoom Actuator (3D)")
		code_lines.append("if %s:" % cam_var)
		if transition:
			code_lines.append("\t%s.fov = lerpf(%s.fov, %s, %s * _delta)" % [cam_var, cam_var, fov, speed])
		else:
			code_lines.append("\t%s.fov = %s" % [cam_var, fov])
		code_lines.append("else:")
		code_lines.append("\tpush_warning(\"Camera Zoom Actuator: No Camera3D assigned to '%s'\")" % cam_var)
	else:
		member_vars.append("@export var %s: Camera2D" % cam_var)
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


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
