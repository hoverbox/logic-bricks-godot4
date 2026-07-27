@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"


func get_brick_info() -> Dictionary:
	return {
		"class": "SaveLoad2DActuator",
		"name": "Save / Load",
		"type": "actuator",
		"category": "Game",
		"domain": "2d",
		"menu_order": 700,
	}


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Save / Load"


func _initialize_properties() -> void:
	properties = {
		"mode": "save",
		"scope": "this_node",
		"target": "",
		"slot": "slot1",
		"save_position": true,
		"save_rotation": true,
		"save_variables": true,
		"restore_velocity": false,
	}


func get_property_definitions() -> Array:
	return [
		{"name": "mode", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Save,Load", "default": "save"},
		{"name": "scope", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "This Node,Target Node,Group", "default": "this_node"},
		{"name": "target", "type": TYPE_STRING, "default": ""},
		{"name": "slot", "type": TYPE_STRING, "default": "slot1"},
		{"name": "save_position", "type": TYPE_BOOL, "default": true},
		{"name": "save_rotation", "type": TYPE_BOOL, "default": true},
		{"name": "save_variables", "type": TYPE_BOOL, "default": true},
		{
			"name": "restore_velocity",
			"type": TYPE_BOOL,
			"default": false,
			"tooltip": "When loading a RigidBody2D, restore the saved linear and angular velocity. When disabled, loading stops the body at the saved transform.",
		},
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode := str(properties.get("mode", "save")).to_lower()
	var scope := str(properties.get("scope", "this_node")).to_lower().replace(" ", "_")
	var target := _gd(str(properties.get("target", "")))
	var slot := str(properties.get("slot", "slot1"))
	var slot_regex := RegEx.new()
	slot_regex.compile("[^A-Za-z0-9_-]")
	slot = slot_regex.sub(slot, "_", true)
	if slot.is_empty():
		slot = "slot1"

	var save_path := "user://saves/%s_2d.json" % slot
	var save_position := bool(properties.get("save_position", true))
	var save_rotation := bool(properties.get("save_rotation", true))
	var save_variables := bool(properties.get("save_variables", true))
	var restore_velocity := bool(properties.get("restore_velocity", false))
	var lines: Array[String] = [
		"DirAccess.make_dir_recursive_absolute(\"user://saves\")",
		"var _sl2_nodes: Array[Node] = []",
	]

	if scope == "group":
		lines.append("_sl2_nodes.assign(get_tree().get_nodes_in_group(\"%s\"))" % target)
	elif scope == "target_node":
		lines.append("var _sl2_target = get_tree().current_scene.find_child(\"%s\", true, false) if get_tree().current_scene else null" % target)
		lines.append("if _sl2_target:")
		lines.append("\t_sl2_nodes.append(_sl2_target)")
	else:
		lines.append("_sl2_nodes.append(self)")

	if mode == "save":
		lines.append("var _sl2_data: Dictionary = {}")
		lines.append("for _sl2_n in _sl2_nodes:")
		lines.append("\tif not _sl2_n is Node2D:")
		lines.append("\t\tcontinue")
		lines.append("\tvar _sl2_d: Dictionary = {}")
		if save_position:
			lines.append("\t_sl2_d[\"position\"] = {\"x\": _sl2_n.global_position.x, \"y\": _sl2_n.global_position.y}")
		if save_rotation:
			lines.append("\t_sl2_d[\"rotation\"] = _sl2_n.global_rotation")
		lines.append("\tif _sl2_n is RigidBody2D:")
		lines.append("\t\t_sl2_d[\"linear_velocity\"] = {\"x\": _sl2_n.linear_velocity.x, \"y\": _sl2_n.linear_velocity.y}")
		lines.append("\t\t_sl2_d[\"angular_velocity\"] = _sl2_n.angular_velocity")
		if save_variables:
			lines.append("\tvar _sl2_v: Dictionary = {}")
			lines.append("\tif _sl2_n.get_script():")
			lines.append("\t\tfor _p in _sl2_n.get_script().get_script_property_list():")
			lines.append("\t\t\tvar _pn = str(_p.get(\"name\", \"\"))")
			lines.append("\t\t\tif _pn.begins_with(\"_\"):")
			lines.append("\t\t\t\tcontinue")
			lines.append("\t\t\tvar _pv = _sl2_n.get(_pn)")
			lines.append("\t\t\tif _pv is int or _pv is float or _pv is bool or _pv is String:")
			lines.append("\t\t\t\t_sl2_v[_pn] = _pv")
			lines.append("\t_sl2_d[\"variables\"] = _sl2_v")
		lines.append("\t_sl2_data[str(_sl2_n.get_path())] = _sl2_d")
		lines.append("var _sl2_file = FileAccess.open(\"%s\", FileAccess.WRITE)" % save_path)
		lines.append("if _sl2_file:")
		lines.append("\t_sl2_file.store_string(JSON.stringify(_sl2_data))")
		lines.append("\t_sl2_file.close()")
	else:
		lines.append("if FileAccess.file_exists(\"%s\"):" % save_path)
		lines.append("\tvar _sl2_json = JSON.parse_string(FileAccess.get_file_as_string(\"%s\"))" % save_path)
		lines.append("\tif _sl2_json is Dictionary:")
		lines.append("\t\tfor _sl2_path in _sl2_json:")
		lines.append("\t\t\tvar _sl2_n = get_node_or_null(NodePath(_sl2_path))")
		lines.append("\t\t\tif not _sl2_n is Node2D:")
		lines.append("\t\t\t\tcontinue")
		lines.append("\t\t\tvar _sl2_d = _sl2_json[_sl2_path]")
		lines.append("\t\t\tvar _sl2_saved_position = _sl2_n.global_position")
		lines.append("\t\t\tvar _sl2_saved_rotation = _sl2_n.global_rotation")
		if save_position:
			lines.append("\t\t\tif _sl2_d.has(\"position\"):")
			lines.append("\t\t\t\t_sl2_saved_position = Vector2(float(_sl2_d.position.x), float(_sl2_d.position.y))")
		if save_rotation:
			lines.append("\t\t\tif _sl2_d.has(\"rotation\"):")
			lines.append("\t\t\t\t_sl2_saved_rotation = float(_sl2_d.rotation)")
		lines.append("\t\t\tif _sl2_n is RigidBody2D:")
		lines.append("\t\t\t\t_sl2_n.sleeping = false")
		lines.append("\t\t\t\t_sl2_n.linear_velocity = Vector2.ZERO")
		lines.append("\t\t\t\t_sl2_n.angular_velocity = 0.0")
		lines.append("\t\t\t\t_sl2_n.global_transform = Transform2D(_sl2_saved_rotation, _sl2_saved_position)")
		if restore_velocity:
			lines.append("\t\t\t\tif _sl2_d.has(\"linear_velocity\"):")
			lines.append("\t\t\t\t\t_sl2_n.linear_velocity = Vector2(float(_sl2_d.linear_velocity.x), float(_sl2_d.linear_velocity.y))")
			lines.append("\t\t\t\tif _sl2_d.has(\"angular_velocity\"):")
			lines.append("\t\t\t\t\t_sl2_n.angular_velocity = float(_sl2_d.angular_velocity)")
		lines.append("\t\t\telse:")
		lines.append("\t\t\t\t_sl2_n.global_transform = Transform2D(_sl2_saved_rotation, _sl2_saved_position)")
		if save_variables:
			lines.append("\t\t\tif _sl2_d.has(\"variables\"):")
			lines.append("\t\t\t\tfor _vn in _sl2_d.variables:")
			lines.append("\t\t\t\t\t_sl2_n.set(_vn, _sl2_d.variables[_vn])")

	return {"actuator_code": "\n".join(lines)}


func _gd(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")
