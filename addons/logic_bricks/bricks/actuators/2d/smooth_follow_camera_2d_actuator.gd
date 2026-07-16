@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Smooth Follow Camera 2D Actuator
## Camera2D smoothly follows this Node2D while maintaining its initial offset.

func get_brick_info() -> Dictionary:
	return {"class":"SmoothFollowCamera2DActuator","name":"Smooth Follow Camera","type":"actuator","category":"Camera","domain":"2d","menu_order":320}

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Smooth Follow Camera"

func _initialize_properties() -> void:
	properties = {
		"camera_node_name": "Camera2D",
		"follow_speed": 5.0,
		"dead_zone_x": 0.0,
		"dead_zone_y": 0.0,
		"follow_pos_x": true,
		"follow_pos_y": true,
		"rotation_source_node_name": "",
		"follow_rotation": false,
		"rotation_speed": 5.0,
	}

func get_property_definitions() -> Array:
	return [
		{"name":"camera_node_name","type":TYPE_STRING,"default":"Camera2D","placeholder":"Camera2D node name"},
		{"name":"follow_speed","type":TYPE_FLOAT,"default":5.0},
		{"name":"dead_zone_x","type":TYPE_FLOAT,"default":0.0},
		{"name":"dead_zone_y","type":TYPE_FLOAT,"default":0.0},
		{"name":"follow_pos_x","type":TYPE_BOOL,"default":true},
		{"name":"follow_pos_y","type":TYPE_BOOL,"default":true},
		{"name":"rotation_source_node_name","type":TYPE_STRING,"default":"","placeholder":"Blank = this node"},
		{"name":"follow_rotation","type":TYPE_BOOL,"default":false},
		{"name":"rotation_speed","type":TYPE_FLOAT,"default":5.0},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Smoothly follows this Node2D with the named Camera2D while maintaining the camera's initial offset from the target.",
		"camera_node_name": "Name of the Camera2D node to move.",
		"follow_speed": "How quickly the camera catches up to the target.",
		"dead_zone_x": "Camera ignores X movement smaller than this many pixels.",
		"dead_zone_y": "Camera ignores Y movement smaller than this many pixels.",
		"rotation_source_node_name": "Optional Node2D to read rotation from. Leave blank to use this node.",
		"follow_rotation": "Smoothly match the rotation source's rotation.",
		"rotation_speed": "How quickly the camera rotates toward the source rotation.",
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var camera_node_name = str(properties.get("camera_node_name", "Camera2D")).strip_edges()
	var follow_speed = float(properties.get("follow_speed", 5.0))
	var dead_zone_x = float(properties.get("dead_zone_x", 0.0))
	var dead_zone_y = float(properties.get("dead_zone_y", 0.0))
	var follow_pos_x = bool(properties.get("follow_pos_x", true))
	var follow_pos_y = bool(properties.get("follow_pos_y", true))
	var rotation_source_node_name = str(properties.get("rotation_source_node_name", "")).strip_edges()
	var follow_rotation = bool(properties.get("follow_rotation", false))
	var rotation_speed = float(properties.get("rotation_speed", 5.0))
	var base_name = instance_name.to_lower().replace(" ", "_") if not instance_name.is_empty() else "smooth_follow_camera_2d"
	var camera_var = base_name
	var offset_var = "_%s_initial_offset" % base_name
	var ready_var = "_%s_offset_ready" % base_name
	var rot_source_var = "_%s_rotation_source" % base_name
	var member_vars: Array[String] = []
	var lines: Array[String] = []
	member_vars.append("var %s: Camera2D = null" % camera_var)
	member_vars.append("var %s: Vector2 = Vector2.ZERO" % offset_var)
	member_vars.append("var %s: bool = false" % ready_var)
	member_vars.append("var %s: Node2D = null" % rot_source_var)
	_append_find_node_helpers(member_vars)
	lines.append("# Smooth Follow Camera 2D")
	lines.append("var _node_name_%s = \"%s\"" % [chain_name, _gd_string(camera_node_name)])
	lines.append("if _node_name_%s.is_empty():" % chain_name)
	lines.append("\tpush_warning(\"Smooth Follow Camera 2D: No camera node name set\")")
	lines.append("\t%s = null" % camera_var)
	lines.append("elif %s == null or %s.name != _node_name_%s:" % [camera_var, camera_var, chain_name])
	lines.append("\tvar _found_node_%s = _lb_find_node_in_current_scene(_node_name_%s)" % [chain_name, chain_name])
	lines.append("\tif _found_node_%s is Camera2D:" % chain_name)
	lines.append("\t\t%s = _found_node_%s" % [camera_var, chain_name])
	lines.append("\t\t%s = false" % ready_var)
	lines.append("\telif _found_node_%s:" % chain_name)
	lines.append("\t\tpush_warning(\"Smooth Follow Camera 2D: node '\" + str(_node_name_%s) + \"' is not a Camera2D\")" % chain_name)
	if follow_rotation:
		lines.append("var _rot_source_name_%s = \"%s\"" % [chain_name, _gd_string(rotation_source_node_name)])
		lines.append("if _rot_source_name_%s.is_empty():" % chain_name)
		lines.append("\t%s = self if self is Node2D else null" % rot_source_var)
		lines.append("else:")
		lines.append("\tvar _found_rot_source_%s = _lb_find_node_in_current_scene(_rot_source_name_%s)" % [chain_name, chain_name])
		lines.append("\tif _found_rot_source_%s is Node2D:" % chain_name)
		lines.append("\t\t%s = _found_rot_source_%s" % [rot_source_var, chain_name])
		lines.append("\telif _found_rot_source_%s:" % chain_name)
		lines.append("\t\tpush_warning(\"Smooth Follow Camera 2D: rotation source '\" + str(_rot_source_name_%s) + \"' is not a Node2D\")" % chain_name)
		lines.append("\telse:")
		lines.append("\t\tpush_warning(\"Smooth Follow Camera 2D: rotation source '\" + str(_rot_source_name_%s) + \"' was not found\")" % chain_name)
	lines.append("if %s and self is Node2D:" % camera_var)
	lines.append("\tif not %s:" % ready_var)
	lines.append("\t\t%s = %s.global_position - global_position" % [offset_var, camera_var])
	lines.append("\t\t%s = true" % ready_var)
	lines.append("\tvar _target_pos_%s = global_position + %s" % [chain_name, offset_var])
	lines.append("\tvar _desired_pos_%s = %s.global_position" % [chain_name, camera_var])
	if follow_pos_x:
		lines.append("\tif abs(_target_pos_%s.x - %s.global_position.x) > %.6f:" % [chain_name, camera_var, dead_zone_x])
		lines.append("\t\t_desired_pos_%s.x = _target_pos_%s.x" % [chain_name, chain_name])
	if follow_pos_y:
		lines.append("\tif abs(_target_pos_%s.y - %s.global_position.y) > %.6f:" % [chain_name, camera_var, dead_zone_y])
		lines.append("\t\t_desired_pos_%s.y = _target_pos_%s.y" % [chain_name, chain_name])
	lines.append("\t%s.global_position = %s.global_position.lerp(_desired_pos_%s, %.6f * _delta)" % [camera_var, camera_var, chain_name, follow_speed])
	if follow_rotation:
		lines.append("\tif %s:" % rot_source_var)
		lines.append("\t\t%s.global_rotation = lerp_angle(%s.global_rotation, %s.global_rotation, %.6f * _delta)" % [camera_var, camera_var, rot_source_var, rotation_speed])
	lines.append("elif not %s:" % camera_var)
	lines.append("\tpush_warning(\"Smooth Follow Camera 2D: No Camera2D assigned\")")
	return {"actuator_code": "\n".join(lines), "member_vars": member_vars}

func _append_find_node_helpers(member_vars: Array[String]) -> void:
	member_vars.append("")
	member_vars.append("func _lb_find_node_by_name_recursive(node: Node, target_name: String) -> Node:")
	member_vars.append("\tif node == null or target_name.is_empty():")
	member_vars.append("\t\treturn null")
	member_vars.append("\tif node.name == target_name:")
	member_vars.append("\t\treturn node")
	member_vars.append("\tfor child in node.get_children():")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(child, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn null")
	member_vars.append("")
	member_vars.append("func _lb_find_node_in_current_scene(target_name: String) -> Node:")
	member_vars.append("\tvar scene_root = get_tree().current_scene")
	member_vars.append("\tif scene_root:")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(scene_root, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn _lb_find_node_by_name_recursive(get_tree().root, target_name)")

func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")
