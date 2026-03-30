@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Screen Flash Actuator - One-shot color flash over the screen
## Requires a full-screen ColorRect in a CanvasLayer
## Assign it via @export — drag a ColorRect into the inspector


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Screen Flash"


func _initialize_properties() -> void:
	properties = {
		"color":        Color(1, 1, 1, 0.8),
		"duration":     "0.3",
		"fade_in":      "0.05",  # time to reach full color
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "color",
			"type": TYPE_COLOR,
			"default": Color(1, 1, 1, 0.8)
		},
		{
			"name": "duration",
			"type": TYPE_STRING,
			"default": "0.3"
		},
		{
			"name": "fade_in",
			"type": TYPE_STRING,
			"default": "0.05"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Flashes a color over the screen.\nRequires a full-screen ColorRect node assigned via inspector.\nUse a CanvasLayer with a ColorRect that covers the whole screen.",
		"color":    "Flash color. Use alpha to control intensity.\nWhite = damage flash, Red = hit, Black = fade to black.",
		"duration": "Total duration of the flash in seconds.",
		"fade_in":  "Time to reach full color. Keep short for snappy flashes.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var color = properties.get("color", Color(1, 1, 1, 0.8))
	if typeof(color) == TYPE_COLOR:
		pass  # already a Color
	else:
		color = Color(1, 1, 1, 0.8)

	var color_str = "Color(%.4f, %.4f, %.4f, %.4f)" % [color.r, color.g, color.b, color.a]
	var clear_str = "Color(%.4f, %.4f, %.4f, 0.0)" % [color.r, color.g, color.b]
	var duration  = _to_expr(properties.get("duration", "0.3"))
	var fade_in   = _to_expr(properties.get("fade_in",  "0.05"))


	# Use instance name if set, otherwise use brick name, sanitized for use as a variable
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name
	var flash_var = "_%s" % _export_label
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("@export var %s: ColorRect" % flash_var)

	code_lines.append("# Screen Flash Actuator")
	code_lines.append("if %s:" % flash_var)
	code_lines.append("\tvar _flash_tw_%s = create_tween()" % chain_name)
	code_lines.append("\t%s.color = %s" % [flash_var, clear_str])
	code_lines.append("\t%s.visible = true" % flash_var)
	code_lines.append("\t_flash_tw_%s.tween_property(%s, \"color\", %s, %s)" % [chain_name, flash_var, color_str, fade_in])
	code_lines.append("\t_flash_tw_%s.tween_property(%s, \"color\", %s, %s - %s)" % [chain_name, flash_var, clear_str, duration, fade_in])
	code_lines.append("\t_flash_tw_%s.finished.connect(func(): %s.visible = false)" % [chain_name, flash_var])
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Screen Flash Actuator: No ColorRect assigned to '%s' — drag one into the inspector\")" % flash_var)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
