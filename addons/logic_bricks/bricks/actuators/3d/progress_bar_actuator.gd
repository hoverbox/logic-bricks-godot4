@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Progress Bar Actuator - Control a ProgressBar, HSlider, VSlider, or any Range node
## Assign the node via @export (drag and drop in inspector)


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Progress Bar"


func _initialize_properties() -> void:
	properties = {
		"set_value":    true,
		"value":        "100.0",
		"set_min":      false,
		"min_value":    "0.0",
		"set_max":      false,
		"max_value":    "100.0",
		"transition":   false,
		"transition_speed": "5.0",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "set_value",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "value",
			"type": TYPE_STRING,
			"default": "100.0"
		},
		{
			"name": "set_min",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "min_value",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "set_max",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "max_value",
			"type": TYPE_STRING,
			"default": "100.0"
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
		"_description": "Sets the value, min, or max of a ProgressBar, HSlider, VSlider, or any Range node.\nDrag the node into the inspector slot.",
		"set_value":    "Enable to set the current value.",
		"value":        "The value to set. Accepts a number or variable name.\nExample: health  or  100.0  or  health / max_health * 100.0",
		"set_min":      "Enable to set the minimum value.",
		"min_value":    "Minimum value. Accepts a number or variable name.",
		"set_max":      "Enable to set the maximum value.",
		"max_value":    "Maximum value. Accepts a number or variable name.",
		"transition":   "Smoothly lerp the value to the target each frame.\nOnly applies to the value, not min/max.",
		"transition_speed": "Lerp speed. Higher = faster. Accepts a number or variable.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var set_value = properties.get("set_value", true)
	var value = _to_expr(properties.get("value", "100.0"))
	var set_min = properties.get("set_min", false)
	var min_value = _to_expr(properties.get("min_value", "0.0"))
	var set_max = properties.get("set_max", false)
	var max_value = _to_expr(properties.get("max_value", "100.0"))
	var transition = properties.get("transition", false)
	var speed = _to_expr(properties.get("transition_speed", "5.0"))


	# Use instance name if set, otherwise use brick name, sanitized for use as a variable
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name
	var bar_var = "_%s" % _export_label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("@export var %s: Range" % bar_var)

	code_lines.append("# Progress Bar Actuator")
	code_lines.append("if %s:" % bar_var)

	if set_min:
		code_lines.append("\t%s.min_value = %s" % [bar_var, min_value])
	if set_max:
		code_lines.append("\t%s.max_value = %s" % [bar_var, max_value])
	if set_value:
		if transition:
			code_lines.append("\t%s.value = lerpf(%s.value, %s, %s * _delta)" % [bar_var, bar_var, value, speed])
		else:
			code_lines.append("\t%s.value = %s" % [bar_var, value])

	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Progress Bar Actuator: No Range node assigned to '%s' — drag one into the inspector\")" % bar_var)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
