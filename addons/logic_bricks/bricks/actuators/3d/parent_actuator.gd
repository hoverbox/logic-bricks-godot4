@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Parent Actuator - Set or remove parent of this node
## Similar to UPBGE's Parent actuator

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Parent"


func _initialize_properties() -> void:
	properties = {
		"mode": "set_parent",       # set_parent, remove_parent
		"parent_target_mode": "node_name", # node_name, group
		"parent_node": "",          # Node name to search for as new parent
		"parent_group": "",         # Group to use as new parent
		"keep_transform": true      # Keep global transform when reparenting
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Set Parent,Remove Parent",
			"default": "set_parent"
		},
		{
			"name": "parent_target_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Node Name,Group",
			"default": "node_name",
			"visible_if": {"mode": "set_parent"}
		},
		{
			"name": "parent_node", "required": true, "required_label": "a parent node", "required_if": {"mode": "set_parent", "parent_target_mode": "node_name"},
			"type": TYPE_STRING,
			"default": "",
			"visible_if": {"mode": "set_parent", "parent_target_mode": "node_name"},
			"node_reference": true,
			"accepted_node_types": ["Node"],
			"node_picker_scope": "scene"
		},
		{
			"name": "parent_group", "required": true, "required_label": "a parent group", "required_if": {"mode": "set_parent", "parent_target_mode": "group"},
			"type": TYPE_STRING,
			"default": "",
			"visible_if": {"mode": "set_parent", "parent_target_mode": "group"},
			"group_picker": true
		},
		{
			"name": "keep_transform",
			"type": TYPE_BOOL,
			"default": true
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "set_parent")
	var parent_target_mode = str(properties.get("parent_target_mode", "node_name")).to_lower().replace(" ", "_")
	var parent_node = str(properties.get("parent_node", "")).strip_edges()
	var parent_group = str(properties.get("parent_group", "")).strip_edges()
	var keep_transform = properties.get("keep_transform", true)

	# Normalize mode
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")

	var code_lines: Array[String] = []

	match mode:
		"set_parent":
			var target_value = parent_group if parent_target_mode == "group" else parent_node
			if target_value.is_empty():
				code_lines.append("push_warning(\"Parent Actuator: No parent target specified\")")
			else:
				if parent_target_mode == "group":
					code_lines.append("# Use the first node in the selected parent group")
					code_lines.append("var _parent_candidates = get_tree().get_nodes_in_group(\"%s\")" % parent_group.c_escape())
					code_lines.append("var _new_parent = _parent_candidates[0] if not _parent_candidates.is_empty() else null")
				else:
					code_lines.append("# Search the full scene tree for parent node: %s" % parent_node)
					code_lines.append("var _new_parent = get_tree().root.find_child(\"%s\", true, false)" % parent_node.c_escape())
				code_lines.append("if _new_parent:")
				code_lines.append("\tvar _old_parent = get_parent()")
				code_lines.append("\tif _old_parent:")
				if keep_transform:
					code_lines.append("\t\t# Store global transform")
					code_lines.append("\t\tvar _global_pos = global_position")
					code_lines.append("\t\tvar _global_rot = global_rotation")
					code_lines.append("\t\tvar _global_scale = global_transform.basis.get_scale()")
					code_lines.append("\t\t")
					code_lines.append("\t\t# Reparent")
					code_lines.append("\t\t_old_parent.remove_child(self)")
					code_lines.append("\t\t_new_parent.add_child(self)")
					code_lines.append("\t\t")
					code_lines.append("\t\t# Restore global transform")
					code_lines.append("\t\tglobal_position = _global_pos")
					code_lines.append("\t\tglobal_rotation = _global_rot")
					code_lines.append("\t\t# Compute local scale to match original global scale under the new parent")
					code_lines.append("\t\tvar _parent_scale = _new_parent.global_transform.basis.get_scale()")
					code_lines.append("\t\tscale = Vector3(_global_scale.x / _parent_scale.x, _global_scale.y / _parent_scale.y, _global_scale.z / _parent_scale.z)")
				else:
					code_lines.append("\t\t# Reparent without preserving transform")
					code_lines.append("\t\t_old_parent.remove_child(self)")
					code_lines.append("\t\t_new_parent.add_child(self)")
				code_lines.append("else:")
				code_lines.append("\tpush_warning(\"Parent Actuator: Parent target not found\")")

		"remove_parent":
			code_lines.append("# Remove parent (reparent to scene root)")
			code_lines.append("var _current_parent = get_parent()")
			code_lines.append("if _current_parent:")
			code_lines.append("\tvar _scene_root = get_tree().root")
			if keep_transform:
				code_lines.append("\t")
				code_lines.append("\t# Store global transform")
				code_lines.append("\tvar _global_pos = global_position")
				code_lines.append("\tvar _global_rot = global_rotation")
				code_lines.append("\tvar _global_scale = global_transform.basis.get_scale()")
				code_lines.append("\t")
				code_lines.append("\t# Reparent to root")
				code_lines.append("\t_current_parent.remove_child(self)")
				code_lines.append("\t_scene_root.add_child(self)")
				code_lines.append("\t")
				code_lines.append("\t# Restore global transform")
				code_lines.append("\tglobal_position = _global_pos")
				code_lines.append("\tglobal_rotation = _global_rot")
				code_lines.append("\t# Scene root scale is always (1,1,1) so saved global scale becomes local scale")
				code_lines.append("\tscale = _global_scale")
			else:
				code_lines.append("\t# Reparent to root without preserving transform")
				code_lines.append("\t_current_parent.remove_child(self)")
				code_lines.append("\t_scene_root.add_child(self)")
			code_lines.append("else:")
			code_lines.append("\tpush_warning(\"Parent Actuator: Node has no parent to remove\")")

		_:
			code_lines.append("push_warning(\"Parent Actuator: Unknown mode '%s'\")" % mode)

	return {
		"actuator_code": "\n".join(code_lines)
	}
