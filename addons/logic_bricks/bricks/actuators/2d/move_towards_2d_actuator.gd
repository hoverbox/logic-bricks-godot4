@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Steering 2D actuator. The legacy filename/class ID is retained for project compatibility.

func get_brick_info() -> Dictionary:
	return {"class":"MoveTowards2DActuator","name":"Steering","type":"actuator","category":"Motion","domain":"2d","menu_order":140}

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Steering"

func _initialize_properties() -> void:
	properties = {
		"behavior":"seek",
		"target_mode":"node_name",
		"target_name":"",
		"coordinate_x":"0.0",
		"coordinate_y":"0.0",
		"speed":"200.0",
		"arrival_distance":"4.0",
		"slowing_distance":"80.0",
		"desired_distance":"120.0",
		"distance_tolerance":"10.0",
		"orbit_distance":"120.0",
		"orbit_direction":"clockwise",
		"wander_amount":"45.0",
		"wander_frequency":"1.5",
		"face_target":false,
		"use_navigation":false
	}

func get_property_definitions() -> Array:
	return [
		{"name":"behavior","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Seek,Flee,Arrive,Wander,Maintain Distance,Orbit","default":"seek"},
		{"name":"target_mode","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Node Name,Group,Coordinates","default":"node_name"},
		{"name":"target_name", "required": true, "required_label": "a target node or group name", "required_if": {"target_mode": ["node_name", "group"]}, "required_unless": {"behavior": "wander"}, "group_picker": true, "group_picker_if": {"target_mode": "group"},"type":TYPE_STRING,"default":""},
		{"name":"coordinate_x","type":TYPE_STRING,"default":"0.0"},
		{"name":"coordinate_y","type":TYPE_STRING,"default":"0.0"},
		{"name":"speed","type":TYPE_STRING,"default":"200.0"},
		{"name":"arrival_distance","type":TYPE_STRING,"default":"4.0"},
		{"name":"slowing_distance","type":TYPE_STRING,"default":"80.0"},
		{"name":"desired_distance","type":TYPE_STRING,"default":"120.0"},
		{"name":"distance_tolerance","type":TYPE_STRING,"default":"10.0"},
		{"name":"orbit_distance","type":TYPE_STRING,"default":"120.0"},
		{"name":"orbit_direction","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Clockwise,Counterclockwise","default":"clockwise"},
		{"name":"wander_amount","type":TYPE_STRING,"default":"45.0"},
		{"name":"wander_frequency","type":TYPE_STRING,"default":"1.5"},
		{"name":"face_target","type":TYPE_BOOL,"default":false},
		{"name":"use_navigation","type":TYPE_BOOL,"default":false}
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Steers a Node2D with Seek, Flee, Arrive, Wander, Maintain Distance, or Orbit behaviors.",
		"behavior":"Choose how this object steers. Wander does not require a target.",
		"slowing_distance":"Arrive only. Begin slowing inside this distance.",
		"desired_distance":"Maintain Distance only. Preferred distance from the target.",
		"distance_tolerance":"Maintain Distance only. Allowed range around the preferred distance.",
		"orbit_distance":"Orbit only. Preferred radius around the target.",
		"orbit_direction":"Orbit only. Direction to circle the target.",
		"wander_amount":"Wander only. Maximum randomized heading change in degrees.",
		"wander_frequency":"Wander only. Seconds between heading changes."
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = str(properties.get("target_mode","node_name")).to_lower().replace(" ","_")
	var behavior = str(properties.get("behavior","seek")).to_lower().replace(" ","_")
	var name = _gd_string(str(properties.get("target_name","")))
	var x = _expr(properties.get("coordinate_x","0.0"))
	var y = _expr(properties.get("coordinate_y","0.0"))
	var sp = _expr(properties.get("speed","200.0"))
	var ar = _expr(properties.get("arrival_distance","4.0"))
	var slow = _expr(properties.get("slowing_distance","80.0"))
	var desired = _expr(properties.get("desired_distance","120.0"))
	var tol = _expr(properties.get("distance_tolerance","10.0"))
	var orbit = _expr(properties.get("orbit_distance","120.0"))
	var orbit_dir = str(properties.get("orbit_direction","clockwise")).to_lower()
	var wander_amount = _expr(properties.get("wander_amount","45.0"))
	var wander_frequency = _expr(properties.get("wander_frequency","1.5"))
	var face = bool(properties.get("face_target",false))
	var nav = bool(properties.get("use_navigation",false))
	var lines: Array[String] = []
	var members: Array[String] = []

	if behavior == "wander":
		var dir_var = "_steer2_wander_dir_%s" % chain_name
		var timer_var = "_steer2_wander_timer_%s" % chain_name
		members = ["var %s: Vector2 = Vector2.ZERO" % dir_var, "var %s: float = 0.0" % timer_var]
		lines.append("%s -= _delta" % timer_var)
		lines.append("if %s.length_squared() < 0.000001:" % dir_var)
		lines.append("\t%s = Vector2.RIGHT.rotated(randf_range(0.0, TAU))" % dir_var)
		lines.append("\t%s = 0.0" % timer_var)
		lines.append("if %s <= 0.0:" % timer_var)
		lines.append("\t%s = %s.rotated(deg_to_rad(randf_range(-absf(float(%s)), absf(float(%s))))).normalized()" % [dir_var, dir_var, wander_amount, wander_amount])
		lines.append("\t%s = maxf(float(%s), 0.01)" % [timer_var, wander_frequency])
		lines.append("var _steer2_dir = %s" % dir_var)
		lines.append("var _steer2_velocity = _steer2_dir * (%s)" % sp)
		lines.append("if self is CharacterBody2D:")
		lines.append("\tvelocity = _steer2_velocity")
		lines.append("\tmove_and_slide()")
		lines.append("else:")
		lines.append("\tglobal_position += _steer2_velocity * _delta")
		if face:
			lines.append("rotation = _steer2_dir.angle()")
		return {"actuator_code":"\n".join(lines), "member_vars":members}

	if mode == "coordinates":
		lines = ["var _steer2_pos = Vector2(%s, %s)" % [x,y], "var _steer2_has_target = true"]
	elif mode == "group":
		lines = ["var _steer2_node: Node2D = null","var _steer2_best := INF","for _n in get_tree().get_nodes_in_group(\"%s\"):" % name,"\tif _n is Node2D and _n != self:","\t\tvar _d = global_position.distance_squared_to(_n.global_position)","\t\tif _d < _steer2_best:","\t\t\t_steer2_best = _d","\t\t\t_steer2_node = _n","var _steer2_has_target = _steer2_node != null","var _steer2_pos = _steer2_node.global_position if _steer2_node else global_position"]
	else:
		lines = ["var _steer2_node = get_tree().current_scene.find_child(\"%s\", true, false) if get_tree().current_scene else null" % name,"var _steer2_has_target = _steer2_node is Node2D","var _steer2_pos = _steer2_node.global_position if _steer2_has_target else global_position"]

	lines.append("if _steer2_has_target:")
	lines.append("\tvar _steer2_to = _steer2_pos - global_position")
	lines.append("\tvar _steer2_dist = _steer2_to.length()")
	lines.append("\tvar _steer2_dir = Vector2.ZERO")
	lines.append("\tvar _steer2_speed_factor = 1.0")
	match behavior:
		"flee":
			lines.append("\tif _steer2_dist > 0.001: _steer2_dir = -_steer2_to.normalized()")
		"arrive":
			lines.append("\tif _steer2_dist > (%s):" % ar)
			lines.append("\t\t_steer2_dir = _steer2_to.normalized()")
			lines.append("\t\t_steer2_speed_factor = clampf((_steer2_dist - (%s)) / maxf((%s) - (%s), 0.001), 0.0, 1.0)" % [ar, slow, ar])
		"maintain_distance":
			lines.append("\tif _steer2_dist > (%s) + (%s): _steer2_dir = _steer2_to.normalized()" % [desired,tol])
			lines.append("\telif _steer2_dist < maxf((%s) - (%s), 0.0) and _steer2_dist > 0.001: _steer2_dir = -_steer2_to.normalized()" % [desired,tol])
		"orbit":
			lines.append("\tif _steer2_dist > 0.001:")
			lines.append("\t\tvar _steer2_radial = _steer2_to.normalized()")
			var tangent = "Vector2(-_steer2_radial.y, _steer2_radial.x)" if orbit_dir == "clockwise" else "Vector2(_steer2_radial.y, -_steer2_radial.x)"
			lines.append("\t\tvar _steer2_tangent = %s" % tangent)
			lines.append("\t\tvar _steer2_error = (_steer2_dist - (%s)) / maxf((%s), 0.001)" % [orbit,orbit])
			lines.append("\t\t_steer2_dir = (_steer2_tangent + _steer2_radial * clampf(_steer2_error, -1.0, 1.0)).normalized()")
		_:
			lines.append("\tif _steer2_dist > (%s): _steer2_dir = _steer2_to.normalized()" % ar)

	if nav and behavior in ["seek","arrive"]:
		lines.append("\tvar _agent = get_node_or_null(\"NavigationAgent2D\")")
		lines.append("\tif _agent is NavigationAgent2D:")
		lines.append("\t\t_agent.target_position = _steer2_pos")
		lines.append("\t\t_steer2_dir = (_agent.get_next_path_position() - global_position).normalized()")
	lines.append("\tvar _steer2_velocity = _steer2_dir * (%s) * _steer2_speed_factor" % sp)
	lines.append("\tif self is CharacterBody2D:")
	lines.append("\t\tvelocity = _steer2_velocity")
	lines.append("\t\tmove_and_slide()")
	lines.append("\telse:")
	lines.append("\t\tglobal_position += _steer2_velocity * _delta")
	if face:
		lines.append("\tif _steer2_dir.length_squared() > 0.000001: rotation = _steer2_dir.angle()")
	return {"actuator_code":"\n".join(lines)}

