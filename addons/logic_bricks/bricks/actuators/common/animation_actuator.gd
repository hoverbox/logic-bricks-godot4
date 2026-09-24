@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Animation Actuator - Play, stop, or control animations via AnimationPlayer
## Automatically finds the AnimationPlayer that owns the named animation.
## Shared by 2D and 3D Logic Bricks.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Animation"


func _initialize_properties() -> void:
	properties = {
		"mode": "play",                 # play, stop, pause, queue
		"animation_name": "",           # Name of the animation to play
		"playback_mode": "as_authored", # as_authored, play_once, loop, ping_pong, flipper
		"trigger_end": "play_to_end",   # play_to_end, stop (ignored by flipper)
		"speed": "1.0",                 # Speed: number, variable, or expression
		"blend_time": -1.0,             # -1 means use AnimationPlayer default
		"priority": 0,                  # Higher priority blocks lower-priority animations while playing
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
			"required": true,
			"required_label": "an animation",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "__ANIMATION_LIST__",
			"default": ""
		},
		{
			"name": "playback_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Use Animation Setting:as_authored,Play Once:play_once,Loop:loop,Ping-Pong:ping_pong,Flipper:flipper",
			"default": "as_authored",
			"visible_if": {"mode": "play"}
		},
		{
			"name": "trigger_end",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Play to End:play_to_end,Stop:stop",
			"default": "play_to_end",
			"visible_if": {"mode": "play"}
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
			"name": "priority",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,100,1",
			"default": 0,
			"visible_if": {"mode": "play"}
		},
		{
			"name": "play_backwards",
			"type": TYPE_BOOL,
			"default": false,
			"visible_if": {"mode": "play"}
		},
		{
			"name": "from_end",
			"type": TYPE_BOOL,
			"default": false,
			"visible_if": {"mode": "play"}
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Play, stop, or control animations by name.\nAutomatically finds the AnimationPlayer that owns the animation.\nWorks with AnimationPlayers nested at any depth.",
		"mode": "Play: start/control an animation\nStop: stop playback\nPause: freeze at current frame\nQueue: play after current finishes",
		"animation_name": "Name of the animation to play.",
		"playback_mode": "Use Animation Setting: preserve the Animation resource loop setting.\nPlay Once: plays once per trigger activation.\nLoop: repeats while triggered.\nPing-Pong: repeats forward and backward while triggered.\nFlipper: plays forward while triggered and reverses toward the start when released.",
		"trigger_end": "What happens when the trigger turns off.\nPlay to End: finish the current pass before stopping.\nStop: stop immediately.\nFlipper always reverses when released, so this setting is ignored for Flipper.",
		"speed": "Playback speed. Accepts:\n• A number: 1.0\n• A variable: move_speed\n• An expression: move_speed * 2",
		"blend_time": "Blend time in seconds (-1 = use default).\nSmooth transition from previous animation.",
		"priority": "Animation priority. Higher numbers override lower numbers while the higher-priority animation is still playing.\nExample: Walk = 0, Jump = 10.",
		"play_backwards": "Start playback in reverse. Flipper controls direction automatically.",
		"from_end": "Start from the last frame. Flipper controls its own start/end behavior.",
	}


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
	var mode = str(properties.get("mode", "play")).to_lower()
	var anim_name = str(properties.get("animation_name", ""))
	var playback_mode = str(properties.get("playback_mode", "as_authored")).to_lower()
	var trigger_end = str(properties.get("trigger_end", "play_to_end")).to_lower()
	var speed_raw = properties.get("speed", "1.0")
	var blend_time = properties.get("blend_time", -1.0)
	var priority = int(properties.get("priority", 0))
	var play_backwards = bool(properties.get("play_backwards", false))
	var from_end = bool(properties.get("from_end", false))

	if typeof(blend_time) == TYPE_STRING:
		blend_time = float(blend_time) if str(blend_time).is_valid_float() else -1.0

	var speed_expr = _speed_to_expr(speed_raw)
	var is_literal = _is_literal_speed(speed_raw)
	var literal_speed = float(speed_raw) if is_literal and not str(speed_raw).is_empty() else 1.0
	var player_var = "_anim_player_%s" % chain_name
	var state_var = "_lb_anim_triggered_%s" % chain_name
	var flipper_var = "_lb_anim_flipper_active_%s" % chain_name
	var original_loop_var = "_lb_anim_original_loop_%s" % chain_name
	var code_lines: Array[String] = []
	var inactive_lines: Array[String] = []
	var member_vars: Array[String] = []

	if anim_name.is_empty():
		code_lines.append("push_warning(\"Animation Actuator: No animation name set — open the brick and select an animation\")")
		return {"actuator_code": "\n".join(code_lines)}

	member_vars.append("")
	member_vars.append("func _find_anim_player(anim_name: String) -> AnimationPlayer:")
	member_vars.append("\tfor child in find_children(\"*\", \"AnimationPlayer\", true, false):")
	member_vars.append("\t\tif child.has_animation(anim_name):")
	member_vars.append("\t\t\treturn child")
	member_vars.append("\treturn null")
	member_vars.append("")
	member_vars.append("func _lb_animation_request(player: AnimationPlayer, anim_name: String, anim_priority: int) -> int:")
	member_vars.append("\tif not player.is_playing():")
	member_vars.append("\t\tplayer.set_meta(\"_lb_animation_priority\", anim_priority)")
	member_vars.append("\t\treturn 2")
	member_vars.append("\tvar current_priority := int(player.get_meta(\"_lb_animation_priority\", 0))")
	member_vars.append("\tif player.current_animation == anim_name:")
	member_vars.append("\t\tif anim_priority >= current_priority:")
	member_vars.append("\t\t\tplayer.set_meta(\"_lb_animation_priority\", anim_priority)")
	member_vars.append("\t\treturn 1")
	member_vars.append("\tif anim_priority < current_priority:")
	member_vars.append("\t\treturn 0")
	member_vars.append("\tplayer.set_meta(\"_lb_animation_priority\", anim_priority)")
	member_vars.append("\treturn 2")

	if mode == "play" and playback_mode == "play_once":
		member_vars.append("var %s: bool = false" % state_var)
	elif mode == "play" and playback_mode == "flipper":
		member_vars.append("var %s: bool = false" % flipper_var)
	elif mode == "play" and playback_mode == "as_authored":
		member_vars.append("var %s: int = -1" % original_loop_var)

	code_lines.append("# Animation Actuator: find player that owns \"%s\"" % anim_name)
	code_lines.append("var %s = _find_anim_player(\"%s\")" % [player_var, anim_name.c_escape()])
	code_lines.append("if %s:" % player_var)

	match mode:
		"play":
			var anim_res_var = "_anim_res_%s" % chain_name
			var request_var = "_anim_request_%s" % chain_name
			code_lines.append("\tvar %s = %s.get_animation(\"%s\")" % [anim_res_var, player_var, anim_name.c_escape()])

			match playback_mode:
				"as_authored":
					code_lines.append("\tif %s:" % anim_res_var)
					code_lines.append("\t\tif %s < 0:" % original_loop_var)
					code_lines.append("\t\t\t%s = int(%s.loop_mode)" % [original_loop_var, anim_res_var])
					code_lines.append("\t\t%s.loop_mode = %s" % [anim_res_var, original_loop_var])
				"loop":
					code_lines.append("\tif %s:" % anim_res_var)
					code_lines.append("\t\t%s.loop_mode = Animation.LOOP_LINEAR" % anim_res_var)
				"ping_pong":
					code_lines.append("\tif %s:" % anim_res_var)
					code_lines.append("\t\t%s.loop_mode = Animation.LOOP_PINGPONG" % anim_res_var)
				_:
					code_lines.append("\tif %s:" % anim_res_var)
					code_lines.append("\t\t%s.loop_mode = Animation.LOOP_NONE" % anim_res_var)

			if playback_mode == "flipper":
				var abs_speed_expr = "absf(float(%s))" % speed_expr
				code_lines.append("\tif not %s:" % flipper_var)
				code_lines.append("\t\tvar %s := _lb_animation_request(%s, \"%s\", %d)" % [request_var, player_var, anim_name.c_escape(), priority])
				code_lines.append("\t\tif %s > 0:" % request_var)
				code_lines.append("\t\t\t%s.speed_scale = %s" % [player_var, abs_speed_expr])
				code_lines.append("\t\t\tif %s == 2:" % request_var)
				if blend_time >= 0.0:
					code_lines.append("\t\t\t\t%s.play(\"%s\", %.3f, %s, false)" % [player_var, anim_name.c_escape(), float(blend_time), abs_speed_expr])
				else:
					code_lines.append("\t\t\t\t%s.play(\"%s\", -1, %s, false)" % [player_var, anim_name.c_escape(), abs_speed_expr])
				code_lines.append("\t\t%s = true" % flipper_var)
				code_lines.append("\telif %s.current_animation == \"%s\":" % [player_var, anim_name.c_escape()])
				code_lines.append("\t\t%s.speed_scale = %s" % [player_var, abs_speed_expr])
			else:
				var gate_prefix = ""
				if playback_mode == "play_once":
					code_lines.append("\tif not %s:" % state_var)
					gate_prefix = "\t"
				code_lines.append("\t%svar %s := _lb_animation_request(%s, \"%s\", %d)" % [gate_prefix, request_var, player_var, anim_name.c_escape(), priority])
				code_lines.append("\t%sif %s > 0:" % [gate_prefix, request_var])
				if not is_literal:
					code_lines.append("\t%s\t%s.speed_scale = %s" % [gate_prefix, player_var, speed_expr])
				elif literal_speed != 1.0:
					code_lines.append("\t%s\t%s.speed_scale = %.3f" % [gate_prefix, player_var, literal_speed])
				else:
					code_lines.append("\t%s\t%s.speed_scale = 1.0" % [gate_prefix, player_var])
				code_lines.append("\t%s\tif %s == 2:" % [gate_prefix, request_var])
				var custom_speed = -abs(literal_speed) if play_backwards and is_literal else literal_speed
				var from_end_flag = play_backwards or from_end
				if blend_time >= 0.0 and is_literal:
					code_lines.append("\t%s\t\t%s.play(\"%s\", %.3f, %.3f, %s)" % [gate_prefix, player_var, anim_name.c_escape(), float(blend_time), custom_speed, "true" if from_end_flag else "false"])
				elif blend_time >= 0.0:
					code_lines.append("\t%s\t\t%s.play(\"%s\", %.3f)" % [gate_prefix, player_var, anim_name.c_escape(), float(blend_time)])
				elif play_backwards or from_end:
					if is_literal:
						code_lines.append("\t%s\t\t%s.play(\"%s\", -1, %.3f, true)" % [gate_prefix, player_var, anim_name.c_escape(), -abs(literal_speed)])
					else:
						code_lines.append("\t%s\t\t%s.play(\"%s\", -1, -absf(float(%s)), true)" % [gate_prefix, player_var, anim_name.c_escape(), speed_expr])
				elif is_literal and literal_speed != 1.0:
					code_lines.append("\t%s\t\t%s.play(\"%s\", -1, %.3f)" % [gate_prefix, player_var, anim_name.c_escape(), literal_speed])
				else:
					code_lines.append("\t%s\t\t%s.play(\"%s\")" % [gate_prefix, player_var, anim_name.c_escape()])
				if playback_mode == "play_once":
					code_lines.append("\t%s\t%s = true" % [gate_prefix, state_var])

			# The inactive branch defines what happens when the trigger stops.
			inactive_lines.append("var %s = _find_anim_player(\"%s\")" % [player_var, anim_name.c_escape()])
			inactive_lines.append("if %s:" % player_var)
			if playback_mode == "flipper":
				var reverse_speed_expr = "-absf(float(%s))" % speed_expr
				var reverse_request_var = "_anim_reverse_request_%s" % chain_name
				inactive_lines.append("\tif %s:" % flipper_var)
				inactive_lines.append("\t\tvar %s := _lb_animation_request(%s, \"%s\", %d)" % [reverse_request_var, player_var, anim_name.c_escape(), priority])
				inactive_lines.append("\t\tif %s > 0:" % reverse_request_var)
				inactive_lines.append("\t\t\tif %s.current_animation == \"%s\" and %s.is_playing():" % [player_var, anim_name.c_escape(), player_var])
				inactive_lines.append("\t\t\t\t%s.speed_scale = %s" % [player_var, reverse_speed_expr])
				inactive_lines.append("\t\t\telse:")
				if blend_time >= 0.0:
					inactive_lines.append("\t\t\t\t%s.play(\"%s\", %.3f, %s, true)" % [player_var, anim_name.c_escape(), float(blend_time), reverse_speed_expr])
				else:
					inactive_lines.append("\t\t\t\t%s.play(\"%s\", -1, %s, true)" % [player_var, anim_name.c_escape(), reverse_speed_expr])
				inactive_lines.append("\t\t\t%s = false" % flipper_var)
			else:
				if playback_mode == "play_once":
					inactive_lines.append("\t%s = false" % state_var)
				if trigger_end == "stop":
					inactive_lines.append("\tif %s.current_animation == \"%s\" and int(%s.get_meta(\"_lb_animation_priority\", 0)) <= %d:" % [player_var, anim_name.c_escape(), player_var, priority])
					inactive_lines.append("\t\t%s.stop()" % player_var)
					inactive_lines.append("\t\t%s.remove_meta(\"_lb_animation_priority\")" % player_var)
				elif playback_mode == "loop" or playback_mode == "ping_pong" or playback_mode == "as_authored":
					inactive_lines.append("\tif %s.current_animation == \"%s\":" % [player_var, anim_name.c_escape()])
					inactive_lines.append("\t\tvar _inactive_anim_%s = %s.get_animation(\"%s\")" % [chain_name, player_var, anim_name.c_escape()])
					inactive_lines.append("\t\tif _inactive_anim_%s:" % chain_name)
					inactive_lines.append("\t\t\t_inactive_anim_%s.loop_mode = Animation.LOOP_NONE" % chain_name)

		"stop":
			code_lines.append("\t%s.stop()" % player_var)
			code_lines.append("\t%s.remove_meta(\"_lb_animation_priority\")" % player_var)
		"pause":
			code_lines.append("\t%s.pause()" % player_var)
		"queue":
			if not is_literal:
				code_lines.append("\t%s.speed_scale = %s" % [player_var, speed_expr])
			elif literal_speed != 1.0:
				code_lines.append("\t%s.speed_scale = %.3f" % [player_var, literal_speed])
			code_lines.append("\t%s.queue(\"%s\")" % [player_var, anim_name.c_escape()])

	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Animation Actuator: No AnimationPlayer found with animation '%s'\")" % anim_name.c_escape())

	var result = {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
	if not inactive_lines.is_empty():
		result["inactive_code"] = "\n".join(inactive_lines)
	return result
