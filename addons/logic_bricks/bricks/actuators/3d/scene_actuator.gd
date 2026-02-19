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
		"scene_path": ""          # Path to scene file for set_scene mode
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
			"name": "scene_path",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.tscn,*.scn",
			"default": ""
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "restart")
	var scene_path = properties.get("scene_path", "")
	
	# Normalize mode
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")
	
	print("Scene Actuator Debug - mode: %s, scene_path: '%s'" % [mode, scene_path])
	
	var code_lines: Array[String] = []
	
	match mode:
		"restart":
			code_lines.append("# Restart current scene")
			code_lines.append("get_tree().reload_current_scene()")
		
		"set_scene":
			if scene_path.is_empty():
				code_lines.append("push_warning(\"Scene Actuator: No scene path specified\")")
			else:
				code_lines.append("# Change to specified scene")
				code_lines.append("get_tree().change_scene_to_file(\"%s\")" % scene_path)
		
		_:
			code_lines.append("push_warning(\"Scene Actuator: Unknown mode '%s'\")" % mode)
	
	return {
		"actuator_code": "\n".join(code_lines)
	}
