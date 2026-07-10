@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Waypoint Path Actuator - Moves a node through a series of waypoints.
## Waypoints are placed visually in the 3D viewport and can be dragged.
## Supports Loop, Ping Pong, and Once (stop at last waypoint) modes.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Waypoint Path"


func _initialize_properties() -> void:
	properties = {
		"path_source": "node_positions", # "node_positions" or "path3d"
		"waypoints": [],          # Array of "x,y,z" strings
		"loop_mode": "loop",      # "loop", "ping_pong", "once"
		"speed": "5.0",
		"arrival_distance": "0.5",
		"face_direction": false,
		"follow_curve_tilt": false,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "path_source",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Node3D Positions:node_positions,Path3D:path3d",
			"default": "node_positions"
		},
		{
			"name": "waypoints",
			"type": TYPE_ARRAY,
			"item_hint": PROPERTY_HINT_NONE,
			"item_hint_string": "",
			"item_label": "Waypoint",
			"default": []
		},
		{
			"name": "loop_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Loop,Ping Pong,Once",
			"default": "loop"
		},
		{
			"name": "speed",
			"type": TYPE_STRING,
			"default": "5.0",
			"placeholder": "number, variable, or expression"
		},
		{
			"name": "arrival_distance",
			"type": TYPE_STRING,
			"default": "0.5",
			"placeholder": "number, variable, or expression"
		},
		{
			"name": "face_direction",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "follow_curve_tilt",
			"type": TYPE_BOOL,
			"default": false
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Moves this node through a series of waypoints or along an editable Path3D curve.",
		"path_source": "Choose Node3D Positions for the original pos_# waypoint nodes, or Path3D for a smooth editable curve.",
		"waypoints": "List of waypoint positions (X,Y,Z).\nAdd with + then drag the handles in the viewport to place them.",
		"loop_mode": "Loop: repeat from the first waypoint after the last.\nPing Pong: reverse direction at each end.\nOnce: stop at the last waypoint.",
		"speed": "Movement speed in units per second. Accepts a number, variable name, or expression, like the Motion actuator fields.",
		"arrival_distance": "How close the node must get to count as having reached a waypoint. Accepts a number, variable name, or expression.",
		"face_direction": "Rotate the node to face the direction of movement.",
		"follow_curve_tilt": "Path3D only. Rotate the node using the Path3D curve's baked rotation and tilt values, similar to PathFollow3D tilt behavior.",
	}


## Parse a "x,y,z" string into a Vector3. Returns Vector3.ZERO on failure.
static func parse_waypoint(s: String) -> Vector3:
	var parts = s.strip_edges().split(",")
	if parts.size() == 3:
		return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	return Vector3.ZERO


## Serialize a Vector3 to "x,y,z" string with 3 decimal places.
static func serialize_waypoint(v: Vector3) -> String:
	return "%.3f,%.3f,%.3f" % [v.x, v.y, v.z]


## Sync Node3D children to match the waypoints array on owner_node.
## - Adds missing pos_# nodes (placed at the node's current position)
## - Removes extra pos_# nodes if waypoints were deleted
## - Reads back existing pos_# positions into the waypoints array
## Call this after any add/remove of a waypoint entry.
static func sync_waypoint_nodes(owner_node: Node3D, brick_instance) -> void:
	var waypoints: Array = brick_instance.get_property("waypoints")
	if typeof(waypoints) != TYPE_ARRAY:
		waypoints = []

	# Read current child positions back into the array first (handles moves)
	for i in waypoints.size():
		var child_name = "pos_%d" % i
		var existing = owner_node.get_node_or_null(child_name)
		if existing is Node3D:
			waypoints[i] = serialize_waypoint(existing.global_position)

	# Remove Node3D children beyond the current waypoint count
	for child in owner_node.get_children():
		if child.name.begins_with("pos_"):
			var idx_str = child.name.substr(4)
			if idx_str.is_valid_int():
				if int(idx_str) >= waypoints.size():
					child.queue_free()

	# Add missing Node3D children
	for i in waypoints.size():
		var child_name = "pos_%d" % i
		if not owner_node.has_node(child_name):
			var wp_node = Node3D.new()
			wp_node.name = child_name
			# Place at stored position, or default to owner position offset slightly
			var stored = parse_waypoint(str(waypoints[i]))
			if stored == Vector3.ZERO and i == 0:
				stored = Vector3.ZERO  # leave at origin-relative
			owner_node.add_child(wp_node)
			wp_node.global_position = stored
			wp_node.owner = owner_node.get_tree().edited_scene_root if owner_node.get_tree() else owner_node

	brick_instance.set_property("waypoints", waypoints)


## Ensure the Path3D helper node exists when this actuator is using Path3D mode.
## Called from Apply Code scene setup.
static func sync_path3d_node(owner_node: Node3D, brick_instance) -> void:
	if not owner_node:
		return
	var path_source = str(brick_instance.get_property("path_source", "node_positions")).to_lower()
	if path_source != "path3d":
		return

	var path_node = owner_node.get_node_or_null("WaypointPath3D")
	if not (path_node is Path3D):
		path_node = Path3D.new()
		path_node.name = "WaypointPath3D"
		path_node.curve = Curve3D.new()
		# Give the user an editable starter path instead of an empty curve.
		path_node.curve.add_point(Vector3.ZERO)
		path_node.curve.add_point(Vector3(0.0, 0.0, -5.0))
		owner_node.add_child(path_node)
		path_node.owner = owner_node.get_tree().edited_scene_root if owner_node.get_tree() else owner_node
	elif not path_node.curve:
		path_node.curve = Curve3D.new()
		path_node.curve.add_point(Vector3.ZERO)
		path_node.curve.add_point(Vector3(0.0, 0.0, -5.0))


## Convert a value to a code expression.
## If it is a number (or string of a number), returns a float literal.
## Otherwise returns it as-is, allowing variable names or expressions.
func _to_expr(val) -> String:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return "%.3f" % val
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var path_source = str(properties.get("path_source", "node_positions")).to_lower()

	# Sync positions from Node3D children into the waypoints array before generating.
	# pos_# nodes are children so child.global_position gives correct world coords.
	var waypoints: Array = properties.get("waypoints", [])
	if path_source != "path3d":
		for i in waypoints.size():
			var child = node.get_node_or_null("pos_%d" % i)
			if child is Node3D:
				waypoints[i] = serialize_waypoint(child.global_position)
		properties["waypoints"] = waypoints

	var loop_mode = properties.get("loop_mode", "loop")
	var speed_expr = _to_expr(properties.get("speed", "5.0"))
	var arrival_dist_expr = _to_expr(properties.get("arrival_distance", "0.5"))
	var face_dir = properties.get("face_direction", false)
	var follow_curve_tilt = properties.get("follow_curve_tilt", false)

	if typeof(loop_mode) == TYPE_STRING:
		loop_mode = loop_mode.to_lower().replace(" ", "_")

	if path_source != "path3d" and waypoints.is_empty():
		return {"actuator_code": "pass  # Waypoint Path: no waypoints set"}

	var cn = chain_name
	var idx_var  = "_wp_idx_%s"  % cn
	var dir_var  = "_wp_dir_%s"  % cn
	var done_var = "_wp_done_%s" % cn

	var points_var = "_wp_points_%s" % cn
	var init_func = "_wp_init_points_%s" % cn

	# Build waypoints array literal. These are only a fallback. At runtime,
	# pos_# child Node3Ds are read first so instanced scenes can be moved and
	# their editable waypoint children can be repositioned per level instance.
	var wp_literals: Array[String] = []
	for wp in waypoints:
		var v = parse_waypoint(str(wp))
		wp_literals.append("Vector3(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z])
	var wp_array = "[%s]" % ", ".join(wp_literals)

	var member_vars: Array[String] = [
		"var %s: int = 0"       % idx_var,
		"var %s: int = 1"       % dir_var,
		"var %s: bool = false"  % done_var,
	]

	var path_offset_var = "_wp_path_offset_%s" % cn
	var path_length_var = "_wp_path_length_%s" % cn
	var path_xform_var = "_wp_path_xform_%s" % cn
	var path_curve_var = "_wp_path_curve_%s" % cn

	if path_source == "path3d":
		member_vars.append_array([
			"var %s: float = 0.0" % path_offset_var,
			"var %s: float = 0.0" % path_length_var,
			"var %s: Transform3D = Transform3D.IDENTITY" % path_xform_var,
			"var %s: Curve3D = null" % path_curve_var,
			"",
			"func %s() -> void:" % init_func,
			"\tvar _wp_path = get_node_or_null(\"WaypointPath3D\")",
			"\t%s = null" % path_curve_var,
			"\t%s = 0.0" % path_length_var,
			"\tif _wp_path is Path3D and _wp_path.curve:",
			"\t\t%s = _wp_path.curve" % path_curve_var,
			"\t\t%s = _wp_path.global_transform" % path_xform_var,
			"\t\t%s = %s.get_baked_length()" % [path_length_var, path_curve_var],
			"\t\t%s = clampf(%s, 0.0, %s)" % [path_offset_var, path_offset_var, path_length_var],
		])
	else:
		member_vars.append_array([
			"var %s: Array = []" % points_var,
			"",
			"func %s() -> void:" % init_func,
			"\t%s = %s.duplicate()" % [points_var, wp_array],
			"\tfor _wp_i in range(%s.size()):" % points_var,
			"\t\tvar _wp_child = get_node_or_null(\"pos_%%d\" %% _wp_i)",
			"\t\tif _wp_child is Node3D:",
			"\t\t\t%s[_wp_i] = _wp_child.global_position" % points_var,
		])

	var ready_code: Array[String] = [
		"%s()" % init_func,
	]

	var lines: Array[String] = []

	if path_source == "path3d":
		# Path3D mode follows the curve by baked distance instead of jumping between baked points.
		# This keeps curved motion smooth and avoids jitter from uneven point spacing.
		if loop_mode == "once":
			lines.append("if %s:" % done_var)
			lines.append("\treturn")

		lines.append("if %s == null or %s <= 0.001:" % [path_curve_var, path_length_var])
		lines.append("\t%s()" % init_func)
		lines.append("\tif %s == null or %s <= 0.001:" % [path_curve_var, path_length_var])
		lines.append("\t\treturn")

		lines.append("var _wp_self: Variant = self")
		lines.append("var _wp_speed = float(%s)" % speed_expr)
		lines.append("var _wp_step = _wp_speed * _delta * float(%s)" % dir_var)

		match loop_mode:
			"loop":
				lines.append("%s = fposmod(%s + _wp_step, %s)" % [path_offset_var, path_offset_var, path_length_var])
			"ping_pong":
				lines.append("%s += _wp_step" % path_offset_var)
				lines.append("if %s >= %s:" % [path_offset_var, path_length_var])
				lines.append("\t%s = %s" % [path_offset_var, path_length_var])
				lines.append("\t%s = -1" % dir_var)
				lines.append("elif %s <= 0.0:" % path_offset_var)
				lines.append("\t%s = 0.0" % path_offset_var)
				lines.append("\t%s = 1" % dir_var)
			"once":
				lines.append("%s += abs(_wp_step)" % path_offset_var)
				lines.append("if %s >= %s:" % [path_offset_var, path_length_var])
				lines.append("\t%s = %s" % [path_offset_var, path_length_var])
				lines.append("\t%s = true" % done_var)

		if follow_curve_tilt:
			lines.append("var _wp_local_transform: Transform3D = %s.sample_baked_with_rotation(%s, true, true)" % [path_curve_var, path_offset_var])
			lines.append("var _wp_target: Vector3 = %s * _wp_local_transform.origin" % path_xform_var)
		else:
			lines.append("var _wp_local_target: Vector3 = %s.sample_baked(%s, true)" % [path_curve_var, path_offset_var])
			lines.append("var _wp_target: Vector3 = %s * _wp_local_target" % path_xform_var)
		lines.append("var _wp_delta_pos: Vector3 = _wp_target - global_position")
		lines.append("var _wp_move_dir: Vector3 = _wp_delta_pos.normalized() if _wp_delta_pos.length_squared() > 0.000001 else Vector3.ZERO")
		lines.append("if _wp_self is CharacterBody3D:")
		lines.append("\tif _delta > 0.0:")
		lines.append("\t\t(_wp_self as CharacterBody3D).velocity = _wp_delta_pos / _delta")
		lines.append("\t(_wp_self as CharacterBody3D).move_and_slide()")
		lines.append("else:")
		lines.append("\tglobal_position = _wp_target")

		if follow_curve_tilt:
			lines.append("var _wp_curve_global_basis: Basis = (%s.basis * _wp_local_transform.basis).orthonormalized()" % path_xform_var)
			lines.append("var _wp_existing_global_scale: Vector3 = global_transform.basis.get_scale()")
			lines.append("var _wp_new_global_basis: Basis = global_transform.basis.orthonormalized().slerp(_wp_curve_global_basis, clampf(10.0 * _delta, 0.0, 1.0))")
			lines.append("global_transform.basis = _wp_new_global_basis.scaled(_wp_existing_global_scale)")
		elif face_dir:
			lines.append("if _wp_move_dir.length_squared() > 0.001:")
			lines.append("\tvar _wp_look = Vector3(_wp_move_dir.x, 0.0, _wp_move_dir.z)")
			lines.append("\tif _wp_look.length_squared() > 0.001:")
			lines.append("\t\tvar _wp_basis = Basis.looking_at(_wp_look.normalized(), Vector3.UP)")
			lines.append("\t\tvar _wp_existing_scale: Vector3 = basis.get_scale()")
			lines.append("\t\tvar _wp_new_basis: Basis = basis.orthonormalized().slerp(_wp_basis, clampf(10.0 * _delta, 0.0, 1.0))")
			lines.append("\t\tbasis = _wp_new_basis.scaled(_wp_existing_scale)")
	else:
		# Once mode — stop if done
		if loop_mode == "once":
			lines.append("if %s:" % done_var)
			lines.append("\treturn")

		lines.append("if %s.is_empty():" % points_var)
		lines.append("\t%s()" % init_func)
		lines.append("\tif %s.is_empty():" % points_var)
		lines.append("\t\treturn")

		# Clamp index defensively
		lines.append("%s = clampi(%s, 0, %s.size() - 1)" % [idx_var, idx_var, points_var])

		# Target is a runtime-snapshotted world-space position
		lines.append("var _wp_target: Vector3 = %s[%s]" % [points_var, idx_var])

		# Movement
		lines.append("var _wp_dist = global_position.distance_to(_wp_target)")
		lines.append("var _wp_move_dir = (_wp_target - global_position).normalized()")
		lines.append("var _wp_self: Variant = self")
		lines.append("var _wp_speed = float(%s)" % speed_expr)
		lines.append("var _wp_arrival_distance = float(%s)" % arrival_dist_expr)
		lines.append("if _wp_dist > _wp_arrival_distance:")
		lines.append("\tif _wp_self is CharacterBody3D:")
		lines.append("\t\t(_wp_self as CharacterBody3D).velocity.x = _wp_move_dir.x * _wp_speed")
		lines.append("\t\t(_wp_self as CharacterBody3D).velocity.z = _wp_move_dir.z * _wp_speed")
		lines.append("\t\t(_wp_self as CharacterBody3D).move_and_slide()")
		lines.append("\telse:")
		lines.append("\t\tglobal_position += _wp_move_dir * _wp_speed * _delta")

		if face_dir:
			lines.append("\tvar _wp_look = Vector3(_wp_move_dir.x, 0.0, _wp_move_dir.z)")
			lines.append("\tif _wp_look.length_squared() > 0.001:")
			lines.append("\t\tvar _wp_basis = Basis.looking_at(_wp_look.normalized(), Vector3.UP)")
			lines.append("\t\tvar _wp_existing_scale: Vector3 = basis.get_scale()")
			lines.append("\t\tvar _wp_new_basis: Basis = basis.orthonormalized().slerp(_wp_basis, clampf(10.0 * _delta, 0.0, 1.0))")
			lines.append("\t\tbasis = _wp_new_basis.scaled(_wp_existing_scale)")

		# Arrival — advance index
		lines.append("else:")
		match loop_mode:
			"loop":
				lines.append("\t%s = (%s + 1) %% %s.size()" % [idx_var, idx_var, points_var])
			"ping_pong":
				lines.append("\t%s += %s" % [idx_var, dir_var])
				lines.append("\tif %s >= %s.size() or %s < 0:" % [idx_var, points_var, idx_var])
				lines.append("\t\t%s = clampi(%s, 0, %s.size() - 1)" % [idx_var, idx_var, points_var])
				lines.append("\t\t%s = -(%s)" % [dir_var, dir_var])
			"once":
				lines.append("\tif %s < %s.size() - 1:" % [idx_var, points_var])
				lines.append("\t\t%s += 1" % idx_var)
				lines.append("\telse:")
				lines.append("\t\t%s = true" % done_var)
	return {
		"actuator_code": "\n".join(lines),
		"member_vars": member_vars,
		"ready_code": ready_code,
	}
