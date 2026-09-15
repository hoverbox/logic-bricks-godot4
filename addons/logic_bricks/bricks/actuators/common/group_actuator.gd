@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Group Actuator - Add, remove, or change a node's group membership.
## Shared by 2D and 3D Logic Bricks.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Group"


func get_brick_info() -> Dictionary:
	return {
		"class": "GroupActuator",
		"name": "Group",
		"type": "actuator",
		"category": "Object",
		"domain": "common",
		"description": "Add, remove, or change a node's group membership.",
		"menu_order": 250,
	}


func _initialize_properties() -> void:
	properties = {
		"mode": "add",
		"target_node": "",
		"group_name": "",
		"from_group": "",
		"to_group": "",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Add:add,Remove:remove,Change:change",
			"default": "add",
		},
		{
			"name": "target_node",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Blank = Self",
			"node_reference": true,
		},
		{
			"name": "group_name",
			"required": true,
			"required_label": "a group name",
			"required_if": {"mode": ["add", "remove"]},
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Enter group name",
			"group_picker": true,
			"visible_if": {"mode": ["add", "remove"]},
		},
		{
			"name": "from_group",
			"required": true,
			"required_label": "the group to remove",
			"required_if": {"mode": "change"},
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Current group",
			"group_picker": true,
			"visible_if": {"mode": "change"},
		},
		{
			"name": "to_group",
			"required": true,
			"required_label": "the new group",
			"required_if": {"mode": "change"},
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "New group",
			"group_picker": true,
			"visible_if": {"mode": "change"},
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Changes group membership at runtime. Works in both 2D and 3D. Leave Target Node blank to affect the node that owns these Logic Bricks.",
		"mode": "Add: add the target to a group.\nRemove: remove the target from a group.\nChange: remove one group and add another.",
		"target_node": "Leave blank to use Self. Otherwise type, Ctrl-drag, or choose a child node beneath this Logic Bricks node.",
		"group_name": "The group to add or remove. Type a new name or choose an existing project group.",
		"from_group": "The group to remove when changing membership.",
		"to_group": "The group to add when changing membership. You can type a new group name.",
	}


func generate_code(_node: Node, _chain_name: String) -> Dictionary:
	var mode := str(properties.get("mode", "add")).strip_edges().to_lower().replace(" ", "_")
	var target_node := str(properties.get("target_node", "")).strip_edges()
	var group_name := str(properties.get("group_name", "")).strip_edges()
	var from_group := str(properties.get("from_group", "")).strip_edges()
	var to_group := str(properties.get("to_group", "")).strip_edges()

	var label := _unique_label(_chain_name)
	var target_var := "_group_target_%s" % label

	var code_lines: Array[String] = []
	code_lines.append("# Group Actuator")
	if target_node.is_empty():
		code_lines.append("var %s: Node = self" % target_var)
	else:
		code_lines.append("var %s: Node = find_child(\"%s\", true, false)" % [target_var, _gd_string(target_node)])

	code_lines.append("if %s == null:" % target_var)
	code_lines.append("\tpush_warning(\"Group Actuator: target node not found\")")
	code_lines.append("else:")

	match mode:
		"add":
			if group_name.is_empty():
				code_lines.append("\tpush_warning(\"Group Actuator: no group name set\")")
			else:
				code_lines.append("\t%s.add_to_group(\"%s\")" % [target_var, _gd_string(group_name)])
		"remove":
			if group_name.is_empty():
				code_lines.append("\tpush_warning(\"Group Actuator: no group name set\")")
			else:
				code_lines.append("\tif %s.is_in_group(\"%s\"):" % [target_var, _gd_string(group_name)])
				code_lines.append("\t\t%s.remove_from_group(\"%s\")" % [target_var, _gd_string(group_name)])
		"change":
			if from_group.is_empty() or to_group.is_empty():
				code_lines.append("\tpush_warning(\"Group Actuator: Change requires both From Group and To Group\")")
			else:
				code_lines.append("\tif %s.is_in_group(\"%s\"):" % [target_var, _gd_string(from_group)])
				code_lines.append("\t\t%s.remove_from_group(\"%s\")" % [target_var, _gd_string(from_group)])
				code_lines.append("\t%s.add_to_group(\"%s\")" % [target_var, _gd_string(to_group)])
		_:
			code_lines.append("\tpush_warning(\"Group Actuator: unknown mode\")")

	return {
		"actuator_code": "\n".join(code_lines),
	}
