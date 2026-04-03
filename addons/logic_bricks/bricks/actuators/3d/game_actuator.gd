@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Game Actuator - Control game flow
## Exit, restart, pause, and screenshot functionality

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Game"


func _initialize_properties() -> void:
	properties = {
		"action": "exit",           # exit, restart, pause, screenshot
		"screenshot_path": "user://screenshot.png"  # Path for screenshots
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Exit,Restart,Screenshot",
			"default": "exit"
		},
		{
			"name": "screenshot_path",
			"type": TYPE_STRING,
			"default": "user://screenshot.png"
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var action = properties.get("action", "exit")
	var screenshot_path = properties.get("screenshot_path", "user://screenshot.png")
	
	# Normalize action
	if typeof(action) == TYPE_STRING:
		action = action.to_lower()
	
	var code_lines: Array[String] = []
	
	match action:
		"exit":
			code_lines.append("# Exit game")
			code_lines.append("get_tree().quit()")
		
		"restart":
			code_lines.append("# Restart game (reload current scene)")
			code_lines.append("get_tree().reload_current_scene()")
		
		"screenshot":
			code_lines.append("# Take screenshot")
			code_lines.append("var _viewport = get_viewport()")
			code_lines.append("var _image = _viewport.get_texture().get_image()")
			code_lines.append("if _image:")
			code_lines.append("\t# Save screenshot")
			code_lines.append("\tvar _error = _image.save_png(\"%s\")" % screenshot_path)
			code_lines.append("\tif _error == OK:")
			code_lines.append("\t\tprint(\"Screenshot saved to: %s\")" % screenshot_path)
			code_lines.append("\telse:")
			code_lines.append("\t\tpush_error(\"Failed to save screenshot: \" + str(_error))")
			code_lines.append("else:")
			code_lines.append("\tpush_error(\"Failed to capture viewport image\")")
		
		_:
			code_lines.append("push_warning(\"Game Actuator: Unknown action '%s'\")" % action)
	
	return {
		"actuator_code": "\n".join(code_lines)
	}
