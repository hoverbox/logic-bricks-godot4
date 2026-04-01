@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Motion Actuator - Movement actuator for location and rotation
## For physics forces/torque/linear velocity, use the Physics actuators in the Physics submenu


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Motion"


func _initialize_properties() -> void:
	properties = {
		"motion_type": "location",  # location, rotation
		
		# Location properties
		"movement_method": "character_velocity",  # translate, character_velocity, position
		
		# Common properties
		"x": "0.0",
		"y": "0.0",
		"z": "0.0",
		"space": "local",  # local or global
		"camera_relative": false,  # true = movement direction based on camera pivot yaw
		"camera_name": "",         # Name of the Camera3D node to use (e.g. "Camera3D")
		"call_move_and_slide": false  # Set true if no other actuator calls move_and_slide
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "motion_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Location,Rotation",
			"default": "location"
		},
		{
			"name": "movement_method",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Character Velocity,Translate,Position",
			"default": "character_velocity"
		},
		{
			"name": "x",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "y",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "z",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "space",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Local,Global",
			"default": "local"
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
			"placeholder": "e.g. Camera3D",
			"condition": {"property": "camera_relative", "value": true}
		},
		{
			"name": "call_move_and_slide",
			"type": TYPE_BOOL,
			"default": false
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Moves or rotates the node.\nX/Y/Z fields accept numbers, variable names, or math expressions.",
		"motion_type": "Location: move by offset, set velocity, or set position\nRotation: rotate by degrees each frame\n\nFor physics forces, torque, or RigidBody velocity,\nuse the Physics actuators in the Physics submenu.",
		"movement_method": "Character Velocity: set velocity on active axes (CharacterBody3D)\nTranslate: move by offset each frame\nPosition: set absolute position",
		"x": "X axis value. Accepts:\n• A number: 5.0\n• A variable: speed\n• An expression: input_x * speed",
		"y": "Y axis value. Accepts:\n• A number: 5.0\n• A variable: speed\n• An expression: input_y * speed",
		"z": "Z axis value. Accepts:\n• A number: 5.0\n• A variable: speed\n• An expression: input_z * speed",
		"space": "Local: relative to node's rotation\nGlobal: world axes",
		"camera_relative": "On: movement direction is based on a camera's yaw instead of the node's own rotation.\nOverrides the Space setting for horizontal movement.",
		"camera_name": "The name of the Camera3D node to use (just the node name, not a path).\nSearches the whole scene — perfect for split-screen where each player has their own camera.\nLeave empty to use get_viewport().get_camera_3d() (single-screen only).",
		"call_move_and_slide": "Call move_and_slide() after setting velocity.\nEnable if no other actuator does this.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var motion_type = properties.get("motion_type", "location")
	
	# Normalize motion_type
	if typeof(motion_type) == TYPE_STRING:
		motion_type = motion_type.to_lower().replace(" ", "_")
	
	# Generate code based on motion type
	match motion_type:
		"location":
			return _generate_location_code(node, chain_name)
		"rotation":
			return _generate_rotation_code(node, chain_name)
		_:
			return {"actuator_code": "# Unknown motion type: %s" % motion_type}


## Convert a value to a code expression.
## If it's a number (or string of a number), returns the float literal.
## Otherwise returns it as-is (a variable name).
func _to_expr(val) -> String:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return "%.3f" % val
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s


## Check if a value is a literal zero
func _is_zero(val) -> bool:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return val == 0.0
	var s = str(val).strip_edges()
	if s.is_empty():
		return true
	if s.is_valid_float() or s.is_valid_int():
		return float(s) == 0.0
	# It's a variable name — not zero
	return false


func _generate_location_code(node: Node, chain_name: String) -> Dictionary:
	var x = properties.get("x", 0.0)
	var y = properties.get("y", 0.0)
	var z = properties.get("z", 0.0)
	var space = properties.get("space", "local")
	var movement_method = properties.get("movement_method", "character_velocity")
	var camera_relative = properties.get("camera_relative", false)
	var camera_name = str(properties.get("camera_name", "")).strip_edges()
	
	# Normalize
	if typeof(space) == TYPE_STRING:
		space = space.to_lower()
	if typeof(movement_method) == TYPE_STRING:
		movement_method = movement_method.to_lower().replace(" ", "_")
	
	var code_lines: Array[String] = []
	var call_mas = properties.get("call_move_and_slide", false)
	var vx = _to_expr(x)
	var vy = _to_expr(y)
	var vz = _to_expr(z)
	var vec = "Vector3(%s, %s, %s)" % [vx, vy, vz]
	
	# Camera-relative: find the named camera node at runtime and use its yaw.
	# find_child() searches the whole scene tree recursively, so just the node
	# name is enough — no path needed. Works in split-screen because each player
	# has their own camera node with its own name.
	# If no name is given, falls back to get_viewport().get_camera_3d().
	if camera_relative:
		if not camera_name.is_empty():
			code_lines.append("# Camera-relative movement — finding camera node '%s'" % camera_name)
			code_lines.append("var _cam = get_tree().root.find_child(\"%s\", true, false)" % camera_name)
		else:
			code_lines.append("# Camera-relative movement — using active viewport camera")
			code_lines.append("var _cam = get_viewport().get_camera_3d()")
		code_lines.append("var _cam_yaw = _cam.global_rotation.y if _cam else 0.0")
		code_lines.append("var _cam_basis = Basis(Vector3.UP, _cam_yaw)")
		code_lines.append("var _motion_dir = _cam_basis * %s" % vec)
	
	match movement_method:
		"translate":
			if camera_relative:
				code_lines.append("global_position += _motion_dir")
			elif space == "local":
				code_lines.append("# Move in local space")
				code_lines.append("translate(%s)" % vec)
			else:
				code_lines.append("# Move in global space")
				code_lines.append("global_position += %s" % vec)
		
		"character_velocity":
			code_lines.append("# Set CharacterBody3D velocity on active axes")
			if camera_relative:
				code_lines.append("velocity.x += _motion_dir.x")
				code_lines.append("velocity.z += _motion_dir.z")
				code_lines.append("# velocity.y intentionally preserved (gravity/jump from Character Actuator)")
			elif space == "local":
				code_lines.append("var _motion_dir = global_transform.basis * %s" % vec)
				code_lines.append("velocity.x += _motion_dir.x")
				code_lines.append("velocity.z += _motion_dir.z")
				code_lines.append("# velocity.y intentionally preserved (gravity/jump from Character Actuator)")
			else:
				if not _is_zero(x):
					code_lines.append("velocity.x = %s" % vx)
				if not _is_zero(y):
					code_lines.append("velocity.y = %s" % vy)
				if not _is_zero(z):
					code_lines.append("velocity.z = %s" % vz)
			if call_mas:
				code_lines.append("move_and_slide()")
		
		"position":
			if camera_relative:
				code_lines.append("# Camera-relative position not supported — applying as global")
				code_lines.append("global_position = _motion_dir")
			elif space == "local":
				code_lines.append("# Set local position")
				code_lines.append("position = %s" % vec)
			else:
				code_lines.append("# Set global position")
				code_lines.append("global_position = %s" % vec)
	
	return {"actuator_code": "\n".join(code_lines)}


func _generate_rotation_code(node: Node, chain_name: String) -> Dictionary:
	var x = properties.get("x", 0.0)
	var y = properties.get("y", 0.0)
	var z = properties.get("z", 0.0)
	var space = properties.get("space", "local")
	
	# Normalize
	if typeof(space) == TYPE_STRING:
		space = space.to_lower()
	
	var code_lines: Array[String] = []
	var vx = _to_expr(x)
	var vy = _to_expr(y)
	var vz = _to_expr(z)
	
	if space == "local":
		if not _is_zero(x):
			code_lines.append("rotate_x(deg_to_rad(%s))" % vx)
		if not _is_zero(y):
			code_lines.append("rotate_y(deg_to_rad(%s))" % vy)
		if not _is_zero(z):
			code_lines.append("rotate_z(deg_to_rad(%s))" % vz)
	else:
		if not _is_zero(x) or not _is_zero(y) or not _is_zero(z):
			code_lines.append("global_rotation += Vector3(deg_to_rad(%s), deg_to_rad(%s), deg_to_rad(%s))" % [vx, vy, vz])
	
	var code = "\n".join(code_lines) if code_lines.size() > 0 else "pass"
	
	return {"actuator_code": code}

