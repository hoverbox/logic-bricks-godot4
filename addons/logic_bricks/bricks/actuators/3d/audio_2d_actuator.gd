@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Audio 2D Actuator - Play 2D/UI audio with file selection, volume, pitch, and play modes
## Creates and manages its own AudioStreamPlayer or AudioStreamPlayer2D at runtime
## Loop behavior is implemented by replaying on `finished`, which matches logic-brick
## expectations better than mutating WAV loop points at runtime.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Audio 2D"


func _initialize_properties() -> void:
	properties = {
		"sound_file":    "",
		"player_type":   "stream_player",   # stream_player, stream_player_2d
		"mode":          "play",            # play, stop, pause, fade_in, fade_out
		"volume":        0.0,
		"pitch":         1.0,
		"pitch_random":  0.0,
		"loop":          false,
		"play_mode":     "restart",         # restart, overlap, ignore_if_playing
		"audio_bus":     "",
		"fade_duration": 1.0,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Play,Stop,Pause,Fade In,Fade Out",
			"default": "play"
		},
		{
			"name": "sound_file",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.wav,*.ogg,*.mp3",
			"default": ""
		},
		{
			"name": "player_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "AudioStreamPlayer,AudioStreamPlayer2D",
			"default": "stream_player"
		},
		{
			"name": "play_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Restart,Overlap,Ignore If Playing",
			"default": "restart"
		},
		{
			"name": "volume",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-80,24,0.1",
			"default": 0.0
		},
		{
			"name": "pitch",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.01,4.0,0.01",
			"default": 1.0
		},
		{
			"name": "pitch_random",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0,0.01",
			"default": 0.0
		},
		{
			"name": "loop",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "audio_bus",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "fade_duration",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.1,10.0,0.1",
			"default": 1.0
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Play 2D/UI audio from a file.\nCreates its own AudioStreamPlayer at runtime — no @export needed.",
		"mode":         "Play, Stop, Pause, Fade In, or Fade Out.",
		"sound_file":   "Audio file to play. Supports .wav, .ogg, .mp3.",
		"player_type":  "AudioStreamPlayer: non-positional (music, UI sounds).\nAudioStreamPlayer2D: positional in 2D space.",
		"play_mode":    "Restart: stop and restart if already playing.\nOverlap: spawn a new player each time.\nIgnore: do nothing if already playing.",
		"volume":       "Volume in dB. 0 = mixer-neutral, lower values reduce volume, -80 = silent.",
		"pitch":        "Pitch multiplier. 1.0 = normal.",
		"pitch_random": "Random pitch variation ± this amount each play.",
		"loop":         "Replay the sound again when it finishes.",
		"audio_bus":    "Audio bus name. Leave empty for Master.",
		"fade_duration":"Duration of fade in/out in seconds.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode          = str(properties.get("mode", "play"))
	var sound_file    = str(properties.get("sound_file", ""))
	var player_type   = str(properties.get("player_type", "stream_player"))
	var volume        = float(properties.get("volume", 0.0))
	var pitch         = float(properties.get("pitch", 1.0))
	var pitch_random  = float(properties.get("pitch_random", 0.0))
	var loop          = bool(properties.get("loop", false))
	var play_mode     = str(properties.get("play_mode", "restart"))
	var audio_bus     = str(properties.get("audio_bus", ""))
	var fade_duration = float(properties.get("fade_duration", 1.0))

	mode = mode.to_lower().replace(" ", "_")
	play_mode = play_mode.to_lower().replace(" ", "_")
	player_type = player_type.to_lower().replace(" ", "_")
	audio_bus = audio_bus.strip_edges()

	if player_type in ["audiostreamplayer2d", "audio_stream_player2d", "stream_player_2d", "player_2d", "2d"]:
		player_type = "stream_player_2d"
	else:
		player_type = "stream_player"

	var player_class = "AudioStreamPlayer2D" if player_type == "stream_player_2d" else "AudioStreamPlayer"
	var player_var = "_audio2d_player_%s" % chain_name
	var fade_var = "_audio2d_fading_%s" % chain_name
	var target_vol_var = "_audio2d_target_vol_%s" % chain_name
	var loop_enabled_var = "_audio2d_loop_enabled_%s" % chain_name
	var loop_handler_name = "_audio2d_on_finished_%s" % chain_name

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("var %s: %s = null" % [player_var, player_class])
	member_vars.append("var %s: bool = %s" % [loop_enabled_var, "true" if loop else "false"])
	member_vars.append("")
	member_vars.append("func %s() -> void:" % loop_handler_name)
	member_vars.append("\tif %s and %s != null:" % [loop_enabled_var, player_var])
	member_vars.append("\t\t%s.play()" % player_var)

	var effective_play_mode = play_mode
	if loop and effective_play_mode in ["restart", "overlap"]:
		effective_play_mode = "ignore_if_playing"

	var stream_setup_lines := func(target_var: String, indent: String = "") -> Array[String]:
		var lines: Array[String] = []
		lines.append("%svar _audio_stream = load(\"%s\")" % [indent, sound_file])
		lines.append("%sif _audio_stream:" % indent)
		lines.append("%s\t_audio_stream = _audio_stream.duplicate(true)" % indent)
		lines.append("%s\t%s.stream = _audio_stream" % [indent, target_var])
		lines.append("%selse:" % indent)
		lines.append("%s\tpush_warning(\"Audio 2D: Failed to load sound file: %s\")" % [indent, sound_file])
		return lines

	match mode:
		"play":
			if sound_file.is_empty():
				code_lines.append("push_warning(\"Audio 2D: No sound file selected — open the brick and pick a file\")")
			else:
				code_lines.append("# Audio 2D Actuator - Play")
				code_lines.append("%s = %s" % [loop_enabled_var, "true" if loop else "false"])
				code_lines.append("if %s == null:" % player_var)
				code_lines.append("\t%s = %s.new()" % [player_var, player_class])
				code_lines.append("\tadd_child(%s)" % player_var)
				code_lines.append_array(stream_setup_lines.call(player_var, "\t"))
				if not audio_bus.is_empty():
					code_lines.append("\t%s.bus = \"%s\"" % [player_var, audio_bus])
				code_lines.append("\tif %s and not %s.finished.is_connected(%s):" % [loop_enabled_var, player_var, loop_handler_name])
				code_lines.append("\t\t%s.finished.connect(%s)" % [player_var, loop_handler_name])
				code_lines.append("\telif not %s and %s.finished.is_connected(%s):" % [loop_enabled_var, player_var, loop_handler_name])
				code_lines.append("\t\t%s.finished.disconnect(%s)" % [player_var, loop_handler_name])

				code_lines.append("%s.volume_db = %.2f" % [player_var, volume])
				if pitch_random > 0.0:
					code_lines.append("%s.pitch_scale = %.2f + randf_range(-%.2f, %.2f)" % [player_var, pitch, pitch_random, pitch_random])
				else:
					code_lines.append("%s.pitch_scale = %.2f" % [player_var, pitch])

				code_lines.append("if %s and not %s.finished.is_connected(%s):" % [loop_enabled_var, player_var, loop_handler_name])
				code_lines.append("\t%s.finished.connect(%s)" % [player_var, loop_handler_name])
				code_lines.append("elif not %s and %s.finished.is_connected(%s):" % [loop_enabled_var, player_var, loop_handler_name])
				code_lines.append("\t%s.finished.disconnect(%s)" % [player_var, loop_handler_name])

				match effective_play_mode:
					"restart":
						code_lines.append("%s.stop()" % player_var)
						code_lines.append("%s.play()" % player_var)

					"overlap":
						code_lines.append("var _ov2d = %s.new()" % player_class)
						code_lines.append("add_child(_ov2d)")
						code_lines.append("_ov2d.stream = %s.stream.duplicate(true) if %s.stream else null" % [player_var, player_var])
						code_lines.append("_ov2d.volume_db = %s.volume_db" % player_var)
						code_lines.append("_ov2d.pitch_scale = %s.pitch_scale" % player_var)
						if not audio_bus.is_empty():
							code_lines.append("_ov2d.bus = \"%s\"" % audio_bus)
						code_lines.append("_ov2d.finished.connect(_ov2d.queue_free)")
						code_lines.append("_ov2d.play()")

					_:
						code_lines.append("if not %s.playing:" % player_var)
						code_lines.append("\t%s.play()" % player_var)

		"stop":
			code_lines.append("# Audio 2D Actuator - Stop")
			code_lines.append("%s = false" % loop_enabled_var)
			code_lines.append("if %s and %s.finished.is_connected(%s):" % [player_var, player_var, loop_handler_name])
			code_lines.append("\t%s.finished.disconnect(%s)" % [player_var, loop_handler_name])
			code_lines.append("if %s and %s.playing:" % [player_var, player_var])
			code_lines.append("\t%s.stop()" % player_var)

		"pause":
			code_lines.append("# Audio 2D Actuator - Pause/Unpause")
			code_lines.append("if %s:" % player_var)
			code_lines.append("\t%s.stream_paused = not %s.stream_paused" % [player_var, player_var])

		"fade_in":
			member_vars.append("var %s: float = %.2f" % [target_vol_var, volume])
			member_vars.append("var %s: bool = false" % fade_var)

			if sound_file.is_empty():
				code_lines.append("push_warning(\"Audio 2D: No sound file selected — open the brick and pick a file\")")
			else:
				code_lines.append("# Audio 2D Actuator - Fade In")
				code_lines.append("%s = %s" % [loop_enabled_var, "true" if loop else "false"])
				code_lines.append("if %s == null:" % player_var)
				code_lines.append("\t%s = %s.new()" % [player_var, player_class])
				code_lines.append("\tadd_child(%s)" % player_var)
				code_lines.append_array(stream_setup_lines.call(player_var, "\t"))
				if not audio_bus.is_empty():
					code_lines.append("\t%s.bus = \"%s\"" % [player_var, audio_bus])
				code_lines.append("\tif %s and not %s.finished.is_connected(%s):" % [loop_enabled_var, player_var, loop_handler_name])
				code_lines.append("\t\t%s.finished.connect(%s)" % [player_var, loop_handler_name])

				if pitch_random > 0.0:
					code_lines.append("%s.pitch_scale = %.2f + randf_range(-%.2f, %.2f)" % [player_var, pitch, pitch_random, pitch_random])
				else:
					code_lines.append("%s.pitch_scale = %.2f" % [player_var, pitch])

				code_lines.append("if not %s.playing:" % player_var)
				code_lines.append("\t%s.volume_db = -80.0" % player_var)
				code_lines.append("\t%s.play()" % player_var)

				code_lines.append("if not %s:" % fade_var)
				code_lines.append("\t%s = true" % fade_var)
				code_lines.append("\tvar _tween = create_tween()")
				code_lines.append("\t_tween.tween_property(%s, \"volume_db\", %.2f, %.2f)" % [player_var, volume, fade_duration])
				code_lines.append("\t_tween.finished.connect(func(): %s = false)" % fade_var)

		"fade_out":
			member_vars.append("var %s: bool = false" % fade_var)
			code_lines.append("# Audio 2D Actuator - Fade Out")
			code_lines.append("%s = false" % loop_enabled_var)
			code_lines.append("if %s and %s.finished.is_connected(%s):" % [player_var, player_var, loop_handler_name])
			code_lines.append("\t%s.finished.disconnect(%s)" % [player_var, loop_handler_name])
			code_lines.append("if %s and %s.playing and not %s:" % [player_var, player_var, fade_var])
			code_lines.append("\t%s = true" % fade_var)
			code_lines.append("\tvar _tween = create_tween()")
			code_lines.append("\t_tween.tween_property(%s, \"volume_db\", -80.0, %.2f)" % [player_var, fade_duration])
			code_lines.append("\t_tween.finished.connect(func():")
			code_lines.append("\t\t%s.stop()" % player_var)
			code_lines.append("\t\t%s = false)" % fade_var)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}