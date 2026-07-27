@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Waypoint Path 2D Actuator - Moves a Node2D through editable point helpers or a Path2D curve.
## Supports Loop, Ping Pong, and Once traversal modes.

func get_brick_info() -> Dictionary:
	return {"class":"WaypointPath2DActuator","name":"Waypoint Path","type":"actuator","category":"Motion","domain":"2d","menu_order":160}

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Waypoint Path"

func _initialize_properties() -> void:
	properties = {
		"path_source": "node_positions", # node_positions or path2d
		"waypoints": [],                 # Array of "x,y" world positions
		"loop_mode": "loop",            # loop, ping_pong, once
		"speed": "150.0",
		"arrival_distance": "4.0",
		"face_direction": false,
	}

func get_property_definitions() -> Array:
	return [
		{"name":"path_source","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Node2D Positions:node_positions,Path2D:path2d","default":"node_positions"},
		{"name":"waypoints","type":TYPE_ARRAY,"item_hint":PROPERTY_HINT_NONE,"item_hint_string":"","item_label":"Waypoint","item_default":"","default":[]},
		{"name":"loop_mode","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Loop:loop,Ping Pong:ping_pong,Once:once","default":"loop"},
		{"name":"speed","type":TYPE_STRING,"default":"150.0","placeholder":"number, variable, or expression"},
		{"name":"arrival_distance","type":TYPE_STRING,"default":"4.0","placeholder":"number, variable, or expression"},
		{"name":"face_direction","type":TYPE_BOOL,"default":false},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Moves this node through editable Node2D waypoint points or along a Path2D curve.",
		"path_source": "Node2D Positions creates draggable pos_# helper nodes. Path2D creates an editable WaypointPath2D curve.",
		"waypoints": "Add waypoint points. In Node2D Positions mode, matching pos_# helpers are created under this node.",
		"loop_mode": "Loop restarts at the beginning. Ping Pong reverses at each end. Once stops at the final point.",
		"speed": "Movement speed in pixels per second.",
		"arrival_distance": "How close the object must be before advancing to the next Node2D waypoint.",
		"face_direction": "Rotate the object to face its current movement direction.",
	}

static func parse_waypoint(value: String) -> Vector2:
	var parts := value.strip_edges().split(",")
	if parts.size() == 2:
		return Vector2(float(parts[0]), float(parts[1]))
	return Vector2.ZERO

static func serialize_waypoint(value: Vector2) -> String:
	return "%.3f,%.3f" % [value.x, value.y]

static func sync_waypoint_nodes(owner_node: Node2D, brick_instance) -> void:
	if not owner_node or not brick_instance:
		return
	var path_source := str(brick_instance.get_property("path_source", "node_positions")).to_lower()
	if path_source == "path2d":
		return
	var waypoints: Array = brick_instance.get_property("waypoints", [])
	if typeof(waypoints) != TYPE_ARRAY:
		waypoints = []

	for i in range(waypoints.size()):
		var existing := owner_node.get_node_or_null("pos_%d" % i)
		if existing is Node2D:
			waypoints[i] = serialize_waypoint(existing.global_position)

	for child in owner_node.get_children():
		if child is Node2D and child.name.begins_with("pos_"):
			var index_text := child.name.substr(4)
			if index_text.is_valid_int() and int(index_text) >= waypoints.size():
				child.queue_free()

	for i in range(waypoints.size()):
		var child_name := "pos_%d" % i
		if owner_node.has_node(child_name):
			continue
		var helper := Node2D.new()
		helper.name = child_name
		owner_node.add_child(helper)
		var stored := parse_waypoint(str(waypoints[i]))
		if str(waypoints[i]).strip_edges().is_empty():
			stored = owner_node.global_position + Vector2(80.0 * float(i + 1), 0.0)
			helper.global_position = stored
			waypoints[i] = serialize_waypoint(stored)
		else:
			helper.global_position = stored
		helper.owner = owner_node.get_tree().edited_scene_root if owner_node.get_tree() else owner_node

	brick_instance.set_property("waypoints", waypoints)

static func sync_path2d_node(owner_node: Node2D, brick_instance) -> void:
	if not owner_node or not brick_instance:
		return
	var path_source := str(brick_instance.get_property("path_source", "node_positions")).to_lower()
	if path_source != "path2d":
		return
	var path_node := owner_node.get_node_or_null("WaypointPath2D")
	if not (path_node is Path2D):
		path_node = Path2D.new()
		path_node.name = "WaypointPath2D"
		path_node.curve = Curve2D.new()
		path_node.curve.add_point(Vector2.ZERO)
		path_node.curve.add_point(Vector2(200.0, 0.0))
		owner_node.add_child(path_node)
		path_node.owner = owner_node.get_tree().edited_scene_root if owner_node.get_tree() else owner_node
	elif not path_node.curve:
		path_node.curve = Curve2D.new()
		path_node.curve.add_point(Vector2.ZERO)
		path_node.curve.add_point(Vector2(200.0, 0.0))

func _to_expr(value) -> String:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return "%.3f" % float(value)
	var text := str(value).strip_edges()
	if text.is_empty():
		return "0.0"
	if text.is_valid_float() or text.is_valid_int():
		return "%.3f" % float(text)
	return text

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var path_source := str(properties.get("path_source", "node_positions")).to_lower().replace(" ", "_")
	# Backward compatibility with the first 2D implementation.
	if properties.has("path_node_name") and not properties.has("path_source"):
		path_source = "path2d"
	var loop_mode := str(properties.get("loop_mode", "loop")).to_lower().replace(" ", "_")
	if not properties.has("loop_mode") and properties.has("loop"):
		loop_mode = "loop" if bool(properties.get("loop", true)) else "once"
	if loop_mode not in ["loop", "ping_pong", "once"]:
		loop_mode = "loop"

	var speed_expr := _to_expr(properties.get("speed", "150.0"))
	var arrival_expr := _to_expr(properties.get("arrival_distance", "4.0"))
	var face_direction := bool(properties.get("face_direction", false))
	var waypoints: Array = properties.get("waypoints", [])
	if typeof(waypoints) != TYPE_ARRAY:
		waypoints = []

	if path_source != "path2d":
		for i in range(waypoints.size()):
			var helper := node.get_node_or_null("pos_%d" % i)
			if helper is Node2D:
				waypoints[i] = serialize_waypoint(helper.global_position)
		properties["waypoints"] = waypoints
		if waypoints.is_empty():
			return {"actuator_code":"pass  # Waypoint Path 2D: no waypoints set"}

	var id := (instance_name if not instance_name.is_empty() else chain_name).to_lower().replace(" ", "_").validate_node_name().replace(".", "_")
	var idx_var := "_wp2_idx_%s" % id
	var dir_var := "_wp2_dir_%s" % id
	var done_var := "_wp2_done_%s" % id
	var offset_var := "_wp2_offset_%s" % id
	var points_var := "_wp2_points_%s" % id
	var init_func := "_wp2_init_%s" % id

	var member_vars: Array[String] = [
		"var %s: int = 0" % idx_var,
		"var %s: int = 1" % dir_var,
		"var %s: bool = false" % done_var,
	]
	var ready_code: Array[String] = ["%s()" % init_func]
	var lines: Array[String] = []

	if path_source == "path2d":
		member_vars.append_array([
			"var %s: float = 0.0" % offset_var,
			"var _wp2_curve_%s: Curve2D = null" % id,
			"var _wp2_path_%s: Path2D = null" % id,
			"",
			"func %s() -> void:" % init_func,
			"\t_wp2_path_%s = get_node_or_null(\"WaypointPath2D\") as Path2D" % id,
			"\t_wp2_curve_%s = _wp2_path_%s.curve if _wp2_path_%s and _wp2_path_%s.curve else null" % [id,id,id,id],
			"\tif _wp2_curve_%s:" % id,
			"\t\t%s = clampf(%s, 0.0, _wp2_curve_%s.get_baked_length())" % [offset_var,offset_var,id],
		])
		if loop_mode == "once":
			lines += ["if %s:" % done_var, "\treturn"]
		lines += [
			"if _wp2_curve_%s == null or _wp2_path_%s == null:" % [id,id],
			"\t%s()" % init_func,
			"\tif _wp2_curve_%s == null or _wp2_path_%s == null:" % [id,id],
			"\t\treturn",
			"var _wp2_length = _wp2_curve_%s.get_baked_length()" % id,
			"if _wp2_length <= 0.001:",
			"\treturn",
			"var _wp2_step = absf(float(%s)) * _delta * float(%s)" % [speed_expr,dir_var],
		]
		match loop_mode:
			"loop":
				lines.append("%s = fposmod(%s + absf(float(%s)) * _delta, _wp2_length)" % [offset_var,offset_var,speed_expr])
			"ping_pong":
				lines += [
					"%s += _wp2_step" % offset_var,
					"if %s >= _wp2_length:" % offset_var,
					"\t%s = _wp2_length" % offset_var,
					"\t%s = -1" % dir_var,
					"elif %s <= 0.0:" % offset_var,
					"\t%s = 0.0" % offset_var,
					"\t%s = 1" % dir_var,
				]
			"once":
				lines += [
					"%s += absf(float(%s)) * _delta" % [offset_var,speed_expr],
					"if %s >= _wp2_length:" % offset_var,
					"\t%s = _wp2_length" % offset_var,
					"\t%s = true" % done_var,
				]
		lines += [
			"var _wp2_old_position = global_position",
			"var _wp2_target = _wp2_path_%s.to_global(_wp2_curve_%s.sample_baked(%s, true))" % [id,id,offset_var],
			"var _wp2_delta_position = _wp2_target - global_position",
			"if self is CharacterBody2D:",
			"\t_logic_brick_character_2d_motion_active = true",
			"\t_logic_brick_character_2d_target_velocity = _wp2_delta_position / _delta if _delta > 0.0 else Vector2.ZERO",
			"else:",
			"\tglobal_position = _wp2_target",
		]
		if face_direction:
			lines += [
				"var _wp2_facing_motion = _wp2_target - _wp2_old_position",
				"if _wp2_facing_motion.length_squared() > 0.0001:",
				"\trotation = _wp2_facing_motion.angle()",
			]
	else:
		var literals: Array[String] = []
		for waypoint in waypoints:
			var point := parse_waypoint(str(waypoint))
			literals.append("Vector2(%.3f, %.3f)" % [point.x,point.y])
		var array_literal := "[%s]" % ", ".join(literals)
		member_vars.append_array([
			"var %s: Array[Vector2] = []" % points_var,
			"",
			"func %s() -> void:" % init_func,
			"\t%s.assign(%s)" % [points_var,array_literal],
			"\tfor _wp2_i in range(%s.size()):" % points_var,
			"\t\tvar _wp2_helper = get_node_or_null(\"pos_\" + str(_wp2_i))",
			"\t\tif _wp2_helper is Node2D:",
			"\t\t\t%s[_wp2_i] = _wp2_helper.global_position" % points_var,
		])
		if loop_mode == "once":
			lines += ["if %s:" % done_var, "\treturn"]
		lines += [
			"if %s.is_empty():" % points_var,
			"\t%s()" % init_func,
			"\tif %s.is_empty():" % points_var,
			"\t\treturn",
			"%s = clampi(%s, 0, %s.size() - 1)" % [idx_var,idx_var,points_var],
			"var _wp2_target: Vector2 = %s[%s]" % [points_var,idx_var],
			"var _wp2_delta_position = _wp2_target - global_position",
			"var _wp2_distance = _wp2_delta_position.length()",
			"var _wp2_speed = absf(float(%s))" % speed_expr,
			"var _wp2_arrival = maxf(0.0, float(%s))" % arrival_expr,
			"if _wp2_distance > _wp2_arrival:",
			"\tvar _wp2_velocity = _wp2_delta_position.normalized() * _wp2_speed",
			"\tif self is CharacterBody2D:",
			"\t\t_logic_brick_character_2d_motion_active = true",
			"\t\t_logic_brick_character_2d_target_velocity = _wp2_velocity",
			"\telse:",
			"\t\tglobal_position = global_position.move_toward(_wp2_target, _wp2_speed * _delta)",
		]
		if face_direction:
			lines += [
				"\tif _wp2_delta_position.length_squared() > 0.0001:",
				"\t\trotation = _wp2_delta_position.angle()",
			]
		lines.append("else:")
		match loop_mode:
			"loop":
				lines.append("\t%s = posmod(%s + 1, %s.size())" % [idx_var,idx_var,points_var])
			"ping_pong":
				lines += [
					"\tif %s.size() <= 1:" % points_var,
					"\t\t%s = 0" % idx_var,
					"\telse:",
					"\t\t%s += %s" % [idx_var,dir_var],
					"\t\tif %s >= %s.size():" % [idx_var,points_var],
					"\t\t\t%s = %s.size() - 2" % [idx_var,points_var],
					"\t\t\t%s = -1" % dir_var,
					"\t\telif %s < 0:" % idx_var,
					"\t\t\t%s = 1" % idx_var,
					"\t\t\t%s = 1" % dir_var,
				]
			"once":
				lines += [
					"\tif %s < %s.size() - 1:" % [idx_var,points_var],
					"\t\t%s += 1" % idx_var,
					"\telse:",
					"\t\t%s = true" % done_var,
				]

	return {"actuator_code":"\n".join(lines),"member_vars":member_vars,"ready_code":ready_code}
