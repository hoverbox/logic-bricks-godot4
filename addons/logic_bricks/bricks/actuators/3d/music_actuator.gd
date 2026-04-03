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
		"set_track":      "0",     # Index of track to make current (number or variable name)
		"set_play":       true,    # Also start playing when setting
		# --- Control ---
		"control_action": "play",  # play, stop, pause, resume, crossfade
		"to_track":       "1",     # Target track index for crossfade (number or variable name)
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
			"type": TYPE_STRING,
			"default": "0"
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
			"type": TYPE_STRING,
			"default": "1"
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
		"set_track":      "Which track index to make current.\nAccepts a number (0, 1, 2…) or a variable name.\nWith a literal number, fires once and stays. With a variable, switches track whenever the variable changes.",
		"set_play":       "Also start playing the track when setting it as current.",
		"control_action": "Play: start the current track.\nStop: stop the current track.\nPause: freeze the current track.\nResume: continue the current track.\nCrossfade: fade out current track and fade in the target track.",
		"to_track":       "Track index to crossfade into.\nAccepts a number (1, 2…) or a variable name.\nWith a literal number, fades once per trigger. With a variable, a new crossfade starts automatically whenever the variable changes.",
		"crossfade_time": "Crossfade duration in seconds.",
	}


## Convert a value to an integer code expression.
## If it looks like a literal number, returns the int string.
## Otherwise returns the string as-is (a variable name / expression).
func _to_int_expr(val) -> String:
	if typeof(val) == TYPE_INT:
		return str(int(val))
	if typeof(val) == TYPE_FLOAT:
		return str(int(val))
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0"
	if s.is_valid_int():
		return str(int(s))
	if s.is_valid_float():
		return str(int(float(s)))
	# Variable name or expression — emit as-is
	return s


## Returns true if the expression is a plain integer literal (not a variable).
func _is_literal_int(val) -> bool:
	if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
		return true
	var s = str(val).strip_edges()
	return s.is_valid_int() or s.is_valid_float()


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var music_mode = properties.get("music_mode", "tracks")
	if typeof(music_mode) == TYPE_STRING:
		music_mode = music_mode.to_lower()

	var member_vars:  Array[String] = []
	var ready_lines:  Array[String] = []
	var code_lines:   Array[String] = []
	var reset_lines:  Array[String] = []

	# Shared variable names used across all three modes
	var arr_var      = "_music_players"
	var cur_var      = "_music_current"
	var fading_var   = "_music_crossfading"
	var group_name   = "_logic_bricks_music"

	match music_mode:
		"tracks":
			var tracks     = properties.get("tracks", [])
			var volume_db  = float(properties.get("volume_db", 0.0))
			var loop       = properties.get("loop", true)
			var audio_bus  = str(properties.get("audio_bus", "")).strip_edges()
			var persist    = properties.get("persist", false)

			if tracks.is_empty():
				return {"actuator_code": "push_warning(\"Music Actuator (Tracks): No tracks added — open the brick and add at least one music file\")"}

			# The Tracks brick owns the shared state declarations.
			# Set and Control bricks must NOT emit these, otherwise the generator
			# produces duplicate member var declarations AND duplicate reset lines
			# in _on_logic_brick_state_enter that wipe _music_players after _ready
			# has already filled it.
			member_vars.append("var %s: Array[AudioStreamPlayer] = []" % arr_var)
			member_vars.append("var %s: int = 0" % cur_var)
			member_vars.append("var %s: bool = false" % fading_var)
			member_vars.append("var _music_initialized: bool = false")

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

			# When a state is entered, the generator resets all member_vars to their
			# defaults then runs reset_code. Rebuild the players so _music_players
			# is never left empty after state entry.
			reset_lines.append("# Music (Tracks): rebuild players on state entry")
			reset_lines.append("for _p in %s: _p.queue_free()" % arr_var)
			reset_lines.append("%s.clear()" % arr_var)
			reset_lines.append("%s = 0" % cur_var)
			reset_lines.append("%s = false" % fading_var)
			reset_lines.append("_music_initialized = false")
			reset_lines.append("_ready()")

		"set":
			var set_track_raw  = properties.get("set_track", "0")
			var set_play       = properties.get("set_play", true)
			var set_track_expr = _to_int_expr(set_track_raw)
			var is_literal     = _is_literal_int(set_track_raw)

			if is_literal:
				# Static track index — fire once only (original behaviour)
				var set_done_var = "_music_set_done_%s" % chain_name
				member_vars.append("var %s: bool = false" % set_done_var)

				code_lines.append("# Music Actuator (Set): static index — fires once only")
				code_lines.append("if %s or not _music_initialized or %s.is_empty():" % [set_done_var, arr_var])
				code_lines.append("\tpass  # Already set, or tracks not ready yet")
				code_lines.append("elif %s >= %s.size():" % [set_track_expr, arr_var])
				code_lines.append("\tpush_warning(\"Music Actuator: Track index %s out of range\")" % set_track_expr)
				code_lines.append("else:")
				code_lines.append("\t%s = true" % set_done_var)
				code_lines.append("\t%s = %s" % [cur_var, set_track_expr])
				if set_play:
					code_lines.append("\tif not %s[%s].playing:" % [arr_var, cur_var])
					code_lines.append("\t\t%s[%s].play()" % [arr_var, cur_var])
			else:
				# Variable track index — re-evaluate every time the brick fires,
				# and switch tracks whenever the value changes.
				var prev_var = "_music_set_prev_%s" % chain_name
				member_vars.append("var %s: int = -1" % prev_var)

				code_lines.append("# Music Actuator (Set): variable index — switches track when value changes")
				code_lines.append("if not _music_initialized or %s.is_empty():" % arr_var)
				code_lines.append("\tpass  # Tracks not ready yet")
				code_lines.append("else:")
				code_lines.append("\tvar _new_track = int(%s)" % set_track_expr)
				code_lines.append("\tif _new_track < 0 or _new_track >= %s.size():" % arr_var)
				code_lines.append("\t\tpush_warning(\"Music Actuator: Track index \" + str(_new_track) + \" out of range\")")
				code_lines.append("\telif _new_track != %s:" % prev_var)
				code_lines.append("\t\t%s = _new_track" % prev_var)
				code_lines.append("\t\t%s = _new_track" % cur_var)
				if set_play:
					code_lines.append("\t\tif not %s[%s].playing:" % [arr_var, cur_var])
					code_lines.append("\t\t\t%s[%s].play()" % [arr_var, cur_var])

		"control":
			var control_action = properties.get("control_action", "play")
			var to_track_raw   = properties.get("to_track", "1")
			var crossfade_time = float(properties.get("crossfade_time", 1.0))
			var volume_db      = float(properties.get("volume_db", 0.0))

			if typeof(control_action) == TYPE_STRING:
				control_action = control_action.to_lower()

			var to_track_expr = _to_int_expr(to_track_raw)
			var is_literal_to = _is_literal_int(to_track_raw)

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
					if is_literal_to:
						# Static target — fade once per trigger (original behaviour)
						code_lines.append("\tif not %s and %s < %s.size() and %s < %s.size():" % [fading_var, cur_var, arr_var, to_track_expr, arr_var])
						code_lines.append("\t\t%s = true" % fading_var)
						code_lines.append("\t\tvar _from = %s[%s]" % [arr_var, cur_var])
						code_lines.append("\t\tvar _to = %s[%s]" % [arr_var, to_track_expr])
						code_lines.append("\t\t# Start target from beginning, set silent")
						code_lines.append("\t\t_to.volume_db = -80.0")
						code_lines.append("\t\tif not _to.playing: _to.play()")
						code_lines.append("\t\t# Crossfade using parallel tween")
						code_lines.append("\t\tvar _cf = create_tween()")
						code_lines.append("\t\t_cf.set_parallel(true)")
						code_lines.append("\t\t_cf.tween_property(_from, \"volume_db\", -80.0, %.2f)" % crossfade_time)
						code_lines.append("\t\t_cf.tween_property(_to, \"volume_db\", %.2f, %.2f)" % [volume_db, crossfade_time])
						code_lines.append("\t\tawait _cf.finished")
						code_lines.append("\t\t_from.stop()")
						code_lines.append("\t\t_from.volume_db = %.2f" % volume_db)
						code_lines.append("\t\t%s = %s" % [cur_var, to_track_expr])
						code_lines.append("\t\t%s = false" % fading_var)
					else:
						# Variable target — crossfade whenever the variable value changes,
						# even if a fade is already in progress (queues a follow-up fade).
						var cf_prev_var = "_music_cf_prev_%s" % chain_name
						member_vars.append("var %s: int = -1" % cf_prev_var)

						code_lines.append("\tvar _target_track = int(%s)" % to_track_expr)
						code_lines.append("\tif _target_track < 0 or _target_track >= %s.size():" % arr_var)
						code_lines.append("\t\tpush_warning(\"Music Actuator: Crossfade target \" + str(_target_track) + \" out of range\")")
						code_lines.append("\telif _target_track == %s:" % cur_var)
						code_lines.append("\t\tpass  # Already on this track")
						code_lines.append("\telif _target_track == %s and not %s:" % [cf_prev_var, fading_var])
						code_lines.append("\t\tpass  # No change since last completed crossfade")
						code_lines.append("\telif not %s:" % fading_var)
						code_lines.append("\t\t# New target — begin crossfade")
						code_lines.append("\t\t%s = _target_track" % cf_prev_var)
						code_lines.append("\t\t%s = true" % fading_var)
						code_lines.append("\t\tvar _from = %s[%s]" % [arr_var, cur_var])
						code_lines.append("\t\tvar _to = %s[_target_track]" % arr_var)
						code_lines.append("\t\t_to.volume_db = -80.0")
						code_lines.append("\t\tif not _to.playing: _to.play()")
						code_lines.append("\t\tvar _cf = create_tween()")
						code_lines.append("\t\t_cf.set_parallel(true)")
						code_lines.append("\t\t_cf.tween_property(_from, \"volume_db\", -80.0, %.2f)" % crossfade_time)
						code_lines.append("\t\t_cf.tween_property(_to, \"volume_db\", %.2f, %.2f)" % [volume_db, crossfade_time])
						code_lines.append("\t\tawait _cf.finished")
						code_lines.append("\t\t_from.stop()")
						code_lines.append("\t\t_from.volume_db = %.2f" % volume_db)
						code_lines.append("\t\t%s = _target_track" % cur_var)
						code_lines.append("\t\t%s = false" % fading_var)
						# If the variable changed again while the fade was running,
						# reset the prev tracker so the next process tick fires a new fade.
						code_lines.append("\t\t# If the variable changed during the fade, allow a follow-up fade")
						code_lines.append("\t\tif int(%s) != %s:" % [to_track_expr, cur_var])
						code_lines.append("\t\t\t%s = -1" % cf_prev_var)

	var result = {"actuator_code": "\n".join(code_lines), "member_vars": member_vars}
	if ready_lines.size() > 0:
		result["ready_code"] = ready_lines
	if reset_lines.size() > 0:
		result["reset_code"] = reset_lines
	return result
