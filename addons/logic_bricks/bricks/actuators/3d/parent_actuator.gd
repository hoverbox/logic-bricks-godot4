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
		"parent_node": "",          # Node path to new parent
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
			"name": "parent_node",
			"type": TYPE_STRING,
			"default": "",
			"visible_if": {"mode": "set_parent"}
		},
		{
			"name": "keep_transform",
			"type": TYPE_BOOL,
			"default": true
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "set_parent")
	var parent_node = properties.get("parent_node", "")
	var keep_transform = properties.get("keep_transform", true)
	
	# Normalize mode
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")
	
	var code_lines: Array[String] = []
	
	match mode:
		"set_parent":
			if parent_node.is_empty():
				code_lines.append("push_warning(\"Parent Actuator: No parent node specified\")")
			else:
				code_lines.append("# Set parent to: %s" % parent_node)
				code_lines.append("var _new_parent = get_node_or_null(\"%s\")" % parent_node)
				code_lines.append("if _new_parent:")
				code_lines.append("\tvar _old_parent = get_parent()")
				code_lines.append("\tif _old_parent:")
				if keep_transform:
					code_lines.append("\t\t# Store global transform")
					code_lines.append("\t\tvar _global_pos = global_position")
					code_lines.append("\t\tvar _global_rot = global_rotation")
					code_lines.append("\t\tvar _global_scale = scale")
					code_lines.append("\t\t")
					code_lines.append("\t\t# Reparent")
					code_lines.append("\t\t_old_parent.remove_child(self)")
					code_lines.append("\t\t_new_parent.add_child(self)")
					code_lines.append("\t\t")
					code_lines.append("\t\t# Restore global transform")
					code_lines.append("\t\tglobal_position = _global_pos")
					code_lines.append("\t\tglobal_rotation = _global_rot")
					code_lines.append("\t\tscale = _global_scale")
				else:
					code_lines.append("\t\t# Reparent without preserving transform")
					code_lines.append("\t\t_old_parent.remove_child(self)")
					code_lines.append("\t\t_new_parent.add_child(self)")
				code_lines.append("else:")
				code_lines.append("\tpush_warning(\"Parent Actuator: Parent node '%s' not found\")" % parent_node)
		
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
				code_lines.append("\tvar _global_scale = scale")
				code_lines.append("\t")
				code_lines.append("\t# Reparent to root")
				code_lines.append("\t_current_parent.remove_child(self)")
				code_lines.append("\t_scene_root.add_child(self)")
				code_lines.append("\t")
				code_lines.append("\t# Restore global transform")
				code_lines.append("\tglobal_position = _global_pos")
				code_lines.append("\tglobal_rotation = _global_rot")
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
