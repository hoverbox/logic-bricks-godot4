@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Parent 2D Actuator - Set or remove the parent of a 2D node.

func get_brick_info() -> Dictionary:
	return {
		"class": "Parent2DActuator",
		"name": "Parent",
		"type": "actuator",
		"category": "Object",
		"domain": "2d",
		"menu_order": 430,
	}

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Parent"

func _initialize_properties() -> void:
	properties = {
		"mode": "set_parent",
		"parent_target_mode": "node_name",
		"parent_node": "",
		"parent_group": "",
		"keep_transform": true,
	}

func get_property_definitions() -> Array:
	return [
		{"name":"mode","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Set Parent,Remove Parent","default":"set_parent"},
		{"name":"parent_target_mode","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Node Name,Group","default":"node_name","visible_if":{"mode":"set_parent"}},
		{"name":"parent_node","required":true,"required_label":"a parent node","required_if":{"mode":"set_parent","parent_target_mode":"node_name"},"type":TYPE_STRING,"default":"","visible_if":{"mode":"set_parent","parent_target_mode":"node_name"},"node_reference":true,"accepted_node_types":["Node"],"node_picker_scope":"scene"},
		{"name":"parent_group","required":true,"required_label":"a parent group","required_if":{"mode":"set_parent","parent_target_mode":"group"},"type":TYPE_STRING,"default":"","visible_if":{"mode":"set_parent","parent_target_mode":"group"},"group_picker":true},
		{"name":"keep_transform","type":TYPE_BOOL,"default":true},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Parents this 2D node to another scene node or the first node in a group, or removes its current parent.",
		"parent_target_mode": "Choose a specific scene node or the first node found in a group.",
		"parent_node": "Scene node to use as the new parent.",
		"parent_group": "Uses the first node found in this group as the new parent.",
		"keep_transform": "Keep the node in the same global position, rotation, and scale while reparenting.",
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode := str(properties.get("mode", "set_parent")).to_lower().replace(" ", "_")
	var target_mode := str(properties.get("parent_target_mode", "node_name")).to_lower().replace(" ", "_")
	var parent_node := str(properties.get("parent_node", "")).strip_edges()
	var parent_group := str(properties.get("parent_group", "")).strip_edges()
	var keep_transform := bool(properties.get("keep_transform", true))
	var lines: Array[String] = []

	if mode == "remove_parent":
		lines.append("# Parent 2D: reparent to the current scene root")
		lines.append("var _parent2d_scene_root = get_tree().current_scene")
		lines.append("if _parent2d_scene_root and get_parent() != _parent2d_scene_root:")
		lines.append("\treparent(_parent2d_scene_root, %s)" % str(keep_transform).to_lower())
		return {"actuator_code":"\n".join(lines)}

	if target_mode == "group":
		lines.append("var _parent2d_candidates = get_tree().get_nodes_in_group(\"%s\")" % parent_group.c_escape())
		lines.append("var _parent2d_target = _parent2d_candidates[0] if not _parent2d_candidates.is_empty() else null")
	else:
		lines.append("var _parent2d_target = null")
		lines.append("if get_tree().current_scene:")
		lines.append("\t_parent2d_target = get_tree().current_scene.find_child(\"%s\", true, false)" % parent_node.c_escape())
		lines.append("if _parent2d_target == null:")
		lines.append("\t_parent2d_target = get_tree().root.find_child(\"%s\", true, false)" % parent_node.c_escape())

	lines.append("if _parent2d_target and _parent2d_target != self:")
	lines.append("\treparent(_parent2d_target, %s)" % str(keep_transform).to_lower())
	lines.append("else:")
	lines.append("\tpush_warning(\"Parent 2D: parent target not found or target is self\")")
	return {"actuator_code":"\n".join(lines)}
