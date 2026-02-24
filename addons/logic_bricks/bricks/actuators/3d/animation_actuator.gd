@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Animation Actuator - Play, stop, or control animations via AnimationPlayer
## Uses @export Node to reference the node that contains the AnimationPlayer
## (e.g. an instanced GLB file). The actuator finds the AnimationPlayer on that node.
## Supports play, stop, pause, and queue modes with speed and blend control.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Animation"


func _initialize_properties() -> void:
	properties = {
		"animation_node_path": "",  # Path to node containing AnimationPlayer
		"mode": "play",  # play, stop, pause, queue
		"animation_name": "",  # Name of the animation to play
		"speed": "1.0",  # Speed: number, variable, or expression
		"blend_time": -1.0,  # -1 means use AnimationPlayer default
		"play_backwards": false,
		"from_end": false,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "animation_node_path",
			"type": TYPE_STRING,
			"default": ""
		},
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
			"depends_on": "animation_node_path",
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
		"_description": "Play, stop, or control animations via AnimationPlayer.\n\n⚠ Adds an @export in the Inspector — assign your AnimationPlayer there.",
		"animation_node_path": "Path to child node containing the AnimationPlayer\n(e.g. your imported GLB model name).",
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
	var anim_node_path = properties.get("animation_node_path", "")
	var mode = properties.get("mode", "play")
	var anim_name = properties.get("animation_name", "")
	var speed_raw = properties.get("speed", "1.0")
	var blend_time = properties.get("blend_time", -1.0)
	var play_backwards = properties.get("play_backwards", false)
	var from_end = properties.get("from_end", false)
	
	# Normalize
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower()
	if typeof(blend_time) == TYPE_STRING:
		blend_time = float(blend_time) if str(blend_time).is_valid_float() else -1.0
	
	var speed_expr = _speed_to_expr(speed_raw)
	var is_literal = _is_literal_speed(speed_raw)
	var literal_speed = float(speed_raw) if is_literal else 1.0
	
	var node_path_str = str(anim_node_path).strip_edges()
	var code_lines: Array[String] = []
	
	if node_path_str.is_empty():
		code_lines.append("# Animation Actuator: No node path specified")
		code_lines.append("pass")
	else:
		code_lines.append("# Get node containing AnimationPlayer")
		code_lines.append("var _anim_node = get_node_or_null(\"%s\")" % node_path_str)
		code_lines.append("if _anim_node:")
		code_lines.append("\t# Find AnimationPlayer on the node")
		code_lines.append("\tvar _anim_player: AnimationPlayer = null")
		code_lines.append("\tfor child in _anim_node.get_children():")
		code_lines.append("\t\tif child is AnimationPlayer:")
		code_lines.append("\t\t\t_anim_player = child")
		code_lines.append("\t\t\tbreak")
		code_lines.append("\t")
		code_lines.append("\tif _anim_player:")
		
		match mode:
			"play":
				if anim_name.is_empty():
					code_lines.append("\t\tpass  # No animation name specified")
				else:
					if not is_literal:
						# Expression/variable — set speed_scale at runtime
						code_lines.append('\t\t_anim_player.speed_scale = %s' % speed_expr)
						if blend_time >= 0.0:
							code_lines.append('\t\t_anim_player.play("%s", %.3f)' % [anim_name, blend_time])
						elif play_backwards or from_end:
							code_lines.append('\t\t_anim_player.play_backwards("%s")' % anim_name)
						else:
							code_lines.append('\t\t_anim_player.play("%s")' % anim_name)
					else:
						# Literal number — use inline parameter
						if blend_time >= 0.0:
							code_lines.append('\t\t_anim_player.play("%s", %.3f, %.3f, %s)' % [anim_name, blend_time, literal_speed, "true" if play_backwards else "false"])
						elif play_backwards or from_end:
							code_lines.append('\t\t_anim_player.play_backwards("%s")' % anim_name)
							if literal_speed != 1.0:
								code_lines.append('\t\t_anim_player.speed_scale = %.3f' % literal_speed)
						elif literal_speed != 1.0:
							code_lines.append('\t\t_anim_player.play("%s", -1, %.3f)' % [anim_name, literal_speed])
						else:
							code_lines.append('\t\t_anim_player.play("%s")' % anim_name)
			
			"stop":
				code_lines.append('\t\t_anim_player.stop()')
			
			"pause":
				code_lines.append('\t\t_anim_player.pause()')
			
			"queue":
				if anim_name.is_empty():
					code_lines.append("\t\tpass  # No animation name specified")
				else:
					if not is_literal:
						code_lines.append('\t\t_anim_player.speed_scale = %s' % speed_expr)
					elif literal_speed != 1.0:
						code_lines.append('\t\t_anim_player.speed_scale = %.3f' % literal_speed)
					code_lines.append('\t\t_anim_player.queue("%s")' % anim_name)
		
		code_lines.append("\telse:")
		code_lines.append('\t\tpush_warning("Animation Actuator: No AnimationPlayer found on node %s")' % node_path_str)
		code_lines.append("else:")
		code_lines.append('\tpush_warning("Animation Actuator: Node not found at path %s")' % node_path_str)
	
	return {"actuator_code": "\n".join(code_lines)}
