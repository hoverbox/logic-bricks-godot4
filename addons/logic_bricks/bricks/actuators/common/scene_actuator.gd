@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Scene Actuator - Restart or change scenes
## Similar to UPBGE's Scene actuator

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Scene"


func _initialize_properties() -> void:
	properties = {
		"mode": "restart",        # restart, set_scene
		"scene_path": "",         # Path to scene file for set_scene mode
		"delay": 0.0               # Seconds to wait before changing/restarting scene
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Restart,Set Scene",
			"default": "restart"
		},
		{
			"name": "scene_path", "required": true, "required_label": "a scene", "required_if": {"mode": "set_scene"},
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.tscn,*.scn",
			"default": ""
		},
		{
			"name": "delay",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,60.0,0.1,or_greater",
			"default": 0.0
		}
	]


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var mode = properties.get("mode", "restart")

	# Normalize mode
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")

	# Hide scene_path when mode is restart
	for child in _get_field_names():
		if true:
			var prop_name = child
			if prop_name == "scene_path":
				shown[child] = (mode == "set_scene")
	return shown


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "restart")
	var scene_path = properties.get("scene_path", "")
	# A variable/math delay always uses the timer (never below 0 seconds).
	var delay_number = _literal_number("delay", 0.0)
	var use_timer: bool = delay_number == null or delay_number > 0.0
	var delay := "maxf(%s, 0.0)" % _num("delay") if delay_number == null else "%.2f" % maxf(delay_number, 0.0)

	# Normalize mode
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")


	var code_lines: Array[String] = []

	match mode:
		"restart":
			code_lines.append("# Restart current scene")
			if use_timer:
				code_lines.append("get_tree().create_timer(%s).timeout.connect(func():" % delay)
				code_lines.append("\tget_tree().reload_current_scene())")
			else:
				code_lines.append("get_tree().reload_current_scene()")

		"set_scene":
			if scene_path.is_empty():
				code_lines.append("push_warning(\"Scene Actuator: No scene path specified\")")
			else:
				code_lines.append("# Change to specified scene")
				if use_timer:
					code_lines.append("get_tree().create_timer(%s).timeout.connect(func():" % delay)
					code_lines.append("\tget_tree().change_scene_to_file(\"%s\"))" % _gd_string(str(scene_path)))
				else:
					code_lines.append("get_tree().change_scene_to_file(\"%s\")" % _gd_string(str(scene_path)))

		_:
			code_lines.append("push_warning(\"Scene Actuator: Unknown mode '%s'\")" % _gd_string(str(mode)))

	return {
		"actuator_code": "\n".join(code_lines)
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Changes or manages scenes.\nCan switch to a new scene or reload the current one.",
		"scene_path": "Path to the .tscn file to load (for Change Scene).",
	}
