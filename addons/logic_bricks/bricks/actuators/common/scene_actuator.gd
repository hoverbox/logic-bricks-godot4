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


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "restart")
	var scene_path = properties.get("scene_path", "")
	var delay = maxf(float(properties.get("delay", 0.0)), 0.0)

	# Normalize mode
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")


	var code_lines: Array[String] = []

	match mode:
		"restart":
			code_lines.append("# Restart current scene")
			if delay > 0.0:
				code_lines.append("get_tree().create_timer(%.2f).timeout.connect(func():" % delay)
				code_lines.append("\tget_tree().reload_current_scene())")
			else:
				code_lines.append("get_tree().reload_current_scene()")

		"set_scene":
			if scene_path.is_empty():
				code_lines.append("push_warning(\"Scene Actuator: No scene path specified\")")
			else:
				code_lines.append("# Change to specified scene")
				if delay > 0.0:
					code_lines.append("get_tree().create_timer(%.2f).timeout.connect(func():" % delay)
					code_lines.append("\tget_tree().change_scene_to_file(\"%s\"))" % scene_path)
				else:
					code_lines.append("get_tree().change_scene_to_file(\"%s\")" % scene_path)

		_:
			code_lines.append("push_warning(\"Scene Actuator: Unknown mode '%s'\")" % mode)

	return {
		"actuator_code": "\n".join(code_lines)
	}
