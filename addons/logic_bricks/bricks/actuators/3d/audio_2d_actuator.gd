@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Audio 2D Actuator - Play 2D/UI audio with file selection, volume, pitch, and play modes
## Creates and manages its own AudioStreamPlayer or AudioStreamPlayer2D at runtime
## Mirrors the Sound (3D) actuator pattern but for non-positional and 2D audio


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Audio 2D"


func _initialize_properties() -> void:
	properties = {
		"sound_file":    "",
		"player_type":   "stream_player",   # stream_player, stream_player_2d
		"mode":          "play",             # play, stop, pause, fade_in, fade_out
		"volume":        0.0,
		"pitch":         1.0,
		"pitch_random":  0.0,
		"loop":          false,
		"play_mode":     "restart",          # restart, overlap, ignore_if_playing
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
		"volume":       "Volume in dB. 0 = default, -80 = silent.",
		"pitch":        "Pitch multiplier. 1.0 = normal.",
		"pitch_random": "Random pitch variation ± this amount each play.",
		"loop":         "Loop the audio.",
		"audio_bus":    "Audio bus name. Leave empty for Master.",
		"fade_duration":"Duration of fade in/out in seconds.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode         = properties.get("mode", "play")
	var sound_file   = properties.get("sound_file", "")
	var player_type  = properties.get("player_type", "stream_player")
	var volume       = properties.get("volume", 0.0)
	var pitch        = properties.get("pitch", 1.0)
	var pitch_random = properties.get("pitch_random", 0.0)
	var loop         = properties.get("loop", false)
	var play_mode    = properties.get("play_mode", "restart")
	var audio_bus    = properties.get("audio_bus", "")
	var fade_duration = properties.get("fade_duration", 1.0)

	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")
	if typeof(play_mode) == TYPE_STRING:
		play_mode = play_mode.to_lower().replace(" ", "_")
	if typeof(player_type) == TYPE_STRING:
		player_type = player_type.to_lower().replace(" ", "_")
	if typeof(audio_bus) == TYPE_STRING:
		audio_bus = audio_bus.strip_edges()

	var player_class = "AudioStreamPlayer2D" if player_type == "audiostreamplayer2d" else "AudioStreamPlayer"
	var player_var   = "_audio2d_player_%s" % chain_name
	var fade_var     = "_audio2d_fading_%s" % chain_name
	var target_vol_var = "_audio2d_target_vol_%s" % chain_name

	var member_vars: Array[String] = []
	var code_lines:  Array[String] = []

	member_vars.append("var %s: %s = null" % [player_var, player_class])

	match mode:
		"play":
			if sound_file.is_empty():
				code_lines.append("push_warning(\"Audio 2D: No sound file selected — open the brick and pick a file\")")
			else:
				code_lines.append("# Audio 2D Actuator - Play")
				code_lines.append("if %s == null:" % player_var)
				code_lines.append("\t%s = %s.new()" % [player_var, player_class])
				code_lines.append("\tadd_child(%s)" % player_var)
				code_lines.append("\t%s.stream = load(\"%s\")" % [player_var, sound_file])
				if loop:
					code_lines.append("\tif %s.stream is AudioStreamWAV:" % player_var)
					code_lines.append("\t\t%s.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD" % player_var)
					code_lines.append("\telif %s.stream is AudioStreamOggVorbis:" % player_var)
					code_lines.append("\t\t%s.stream.loop = true" % player_var)
				if not audio_bus.is_empty():
					code_lines.append("\t%s.bus = \"%s\"" % [player_var, audio_bus])
				code_lines.append("")
				code_lines.append("%s.volume_db = %.2f" % [player_var, volume])
				if pitch_random > 0.0:
					code_lines.append("%s.pitch_scale = %.2f + randf_range(-%.2f, %.2f)" % [player_var, pitch, pitch_random, pitch_random])
				else:
					code_lines.append("%s.pitch_scale = %.2f" % [player_var, pitch])
				match play_mode:
					"restart":
						code_lines.append("%s.stop()" % player_var)
						code_lines.append("%s.play()" % player_var)
					"overlap":
						code_lines.append("var _ov2d = %s.new()" % player_class)
						code_lines.append("add_child(_ov2d)")
						code_lines.append("_ov2d.stream = %s.stream" % player_var)
						code_lines.append("_ov2d.volume_db = %s.volume_db" % player_var)
						code_lines.append("_ov2d.pitch_scale = %s.pitch_scale" % player_var)
						if not audio_bus.is_empty():
							code_lines.append("_ov2d.bus = \"%s\"" % audio_bus)
						code_lines.append("_ov2d.finished.connect(_ov2d.queue_free)")
						code_lines.append("_ov2d.play()")
					_:  # ignore_if_playing
						code_lines.append("if not %s.playing:" % player_var)
						code_lines.append("\t%s.play()" % player_var)

		"stop":
			code_lines.append("# Audio 2D Actuator - Stop")
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
				code_lines.append("if %s == null:" % player_var)
				code_lines.append("\t%s = %s.new()" % [player_var, player_class])
				code_lines.append("\tadd_child(%s)" % player_var)
				code_lines.append("\t%s.stream = load(\"%s\")" % [player_var, sound_file])
				if loop:
					code_lines.append("\tif %s.stream is AudioStreamWAV:" % player_var)
					code_lines.append("\t\t%s.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD" % player_var)
					code_lines.append("\telif %s.stream is AudioStreamOggVorbis:" % player_var)
					code_lines.append("\t\t%s.stream.loop = true" % player_var)
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
			code_lines.append("# Audio 2D Actuator - Fade Out")
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
