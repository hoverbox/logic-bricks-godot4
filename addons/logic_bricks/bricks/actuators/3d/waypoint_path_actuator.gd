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
		"waypoints": [],          # Array of "x,y,z" strings
		"loop_mode": "loop",      # "loop", "ping_pong", "once"
		"speed": 5.0,
		"arrival_distance": 0.5,
		"face_direction": false,
	}


func get_property_definitions() -> Array:
	return [
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
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.1,100.0,0.1",
			"default": 5.0
		},
		{
			"name": "arrival_distance",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.01,10.0,0.01",
			"default": 0.5
		},
		{
			"name": "face_direction",
			"type": TYPE_BOOL,
			"default": false
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Moves this node through a series of waypoints placed in the 3D viewport.\nDrag the sphere handles in the editor to position each waypoint.",
		"waypoints": "List of waypoint positions (X,Y,Z).\nAdd with + then drag the handles in the viewport to place them.",
		"loop_mode": "Loop: repeat from the first waypoint after the last.\nPing Pong: reverse direction at each end.\nOnce: stop at the last waypoint.",
		"speed": "Movement speed in units per second.",
		"arrival_distance": "How close the node must get to count as having reached a waypoint.",
		"face_direction": "Rotate the node to face the direction of movement.",
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
			waypoints[i] = serialize_waypoint(existing.position)

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
			wp_node.position = stored
			owner_node.add_child(wp_node)
			wp_node.owner = owner_node.get_tree().edited_scene_root if owner_node.get_tree() else owner_node

	brick_instance.set_property("waypoints", waypoints)


func generate_code(node: Node, chain_name: String) -> Dictionary:
	# Sync positions from Node3D children into the waypoints array before generating.
	# pos_# nodes are children so child.global_position gives correct world coords.
	var waypoints: Array = properties.get("waypoints", [])
	for i in waypoints.size():
		var child = node.get_node_or_null("pos_%d" % i)
		if child is Node3D:
			waypoints[i] = serialize_waypoint(child.global_position)
	properties["waypoints"] = waypoints

	var loop_mode = properties.get("loop_mode", "loop")
	var speed = float(str(properties.get("speed", 5.0)))
	var arrival_dist = float(str(properties.get("arrival_distance", 0.5)))
	var face_dir = properties.get("face_direction", false)

	if typeof(loop_mode) == TYPE_STRING:
		loop_mode = loop_mode.to_lower().replace(" ", "_")

	if waypoints.is_empty():
		return {"actuator_code": "pass  # Waypoint Path: no waypoints set"}

	var cn = chain_name
	var idx_var  = "_wp_idx_%s"  % cn
	var dir_var  = "_wp_dir_%s"  % cn
	var done_var = "_wp_done_%s" % cn

	var member_vars: Array[String] = [
		"var %s: int = 0"       % idx_var,
		"var %s: int = 1"       % dir_var,
		"var %s: bool = false"  % done_var,
	]

	# Build waypoints array literal (world-space global positions)
	var wp_literals: Array[String] = []
	for wp in waypoints:
		var v = parse_waypoint(str(wp))
		wp_literals.append("Vector3(%.3f, %.3f, %.3f)" % [v.x, v.y, v.z])
	var wp_array = "[%s]" % ", ".join(wp_literals)

	var lines: Array[String] = []

	# Once mode — stop if done
	if loop_mode == "once":
		lines.append("if %s:" % done_var)
		lines.append("\treturn")

	lines.append("var _wp_points: Array = %s" % wp_array)

	# Clamp index defensively
	lines.append("%s = clampi(%s, 0, _wp_points.size() - 1)" % [idx_var, idx_var])

	# Target is always a world-space position
	lines.append("var _wp_target: Vector3 = _wp_points[%s]" % idx_var)

	# Movement
	lines.append("var _wp_dist = global_position.distance_to(_wp_target)")
	lines.append("var _wp_dir = (_wp_target - global_position).normalized()")
	lines.append("var _wp_self: Variant = self")
	lines.append("if _wp_dist > %.3f:" % arrival_dist)
	lines.append("\tif _wp_self is CharacterBody3D:")
	lines.append("\t\t(_wp_self as CharacterBody3D).velocity.x = _wp_dir.x * %.3f" % speed)
	lines.append("\t\t(_wp_self as CharacterBody3D).velocity.z = _wp_dir.z * %.3f" % speed)
	lines.append("\t\t(_wp_self as CharacterBody3D).move_and_slide()")
	lines.append("\telse:")
	lines.append("\t\tglobal_position += _wp_dir * %.3f * _delta" % speed)

	if face_dir:
		lines.append("\tvar _wp_look = Vector3(_wp_dir.x, 0.0, _wp_dir.z)")
		lines.append("\tif _wp_look.length_squared() > 0.001:")
		lines.append("\t\tvar _wp_basis = Basis.looking_at(_wp_look.normalized(), Vector3.UP)")
		lines.append("\t\tbasis = basis.orthonormalized().slerp(_wp_basis, clampf(10.0 * _delta, 0.0, 1.0))")

	# Arrival — advance index
	lines.append("else:")
	match loop_mode:
		"loop":
			lines.append("\t%s = (%s + 1) %% _wp_points.size()" % [idx_var, idx_var])
		"ping_pong":
			lines.append("\t%s += %s" % [idx_var, dir_var])
			lines.append("\tif %s >= _wp_points.size() or %s < 0:" % [idx_var, idx_var])
			lines.append("\t\t%s = clampi(%s, 0, _wp_points.size() - 1)" % [idx_var, idx_var])
			lines.append("\t\t%s = -(%s)" % [dir_var, dir_var])
		"once":
			lines.append("\tif %s < _wp_points.size() - 1:" % idx_var)
			lines.append("\t\t%s += 1" % idx_var)
			lines.append("\telse:")
			lines.append("\t\t%s = true" % done_var)

	return {
		"actuator_code": "\n".join(lines),
		"member_vars": member_vars,
	}
