@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Animation Actuator - Play, stop, or control animations via AnimationPlayer
## Automatically finds the AnimationPlayer that owns the named animation
## Works with AnimationPlayers nested at any depth in the scene tree


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Animation"


func _initialize_properties() -> void:
	properties = {
		"mode": "play",             # play, stop, pause, queue
		"animation_name": "",       # Name of the animation to play
		"speed": "1.0",             # Speed: number, variable, or expression
		"blend_time": -1.0,         # -1 means use AnimationPlayer default
		"play_backwards": false,
		"from_end": false,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Play,Stop,Pause,Queue",
			"default": "play"
		},
		{
			"name": "animation_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "__ANIMATION_LIST__",
			"default": ""
		},
		{
			"name": "speed",
			"type": TYPE_STRING,
			"default": "1.0"
		},
		{
			"name": "blend_time",
			"type": TYPE_FLOAT,
			"default": -1.0
		},
		{
			"name": "play_backwards",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "from_end",
			"type": TYPE_BOOL,
			"default": false
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Play, stop, or control animations by name.\nAutomatically finds the AnimationPlayer that owns the animation.\nWorks with AnimationPlayers nested at any depth.",
		"mode": "Play: start animation\nStop: stop playback\nPause: freeze at current frame\nQueue: play after current finishes",
		"animation_name": "Name of the animation to play.",
		"speed": "Playback speed. Accepts:\n• A number: 1.0\n• A variable: move_speed\n• An expression: move_speed * 2",
		"blend_time": "Blend time in seconds (-1 = use default).\nSmooth transition from previous animation.",
		"play_backwards": "Play the animation in reverse.",
		"from_end": "Start from the last frame.",
	}


## Convert speed value to a code expression
func _speed_to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty():
		return "1.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s


## Check if speed is a simple numeric literal
func _is_literal_speed(val) -> bool:
	var s = str(val).strip_edges()
	return s.is_valid_float() or s.is_valid_int() or s.is_empty()


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode           = properties.get("mode", "play")
	var anim_name      = properties.get("animation_name", "")
	var speed_raw      = properties.get("speed", "1.0")
	var blend_time     = properties.get("blend_time", -1.0)
	var play_backwards = properties.get("play_backwards", false)
	var from_end       = properties.get("from_end", false)

	# Normalize
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower()
	if typeof(blend_time) == TYPE_STRING:
		blend_time = float(blend_time) if str(blend_time).is_valid_float() else -1.0

	var speed_expr    = _speed_to_expr(speed_raw)
	var is_literal    = _is_literal_speed(speed_raw)
	var literal_speed = float(speed_raw) if is_literal else 1.0

	var player_var = "_anim_player_%s" % chain_name
	var code_lines: Array[String] = []
	var member_vars: Array[String] = []

	# Inject a shared helper method (manager deduplicates identical member_vars)
	member_vars.append("")
	member_vars.append("func _find_anim_player(anim_name: String) -> AnimationPlayer:")
	member_vars.append("\treturn _find_anim_player_recursive(self, anim_name)")
	member_vars.append("")
	member_vars.append("func _find_anim_player_recursive(node: Node, anim_name: String) -> AnimationPlayer:")
	member_vars.append("\tfor child in node.get_children():")
	member_vars.append("\t\tif child is AnimationPlayer and child.has_animation(anim_name):")
	member_vars.append("\t\t\treturn child")
	member_vars.append("\t\tvar found = _find_anim_player_recursive(child, anim_name)")
	member_vars.append("\t\tif found: return found")
	member_vars.append("\treturn null")

	if anim_name.is_empty():
		code_lines.append("push_warning(\"Animation Actuator: No animation name set — open the brick and select an animation\")")
		return {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}

	code_lines.append("# Animation Actuator: find player that owns \"%s\"" % anim_name)
	code_lines.append("var %s = _find_anim_player(\"%s\")" % [player_var, anim_name])
	code_lines.append("if %s:" % player_var)

	match mode:
		"play":
			if not is_literal:
				code_lines.append("\t%s.speed_scale = %s" % [player_var, speed_expr])
				if blend_time >= 0.0:
					code_lines.append("\t%s.play(\"%s\", %.3f)" % [player_var, anim_name, blend_time])
				elif play_backwards or from_end:
					code_lines.append("\t%s.play_backwards(\"%s\")" % [player_var, anim_name])
				else:
					code_lines.append("\t%s.play(\"%s\")" % [player_var, anim_name])
			else:
				if blend_time >= 0.0:
					code_lines.append("\t%s.play(\"%s\", %.3f, %.3f, %s)" % [player_var, anim_name, blend_time, literal_speed, "true" if play_backwards else "false"])
				elif play_backwards or from_end:
					code_lines.append("\t%s.play_backwards(\"%s\")" % [player_var, anim_name])
					if literal_speed != 1.0:
						code_lines.append("\t%s.speed_scale = %.3f" % [player_var, literal_speed])
				elif literal_speed != 1.0:
					code_lines.append("\t%s.play(\"%s\", -1, %.3f)" % [player_var, anim_name, literal_speed])
				else:
					code_lines.append("\t%s.play(\"%s\")" % [player_var, anim_name])
		"stop":
			code_lines.append("\t%s.stop()" % player_var)
		"pause":
			code_lines.append("\t%s.pause()" % player_var)
		"queue":
			if not is_literal:
				code_lines.append("\t%s.speed_scale = %s" % [player_var, speed_expr])
			elif literal_speed != 1.0:
				code_lines.append("\t%s.speed_scale = %.3f" % [player_var, literal_speed])
			code_lines.append("\t%s.queue(\"%s\")" % [player_var, anim_name])

	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Animation Actuator: No AnimationPlayer found with animation '%s'\")" % anim_name)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
