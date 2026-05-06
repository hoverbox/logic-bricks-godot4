@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Sprite Frames Actuator - Play, stop, or pause Sprite3D / AnimatedSprite3D animations
## Works with Sprite3D (SpriteFrames) and AnimatedSprite3D nodes.
## Automatically finds the target node in the scene tree.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Sprite Frames"


func _initialize_properties() -> void:
	properties = {
		"mode": "play",             # play, stop, pause
		"animation_name": "",       # SpriteFrames animation name
		"speed_scale": "1.0",       # Playback speed multiplier (number or expression)
		"target_node": "",          # Node name to search for (leave empty = self)
		"loop": true,               # Override loop setting on play
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Play,Stop,Pause",
			"default": "play"
		},
		{
			"name": "animation_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"default": ""
		},
		{
			"name": "speed_scale",
			"type": TYPE_STRING,
			"default": "1.0"
		},
		{
			"name": "loop",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "target_node",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_NONE,
			"default": ""
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Play, stop, or pause Sprite3D / AnimatedSprite3D frame animations.\nFinds the target by name anywhere in the scene tree.\nLeave Target Node empty to use the node this script is on.",
		"mode": "Play: start the animation\nStop: stop playback and reset to frame 0\nPause: freeze at the current frame",
		"animation_name": "Name of the animation in the SpriteFrames resource to play.\nMust match exactly (case-sensitive).",
		"speed_scale": "Playback speed multiplier.\n• A number: 1.0 (normal), 2.0 (double speed), -1.0 (reverse)\n• A variable: my_speed\n• An expression: base_speed * 2",
		"loop": "Whether the animation loops.\nOnly applied when Mode is Play.",
		"target_node": "Name of the Sprite3D or AnimatedSprite3D node to control.\nSearches the entire scene tree. Leave empty to target self.",
	}


## Resolve speed value to a GDScript expression string
func _speed_to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty():
		return "1.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s


func _is_literal_speed(val) -> bool:
	var s = str(val).strip_edges()
	return s.is_valid_float() or s.is_valid_int() or s.is_empty()


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode         = properties.get("mode", "play")
	var anim_name    = properties.get("animation_name", "")
	var speed_raw    = properties.get("speed_scale", "1.0")
	var do_loop      = properties.get("loop", true)
	var target_name  = properties.get("target_node", "").strip_edges()

	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower()

	var speed_expr    = _speed_to_expr(speed_raw)
	var is_literal    = _is_literal_speed(speed_raw)
	var literal_speed = float(speed_raw) if is_literal else 1.0

	var sprite_var = "_sprite_node_%s" % chain_name
	var code_lines: Array[String] = []
	var member_vars: Array[String] = []

	# Inject a shared helper that finds Sprite3D or AnimatedSprite3D by name
	member_vars.append("")
	member_vars.append("func _find_sprite_node(node_name: String) -> Node:")
	member_vars.append("\tif node_name.is_empty():")
	member_vars.append("\t\treturn self")
	member_vars.append("\treturn _find_sprite_node_recursive(get_tree().root, node_name)")
	member_vars.append("")
	member_vars.append("func _find_sprite_node_recursive(root: Node, node_name: String) -> Node:")
	member_vars.append("\tfor child in root.get_children():")
	member_vars.append("\t\tif (child is Sprite3D or child is AnimatedSprite3D) and child.name == node_name:")
	member_vars.append("\t\t\treturn child")
	member_vars.append("\t\tvar found = _find_sprite_node_recursive(child, node_name)")
	member_vars.append("\t\tif found: return found")
	member_vars.append("\treturn null")

	# Resolve target node
	if target_name.is_empty():
		code_lines.append("# Sprite Frames Actuator: target is self")
		code_lines.append("var %s = self" % sprite_var)
	else:
		code_lines.append("# Sprite Frames Actuator: find '%s'" % target_name)
		code_lines.append("var %s = _find_sprite_node(\"%s\")" % [sprite_var, target_name])

	code_lines.append("if %s:" % sprite_var)

	match mode:
		"play":
			if anim_name.is_empty():
				# No animation name — just call play() to resume/start default
				if not is_literal or literal_speed != 1.0:
					code_lines.append("\t%s.speed_scale = %s" % [sprite_var, speed_expr])
				code_lines.append("\t%s.play()" % sprite_var)
			else:
				# Full play call with animation name
				if not is_literal or literal_speed != 1.0:
					code_lines.append("\t%s.speed_scale = %s" % [sprite_var, speed_expr])
				code_lines.append("\t%s.play(\"%s\", %s, %s)" % [
					sprite_var,
					anim_name,
					speed_expr if not is_literal else "%.3f" % literal_speed,
					"true" if do_loop else "false"
				])
		"stop":
			code_lines.append("\t%s.stop()" % sprite_var)
		"pause":
			code_lines.append("\t%s.pause()" % sprite_var)

	code_lines.append("else:")
	if target_name.is_empty():
		code_lines.append("\tpush_warning(\"Sprite Frames Actuator: self is not a Sprite3D or AnimatedSprite3D\")")
	else:
		code_lines.append("\tpush_warning(\"Sprite Frames Actuator: Could not find Sprite3D/AnimatedSprite3D named '%s'\")" % target_name)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
