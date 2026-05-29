@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Camera Actuator - Control camera behavior
## Camera is found by typed node name
## Modes: Set Active, Smooth Follow (with dead zone and per-axis control)
## The camera maintains its initial offset (distance and angle) from the target
## Rotation follow orbits the camera around the target, keeping it looking at the object


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Camera"


func _initialize_properties() -> void:
	properties = {
		"camera_node_name": "Camera3D",
		"mode": "smooth_follow",        # set_active, smooth_follow
		"follow_speed": 5.0,            # Position interpolation speed
		# Dead zone — camera won't move until target exceeds this distance from offset position
		"dead_zone_x": 0.0,             # 0 = no dead zone (always follow)
		"dead_zone_y": 0.0,
		"dead_zone_z": 0.0,
		# Position follow axes
		"follow_pos_x": true,
		"follow_pos_y": true,
		"follow_pos_z": true,
		# Rotation follow axes (orbits camera around the target)
		"follow_rot_x": false,
		"follow_rot_y": false,
		"follow_rot_z": false,
		# Rotation speed (separate from position speed)
		"rotation_speed": 5.0
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "camera_node_name",
			"type": TYPE_STRING,
			"default": "Camera3D",
			"placeholder": "Camera3D node name"
		},
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Set Active,Smooth Follow",
			"default": "smooth_follow"
		},
		{
			"name": "follow_speed",
			"type": TYPE_FLOAT,
			"default": 5.0
		},
		{
			"name": "dead_zone_x",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "dead_zone_y",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "dead_zone_z",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "follow_pos_x",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "follow_pos_y",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "follow_pos_z",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "follow_rot_x",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "follow_rot_y",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "follow_rot_z",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "rotation_speed",
			"type": TYPE_FLOAT,
			"default": 5.0
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Controls camera behavior.\nModes: Set Active, Smooth Follow.\n\n⚠ Adds an @export in the Inspector — assign your Camera3D there.",
		"mode": "Set Active: switch to this camera\nSmooth Follow: camera follows with smoothing and dead zones",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var camera_node_name = str(properties.get("camera_node_name", "Camera3D")).strip_edges()
	var mode = properties.get("mode", "smooth_follow")

	# Normalize
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")

	var camera_var = "_camera_%s" % chain_name
	var offset_var = "_camera_offset_%s" % chain_name
	var rot_offset_var = "_camera_rot_offset_%s" % chain_name
	var init_flag_var = "_camera_offset_ready_%s" % chain_name
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	# Exported Camera3D variable — user assigns via inspector drag-and-drop
	member_vars.append("var %s: Camera3D = null" % camera_var)
	_append_find_node_helpers(member_vars)

	code_lines.append("var _node_name_%s = \"%s\"" % [chain_name, _gd_string(camera_node_name)])
	code_lines.append("if _node_name_%s.is_empty():" % chain_name)
	code_lines.append("\tpush_warning(\"Camera Actuator: No node name set\")")
	code_lines.append("\t" + camera_var + " = null")
	code_lines.append("elif " + camera_var + " == null or " + camera_var + ".name != _node_name_%s:" % chain_name)
	code_lines.append("\tvar _found_node_%s = _lb_find_node_in_current_scene(_node_name_%s)" % [chain_name, chain_name])
	code_lines.append("\tif _found_node_%s is Camera3D:" % chain_name)
	code_lines.append("\t\t" + camera_var + " = _found_node_%s" % chain_name)
	code_lines.append("\telif _found_node_%s:" % chain_name)
	code_lines.append("\t\tpush_warning(\"Camera Actuator: node '\" + str(_node_name_%s) + \"' is not a Camera3D\")" % chain_name)

	match mode:
		"set_active":
			code_lines.append_array(_generate_set_active_code(camera_var))
		"smooth_follow":
			# Member vars to store initial offsets and a first-frame init flag.
			# The offset is captured lazily on the first execution frame (not in _ready)
			# so that other actuators (e.g. 3rd person camera pivot snap) have already
			# run their _process code and the camera is at its true starting position.
			member_vars.append("var %s: Vector3 = Vector3.ZERO" % offset_var)
			member_vars.append("var %s: Vector3 = Vector3.ZERO" % rot_offset_var)
			member_vars.append("var %s: bool = false" % init_flag_var)

			code_lines.append_array(_generate_smooth_follow_code(camera_var, offset_var, rot_offset_var, init_flag_var, chain_name))
		_:
			code_lines.append("push_warning(\"Camera Actuator: Unknown mode '%s'\")" % mode)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}


func _generate_set_active_code(camera_var: String) -> Array[String]:
	var lines: Array[String] = []

	lines.append("# Set camera as active")
	lines.append("if %s:" % camera_var)
	lines.append("\t%s.make_current()" % camera_var)
	lines.append("else:")
	lines.append("\tpush_warning(\"Camera Actuator: No Camera3D assigned to '%s' — drag one into the inspector\")" % camera_var)

	return lines


func _generate_smooth_follow_code(camera_var: String, offset_var: String, rot_offset_var: String, init_flag_var: String, chain_name: String) -> Array[String]:
	var follow_speed = properties.get("follow_speed", 5.0)
	var follow_pos_x = properties.get("follow_pos_x", true)
	var follow_pos_y = properties.get("follow_pos_y", true)
	var follow_pos_z = properties.get("follow_pos_z", true)
	var follow_rot_x = properties.get("follow_rot_x", false)
	var follow_rot_y = properties.get("follow_rot_y", false)
	var follow_rot_z = properties.get("follow_rot_z", false)
	var rotation_speed = properties.get("rotation_speed", 5.0)
	var dead_zone_x = properties.get("dead_zone_x", 0.0)
	var dead_zone_y = properties.get("dead_zone_y", 0.0)
	var dead_zone_z = properties.get("dead_zone_z", 0.0)

	var has_position = follow_pos_x or follow_pos_y or follow_pos_z
	var has_rotation = follow_rot_x or follow_rot_y or follow_rot_z
	var has_dead_zone = dead_zone_x > 0.0 or dead_zone_y > 0.0 or dead_zone_z > 0.0

	var lines: Array[String] = []

	lines.append("# Smooth follow — camera tracks this object while maintaining offset")
	lines.append("if not %s:" % camera_var)
	lines.append("\tpush_warning(\"Camera Actuator: No Camera3D assigned to '%s' — drag one into the inspector\")" % camera_var)
	lines.append("else:")

	if not has_position and not has_rotation:
		lines.append("\tpass  # No axes enabled")
		return lines

	# Lazy first-frame offset capture (runs once after all _process code has settled,
	# avoiding conflicts with other actuators that reposition nodes in their first frame).
	lines.append("\tif not %s:" % init_flag_var)
	lines.append("\t\t%s = %s.global_position - global_position" % [offset_var, camera_var])
	lines.append("\t\t%s = %s.global_rotation - global_rotation" % [rot_offset_var, camera_var])
	lines.append("\t\t%s = true" % init_flag_var)
	lines.append("\t\treturn")

	lines.append("\tvar _cam_pos = %s.global_position" % camera_var)
	lines.append("\t")

	# Build the rotation basis used to rotate the offset around the target
	# Start with identity, then apply each followed rotation axis from the target
	if has_rotation:
		lines.append("\t# Build rotation basis from followed axes of target")
		lines.append("\tvar _rot_basis = Basis.IDENTITY")

		if follow_rot_x:
			lines.append("\t_rot_basis = _rot_basis.rotated(Vector3.RIGHT, global_rotation.x)")
		if follow_rot_y:
			lines.append("\t_rot_basis = _rot_basis.rotated(Vector3.UP, global_rotation.y)")
		if follow_rot_z:
			lines.append("\t_rot_basis = _rot_basis.rotated(Vector3.FORWARD, global_rotation.z)")

		lines.append("\t")
		lines.append("\t# Desired position = target + rotated offset (camera orbits around target)")
		lines.append("\tvar _desired_pos = global_position + _rot_basis * %s" % offset_var)
	else:
		lines.append("\t# Desired position = target + fixed offset")
		lines.append("\tvar _desired_pos = global_position + %s" % offset_var)

	if has_position:
		lines.append("\tvar _diff = _desired_pos - _cam_pos")

		if has_dead_zone:
			lines.append("\t")
			lines.append("\t# Dead zone — only follow when target exceeds threshold from offset position")
			lines.append("\tvar _follow_target = _cam_pos")

			if follow_pos_x:
				if dead_zone_x > 0.0:
					lines.append("\tif abs(_diff.x) > %.3f:" % dead_zone_x)
					lines.append("\t\tvar _overshoot_x = _diff.x - sign(_diff.x) * %.3f" % dead_zone_x)
					lines.append("\t\t_follow_target.x = _cam_pos.x + _overshoot_x")
				else:
					lines.append("\t_follow_target.x = _desired_pos.x")

			if follow_pos_y:
				if dead_zone_y > 0.0:
					lines.append("\tif abs(_diff.y) > %.3f:" % dead_zone_y)
					lines.append("\t\tvar _overshoot_y = _diff.y - sign(_diff.y) * %.3f" % dead_zone_y)
					lines.append("\t\t_follow_target.y = _cam_pos.y + _overshoot_y")
				else:
					lines.append("\t_follow_target.y = _desired_pos.y")

			if follow_pos_z:
				if dead_zone_z > 0.0:
					lines.append("\tif abs(_diff.z) > %.3f:" % dead_zone_z)
					lines.append("\t\tvar _overshoot_z = _diff.z - sign(_diff.z) * %.3f" % dead_zone_z)
					lines.append("\t\t_follow_target.z = _cam_pos.z + _overshoot_z")
				else:
					lines.append("\t_follow_target.z = _desired_pos.z")

			lines.append("\t")
			lines.append("\t# Smoothly interpolate toward follow target")
			lines.append("\tvar _new_pos = _cam_pos")

			if follow_pos_x:
				lines.append("\t_new_pos.x = lerp(_cam_pos.x, _follow_target.x, %.2f * _delta)" % follow_speed)
			if follow_pos_y:
				lines.append("\t_new_pos.y = lerp(_cam_pos.y, _follow_target.y, %.2f * _delta)" % follow_speed)
			if follow_pos_z:
				lines.append("\t_new_pos.z = lerp(_cam_pos.z, _follow_target.z, %.2f * _delta)" % follow_speed)

		else:
			# No dead zone — simple smooth follow maintaining offset
			lines.append("\t")
			lines.append("\t# Smoothly interpolate position (maintaining offset)")
			lines.append("\tvar _new_pos = _cam_pos")

			if follow_pos_x:
				lines.append("\t_new_pos.x = lerp(_cam_pos.x, _desired_pos.x, %.2f * _delta)" % follow_speed)
			if follow_pos_y:
				lines.append("\t_new_pos.y = lerp(_cam_pos.y, _desired_pos.y, %.2f * _delta)" % follow_speed)
			if follow_pos_z:
				lines.append("\t_new_pos.z = lerp(_cam_pos.z, _desired_pos.z, %.2f * _delta)" % follow_speed)

		lines.append("\t%s.global_position = _new_pos" % camera_var)

	if has_rotation:
		lines.append("\t")
		lines.append("\t# Smoothly rotate camera to look at target from the new orbit position")
		lines.append("\t# Desired rotation = target rotation + initial rotation offset")
		lines.append("\tvar _desired_rot = global_rotation + %s" % rot_offset_var)
		lines.append("\tvar _cam_rot = %s.global_rotation" % camera_var)
		lines.append("\tvar _new_rot = _cam_rot")

		if follow_rot_x:
			lines.append("\t_new_rot.x = lerp_angle(_cam_rot.x, _desired_rot.x, %.2f * _delta)" % rotation_speed)
		if follow_rot_y:
			lines.append("\t_new_rot.y = lerp_angle(_cam_rot.y, _desired_rot.y, %.2f * _delta)" % rotation_speed)
		if follow_rot_z:
			lines.append("\t_new_rot.z = lerp_angle(_cam_rot.z, _desired_rot.z, %.2f * _delta)" % rotation_speed)

		lines.append("\t%s.global_rotation = _new_rot" % camera_var)

	return lines


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
