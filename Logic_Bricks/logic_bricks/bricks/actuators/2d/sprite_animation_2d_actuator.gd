@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Sprite Animation 2D Actuator - Play, stop, or pause AnimatedSprite2D animations.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Sprite Animation"

func get_brick_info() -> Dictionary:
	return {
		"class": "SpriteAnimation2DActuator",
		"name": "Sprite Animation",
		"type": "actuator",
		"category": "Animation",
		"description": "Play, stop, or pause AnimatedSprite2D animations.",
		"menu_order": 300,
		"domain": "2d",
	}

func _initialize_properties() -> void:
	properties = {
		"mode": "play",
		"animation_name": "",
		"speed_scale": "1.0",
		"target_node": "",
	}

func get_property_definitions() -> Array:
	return [
		{"name": "mode", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Play,Stop,Pause", "default": "play"},
		{"name": "animation_name", "type": TYPE_STRING, "hint": PROPERTY_HINT_NONE, "default": ""},
		{"name": "speed_scale", "type": TYPE_STRING, "default": "1.0"},
		{"name": "target_node", "type": TYPE_STRING, "hint": PROPERTY_HINT_NONE, "default": ""},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Play, stop, or pause AnimatedSprite2D animations. Leave Target Node empty to use the node this script is on.",
		"mode": "Play: start or resume the animation.\nStop: stop playback and reset.\nPause: freeze at the current frame.",
		"animation_name": "Name of the animation in the AnimatedSprite2D SpriteFrames resource. Leave blank to play the default/current animation.",
		"speed_scale": "Playback speed multiplier. Accepts a number, variable, or expression.",
		"target_node": "Name of the AnimatedSprite2D node to control. Leave empty to target self.",
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = str(properties.get("mode", "play")).to_lower()
	var anim_name = str(properties.get("animation_name", ""))
	var speed_raw = properties.get("speed_scale", "1.0")
	var target_name = str(properties.get("target_node", "")).strip_edges()
	var speed_expr = _speed_to_expr(speed_raw)
	var is_literal = _is_literal_number(speed_raw)
	var literal_speed = float(str(speed_raw)) if is_literal and not str(speed_raw).strip_edges().is_empty() else 1.0
	var label = _safe_label(chain_name)
	var sprite_var = "_sprite_anim_2d_%s" % label

	var member_vars: Array[String] = []
	_append_find_animated_sprite_2d_helpers(member_vars)

	var code_lines: Array[String] = []
	if target_name.is_empty():
		code_lines.append("# Sprite Animation 2D Actuator: target is self")
		code_lines.append("var %s = _lb_find_animated_sprite_2d(\"\")" % sprite_var)
	else:
		code_lines.append("# Sprite Animation 2D Actuator: find '%s'" % _gd_string(target_name))
		code_lines.append("var %s = _lb_find_animated_sprite_2d(\"%s\")" % [sprite_var, _gd_string(target_name)])

	code_lines.append("if %s:" % sprite_var)
	match mode:
		"stop":
			code_lines.append("\t%s.stop()" % sprite_var)
		"pause":
			code_lines.append("\t%s.pause()" % sprite_var)
		_:
			if not is_literal or absf(literal_speed - 1.0) > 0.0001:
				code_lines.append("\t%s.speed_scale = %s" % [sprite_var, speed_expr])
			if anim_name.strip_edges().is_empty():
				code_lines.append("\t%s.play()" % sprite_var)
			else:
				code_lines.append("\t%s.play(\"%s\")" % [sprite_var, _gd_string(anim_name)])
	code_lines.append("else:")
	if target_name.is_empty():
		code_lines.append("\tpush_warning(\"Sprite Animation 2D Actuator: self is not AnimatedSprite2D. Set Target Node to an AnimatedSprite2D name.\")")
	else:
		code_lines.append("\tpush_warning(\"Sprite Animation 2D Actuator: Could not find AnimatedSprite2D named '%s'\")" % _gd_string(target_name))

	return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}

func _append_find_animated_sprite_2d_helpers(member_vars: Array[String]) -> void:
	member_vars.append("")
	member_vars.append("func _lb_find_animated_sprite_2d(node_name: String):")
	member_vars.append("\t# Avoid `self is AnimatedSprite2D` here. Godot 4.7 can reject impossible")
	member_vars.append("\t# type checks at parse time when this generated script extends CharacterBody2D.")
	member_vars.append("\tif node_name.is_empty():")
	member_vars.append("\t\treturn _lb_find_first_animated_sprite_2d(self)")
	member_vars.append("\treturn _lb_find_animated_sprite_2d_recursive(get_tree().root, node_name)")
	member_vars.append("")
	member_vars.append("func _lb_find_first_animated_sprite_2d(root: Node):")
	member_vars.append("\tif root == null:")
	member_vars.append("\t\treturn null")
	member_vars.append("\tfor child in root.get_children():")
	member_vars.append("\t\tif child is AnimatedSprite2D:")
	member_vars.append("\t\t\treturn child")
	member_vars.append("\t\tvar found = _lb_find_first_animated_sprite_2d(child)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn null")
	member_vars.append("")
	member_vars.append("func _lb_find_animated_sprite_2d_recursive(root: Node, node_name: String):")
	member_vars.append("\tif root == null:")
	member_vars.append("\t\treturn null")
	member_vars.append("\tif root is AnimatedSprite2D and root.name == node_name:")
	member_vars.append("\t\treturn root")
	member_vars.append("\tfor child in root.get_children():")
	member_vars.append("\t\tvar found = _lb_find_animated_sprite_2d_recursive(child, node_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn null")

func _speed_to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty():
		return "1.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s

func _is_literal_number(val) -> bool:
	var s = str(val).strip_edges()
	return s.is_empty() or s.is_valid_float() or s.is_valid_int()

func _safe_label(chain_name: String) -> String:
	var label = chain_name.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	return label if not label.is_empty() else "sprite_animation_2d"

func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")
