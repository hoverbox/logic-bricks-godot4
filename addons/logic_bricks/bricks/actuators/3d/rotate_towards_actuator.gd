@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Rotate Towards Actuator - Smoothly rotates a node to face a target.
## Finds the target at runtime by node name or group (nearest member).
## Useful for turrets, enemies tracking a player, or any look-at behaviour.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Rotate Towards"


func _initialize_properties() -> void:
	properties = {
		"target_mode": "node_name",  # node_name, group
		"target_name": "",           # Node name or group name to find
		"axes": "y_only",            # y_only, x_only, both
		"forward_axis": "positive_z", # positive_z, negative_z
		"speed": 5.0,                # Rotation speed in deg/s; 0 = instant
		"clamp_x": false,            # Clamp pitch (useful for turrets)
		"clamp_x_min": -45.0,
		"clamp_x_max": 45.0,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Node Name,Group",
			"default": "node_name"
		},
		{
			"name": "target_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "axes",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Y Only (Horizontal),X Only (Vertical),Both",
			"default": "y_only"
		},
		{
			"name": "forward_axis",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Positive Z (+Z),Negative Z (-Z)",
			"default": "positive_z"
		},
		{
			"name": "speed",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,360.0,0.1",
			"default": 5.0
		},
		{
			"name": "clamp_x",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "clamp_x_min",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-180.0,0.0,0.1",
			"default": -45.0
		},
		{
			"name": "clamp_x_max",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,180.0,0.1",
			"default": 45.0
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Rotates this node to face a target found by name or group.\nUseful for turrets, enemies tracking a player, or any look-at behaviour.",
		"target_mode": "How to find the target:\n• Node Name: find a node anywhere in the scene tree by name\n• Group: find the nearest node in the specified group",
		"target_name": "The node name or group name to search for.",
		"axes": "Which axes to rotate on:\n• Y Only: horizontal turning only (typical for turret bases)\n• X Only: vertical pitch only (typical for turret barrels)\n• Both: full 3D look-at rotation",
		"forward_axis": "Which direction your mesh faces.\n• Positive Z (+Z): mesh faces toward +Z (Godot default for most imported models)\n• Negative Z (-Z): mesh faces toward -Z (cameras, some exporters)",
		"speed": "Rotation speed in degrees per second.\n0 = snap instantly to face the target.",
		"clamp_x": "Clamp the vertical (pitch) rotation to a min/max range.\nUseful for turret barrels that shouldn't flip upside-down.",
		"clamp_x_min": "Minimum pitch angle in degrees (e.g. -45 = 45 degrees down).",
		"clamp_x_max": "Maximum pitch angle in degrees (e.g. 45 = 45 degrees up).",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_mode = properties.get("target_mode", "node_name")
	var target_name = properties.get("target_name", "")
	var axes = properties.get("axes", "y_only")
	var forward_axis = properties.get("forward_axis", "positive_z")
	var speed = float(str(properties.get("speed", 5.0)))
	var clamp_x = properties.get("clamp_x", false)
	var clamp_x_min = float(str(properties.get("clamp_x_min", -45.0)))
	var clamp_x_max = float(str(properties.get("clamp_x_max", 45.0)))

	# Normalize enum values coming from the UI
	if typeof(target_mode) == TYPE_STRING:
		target_mode = target_mode.to_lower().replace(" ", "_")
	if typeof(axes) == TYPE_STRING:
		# Strip parenthetical suffixes added by the display label
		axes = axes.to_lower().split("(")[0].strip_edges().replace(" ", "_")
	if typeof(forward_axis) == TYPE_STRING:
		forward_axis = forward_axis.to_lower().replace(" ", "_").replace("(", "").replace(")", "").replace("+", "positive_").replace("-", "negative_")
	
	# Positive Z faces +Z so we must flip the direction to face the target
	# Negative Z faces -Z which is what Basis.looking_at/look_at expects natively
	var flip_dir: bool = (forward_axis == "positive_z" or forward_axis.contains("positive"))

	var code_lines: Array[String] = []

	if target_name.is_empty():
		code_lines.append("# Rotate Towards: no target name set")
		code_lines.append("pass")
		return {"actuator_code": "\n".join(code_lines)}

	var escaped_name = target_name.replace("\"", "\\\"")

	# --- Find the target node ---
	code_lines.append("# Rotate Towards: find target")
	if target_mode == "group":
		# Find nearest node in the group each frame
		code_lines.append("var _rt_target: Node3D = null")
		code_lines.append("var _rt_best_dist: float = INF")
		code_lines.append("for _rt_member in get_tree().get_nodes_in_group(\"%s\"):" % escaped_name)
		code_lines.append("\tif not _rt_member is Node3D or _rt_member == self:")
		code_lines.append("\t\tcontinue")
		code_lines.append("\tvar _rt_d = global_position.distance_to(_rt_member.global_position)")
		code_lines.append("\tif _rt_d < _rt_best_dist:")
		code_lines.append("\t\t_rt_best_dist = _rt_d")
		code_lines.append("\t\t_rt_target = _rt_member")
	else:
		# Find node by name anywhere in the scene tree
		code_lines.append("var _rt_target = get_tree().root.find_child(\"%s\", true, false)" % escaped_name)

	code_lines.append("if _rt_target and _rt_target is Node3D:")

	# --- Rotation logic per axis mode ---
	match axes:
		"y_only":
			_append_y_only(code_lines, speed, flip_dir)
		"x_only":
			_append_x_only(code_lines, speed, flip_dir, clamp_x, clamp_x_min, clamp_x_max)
		_:  # "both" or anything else
			_append_both(code_lines, speed, flip_dir, clamp_x, clamp_x_min, clamp_x_max)

	return {"actuator_code": "\n".join(code_lines)}


## Horizontal-only rotation: rotates around Y axis to face the target,
## ignoring any height difference.
func _append_y_only(lines: Array[String], speed: float, flip_dir: bool) -> void:
	lines.append("\t# Horizontal rotation only (Y axis)")
	lines.append("\tvar _rt_dir = _rt_target.global_position - global_position")
	lines.append("\t_rt_dir.y = 0.0")
	if flip_dir:
		lines.append("\t_rt_dir = -_rt_dir  # Mesh faces +Z, flip so it faces the target")
	lines.append("\tif _rt_dir.length_squared() > 0.0001:")
	if speed == 0.0:
		lines.append("\t\tlook_at(global_position + _rt_dir, Vector3.UP)")
	else:
		lines.append("\t\tvar _rt_target_basis = Basis.looking_at(_rt_dir.normalized(), Vector3.UP)")
		lines.append("\t\tvar _rt_weight = clampf(deg_to_rad(%.4f) * _delta, 0.0, 1.0)" % speed)
		lines.append("\t\tbasis = basis.orthonormalized().slerp(_rt_target_basis, _rt_weight)")


## Vertical-only rotation: adjusts pitch (X axis) to aim up/down at the target.
## Useful for a turret barrel that sits on top of a rotating base.
func _append_x_only(lines: Array[String], speed: float, flip_dir: bool, clamp_x: bool, x_min: float, x_max: float) -> void:
	lines.append("\t# Vertical rotation only (X axis / pitch)")
	lines.append("\tvar _rt_dir = _rt_target.global_position - global_position")
	if flip_dir:
		lines.append("\t_rt_dir = -_rt_dir  # Mesh faces +Z, flip so it faces the target")
	lines.append("\tvar _rt_pitch = -atan2(_rt_dir.y, Vector2(_rt_dir.x, _rt_dir.z).length())")
	if clamp_x:
		lines.append("\t_rt_pitch = clampf(_rt_pitch, deg_to_rad(%.4f), deg_to_rad(%.4f))" % [x_min, x_max])
	if speed == 0.0:
		lines.append("\trotation.x = _rt_pitch")
	else:
		lines.append("\tvar _rt_speed_rad = deg_to_rad(%.4f) * _delta" % speed)
		lines.append("\trotation.x = rotate_toward(rotation.x, _rt_pitch, _rt_speed_rad)")


## Full look-at rotation: rotates on both Y and X to face the target completely.
func _append_both(lines: Array[String], speed: float, flip_dir: bool, clamp_x: bool, x_min: float, x_max: float) -> void:
	lines.append("\t# Full look-at rotation (both axes)")
	lines.append("\tvar _rt_dir = (_rt_target.global_position - global_position).normalized()")
	if flip_dir:
		lines.append("\t_rt_dir = -_rt_dir  # Mesh faces +Z, flip so it faces the target")
	lines.append("\tif _rt_dir.length_squared() > 0.0001:")
	if speed == 0.0:
		if flip_dir:
			lines.append("\t\tlook_at(global_position + _rt_dir, Vector3.UP)")
		else:
			lines.append("\t\tlook_at(_rt_target.global_position, Vector3.UP)")
		if clamp_x:
			lines.append("\t\trotation.x = clampf(rotation.x, deg_to_rad(%.4f), deg_to_rad(%.4f))" % [x_min, x_max])
	else:
		lines.append("\t\tvar _rt_target_basis = Basis.looking_at(_rt_dir, Vector3.UP)")
		lines.append("\t\tvar _rt_weight = clampf(deg_to_rad(%.4f) * _delta, 0.0, 1.0)" % speed)
		lines.append("\t\tbasis = basis.orthonormalized().slerp(_rt_target_basis, _rt_weight)")
		if clamp_x:
			lines.append("\t\trotation.x = clampf(rotation.x, deg_to_rad(%.4f), deg_to_rad(%.4f))" % [x_min, x_max])
