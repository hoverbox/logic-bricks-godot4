@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Game Actuator - Control game flow
## Exit, restart, save, load, and screenshot functionality

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Game"


func _initialize_properties() -> void:
	properties = {
		"action": "exit",           # exit, restart, save, load, screenshot
		"save_path": "user://savegame.save",  # Path for save file
		"screenshot_path": "user://screenshot.png"  # Path for screenshots
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Exit,Restart,Save,Load,Screenshot",
			"default": "exit"
		},
		{
			"name": "save_path",
			"type": TYPE_STRING,
			"default": "user://savegame.save"
		},
		{
			"name": "screenshot_path",
			"type": TYPE_STRING,
			"default": "user://screenshot.png"
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var action = properties.get("action", "exit")
	var save_path = properties.get("save_path", "user://savegame.save")
	var screenshot_path = properties.get("screenshot_path", "user://screenshot.png")
	
	# Normalize action
	if typeof(action) == TYPE_STRING:
		action = action.to_lower()
	
	print("Game Actuator Debug - action: %s" % action)
	
	var code_lines: Array[String] = []
	
	match action:
		"exit":
			code_lines.append("# Exit game")
			code_lines.append("get_tree().quit()")
		
		"restart":
			code_lines.append("# Restart game (reload current scene)")
			code_lines.append("get_tree().reload_current_scene()")
		
		"save":
			code_lines.append("# Save game")
			code_lines.append("var _save_file = FileAccess.open(\"%s\", FileAccess.WRITE)" % save_path)
			code_lines.append("if _save_file:")
			code_lines.append("\t# Save game state")
			code_lines.append("\tvar _save_data = {}")
			code_lines.append("\t")
			code_lines.append("\t# Collect saveable data from nodes with 'save' method")
			code_lines.append("\tfor _node in get_tree().get_nodes_in_group(\"save\"):")
			code_lines.append("\t\tif _node.has_method(\"save\"):")
			code_lines.append("\t\t\tvar _node_data = _node.save()")
			code_lines.append("\t\t\tif _node_data:")
			code_lines.append("\t\t\t\t_save_data[_node.get_path()] = _node_data")
			code_lines.append("\t")
			code_lines.append("\t# Write to file")
			code_lines.append("\t_save_file.store_var(_save_data)")
			code_lines.append("\t_save_file.close()")
			code_lines.append("\tprint(\"Game saved to: %s\")" % save_path)
			code_lines.append("else:")
			code_lines.append("\tpush_error(\"Failed to open save file: %s\")" % save_path)
		
		"load":
			code_lines.append("# Load game")
			code_lines.append("if FileAccess.file_exists(\"%s\"):" % save_path)
			code_lines.append("\tvar _save_file = FileAccess.open(\"%s\", FileAccess.READ)" % save_path)
			code_lines.append("\tif _save_file:")
			code_lines.append("\t\t# Read save data")
			code_lines.append("\t\tvar _save_data = _save_file.get_var()")
			code_lines.append("\t\t_save_file.close()")
			code_lines.append("\t\t")
			code_lines.append("\t\tif _save_data and _save_data is Dictionary:")
			code_lines.append("\t\t\t# Restore data to nodes with 'load' method")
			code_lines.append("\t\t\tfor _node_path in _save_data.keys():")
			code_lines.append("\t\t\t\tvar _node = get_node_or_null(_node_path)")
			code_lines.append("\t\t\t\tif _node and _node.has_method(\"load\"):")
			code_lines.append("\t\t\t\t\t_node.load(_save_data[_node_path])")
			code_lines.append("\t\t\tprint(\"Game loaded from: %s\")" % save_path)
			code_lines.append("\t\telse:")
			code_lines.append("\t\t\tpush_error(\"Invalid save data format\")")
			code_lines.append("\telse:")
			code_lines.append("\t\tpush_error(\"Failed to open save file: %s\")" % save_path)
			code_lines.append("else:")
			code_lines.append("\tpush_warning(\"Save file not found: %s\")" % save_path)
		
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
