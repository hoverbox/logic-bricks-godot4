@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Screen Flash Actuator - One-shot color flash over the screen.
## When you press "Apply Code", the plugin automatically creates the required
## CanvasLayer + ColorRect in the scene — no manual setup needed.
##
## At runtime the actuator checks whether the current viewport is a SubViewport
## (i.e. the scene is running in split-screen). If it is, it finds the
## SubViewportContainer and its parent CanvasLayer, then places a sized
## ColorRect directly in that CanvasLayer at the container's exact pixel rect —
## so only that camera's region flashes. If no SubViewport is detected it falls
## back to the pre-created full-screen CanvasLayer as normal.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Screen Flash"


func _initialize_properties() -> void:
	properties = {
		"color":    Color(1, 0, 0, 0.8),
		"duration": "0.3",
		"fade_in":  "0.05",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name":    "color",
			"type":    TYPE_COLOR,
			"default": Color(1, 0, 0, 0.8)
		},
		{
			"name":    "duration",
			"type":    TYPE_STRING,
			"default": "0.3"
		},
		{
			"name":    "fade_in",
			"type":    TYPE_STRING,
			"default": "0.05"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Flashes a color over the screen.\nPress \"Apply Code\" and the plugin creates the required nodes automatically.\nWorks automatically in both standard and split-screen setups.",
		"color":    "Flash color. Use alpha to control intensity.\nRed = damage flash, White = hit, Black = fade to black.",
		"duration": "Total duration of the flash in seconds.",
		"fade_in":  "Time to reach full color. Keep short for snappy flashes.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	# -- Resolve property values
	var color = properties.get("color", Color(1, 0, 0, 0.8))
	if typeof(color) != TYPE_COLOR:
		color = Color(1, 0, 0, 0.8)

	var color_str = "Color(%.4f, %.4f, %.4f, %.4f)" % [color.r, color.g, color.b, color.a]
	var clear_str = "Color(%.4f, %.4f, %.4f, 0.0)"  % [color.r, color.g, color.b]
	var duration  = _to_expr(properties.get("duration", "0.3"))
	var fade_in   = _to_expr(properties.get("fade_in",  "0.05"))

	# -- Build a unique sanitized variable stem
	var _label = instance_name if not instance_name.is_empty() else brick_name
	_label = _label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_label = _regex.sub(_label, "", true)
	if _label.is_empty():
		_label = chain_name
	var flash_var  = "_%s_rect"  % _label
	var layer_name = "__FlashLayer_%s" % flash_var
	var overlay_name = "__FlashOverlay_%s" % _label

	# Unique per-chain helper var names to avoid collisions if multiple
	# flash actuators exist in the same generated script.
	var vp_var   = "_fvp_%s"   % chain_name
	var svc_var  = "_fsvc_%s"  % chain_name
	var cl_var   = "_fcl_%s"   % chain_name
	var rect_var = "_frect_%s" % chain_name
	var tw_var   = "_flash_tw_%s" % chain_name

	var code_lines: Array[String] = []
	code_lines.append("# Screen Flash Actuator")

	# Detect whether this node is running inside a SubViewport (split-screen).
	# get_viewport() on a node inside a SubViewport returns that SubViewport,
	# so we check if it IS a SubViewport to know we're in split-screen.
	code_lines.append("var %s = get_viewport()" % vp_var)
	code_lines.append("if %s is SubViewport:" % vp_var)

	# --- Split-screen path ---
	# Walk up from the SubViewport to find its SubViewportContainer, then
	# find the CanvasLayer that owns the container. Place a ColorRect in that
	# CanvasLayer at the container's exact pixel position and size.
	code_lines.append("\t# Split-screen: overlay only this viewport's region")
	code_lines.append("\tvar %s: SubViewportContainer = null" % svc_var)
	code_lines.append("\tvar _fp_%s = %s.get_parent()" % [chain_name, vp_var])
	code_lines.append("\twhile is_instance_valid(_fp_%s):" % chain_name)
	code_lines.append("\t\tif _fp_%s is SubViewportContainer:" % chain_name)
	code_lines.append("\t\t\t%s = _fp_%s as SubViewportContainer" % [svc_var, chain_name])
	code_lines.append("\t\t\tbreak")
	code_lines.append("\t\t_fp_%s = _fp_%s.get_parent()" % [chain_name, chain_name])
	code_lines.append("\tvar %s: CanvasLayer = null" % cl_var)
	code_lines.append("\tif is_instance_valid(%s):" % svc_var)
	code_lines.append("\t\tvar _fclp_%s = %s.get_parent()" % [chain_name, svc_var])
	code_lines.append("\t\twhile is_instance_valid(_fclp_%s):" % chain_name)
	code_lines.append("\t\t\tif _fclp_%s is CanvasLayer:" % chain_name)
	code_lines.append("\t\t\t\t%s = _fclp_%s as CanvasLayer" % [cl_var, chain_name])
	code_lines.append("\t\t\t\tbreak")
	code_lines.append("\t\t\t_fclp_%s = _fclp_%s.get_parent()" % [chain_name, chain_name])
	code_lines.append("\tif is_instance_valid(%s) and is_instance_valid(%s):" % [svc_var, cl_var])
	# Reuse or create the overlay ColorRect as a sibling of the container
	# inside the same CanvasLayer.
	code_lines.append("\t\tvar %s = %s.get_node_or_null(\"%s\") as ColorRect" % [rect_var, cl_var, overlay_name])
	code_lines.append("\t\tif not is_instance_valid(%s):" % rect_var)
	code_lines.append("\t\t\t%s = ColorRect.new()" % rect_var)
	code_lines.append("\t\t\t%s.name = \"%s\"" % [rect_var, overlay_name])
	code_lines.append("\t\t\t%s.mouse_filter = Control.MOUSE_FILTER_IGNORE" % rect_var)
	code_lines.append("\t\t\t%s.z_index = 100" % rect_var)
	code_lines.append("\t\t\t%s.add_child(%s)" % [cl_var, rect_var])
	# Use explicit position + size — NOT anchors. Inside a CanvasLayer,
	# anchors always resolve to the full viewport, not the container's bounds.
	code_lines.append("\t\t%s.anchor_left   = 0.0" % rect_var)
	code_lines.append("\t\t%s.anchor_top    = 0.0" % rect_var)
	code_lines.append("\t\t%s.anchor_right  = 0.0" % rect_var)
	code_lines.append("\t\t%s.anchor_bottom = 0.0" % rect_var)
	code_lines.append("\t\t%s.position = %s.position" % [rect_var, svc_var])
	code_lines.append("\t\t%s.size     = %s.size" % [rect_var, svc_var])
	code_lines.append("\t\tvar %s = create_tween()" % tw_var)
	code_lines.append("\t\t%s.color = %s" % [rect_var, clear_str])
	code_lines.append("\t\t%s.visible = true" % rect_var)
	code_lines.append("\t\t%s.tween_property(%s, \"color\", %s, %s)" % [tw_var, rect_var, color_str, fade_in])
	code_lines.append("\t\t%s.tween_property(%s, \"color\", %s, %s - %s)" % [tw_var, rect_var, clear_str, duration, fade_in])
	code_lines.append("\t\t%s.finished.connect(func(): %s.visible = false)" % [tw_var, rect_var])
	code_lines.append("\telse:")
	code_lines.append("\t\tpush_warning(\"Screen Flash Actuator: could not find SubViewportContainer or its CanvasLayer\")")

	# --- Standard / full-screen path ---
	code_lines.append("else:")
	code_lines.append("\t# Standard: use the pre-created full-screen CanvasLayer")
	code_lines.append("\tvar %s = (get_tree().current_scene.get_node_or_null(\"%s/ColorRect\") as ColorRect)" % [flash_var, layer_name])
	code_lines.append("\tif is_instance_valid(%s):" % flash_var)
	code_lines.append("\t\t%s.anchor_left   = 0.0" % flash_var)
	code_lines.append("\t\t%s.anchor_top    = 0.0" % flash_var)
	code_lines.append("\t\t%s.anchor_right  = 1.0" % flash_var)
	code_lines.append("\t\t%s.anchor_bottom = 1.0" % flash_var)
	code_lines.append("\t\t%s.offset_left   = 0.0" % flash_var)
	code_lines.append("\t\t%s.offset_top    = 0.0" % flash_var)
	code_lines.append("\t\t%s.offset_right  = 0.0" % flash_var)
	code_lines.append("\t\t%s.offset_bottom = 0.0" % flash_var)
	code_lines.append("\t\tvar %s = create_tween()" % tw_var)
	code_lines.append("\t\t%s.color = %s" % [flash_var, clear_str])
	code_lines.append("\t\t%s.visible = true" % flash_var)
	code_lines.append("\t\t%s.tween_property(%s, \"color\", %s, %s)" % [tw_var, flash_var, color_str, fade_in])
	code_lines.append("\t\t%s.tween_property(%s, \"color\", %s, %s - %s)" % [tw_var, flash_var, clear_str, duration, fade_in])
	code_lines.append("\t\t%s.finished.connect(func(): %s.visible = false)" % [tw_var, flash_var])
	code_lines.append("\telse:")
	code_lines.append("\t\tpush_warning(\"Screen Flash Actuator: ColorRect not found at '%s/ColorRect' — re-apply code to auto-create it\")" % layer_name)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars":   [],
		"scene_setup": {
			"type":        "ScreenFlash",
			"flash_var":   flash_var,
			"camera_name": "",
			"full_screen": true,
		},
	}


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
