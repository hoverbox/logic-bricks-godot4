@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Movement Detected Trigger - Detect 2D object movement in specific directions.
## Check which directions to monitor. Active when any checked direction moves past the threshold.


func get_brick_info() -> Dictionary:
	return {
		"class": "Movement2DSensor",
		"name": "Movement Detected",
		"type": "sensor",
		"category": "",
		"domain": "2d",
		"menu_order": 110,
	}


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Movement Detected"


func _initialize_properties() -> void:
	properties = {
		"all_axis": false,          # Any movement on X or Y
		"pos_x": false,             # +X / right
		"neg_x": false,             # -X / left
		"pos_y": false,             # +Y / down in Godot 2D
		"neg_y": false,             # -Y / up in Godot 2D
		"threshold": 0.1,
		"use_local_axes": false,
		"ignore_platform_motion": true,
		"invert": false,
	}


func get_property_definitions() -> Array:
	return [
		{"name": "all_axis", "type": TYPE_BOOL, "default": false},
		{"name": "pos_x", "type": TYPE_BOOL, "default": false},
		{"name": "neg_x", "type": TYPE_BOOL, "default": false},
		{"name": "pos_y", "type": TYPE_BOOL, "default": false},
		{"name": "neg_y", "type": TYPE_BOOL, "default": false},
		{"name": "threshold", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,10000,0.01", "default": 0.1},
		{"name": "use_local_axes", "type": TYPE_BOOL, "default": false},
		{"name": "ignore_platform_motion", "type": TYPE_BOOL, "default": true},
		{"name": "invert", "type": TYPE_BOOL, "default": false},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Detects if a 2D node is moving in specific directions.\nCheck which directions to monitor.\nActive when any checked direction moves past the threshold.",
		"all_axis": "Any axis. Detects movement in any 2D direction.",
		"pos_x": "+X direction, usually right.",
		"neg_x": "-X direction, usually left.",
		"pos_y": "+Y direction. In Godot 2D this is usually down / falling.",
		"neg_y": "-Y direction. In Godot 2D this is usually up / jumping.",
		"threshold": "Minimum speed to count as moving (positive magnitude; direction supplies the sign). For CharacterBody2D this checks body velocity.",
		"use_local_axes": "Use the node's local rotated 2D axes instead of world axes.",
		"ignore_platform_motion": "Ignore inherited moving-platform velocity when detecting CharacterBody2D movement.",
		"invert": "Invert the result. Active when NOT moving in the checked directions.",
	}


## Member variables this brick declares that keep their value when the node
## changes state (other state-specific variables are reset on state entry).
## Read from the Character 2D brick's runtime state.
func get_kept_member_vars() -> PackedStringArray:
	return PackedStringArray(["_inherited_platform_velocity*"])


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var use_local = properties.get("use_local_axes", false)
	var invert = properties.get("invert", false)
	var all_axis = properties.get("all_axis", false)
	var ignore_platform_motion = properties.get("ignore_platform_motion", true)

	# Direction checkboxes supply the sign; thresholds are speed magnitudes.
	# A variable/math threshold is read into _ms_threshold each time the brick runs.
	var threshold_number = _literal_number("threshold", 0.1)
	var threshold := "_ms_threshold"
	if threshold_number != null:
		threshold_number = absf(threshold_number)
		if not is_finite(threshold_number):
			threshold_number = 0.1
		threshold = "%.3f" % threshold_number

	var safe_chain_name = chain_name.replace(" ", "_").replace("-", "_")
	var prev_pos_var = "_prev_pos_2d_%s" % safe_chain_name
	var prev_ready_var = "_prev_pos_2d_ready_%s" % safe_chain_name

	var member_vars: Array[String] = []
	member_vars.append("var %s: Vector2 = Vector2.ZERO" % prev_pos_var)
	member_vars.append("var %s: bool = false" % prev_ready_var)
	if ignore_platform_motion:
		member_vars.append("var _inherited_platform_velocity_2d: Vector2 = Vector2.ZERO")

	var code_lines: Array[String] = []
	code_lines.append("var _ms_vel := Vector2.ZERO")
	code_lines.append("var _ms_velocity_prop = get(\"velocity\")")
	code_lines.append("var _ms_linear_velocity_prop = get(\"linear_velocity\")")
	code_lines.append("if _ms_velocity_prop is Vector2:")
	code_lines.append("\t_ms_vel = _ms_velocity_prop")
	if ignore_platform_motion:
		code_lines.append("\t_ms_vel -= _inherited_platform_velocity_2d")
	code_lines.append("elif _ms_linear_velocity_prop is Vector2:")
	code_lines.append("\t_ms_vel = _ms_linear_velocity_prop")
	code_lines.append("elif self is Node2D:")
	code_lines.append("\tvar _ms_pos = global_position")
	code_lines.append("\tif not %s:" % prev_ready_var)
	code_lines.append("\t\t%s = _ms_pos" % prev_pos_var)
	code_lines.append("\t\t%s = true" % prev_ready_var)
	code_lines.append("\tvar _ms_dt = get_physics_process_delta_time() if is_inside_tree() else 0.016")
	code_lines.append("\tvar _ms_motion_delta = _ms_pos - %s" % prev_pos_var)
	code_lines.append("\t_ms_vel = _ms_motion_delta / _ms_dt if _ms_dt > 0.0 else Vector2.ZERO")
	code_lines.append("\t%s = _ms_pos" % prev_pos_var)

	if use_local:
		code_lines.append("if self is Node2D:")
		code_lines.append("\tvar _ms_right = global_transform.x.normalized() if global_transform.x.length_squared() > 0.000001 else Vector2.RIGHT")
		code_lines.append("\tvar _ms_down = global_transform.y.normalized() if global_transform.y.length_squared() > 0.000001 else Vector2.DOWN")
		code_lines.append("\t_ms_vel = Vector2(_ms_vel.dot(_ms_right), _ms_vel.dot(_ms_down))")

	var conditions: Array[String] = []
	if all_axis:
		conditions.append("_ms_vel.x > %s" % threshold)
		conditions.append("_ms_vel.x < -%s" % threshold)
		conditions.append("_ms_vel.y > %s" % threshold)
		conditions.append("_ms_vel.y < -%s" % threshold)
	else:
		if properties.get("pos_x", false):
			conditions.append("_ms_vel.x > %s" % threshold)
		if properties.get("neg_x", false):
			conditions.append("_ms_vel.x < -%s" % threshold)
		if properties.get("pos_y", false):
			conditions.append("_ms_vel.y > %s" % threshold)
		if properties.get("neg_y", false):
			conditions.append("_ms_vel.y < -%s" % threshold)

	if threshold_number == null and not conditions.is_empty():
		code_lines.append("var _ms_threshold = absf(%s)" % _num("threshold", 0.1))

	if conditions.is_empty():
		code_lines.append("var sensor_active = %s  # No directions checked" % ("true" if invert else "false"))
	else:
		var joined = " or ".join(conditions)
		code_lines.append("var sensor_active = %s(%s)" % [["not ", ""][int(not invert)], joined])

	return {
		"sensor_code": "\n".join(code_lines),
		"member_vars": member_vars,
	}
