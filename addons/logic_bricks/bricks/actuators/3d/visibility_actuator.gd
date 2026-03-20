@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Visibility Actuator - Show or hide any node
## Works with CanvasItem (UI/2D) via visible property
## Works with Node3D via visible property
## Can also target a specific node via @export, or apply to self


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Visibility"


func _initialize_properties() -> void:
	properties = {
		"action":      "show",   # show, hide, toggle
		"target_mode": "self",   # self, node
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Show,Hide,Toggle",
			"default": "show"
		},
		{
			"name": "target_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Self,Node",
			"default": "self"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Shows, hides, or toggles visibility of a node.\nWorks with Node3D, Control, Sprite2D, and any other node with a visible property.",
		"action":      "Show: set visible = true\nHide: set visible = false\nToggle: flip current visibility",
		"target_mode": "Self: apply to the node this script is on.\nNode: apply to an assigned node via inspector.\n⚠ Node mode adds @export in inspector.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var action = properties.get("action", "show")
	var target_mode = properties.get("target_mode", "self")

	if typeof(action) == TYPE_STRING:
		action = action.to_lower()
	if typeof(target_mode) == TYPE_STRING:
		target_mode = target_mode.to_lower()

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	if target_mode == "node":
		# Use instance name if set, otherwise use brick name, sanitized for use as a variable
		var _export_label = instance_name if not instance_name.is_empty() else brick_name
		_export_label = _export_label.to_lower().replace(" ", "_")
		var _regex = RegEx.new()
		_regex.compile("[^a-z0-9_]")
		_export_label = _regex.sub(_export_label, "", true)
		if _export_label.is_empty():
			_export_label = chain_name
		var vis_var = "_%s" % _export_label
		member_vars.append("@export var %s: Node" % vis_var)
		code_lines.append("# Visibility Actuator")
		code_lines.append("if %s:" % vis_var)
		match action:
			"show":
				code_lines.append("\t%s.visible = true" % vis_var)
			"hide":
				code_lines.append("\t%s.visible = false" % vis_var)
			"toggle":
				code_lines.append("\t%s.visible = not %s.visible" % [vis_var, vis_var])
		code_lines.append("else:")
		code_lines.append("\tpush_warning(\"Visibility Actuator: No node assigned to '%s' — drag one into the inspector\")" % vis_var)
	else:
		code_lines.append("# Visibility Actuator")
		match action:
			"show":
				code_lines.append("visible = true")
			"hide":
				code_lines.append("visible = false")
			"toggle":
				code_lines.append("visible = not visible")

	var result = {"actuator_code": "\n".join(code_lines)}
	if member_vars.size() > 0:
		result["member_vars"] = member_vars
	return result
