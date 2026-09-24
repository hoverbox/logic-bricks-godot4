@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Smooth Follow Camera Actuator
## Camera smoothly follows this node while maintaining its initial offset.
## Supports per-axis position and rotation follow, dead zones, and independent speeds.
## Type your Camera3D node name.
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
		"camera_node_name": "Camera3D",
		"target_node_name": "",
		"positioning": "Keep Offset",
		"position_offset_amount": 3.0,
		"follow_speed": 5.0,
		"dead_zone_x": 0.0,
		"dead_zone_y": 0.0,
		"dead_zone_z": 0.0,
		"follow_pos_x": true,
		"follow_pos_y": true,
		"follow_pos_z": true,
		"rotation_source_node_name": "",
		"follow_rot_x": false,
		"follow_rot_y": false,
		"follow_rot_z": false,
		"rotation_speed": 5.0,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "camera_node_name", "required": true, "required_label": "a Camera3D node name",
			"type": TYPE_STRING,
			"default": "Camera3D",
			"placeholder": "Camera3D node name",
			"node_reference": true,
			"accepted_node_types": ["Camera3D"],
			"node_picker_scope": "scene"
		},
		{
			"name": "target_node_name", "required": true, "required_label": "a Node3D to follow",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Node3D to follow",
			"node_reference": true,
			"accepted_node_types": ["Node3D"],
			"node_picker_scope": "scene"
		},
		{
			"name": "positioning",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Keep Offset,Left,Center,Right",
			"default": "Keep Offset"
		},
		{
			"name": "position_offset_amount",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1000.0,0.1",
			"default": 3.0
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
			"name": "rotation_source_node_name",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Rotation source node name (blank = self)"
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


func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings: Array[String] = []
	if node is Camera3D:
		if str(properties.get("target_node_name", "")).strip_edges().is_empty():
			warnings.append("Select or enter a Node3D to follow.")
	else:
		if str(properties.get("camera_node_name", "")).strip_edges().is_empty():
			warnings.append("Select or enter a Camera3D node name.")
	return warnings


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Smoothly follows this node with the assigned Camera3D,\nmaintaining the camera's initial offset from the target.\n\nPosition follow: camera tracks the node's position per axis.\nRotation follow: camera orbits the node, keeping it in frame.\nDead zone: camera only moves once the node exceeds the threshold.\n\n⚠ Adds an @export in the Inspector — assign your Camera3D there.",
		"camera_node_name": "Camera3D to move when this brick is on a character or other object.\nType a name, Ctrl-drag a node, or use the picker.",
		"target_node_name": "Node3D this Camera3D should follow when the brick is placed directly on a Camera3D.\nType a node name, pick one from the dropdown, or enter the name of a Logic Bricks String variable. If a String variable is used, changing that variable at runtime retargets the camera.",
		"positioning": "Horizontal framing relative to the followed node.\nKeep Offset preserves the camera's captured X offset.\nLeft places the camera to the left by Offset Amount.\nCenter aligns the camera's X with the target.\nRight places the camera to the right by Offset Amount.",
		"position_offset_amount": "Horizontal distance used by Left or Right positioning. Center ignores this value.",
		"follow_speed": "How quickly the camera interpolates toward the target position.\nHigher = snappier. Lower = more lag.",
		"dead_zone_x": "X distance the target must move before the camera follows.\n0 = always follow.",
		"dead_zone_y": "Y distance the target must move before the camera follows.\n0 = always follow.",
		"dead_zone_z": "Z distance the target must move before the camera follows.\n0 = always follow.",
		"follow_pos_x": "Follow the target's X position.",
		"follow_pos_y": "Follow the target's Y position.",
		"follow_pos_z": "Follow the target's Z position.",
		"rotation_source_node_name": "Optional Node3D name to read rotation from.\nLeave blank to use this/root node.\nUse this when a child mesh rotates separately, such as with Look Toward Input.",
		"follow_rot_x": "Orbit the camera around the target's X rotation axis.",
		"follow_rot_y": "Orbit the camera around the target's Y rotation axis.",
		"follow_rot_z": "Orbit the camera around the target's Z rotation axis.",
		"rotation_speed": "How quickly the camera interpolates toward the target rotation.\nIndependent from follow_speed.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var camera_mode := node is Camera3D
	var camera_node_name = str(properties.get("camera_node_name", "Camera3D")).strip_edges()
	var target_node_name = str(properties.get("target_node_name", "")).strip_edges()
	var rotation_source_node_name = str(properties.get("rotation_source_node_name", "")).strip_edges()
	var positioning := str(properties.get("positioning", "Keep Offset")).strip_edges().to_lower()
	var position_offset_amount := abs(float(properties.get("position_offset_amount", 3.0)))
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

	# instance_name contributes to generated member names, so it must always be a valid GDScript identifier.
	var _base := _safe_identifier(instance_name)
	if _base.is_empty():
		_base = "smooth_follow"
	var camera_var     = _base
	var offset_var     = "_%s_offset"   % _base
	var rot_offset_var = "_%s_rot"      % _base
	var init_flag_var  = "_%s_ready"    % _base

	var member_vars: Array[String] = []
	_append_find_node_helpers(member_vars)
	var target_uses_string_variable := camera_mode and _node_has_string_variable(node, target_node_name)
	if camera_mode:
		if not target_uses_string_variable:
			member_vars.append("@export var %s_target_node_name: String = \"%s\"" % [_base, _gd_string(target_node_name)])
		member_vars.append("var %s_target: Node3D = null" % _base)
		member_vars.append("var %s_last_target_name: String = \"\"" % _base)
	else:
		member_vars.append("var %s: Camera3D = null" % camera_var)
	member_vars.append("var %s: Vector3 = Vector3.ZERO" % offset_var)
	member_vars.append("var %s: Vector3 = Vector3.ZERO" % rot_offset_var)
	member_vars.append("var %s: bool = false" % init_flag_var)

	var lines: Array[String] = []
	lines.append("# Smooth Follow Camera — maintains initial offset")
	if camera_mode:
		var target_name_expr := ("str(%s)" % target_node_name) if target_uses_string_variable else ("%s_target_node_name" % _base)
		lines.append("var _follow_name_%s: String = %s" % [chain_name, target_name_expr])
		lines.append("if _follow_name_%s != %s_last_target_name:" % [chain_name, _base])
		lines.append("\t%s_last_target_name = _follow_name_%s" % [_base, chain_name])
		lines.append("\t%s_target = null" % _base)
		lines.append("\t%s = false" % init_flag_var)
		lines.append("if %s_target == null and not _follow_name_%s.is_empty():" % [_base, chain_name])
		lines.append("\tvar _found_target_%s = _lb_find_node_in_current_scene(_follow_name_%s)" % [chain_name, chain_name])
		lines.append("\tif _found_target_%s is Node3D and _found_target_%s != self:" % [chain_name, chain_name])
		lines.append("\t\t%s_target = _found_target_%s" % [_base, chain_name])
		lines.append("if not %s_target:" % _base)
		lines.append("\tpush_warning(\"Smooth Follow Camera: Follow Target '\" + _follow_name_%s + \"' was not found or is not a Node3D\")" % chain_name)
		lines.append("else:")
	else:
		lines.append("var _node_name_%s = \"%s\"" % [chain_name, _gd_string(camera_node_name)])
		lines.append("if _node_name_%s.is_empty():" % chain_name)
		lines.append("\tpush_warning(\"Smooth Follow Camera: No node name set\")")
		lines.append("\t" + camera_var + " = null")
		lines.append("elif " + camera_var + " == null or " + camera_var + ".name != _node_name_%s:" % chain_name)
		lines.append("\tvar _found_node_%s = _lb_find_node_in_current_scene(_node_name_%s)" % [chain_name, chain_name])
		lines.append("\tif _found_node_%s is Camera3D:" % chain_name)
		lines.append("\t\t" + camera_var + " = _found_node_%s" % chain_name)
		lines.append("\telif _found_node_%s:" % chain_name)
		lines.append("\t\tpush_warning(\"Smooth Follow Camera: node '\" + str(_node_name_%s) + \"' is not a Camera3D\")" % chain_name)
		lines.append("if not %s:" % camera_var)
		lines.append("\tpush_warning(\"Smooth Follow Camera: No Camera3D assigned\")")
		lines.append("else:")

	var generated_camera: String = "self" if camera_mode else str(camera_var)
	var generated_target: String = ("%s_target" % _base) if camera_mode else "self"

	if not has_position and not has_rotation:
		lines.append("\tpass  # No axes enabled — tick at least one Follow Pos or Follow Rot axis")
		return {"actuator_code": "\n".join(lines), "member_vars": member_vars}

	if has_rotation:
		lines.append("\t# Optional rotation source — blank uses this/root node")
		lines.append("\tvar _rot_source_name_%s = \"%s\"" % [chain_name, _gd_string(rotation_source_node_name)])
		lines.append("\tvar _rot_source: Node3D = %s" % generated_target)
		lines.append("\tif not _rot_source_name_%s.is_empty():" % chain_name)
		lines.append("\t\tvar _found_rot_source_%s = _lb_find_node_in_current_scene(_rot_source_name_%s)" % [chain_name, chain_name])
		lines.append("\t\tif _found_rot_source_%s is Node3D:" % chain_name)
		lines.append("\t\t\t_rot_source = _found_rot_source_%s" % chain_name)
		lines.append("\t\telif _found_rot_source_%s:" % chain_name)
		lines.append("\t\t\tpush_warning(\"Smooth Follow Camera: rotation source '\" + str(_rot_source_name_%s) + \"' is not a Node3D\")" % chain_name)
		lines.append("\t\telse:")
		lines.append("\t\t\tpush_warning(\"Smooth Follow Camera: rotation source '\" + str(_rot_source_name_%s) + \"' was not found\")" % chain_name)
		lines.append("\t")

	# Sample the followed target through Godot physics interpolation when available.
	# This keeps a render-frame camera smooth while CharacterBody movement stays in physics ticks.
	lines.append("\tvar _follow_transform_%s: Transform3D = %s.call(\"get_global_transform_interpolated\") if %s.has_method(\"get_global_transform_interpolated\") else %s.global_transform" % [chain_name, generated_target, generated_target, generated_target])
	lines.append("\tvar _follow_pos_%s: Vector3 = _follow_transform_%s.origin" % [chain_name, chain_name])

	# Lazy first-frame offset capture
	lines.append("\tif not %s:" % init_flag_var)
	lines.append("\t\t%s = %s.global_position - _follow_pos_%s" % [offset_var, generated_camera, chain_name])
	if positioning == "left":
		lines.append("\t\t%s.x = -%.6f" % [offset_var, position_offset_amount])
	elif positioning == "center":
		lines.append("\t\t%s.x = 0.0" % offset_var)
	elif positioning == "right":
		lines.append("\t\t%s.x = %.6f" % [offset_var, position_offset_amount])
	if has_rotation:
		lines.append("\t\t%s = %s.global_rotation - _rot_source.global_rotation" % [rot_offset_var, generated_camera])
	else:
		lines.append("\t\t%s = %s.global_rotation - %s.global_rotation" % [rot_offset_var, generated_camera, generated_target])
	lines.append("\t\t%s = true" % init_flag_var)
	lines.append("\t\treturn")

	lines.append("\tvar _cam_pos = %s.global_position" % generated_camera)
	lines.append("\t")

	# Build rotation basis for orbit mode
	if has_rotation:
		lines.append("\t# Build rotation basis from followed axes of rotation source")
		lines.append("\tvar _rot_basis = Basis.IDENTITY")
		if follow_rot_x:
			lines.append("\t_rot_basis = _rot_basis.rotated(Vector3.RIGHT,   _rot_source.global_rotation.x)")
		if follow_rot_y:
			lines.append("\t_rot_basis = _rot_basis.rotated(Vector3.UP,      _rot_source.global_rotation.y)")
		if follow_rot_z:
			lines.append("\t_rot_basis = _rot_basis.rotated(Vector3.FORWARD, _rot_source.global_rotation.z)")
		lines.append("\t")
		lines.append("\tvar _desired_pos = _follow_pos_%s + _rot_basis * %s" % [chain_name, offset_var])
	else:
		lines.append("\tvar _desired_pos = _follow_pos_%s + %s" % [chain_name, offset_var])

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

		lines.append("\t%s.global_position = _new_pos" % generated_camera)

	if has_rotation:
		lines.append("\t")
		lines.append("\t# Smoothly rotate camera toward rotation source + initial offset")
		lines.append("\tvar _desired_rot = _rot_source.global_rotation + %s" % rot_offset_var)
		lines.append("\tvar _cam_rot = %s.global_rotation" % generated_camera)
		lines.append("\tvar _new_rot = _cam_rot")
		if follow_rot_x:
			lines.append("\t_new_rot.x = lerp_angle(_cam_rot.x, _desired_rot.x, %.2f * _delta)" % rotation_speed)
		if follow_rot_y:
			lines.append("\t_new_rot.y = lerp_angle(_cam_rot.y, _desired_rot.y, %.2f * _delta)" % rotation_speed)
		if follow_rot_z:
			lines.append("\t_new_rot.z = lerp_angle(_cam_rot.z, _desired_rot.z, %.2f * _delta)" % rotation_speed)
		lines.append("\t%s.global_rotation = _new_rot" % generated_camera)

	return {
		"actuator_code": "\n".join(lines),
		"member_vars": member_vars
	}




func _node_has_string_variable(node: Node, variable_name: String) -> bool:
	if node == null or variable_name.is_empty() or not node.has_meta("logic_bricks_variables"):
		return false
	var variables_data = node.get_meta("logic_bricks_variables")
	if not (variables_data is Array):
		return false
	for var_data in variables_data:
		if var_data is Dictionary and str(var_data.get("name", "")).strip_edges() == variable_name:
			var var_type := str(var_data.get("type", "")).to_lower()
			return var_type in ["string", "str"]
	return false


func _safe_identifier(value: String) -> String:
	var sanitized := value.strip_edges().to_lower().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	sanitized = regex.sub(sanitized, "", true)
	if sanitized.is_empty():
		return ""
	if sanitized.substr(0, 1).is_valid_int():
		sanitized = "brick_" + sanitized
	return sanitized
