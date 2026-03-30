@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Music Actuator - Three modes:
## Tracks: Define music files and create persistent AudioStreamPlayers at startup.
## Set:    Set the current track (optionally start playing it).
## Control: Play, stop, pause, resume, or crossfade from current track to another.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Music"


func _initialize_properties() -> void:
	properties = {
		"music_mode":     "tracks",
		# --- Tracks ---
		"tracks":         [],
		"volume_db":      0.0,
		"loop":           true,
		"audio_bus":      "",
		"persist":        false,   # Keep playing across scene changes
		# --- Set ---
		"set_track":      0,       # Index of track to make current
		"set_play":       true,    # Also start playing when setting
		# --- Control ---
		"control_action": "play",  # play, stop, pause, resume, crossfade
		"to_track":       1,       # Target track index for crossfade
		"crossfade_time": 1.0,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "music_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Tracks,Set,Control",
			"default": "tracks"
		},
		# === Tracks ===
		{
			"name": "tracks",
			"type": TYPE_ARRAY,
			"default": [],
			"item_hint": PROPERTY_HINT_FILE,
			"item_hint_string": "*.wav,*.ogg,*.mp3",
			"item_label": "Track"
		},
		{
			"name": "volume_db",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "-80,24,0.1",
			"default": 0.0
		},
		{
			"name": "loop",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "audio_bus",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "persist",
			"type": TYPE_BOOL,
			"default": false
		},
		# === Set ===
		{
			"name": "set_track",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,31,1",
			"default": 0
		},
		{
			"name": "set_play",
			"type": TYPE_BOOL,
			"default": true
		},
		# === Control ===
		{
			"name": "control_action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Play,Stop,Pause,Resume,Crossfade",
			"default": "play"
		},
		{
			"name": "to_track",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,31,1",
			"default": 1
		},
		{
			"name": "crossfade_time",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.1,10.0,0.1",
			"default": 1.0
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Three modes:\nTracks: define and create music players at startup.\nSet: set which track is current (and optionally play it).\nControl: play, stop, pause, resume, or crossfade from current to another track.",
		"music_mode":     "Tracks: set up your music files.\nSet: choose the active track.\nControl: control playback.",
		"tracks":         "Music files to preload. Track 0 is first, Track 1 second, etc.",
		"volume_db":      "Default volume in dB for all tracks.",
		"loop":           "Loop all tracks.",
		"audio_bus":      "Audio bus for all tracks. Leave empty for Master.",
		"persist":        "Keep music playing when the scene restarts or changes.\nPlayers are moved to GlobalVars so they survive scene transitions.",
		"set_track":      "Which track index to make current (0 = first track).",
		"set_play":       "Also start playing the track when setting it as current.",
		"control_action": "Play: start the current track.\nStop: stop the current track.\nPause: freeze the current track.\nResume: continue the current track.\nCrossfade: fade out current track and fade in the target track.",
		"to_track":       "Track index to crossfade into.",
		"crossfade_time": "Crossfade duration in seconds.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var music_mode = properties.get("music_mode", "tracks")
	if typeof(music_mode) == TYPE_STRING:
		music_mode = music_mode.to_lower()

	var member_vars:  Array[String] = []
	var ready_lines:  Array[String] = []
	var code_lines:   Array[String] = []

	# Shared variable names used across all three modes
	var arr_var      = "_music_players"
	var cur_var      = "_music_current"
	var fading_var   = "_music_crossfading"
	var group_name   = "_logic_bricks_music"

	# Shared member vars — always emitted so Set/Control bricks can reference them
	# even when no Tracks brick is present in the same script.
	member_vars.append("var %s: Array[AudioStreamPlayer] = []" % arr_var)
	member_vars.append("var %s: int = 0" % cur_var)
	member_vars.append("var %s: bool = false" % fading_var)
	member_vars.append("var _music_initialized: bool = false")

	match music_mode:
		"tracks":
			var tracks     = properties.get("tracks", [])
			var volume_db  = float(properties.get("volume_db", 0.0))
			var loop       = properties.get("loop", true)
			var audio_bus  = str(properties.get("audio_bus", "")).strip_edges()
			var persist    = properties.get("persist", false)

			if tracks.is_empty():
				return {"actuator_code": "push_warning(\"Music Actuator (Tracks): No tracks added — open the brick and add at least one music file\")"}

			ready_lines.append("# Music Actuator: check if players already exist (persist mode)")
			if persist:
				ready_lines.append("var _gv = get_node_or_null(\"/root/GlobalVars\")")
				ready_lines.append("if _gv:")
				ready_lines.append("\tvar _existing = []")
				ready_lines.append("\tfor c in _gv.get_children():")
				ready_lines.append("\t\tif c.is_in_group(\"%s\"):" % group_name)
				ready_lines.append("\t\t\t_existing.append(c)")
				ready_lines.append("\tif not _existing.is_empty():")
				ready_lines.append("\t\t%s = _existing" % arr_var)
				ready_lines.append("\t\treturn  # Reuse existing players")
			
			# Create players
			ready_lines.append("# Create music players")
			for i in tracks.size():
				var path = str(tracks[i]).strip_edges()
				if path.is_empty():
					continue
				var pvar = "_mt_%s_%d" % [chain_name, i]
				ready_lines.append("var %s = AudioStreamPlayer.new()" % pvar)
				ready_lines.append("%s.stream = load(\"%s\")" % [pvar, path])
				ready_lines.append("%s.volume_db = %.2f" % [pvar, volume_db])
				if not audio_bus.is_empty():
					ready_lines.append("%s.bus = \"%s\"" % [pvar, audio_bus])
				if loop:
					ready_lines.append("if %s.stream is AudioStreamWAV:" % pvar)
					ready_lines.append("\t%s.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD" % pvar)
					ready_lines.append("elif %s.stream is AudioStreamOggVorbis:" % pvar)
					ready_lines.append("\t%s.stream.loop = true" % pvar)
				ready_lines.append("%s.add_to_group(\"%s\")" % [pvar, group_name])
				if persist:
					ready_lines.append("if _gv: _gv.add_child(%s)" % pvar)
					ready_lines.append("else: add_child(%s)" % pvar)
				else:
					ready_lines.append("add_child(%s)" % pvar)
				ready_lines.append("%s.append(%s)" % [arr_var, pvar])

			ready_lines.append("_music_initialized = true")
			code_lines.append("pass  # Music (Tracks): players created in _ready")

		"set":
			var set_track = int(properties.get("set_track", 0))
			var set_play  = properties.get("set_play", true)

			# Use a per-chain flag so Set only fires once regardless of sensor
			var set_done_var = "_music_set_done_%s" % chain_name
			member_vars.append("var %s: bool = false" % set_done_var)

			code_lines.append("# Music Actuator (Set): fires once only")
			code_lines.append("if %s or not _music_initialized or %s.is_empty():" % [set_done_var, arr_var])
			code_lines.append("\tpass  # Already set, or tracks not ready yet")
			code_lines.append("elif %d >= %s.size():" % [set_track, arr_var])
			code_lines.append("\tpush_warning(\"Music Actuator: Track index %d out of range\")" % set_track)
			code_lines.append("else:")
			code_lines.append("\t%s = true" % set_done_var)
			code_lines.append("\t%s = %d" % [cur_var, set_track])
			if set_play:
				code_lines.append("\tif not %s[%s].playing:" % [arr_var, cur_var])
				code_lines.append("\t\t%s[%s].play()" % [arr_var, cur_var])

		"control":
			var control_action = properties.get("control_action", "play")
			var to_track       = int(properties.get("to_track", 1))
			var crossfade_time = float(properties.get("crossfade_time", 1.0))
			var volume_db      = float(properties.get("volume_db", 0.0))

			if typeof(control_action) == TYPE_STRING:
				control_action = control_action.to_lower()

			code_lines.append("# Music Actuator (Control): %s" % control_action)
			code_lines.append("if %s.is_empty():" % arr_var)
			code_lines.append("\tpush_warning(\"Music Actuator: No tracks loaded — add a Tracks brick first\")")
			code_lines.append("else:")

			match control_action:
				"play":
					code_lines.append("\tif %s < %s.size():" % [cur_var, arr_var])
					code_lines.append("\t\t%s[%s].play()" % [arr_var, cur_var])
				"stop":
					code_lines.append("\tif %s < %s.size():" % [cur_var, arr_var])
					code_lines.append("\t\t%s[%s].stop()" % [arr_var, cur_var])
				"pause":
					code_lines.append("\tif %s < %s.size():" % [cur_var, arr_var])
					code_lines.append("\t\t%s[%s].stream_paused = true" % [arr_var, cur_var])
				"resume":
					code_lines.append("\tif %s < %s.size():" % [cur_var, arr_var])
					code_lines.append("\t\t%s[%s].stream_paused = false" % [arr_var, cur_var])
				"crossfade":
					code_lines.append("\tif not %s and %s < %s.size() and %d < %s.size():" % [fading_var, cur_var, arr_var, to_track, arr_var])
					code_lines.append("\t\t%s = true" % fading_var)
					code_lines.append("\t\tvar _from = %s[%s]" % [arr_var, cur_var])
					code_lines.append("\t\tvar _to = %s[%d]" % [arr_var, to_track])
					code_lines.append("\t\t# Start target from beginning, set silent")
					code_lines.append("\t\t_to.volume_db = -80.0")
					code_lines.append("\t\tif not _to.playing: _to.play()")
					code_lines.append("\t\t# Crossfade using parallel tween")
					code_lines.append("\t\tvar _cf = create_tween()")
					code_lines.append("\t\t_cf.set_parallel(true)")
					code_lines.append("\t\t_cf.tween_property(_from, \"volume_db\", -80.0, %.2f)" % [crossfade_time])
					code_lines.append("\t\t_cf.tween_property(_to, \"volume_db\", %.2f, %.2f)" % [volume_db, crossfade_time])
					code_lines.append("\t\tawait _cf.finished")
					code_lines.append("\t\t_from.stop()")
					code_lines.append("\t\t# Restore from-track volume for next use")
					code_lines.append("\t\t_from.volume_db = %.2f" % [volume_db])
					code_lines.append("\t\t%s = %d  # Update current track" % [cur_var, to_track])
					code_lines.append("\t\t%s = false" % fading_var)

	var result = {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}
	if ready_lines.size() > 0:
		result["ready_code"] = ready_lines
	return result
