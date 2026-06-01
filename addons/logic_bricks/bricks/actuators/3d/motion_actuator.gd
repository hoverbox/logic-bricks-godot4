@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Motion Actuator - Movement actuator for location and rotation
## For physics forces/torque/linear velocity, use the Physics actuators in the Physics submenu
## Target Node Name is optional. Leave blank to affect self, or type a child/node name
## to move or rotate that node instead.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Motion"


func _initialize_properties() -> void:
	properties = {
		"target_node_name": "",
		"node_name_source": "literal",
		"export_node_name": false,
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
			"name": "target_node_name",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "blank = self, or child/node name"
		},
		{
			"name": "node_name_source",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Literal Node Name,String Variable",
			"default": "literal"
		},
		{
			"name": "export_node_name",
			"type": TYPE_BOOL,
			"default": false
		},
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
		"_description": "Moves or rotates a target node. Leave Target Node Name blank to affect self. X/Y/Z fields accept numbers, variable names, or math expressions.",
		"target_node_name": "Leave blank to move/rotate the node that owns this logic brick. Type a node name, such as PlayerMesh or GunPivot, to affect that child/node instead. The actuator first searches under this node, then the current scene.",
		"node_name_source": "Literal Node Name: use Target Node Name directly. String Variable: treat Target Node Name as a variable name and read that String at runtime.",
		"export_node_name": "Literal mode only. Adds an @export String to the generated script so the target node name can be edited in the Inspector.",
		"motion_type": "Location: move by offset, set velocity, or set position\nRotation: rotate by degrees each frame\n\nFor physics forces, torque, or RigidBody velocity,\nuse the Physics actuators in the Physics submenu.",
		"movement_method": "Character Velocity: set velocity on active axes (CharacterBody3D target)\nTranslate: move by offset each frame\nPosition: set absolute position",
		"x": "X axis value. Accepts:\n• A number: 5.0\n• A variable: speed\n• An expression: input_x * speed",
		"y": "Y axis value. Accepts:\n• A number: 5.0\n• A variable: speed\n• An expression: input_y * speed",
		"z": "Z axis value. Accepts:\n• A number: 5.0\n• A variable: speed\n• An expression: input_z * speed",
		"space": "Local: relative to the target node's rotation\nGlobal: world axes",
		"camera_relative": "On: movement direction is based on a camera's yaw instead of the target node's own rotation.\nOverrides the Space setting for horizontal movement.",
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
## Otherwise returns it as-is (a variable name/expression).
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
	# It's a variable name/expression — not known to be zero
	return false


func _append_target_setup(code_lines: Array[String], member_vars: Array[String], chain_name: String) -> String:
	var target_node_name = str(properties.get("target_node_name", "")).strip_edges()
	var node_name_source = str(properties.get("node_name_source", "literal")).to_lower().replace(" ", "_")
	var export_node_name = properties.get("export_node_name", false)
	var label = _unique_label(chain_name)
	var target_var = "_motion_target_%s" % label
	var node_name_var = "_%s_node_name" % label

	member_vars.append("var %s = null" % target_var)
	if export_node_name and node_name_source != "string_variable":
		member_vars.append("@export var %s: String = \"%s\"" % [node_name_var, _gd_string(target_node_name)])

	var name_expr = "\"%s\"" % _gd_string(target_node_name)
	if node_name_source == "string_variable" and not target_node_name.is_empty():
		name_expr = "str(%s)" % target_node_name
	elif export_node_name and node_name_source != "string_variable":
		name_expr = node_name_var

	code_lines.append("# Motion Actuator target")
	code_lines.append("var _motion_target_name_%s = %s" % [label, name_expr])
	code_lines.append("if _motion_target_name_%s.is_empty():" % label)
	code_lines.append("\t%s = self" % target_var)
	code_lines.append("elif %s == null or %s.name != _motion_target_name_%s:" % [target_var, target_var, label])
	code_lines.append("\t%s = find_child(_motion_target_name_%s, true, false)" % [target_var, label])
	code_lines.append("\tif %s == null and get_tree().current_scene:" % target_var)
	code_lines.append("\t\t%s = get_tree().current_scene.find_child(_motion_target_name_%s, true, false)" % [target_var, label])
	code_lines.append("if %s == null:" % target_var)
	code_lines.append("\tpush_warning(\"Motion Actuator: could not find target node named '\" + str(_motion_target_name_%s) + \"'\")" % label)
	code_lines.append("elif not (%s is Node3D):" % target_var)
	code_lines.append("\tpush_warning(\"Motion Actuator: target node '\" + str(%s.name) + \"' is not a Node3D\")" % target_var)
	code_lines.append("else:")
	return target_var


func _indent_lines(lines: Array[String], indent: String = "\t") -> Array[String]:
	var result: Array[String] = []
	for line in lines:
		if line.is_empty():
			result.append("")
		else:
			result.append(indent + line)
	return result


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
	var member_vars: Array[String] = []
	var target_var = _append_target_setup(code_lines, member_vars, chain_name)
	var body_lines: Array[String] = []
	var call_mas = properties.get("call_move_and_slide", false)
	var vx = _to_expr(x)
	var vy = _to_expr(y)
	var vz = _to_expr(z)
	var vec = "Vector3(%s, %s, %s)" % [vx, vy, vz]

	# Camera-relative: find the named camera node at runtime and use its yaw.
	# If no name is given, falls back to get_viewport().get_camera_3d().
	if camera_relative:
		if not camera_name.is_empty():
			body_lines.append("# Camera-relative movement — finding camera node '%s'" % camera_name)
			body_lines.append("var _cam = get_tree().root.find_child(\"%s\", true, false)" % camera_name)
		else:
			body_lines.append("# Camera-relative movement — using active viewport camera")
			body_lines.append("var _cam = get_viewport().get_camera_3d()")
		body_lines.append("var _cam_yaw = _cam.global_rotation.y if _cam else 0.0")
		body_lines.append("var _cam_basis = Basis(Vector3.UP, _cam_yaw)")
		body_lines.append("var _motion_dir = _cam_basis * %s" % vec)

	match movement_method:
		"translate":
			if camera_relative:
				body_lines.append("%s.global_position += _motion_dir" % target_var)
			elif space == "local":
				body_lines.append("# Move target in local space")
				body_lines.append("%s.translate(%s)" % [target_var, vec])
			else:
				body_lines.append("# Move target in global space")
				body_lines.append("%s.global_position += %s" % [target_var, vec])

		"character_velocity":
			body_lines.append("if not (%s is CharacterBody3D):" % target_var)
			body_lines.append("\tpush_warning(\"Motion Actuator: Character Velocity requires the target node to be a CharacterBody3D\")")
			body_lines.append("else:")
			body_lines.append("\t# Set CharacterBody3D velocity on active axes")
			body_lines.append("\t_logic_brick_character_motion_active = true")
			body_lines.append("\tif _logic_brick_character_use_acceleration:")
			body_lines.append("\t\tif not _logic_brick_character_motion_frame_prepared:")
			body_lines.append("\t\t\t_logic_brick_character_target_velocity = Vector3.ZERO")
			body_lines.append("\t\t\t_logic_brick_character_motion_frame_prepared = true")
			body_lines.append("\telse:")
			body_lines.append("\t\tif not _logic_brick_character_motion_frame_prepared:")
			body_lines.append("\t\t\t%s.velocity.x = 0.0" % target_var)
			body_lines.append("\t\t\t%s.velocity.z = 0.0" % target_var)
			body_lines.append("\t\t\t_logic_brick_character_motion_frame_prepared = true")
			if camera_relative:
				body_lines.append("\tif _logic_brick_character_use_acceleration:")
				body_lines.append("\t\t_logic_brick_character_target_velocity.x += _motion_dir.x")
				body_lines.append("\t\t_logic_brick_character_target_velocity.z += _motion_dir.z")
				body_lines.append("\telse:")
				body_lines.append("\t\t%s.velocity.x += _motion_dir.x" % target_var)
				body_lines.append("\t\t%s.velocity.z += _motion_dir.z" % target_var)
				body_lines.append("\t# velocity.y intentionally preserved (gravity/jump from Character Actuator)")
			elif space == "local":
				body_lines.append("\tvar _motion_dir = %s.global_transform.basis * %s" % [target_var, vec])
				body_lines.append("\tif _logic_brick_character_use_acceleration:")
				body_lines.append("\t\t_logic_brick_character_target_velocity.x += _motion_dir.x")
				body_lines.append("\t\t_logic_brick_character_target_velocity.z += _motion_dir.z")
				body_lines.append("\telse:")
				body_lines.append("\t\t%s.velocity.x += _motion_dir.x" % target_var)
				body_lines.append("\t\t%s.velocity.z += _motion_dir.z" % target_var)
				body_lines.append("\t# velocity.y intentionally preserved (gravity/jump from Character Actuator)")
			else:
				if not _is_zero(x):
					body_lines.append("\tif _logic_brick_character_use_acceleration:")
					body_lines.append("\t\t_logic_brick_character_target_velocity.x = %s" % vx)
					body_lines.append("\telse:")
					body_lines.append("\t\t%s.velocity.x = %s" % [target_var, vx])
				if not _is_zero(y):
					body_lines.append("\t%s.velocity.y = %s" % [target_var, vy])
				if not _is_zero(z):
					body_lines.append("\tif _logic_brick_character_use_acceleration:")
					body_lines.append("\t\t_logic_brick_character_target_velocity.z = %s" % vz)
					body_lines.append("\telse:")
					body_lines.append("\t\t%s.velocity.z = %s" % [target_var, vz])
			if call_mas:
				body_lines.append("\t%s.move_and_slide()" % target_var)

		"position":
			if camera_relative:
				body_lines.append("# Camera-relative position not supported — applying as global")
				body_lines.append("%s.global_position = _motion_dir" % target_var)
			elif space == "local":
				body_lines.append("# Set target local position")
				body_lines.append("%s.position = %s" % [target_var, vec])
			else:
				body_lines.append("# Set target global position")
				body_lines.append("%s.global_position = %s" % [target_var, vec])

		_:
			body_lines.append("push_warning(\"Motion Actuator: unknown movement method '%s'\")" % movement_method)

	if body_lines.is_empty():
		body_lines.append("pass")
	code_lines.append_array(_indent_lines(body_lines))

	member_vars.append("var _logic_brick_character_use_acceleration: bool = false")
	member_vars.append("var _logic_brick_character_acceleration: float = 1.0")
	member_vars.append("var _logic_brick_character_motion_frame_prepared: bool = false")
	member_vars.append("var _logic_brick_character_motion_active: bool = false")
	member_vars.append("var _logic_brick_character_target_velocity: Vector3 = Vector3.ZERO")
	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}


func _generate_rotation_code(node: Node, chain_name: String) -> Dictionary:
	var x = properties.get("x", 0.0)
	var y = properties.get("y", 0.0)
	var z = properties.get("z", 0.0)
	var space = properties.get("space", "local")

	# Normalize
	if typeof(space) == TYPE_STRING:
		space = space.to_lower()

	var code_lines: Array[String] = []
	var member_vars: Array[String] = []
	var target_var = _append_target_setup(code_lines, member_vars, chain_name)
	var body_lines: Array[String] = []
	var vx = _to_expr(x)
	var vy = _to_expr(y)
	var vz = _to_expr(z)

	if space == "local":
		if not _is_zero(x):
			body_lines.append("%s.rotate_x(deg_to_rad(%s))" % [target_var, vx])
		if not _is_zero(y):
			body_lines.append("%s.rotate_y(deg_to_rad(%s))" % [target_var, vy])
		if not _is_zero(z):
			body_lines.append("%s.rotate_z(deg_to_rad(%s))" % [target_var, vz])
	else:
		if not _is_zero(x) or not _is_zero(y) or not _is_zero(z):
			body_lines.append("%s.global_rotation += Vector3(deg_to_rad(%s), deg_to_rad(%s), deg_to_rad(%s))" % [target_var, vx, vy, vz])

	if body_lines.is_empty():
		body_lines.append("pass")
	code_lines.append_array(_indent_lines(body_lines))

	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}


func _unique_label(chain_name: String) -> String:
	var label = instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	label = label.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	return label if not label.is_empty() else chain_name


func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")
