@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Modulate Actuator - Set or lerp the color/alpha of a CanvasItem (UI or 2D nodes)
## Assign the target UI node via @export (drag and drop in inspector)
## Works with Control, Label, Sprite2D, TextureRect, Panel, etc.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Modulate"


func _initialize_properties() -> void:
	properties = {
		"target_modulate": "self_modulate",
		"color":            Color(1, 1, 1, 1),
		"transition":       false,
		"transition_speed": "5.0",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_modulate",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Self Modulate,Modulate",
			"default": "self_modulate"
		},
		{
			"name": "color",
			"type": TYPE_COLOR,
			"default": Color(1, 1, 1, 1)
		},
		{
			"name": "transition",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "transition_speed",
			"type": TYPE_STRING,
			"default": "5.0"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Sets or smoothly transitions the color/alpha of a UI or 2D node.\nWorks with Control, Label, Sprite2D, TextureRect, Panel, etc.\n⚠ Adds @export in Inspector — assign your CanvasItem node.",
		"target_modulate": "Self Modulate: affects only this node, not children.\nModulate: affects this node and all children.",
		"color":           "Target color. Set alpha to 0 for fade out, 1 for fade in.",
		"transition":      "Smoothly lerp to the target color each frame.",
		"transition_speed":"Lerp speed. Higher = faster. Accepts a number or variable.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target     = properties.get("target_modulate", "self_modulate")
	var color      = properties.get("color", Color(1, 1, 1, 1))
	var transition = properties.get("transition", false)
	var speed      = _to_expr(properties.get("transition_speed", "5.0"))

	if typeof(target) == TYPE_STRING:
		target = target.to_lower().replace(" ", "_")

	if typeof(color) != TYPE_COLOR:
		color = Color(1, 1, 1, 1)

	# Use instance name if set, otherwise use brick name, sanitized for use as a variable
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name

	var node_var    = "_%s" % _export_label
	var color_str   = "Color(%.4f, %.4f, %.4f, %.4f)" % [color.r, color.g, color.b, color.a]
	var member_vars: Array[String] = []
	var code_lines:  Array[String] = []

	member_vars.append("@export var %s: CanvasItem" % node_var)

	if transition:
		# Store the target color in a member var so the lerp persists across frames,
		# even when the sensor fires for only a single frame (just_pressed, Delay, etc.).
		var target_var = "_%s_target_color" % _export_label
		member_vars.append("var %s: Color = Color(1.0000, 1.0000, 1.0000, 1.0000)" % target_var)

		# Actuator code: when the sensor fires, record the desired target color.
		code_lines.append("# Modulate Actuator")
		code_lines.append("if %s:" % node_var)
		code_lines.append("\t%s = %s" % [target_var, color_str])
		code_lines.append("else:")
		code_lines.append("\tpush_warning(\"Modulate Actuator: No CanvasItem assigned to '%s' — drag one into the inspector\")" % node_var)

		# Post-process code: lerp toward the stored target every frame regardless of sensor state.
		# Uses "delta" (not "_delta") because post_process lines are emitted inside
		# _process(delta) / _physics_process(delta), not inside a chain function.
		var post_line = "if %s: %s.%s = %s.%s.lerp(%s, %s * delta)" % [
			node_var, node_var, target, node_var, target, target_var, speed
		]

		return {
			"actuator_code": "\n".join(code_lines),
			"member_vars": member_vars,
			"post_process_code": [post_line],
		}
	else:
		code_lines.append("# Modulate Actuator")
		code_lines.append("if %s:" % node_var)
		code_lines.append("\t%s.%s = %s" % [node_var, target, color_str])
		code_lines.append("else:")
		code_lines.append("\tpush_warning(\"Modulate Actuator: No CanvasItem assigned to '%s' — drag one into the inspector\")" % node_var)

		return {
			"actuator_code": "\n".join(code_lines),
			"member_vars": member_vars,
		}


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "5.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
