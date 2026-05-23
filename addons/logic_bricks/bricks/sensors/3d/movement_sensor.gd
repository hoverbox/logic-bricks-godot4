@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Movement Sensor - Detect object movement in specific directions
## Check which directions to monitor. Active when any checked direction moves past the threshold.


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Movement"


func _initialize_properties() -> void:
	properties = {
		"all_axis": false,          # All axes (any movement)
		"pos_x": false,         # +X (right)
		"neg_x": false,         # -X (left)
		"pos_y": false,         # +Y (up)
		"neg_y": false,         # -Y (down)
		"pos_z": false,         # +Z (back)
		"neg_z": false,         # -Z (forward)
		"threshold": 0.1,
		"use_local_axes": false,
		"ignore_platform_motion": true,  # Ignore moving platform carry/inherited velocity when detecting movement
		"invert": false,        # Invert the result
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "all_axis",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "pos_x",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "neg_x",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "pos_y",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "neg_y",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "pos_z",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "neg_z",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "threshold",
			"type": TYPE_FLOAT,
			"default": 0.1
		},
		{
			"name": "use_local_axes",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "ignore_platform_motion",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "invert",
			"type": TYPE_BOOL,
			"default": false
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Detects if the node is moving in specific directions.\nCheck which directions to monitor.\nActive when any checked direction moves past the threshold.",
		"all_axis": "Any axis (detects movement in any direction).",
		"pos_x": "+X direction (right).",
		"neg_x": "-X direction (left).",
		"pos_y": "+Y direction (up).",
		"neg_y": "-Y direction (down / falling).",
		"pos_z": "+Z direction (back).",
		"neg_z": "-Z direction (forward).",
		"threshold": "Minimum speed to count as moving.\nFor CharacterBody3D this checks body velocity, which is stable between physics ticks.",
		"use_local_axes": "Use the node's local axes instead of world axes.",
		"invert": "Invert the result.\nActive when NOT moving in the checked directions.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var threshold = properties.get("threshold", 0.1)
	var use_local = properties.get("use_local_axes", false)
	var invert = properties.get("invert", false)
	var all_axis = properties.get("all_axis", false)
	var ignore_platform_motion = properties.get("ignore_platform_motion", true)

	if typeof(threshold) == TYPE_STRING:
		threshold = float(threshold) if str(threshold).is_valid_float() else 0.1

	var code_lines: Array[String] = []
	var member_vars: Array[String] = []

	var prev_pos_var = "_prev_pos_%s" % chain_name
	member_vars.append("var %s: Vector3 = Vector3.ZERO" % prev_pos_var)
	if ignore_platform_motion:
		# Character/Gravity actuators write these so sensors can ignore external carry.
		# When no platform actuator is present they remain zero.
		member_vars.append("var _logic_brick_external_motion_delta: Vector3 = Vector3.ZERO")
		member_vars.append("var _logic_brick_external_motion_total: Vector3 = Vector3.ZERO")
		member_vars.append("var _inherited_platform_velocity: Vector3 = Vector3.ZERO")

	if node is CharacterBody3D:
		code_lines.append("# CharacterBody3D: use current body velocity instead of position delta")
		code_lines.append("# This stays stable when animation chains run in _process between physics ticks")
		code_lines.append("var _ms_vel = velocity")
		if ignore_platform_motion:
			code_lines.append("# Remove airborne inherited platform momentum; grounded platform carry is positional, not body velocity")
			code_lines.append("_ms_vel -= _inherited_platform_velocity")
	else:
		code_lines.append("# Calculate velocity from position change")
		if ignore_platform_motion:
			code_lines.append("# Use a platform-corrected position so moving platforms do not count as self movement")
			code_lines.append("var _ms_pos = global_position - _logic_brick_external_motion_total")
		else:
			code_lines.append("var _ms_pos = global_position")
		code_lines.append("var _ms_dt = get_physics_process_delta_time() if is_inside_tree() else 0.016")
		code_lines.append("var _ms_motion_delta = _ms_pos - %s" % prev_pos_var)
		code_lines.append("var _ms_vel = _ms_motion_delta / _ms_dt if _ms_dt > 0 else Vector3.ZERO")
		code_lines.append("%s = _ms_pos" % prev_pos_var)

	if use_local:
		code_lines.append("# Convert to local horizontal movement without letting jump/fall velocity bleed into X/Z")
		code_lines.append("var _ms_right = global_transform.basis.x")
		code_lines.append("var _ms_forward = global_transform.basis.z")
		code_lines.append("_ms_right.y = 0.0")
		code_lines.append("_ms_forward.y = 0.0")
		code_lines.append("_ms_right = _ms_right.normalized() if _ms_right.length_squared() > 0.000001 else Vector3.RIGHT")
		code_lines.append("_ms_forward = _ms_forward.normalized() if _ms_forward.length_squared() > 0.000001 else Vector3.FORWARD")
		# Only preserve the Y component if a Y axis is actually being monitored.
		# When only X/Z are checked, zeroing Y prevents jump/fall velocity from
		# bleeding into the sensor result (e.g. triggering Run while airborne).
		var y_needed = all_axis or properties.get("pos_y", false) or properties.get("neg_y", false)
		var y_component = "_ms_vel.y" if y_needed else "0.0"
		code_lines.append("_ms_vel = Vector3(_ms_vel.dot(_ms_right), %s, _ms_vel.dot(_ms_forward))" % y_component)

	# Build conditions from checked directions
	var conditions: Array[String] = []

	if all_axis:
		# Any movement on any axis past the threshold
		conditions.append("_ms_vel.x > %.3f" % threshold)
		conditions.append("_ms_vel.x < -%.3f" % threshold)
		conditions.append("_ms_vel.y > %.3f" % threshold)
		conditions.append("_ms_vel.y < -%.3f" % threshold)
		conditions.append("_ms_vel.z > %.3f" % threshold)
		conditions.append("_ms_vel.z < -%.3f" % threshold)
	else:
		if properties.get("pos_x", false):
			conditions.append("_ms_vel.x > %.3f" % threshold)
		if properties.get("neg_x", false):
			conditions.append("_ms_vel.x < -%.3f" % threshold)
		if properties.get("pos_y", false):
			conditions.append("_ms_vel.y > %.3f" % threshold)
		if properties.get("neg_y", false):
			conditions.append("_ms_vel.y < -%.3f" % threshold)
		if properties.get("pos_z", false):
			conditions.append("_ms_vel.z > %.3f" % threshold)
		if properties.get("neg_z", false):
			conditions.append("_ms_vel.z < -%.3f" % threshold)

	if conditions.is_empty():
		code_lines.append("var sensor_active = %s  # No directions checked" % ("true" if invert else "false"))
	else:
		var joined = " or ".join(conditions)
		if invert:
			code_lines.append("var sensor_active = not (%s)" % joined)
		else:
			code_lines.append("var sensor_active = %s" % joined)

	return {
		"sensor_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
