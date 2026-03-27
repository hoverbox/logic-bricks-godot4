@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Smooth Follow Camera Actuator
## Camera smoothly follows this node while maintaining its initial offset.
## Supports per-axis position and rotation follow, dead zones, and independent speeds.
## Assign your Camera3D via the @export in the Inspector.
##
## The offset is captured lazily on the first execution frame (not in _ready) so
## that other actuators which reposition nodes in their first frame have already
## settled before the offset is locked in.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Smooth Follow Camera"


func _initialize_properties() -> void:
	properties = {
		"follow_speed": 5.0,
		"dead_zone_x": 0.0,
		"dead_zone_y": 0.0,
		"dead_zone_z": 0.0,
		"follow_pos_x": true,
		"follow_pos_y": true,
		"follow_pos_z": true,
		"follow_rot_x": false,
		"follow_rot_y": false,
		"follow_rot_z": false,
		"rotation_speed": 5.0,
	}


func get_property_definitions() -> Array:
	return [
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
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Smoothly follows this node with the assigned Camera3D,\nmaintaining the camera's initial offset from the target.\n\nPosition follow: camera tracks the node's position per axis.\nRotation follow: camera orbits the node, keeping it in frame.\nDead zone: camera only moves once the node exceeds the threshold.\n\n⚠ Adds an @export in the Inspector — assign your Camera3D there.",
		"follow_speed": "How quickly the camera interpolates toward the target position.\nHigher = snappier. Lower = more lag.",
		"dead_zone_x": "X distance the target must move before the camera follows.\n0 = always follow.",
		"dead_zone_y": "Y distance the target must move before the camera follows.\n0 = always follow.",
		"dead_zone_z": "Z distance the target must move before the camera follows.\n0 = always follow.",
		"follow_pos_x": "Follow the target's X position.",
		"follow_pos_y": "Follow the target's Y position.",
		"follow_pos_z": "Follow the target's Z position.",
		"follow_rot_x": "Orbit the camera around the target's X rotation axis.",
		"follow_rot_y": "Orbit the camera around the target's Y rotation axis.",
		"follow_rot_z": "Orbit the camera around the target's Z rotation axis.",
		"rotation_speed": "How quickly the camera interpolates toward the target rotation.\nIndependent from follow_speed.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var follow_speed   = properties.get("follow_speed",   5.0)
	var follow_pos_x   = properties.get("follow_pos_x",   true)
	var follow_pos_y   = properties.get("follow_pos_y",   true)
	var follow_pos_z   = properties.get("follow_pos_z",   true)
	var follow_rot_x   = properties.get("follow_rot_x",   false)
	var follow_rot_y   = properties.get("follow_rot_y",   false)
	var follow_rot_z   = properties.get("follow_rot_z",   false)
	var rotation_speed = properties.get("rotation_speed", 5.0)
	var dead_zone_x    = properties.get("dead_zone_x",    0.0)
	var dead_zone_y    = properties.get("dead_zone_y",    0.0)
	var dead_zone_z    = properties.get("dead_zone_z",    0.0)

	var has_position = follow_pos_x or follow_pos_y or follow_pos_z
	var has_rotation = follow_rot_x or follow_rot_y or follow_rot_z
	var has_dead_zone = dead_zone_x > 0.0 or dead_zone_y > 0.0 or dead_zone_z > 0.0

	# instance_name IS the variable name when set (e.g. "player_cam" -> @export var player_cam).
	# Falls back to a descriptive default when unnamed.
	var _base = instance_name.to_lower().replace(" ", "_") if not instance_name.is_empty() else "smooth_follow"
	var camera_var     = _base
	var offset_var     = "_%s_offset"   % _base
	var rot_offset_var = "_%s_rot"      % _base
	var init_flag_var  = "_%s_ready"    % _base

	var member_vars: Array[String] = []
	member_vars.append("@export var %s: Camera3D" % camera_var)
	member_vars.append("var %s: Vector3 = Vector3.ZERO" % offset_var)
	member_vars.append("var %s: Vector3 = Vector3.ZERO" % rot_offset_var)
	member_vars.append("var %s: bool = false" % init_flag_var)

	var lines: Array[String] = []

	lines.append("# Smooth Follow Camera — tracks this node while maintaining initial offset")
	lines.append("if not %s:" % camera_var)
	lines.append("\tpush_warning(\"Smooth Follow Camera: No Camera3D assigned to '%s' — drag one into the inspector\")" % camera_var)
	lines.append("else:")

	if not has_position and not has_rotation:
		lines.append("\tpass  # No axes enabled — tick at least one Follow Pos or Follow Rot axis")
		return {"actuator_code": "\n".join(lines), "member_vars": member_vars}

	# Lazy first-frame offset capture
	lines.append("\tif not %s:" % init_flag_var)
	lines.append("\t\t%s = %s.global_position - global_position" % [offset_var, camera_var])
	lines.append("\t\t%s = %s.global_rotation - global_rotation" % [rot_offset_var, camera_var])
	lines.append("\t\t%s = true" % init_flag_var)
	lines.append("\t\treturn")

	lines.append("\tvar _cam_pos = %s.global_position" % camera_var)
	lines.append("\t")

	# Build rotation basis for orbit mode
	if has_rotation:
		lines.append("\t# Build rotation basis from followed axes of target")
		lines.append("\tvar _rot_basis = Basis.IDENTITY")
		if follow_rot_x:
			lines.append("\t_rot_basis = _rot_basis.rotated(Vector3.RIGHT,   global_rotation.x)")
		if follow_rot_y:
			lines.append("\t_rot_basis = _rot_basis.rotated(Vector3.UP,      global_rotation.y)")
		if follow_rot_z:
			lines.append("\t_rot_basis = _rot_basis.rotated(Vector3.FORWARD, global_rotation.z)")
		lines.append("\t")
		lines.append("\tvar _desired_pos = global_position + _rot_basis * %s" % offset_var)
	else:
		lines.append("\tvar _desired_pos = global_position + %s" % offset_var)

	if has_position:
		lines.append("\tvar _diff = _desired_pos - _cam_pos")

		if has_dead_zone:
			lines.append("\t")
			lines.append("\t# Dead zone — only follow once target exceeds threshold from offset position")
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
			lines.append("\tvar _new_pos = _cam_pos")
			if follow_pos_x:
				lines.append("\t_new_pos.x = lerp(_cam_pos.x, _follow_target.x, %.2f * _delta)" % follow_speed)
			if follow_pos_y:
				lines.append("\t_new_pos.y = lerp(_cam_pos.y, _follow_target.y, %.2f * _delta)" % follow_speed)
			if follow_pos_z:
				lines.append("\t_new_pos.z = lerp(_cam_pos.z, _follow_target.z, %.2f * _delta)" % follow_speed)

		else:
			lines.append("\t")
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
		lines.append("\t# Smoothly rotate camera toward target rotation + initial offset")
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

	return {
		"actuator_code": "\n".join(lines),
		"member_vars": member_vars
	}
