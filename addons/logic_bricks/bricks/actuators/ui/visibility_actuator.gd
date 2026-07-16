@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Visibility Actuator - Show, hide, or toggle a node by name.
## Uses the same node-name lookup pattern as the Text Actuator.
## Type the node name you want affected, or use "self" to affect the node this generated script is attached to.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Visibility"



func get_brick_info() -> Dictionary:
	return {
		"class": "UIVisibilityActuator",
		"name": "Visibility",
		"type": "actuator",
		"category": "UI",
		"description": "Shows, hides, or toggles a UI node.",
		"menu_order": 130,
		"domain": "ui"
	}

func _initialize_properties() -> void:
	properties = {
		"target_node_name": "self",
		"action": "show",   # show, hide, toggle
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_node_name",
			"type": TYPE_STRING,
			"default": "self",
			"placeholder": "Node name"
		},
		{
			"name": "action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Show,Hide,Toggle",
			"default": "show"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Shows, hides, or toggles visibility of a node by name. Uses the same current-scene recursive name lookup as the Text Actuator.",
		"target_node_name": "Type the node name to show/hide/toggle. Use \"self\" to affect the scripted node and its children.",
		"action": "Show: set visible = true\nHide: set visible = false\nToggle: flip current visibility",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "self")).strip_edges()
	var action = properties.get("action", "show")

	if typeof(action) == TYPE_STRING:
		action = action.to_lower()

	var label = _unique_label(chain_name)
	var vis_var = "_%s" % label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("var %s: Node = null" % vis_var)
	_append_find_node_helpers(member_vars)

	code_lines.append("# Visibility Actuator")
	code_lines.append("var _target_name_%s = \"%s\"" % [label, _gd_string(target_node_name)])
	code_lines.append("if _target_name_%s.strip_edges().to_lower() == \"self\":" % label)
	code_lines.append("\t%s = self" % vis_var)
	code_lines.append("elif %s == null or %s.name != _target_name_%s:" % [vis_var, vis_var, label])
	code_lines.append("\t%s = _lb_find_node_in_current_scene(_target_name_%s)" % [vis_var, label])
	code_lines.append("if %s:" % vis_var)
	code_lines.append("\tif %s is Node3D or %s is CanvasItem:" % [vis_var, vis_var])
	match action:
		"show":
			code_lines.append("\t\t%s.visible = true" % vis_var)
		"hide":
			code_lines.append("\t\t%s.visible = false" % vis_var)
		"toggle":
			code_lines.append("\t\t%s.visible = not %s.visible" % [vis_var, vis_var])
		_:
			code_lines.append("\t\tpush_warning(\"Visibility Actuator: Unknown action '%s'\")" % _gd_string(str(action)))
	code_lines.append("\telse:")
	code_lines.append("\t\tpush_warning(\"Visibility Actuator: found node is not a visible Node3D or CanvasItem\")")
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Visibility Actuator: could not find node named '\" + str(_target_name_%s) + \"'\")" % label)

	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}


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


func _unique_label(chain_name: String) -> String:
	var label = instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	label = label.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	return label if not label.is_empty() else chain_name


func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")
