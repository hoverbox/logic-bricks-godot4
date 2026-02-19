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
		"pos_x": false,         # +X (right)
		"neg_x": false,         # -X (left)
		"pos_y": false,         # +Y (up)
		"neg_y": false,         # -Y (down)
		"pos_z": false,         # +Z (back)
		"neg_z": false,         # -Z (forward)
		"threshold": 0.1,
		"use_local_axes": false,
	}


func get_property_definitions() -> Array:
	return [
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
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Detects if the node is moving in specific directions.\nCheck which directions to monitor.\nActive when any checked direction moves past the threshold.",
		"pos_x": "+X direction (right).",
		"neg_x": "-X direction (left).",
		"pos_y": "+Y direction (up).",
		"neg_y": "-Y direction (down / falling).",
		"pos_z": "+Z direction (back).",
		"neg_z": "-Z direction (forward).",
		"threshold": "Minimum speed to count as moving.\nIncrease if jitter causes false positives.",
		"use_local_axes": "Use the node's local axes instead of world axes.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var threshold = properties.get("threshold", 0.1)
	var use_local = properties.get("use_local_axes", false)
	
	if typeof(threshold) == TYPE_STRING:
		threshold = float(threshold) if str(threshold).is_valid_float() else 0.1
	
	var code_lines: Array[String] = []
	var member_vars: Array[String] = []
	
	var prev_pos_var = "_prev_pos_%s" % chain_name
	member_vars.append("var %s: Vector3 = Vector3.ZERO" % prev_pos_var)
	
	code_lines.append("# Calculate velocity from position change")
	code_lines.append("var _ms_pos = global_position")
	code_lines.append("var _ms_dt = get_physics_process_delta_time() if is_inside_tree() else 0.016")
	code_lines.append("var _ms_vel = (_ms_pos - %s) / _ms_dt if _ms_dt > 0 else Vector3.ZERO" % prev_pos_var)
	code_lines.append("%s = _ms_pos" % prev_pos_var)
	
	if use_local:
		code_lines.append("_ms_vel = global_transform.basis.inverse() * _ms_vel")
	
	# Build conditions from checked directions
	var conditions: Array[String] = []
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
		code_lines.append("var sensor_active = false  # No directions checked")
	else:
		code_lines.append("var sensor_active = %s" % " or ".join(conditions))
	
	return {
		"sensor_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
