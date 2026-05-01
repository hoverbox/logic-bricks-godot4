@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Sound Actuator - Play, stop, pause, and fade audio from a file
## Creates and manages its own AudioStreamPlayer / AudioStreamPlayer3D at runtime
## No @export variables needed on the target node


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Sound"


func _initialize_properties() -> void:
	properties = {
		"mode": "play",             # play, stop, pause, fade_in, fade_out
		"sound_file": "",           # File path to the audio stream
		"volume": 0.0,              # dB
		"pitch": 1.0,               # Pitch scale
		"pitch_random": 0.0,        # Random pitch range (+/-)
		"loop": false,              # Loop the sound
		"positional": false,        # Use AudioStreamPlayer3D if true
		"play_mode": "restart",     # restart, overlap, ignore
		"audio_bus": "",            # Audio bus name (empty = Master)
		"fade_duration": 1.0,       # Duration for fade_in / fade_out in seconds
		"min_delay": 0.0,           # Minimum delay between plays (seconds)
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
			"name": "play_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Restart,Overlap,Ignore If Playing",
			"default": "restart"
		},
		{
			"name": "volume",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-80,24,0.1"
		},
		{
			"name": "pitch",
			"type": TYPE_FLOAT,
			"default": 1.0,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.01,4.0,0.01"
		},
		{
			"name": "pitch_random",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,1.0,0.01"
		},
		{
			"name": "loop",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "positional",
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
			"default": 1.0,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.1,10.0,0.1"
		},
		{
			"name": "min_delay",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,5.0,0.05"
		},
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "play")
	var sound_file = str(properties.get("sound_file", ""))
	var volume = float(properties.get("volume", 0.0))
	var pitch = float(properties.get("pitch", 1.0))
	var pitch_random = float(properties.get("pitch_random", 0.0))
	var loop = bool(properties.get("loop", false))
	var positional = bool(properties.get("positional", false))
	var play_mode = str(properties.get("play_mode", "restart"))
	var audio_bus = str(properties.get("audio_bus", ""))
	var fade_duration = float(properties.get("fade_duration", 1.0))
	var min_delay = float(properties.get("min_delay", 0.0))

	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")
	if typeof(play_mode) == TYPE_STRING:
		play_mode = play_mode.to_lower().replace(" ", "_")
	if typeof(audio_bus) == TYPE_STRING:
		audio_bus = audio_bus.strip_edges()

	var code_lines: Array[String] = []
	var member_vars: Array[String] = []

	var player_var = "_audio_player_%s" % chain_name
	var player_type = "AudioStreamPlayer3D" if positional else "AudioStreamPlayer"
	var target_vol_var = "_audio_target_vol_%s" % chain_name
	var fade_var = "_audio_fading_%s" % chain_name
	var last_play_time_var = "_audio_last_play_%s" % chain_name

	var stream_setup_lines := func(target_var: String, indent: String = "") -> Array[String]:
		var lines: Array[String] = []
		lines.append("%svar _audio_stream = load(\"%s\")" % [indent, sound_file])
		lines.append("%sif _audio_stream:" % indent)
		lines.append("%s\t_audio_stream = _audio_stream.duplicate(true)" % indent)
		if loop:
			lines.append("%s\tif _audio_stream is AudioStreamWAV:" % indent)
			lines.append("%s\t\t_audio_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD" % indent)
			lines.append("%s\telif _audio_stream is AudioStreamOggVorbis or _audio_stream is AudioStreamMP3:" % indent)
			lines.append("%s\t\t_audio_stream.loop = true" % indent)
		lines.append("%s\t%s.stream = _audio_stream" % [indent, target_var])
		lines.append("%selse:" % indent)
		lines.append("%s\tpush_warning(\"Sound: Failed to load sound file: %s\")" % [indent, sound_file])
		return lines

	member_vars.append("var %s: %s = null" % [player_var, player_type])

	if min_delay > 0.0:
		member_vars.append("var %s: float = 0.0" % last_play_time_var)

	match mode:
		"play":
			if sound_file.is_empty():
				code_lines.append("pass  # No sound file set")
			else:
				var indent = ""
				if min_delay > 0.0:
					code_lines.append("# Check minimum delay between plays")
					code_lines.append("var _current_time = Time.get_ticks_msec() / 1000.0")
					code_lines.append("if _current_time - %s >= %.3f:" % [last_play_time_var, min_delay])
					code_lines.append("\t%s = _current_time" % last_play_time_var)
					indent = "\t"

				code_lines.append("%s# Sound actuator - Play" % indent)
				code_lines.append("%sif %s == null:" % [indent, player_var])
				code_lines.append("%s\t%s = %s.new()" % [indent, player_var, player_type])
				code_lines.append("%s\tadd_child(%s)" % [indent, player_var])
				code_lines.append_array(stream_setup_lines.call(player_var, "%s\t" % indent))

				if not audio_bus.is_empty():
					code_lines.append("%s\t%s.bus = \"%s\"" % [indent, player_var, audio_bus])

				code_lines.append("%s%s.volume_db = %.2f" % [indent, player_var, volume])

				if pitch_random > 0.0:
					code_lines.append("%s%s.pitch_scale = %.2f + randf_range(-%.2f, %.2f)" % [indent, player_var, pitch, pitch_random, pitch_random])
				else:
					code_lines.append("%s%s.pitch_scale = %.2f" % [indent, player_var, pitch])

				match play_mode:
					"restart":
						code_lines.append("%s%s.stop()" % [indent, player_var])
						code_lines.append("%s%s.play()" % [indent, player_var])
					"overlap":
						code_lines.append("%svar _overlap = %s.new()" % [indent, player_type])
						code_lines.append("%sadd_child(_overlap)" % indent)
						code_lines.append("%s_overlap.stream = %s.stream.duplicate(true) if %s.stream else null" % [indent, player_var, player_var])
						code_lines.append("%s_overlap.volume_db = %s.volume_db" % [indent, player_var])
						code_lines.append("%s_overlap.pitch_scale = %s.pitch_scale" % [indent, player_var])
						if not audio_bus.is_empty():
							code_lines.append("%s_overlap.bus = \"%s\"" % [indent, audio_bus])
						code_lines.append("%s_overlap.finished.connect(_overlap.queue_free)" % indent)
						code_lines.append("%s_overlap.play()" % indent)
					_:
						code_lines.append("%sif not %s.playing:" % [indent, player_var])
						code_lines.append("%s\t%s.play()" % [indent, player_var])

		"stop":
			code_lines.append("# Sound actuator - Stop")
			code_lines.append("if %s and %s.playing:" % [player_var, player_var])
			code_lines.append("\t%s.stop()" % player_var)

		"pause":
			code_lines.append("# Sound actuator - Pause/Unpause")
			code_lines.append("if %s:" % player_var)
			code_lines.append("\t%s.stream_paused = not %s.stream_paused" % [player_var, player_var])

		"fade_in":
			member_vars.append("var %s: float = %.2f" % [target_vol_var, volume])
			member_vars.append("var %s: bool = false" % fade_var)

			if sound_file.is_empty():
				code_lines.append("pass  # No sound file set")
			else:
				code_lines.append("# Sound actuator - Fade In")
				code_lines.append("if %s == null:" % player_var)
				code_lines.append("\t%s = %s.new()" % [player_var, player_type])
				code_lines.append("\tadd_child(%s)" % player_var)
				code_lines.append_array(stream_setup_lines.call(player_var, "\t"))
				if not audio_bus.is_empty():
					code_lines.append("\t%s.bus = \"%s\"" % [player_var, audio_bus])

				if pitch_random > 0.0:
					code_lines.append("%s.pitch_scale = %.2f + randf_range(-%.2f, %.2f)" % [player_var, pitch, pitch_random, pitch_random])
				else:
					code_lines.append("%s.pitch_scale = %.2f" % [player_var, pitch])

				code_lines.append("if not %s:" % fade_var)
				code_lines.append("\t%s = true" % fade_var)
				code_lines.append("\t%s.volume_db = -80.0" % player_var)
				code_lines.append("\tif not %s.playing:" % player_var)
				code_lines.append("\t\t%s.play()" % player_var)
				code_lines.append("\tvar _tween = create_tween()")
				code_lines.append("\t_tween.tween_property(%s, \"volume_db\", %.2f, %.2f)" % [player_var, volume, fade_duration])
				code_lines.append("\t_tween.finished.connect(func(): %s = false)" % fade_var)

		"fade_out":
			member_vars.append("var %s: bool = false" % fade_var)

			code_lines.append("# Sound actuator - Fade Out")
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