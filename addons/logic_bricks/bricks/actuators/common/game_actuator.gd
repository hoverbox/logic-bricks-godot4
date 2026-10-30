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
		"action": "exit",           # exit, reload_scene, pause, unpause, toggle_pause, screenshot
		"screenshot_path": "user://screenshot.png"  # Path for screenshots
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Exit,Reload Scene,Pause,Unpause,Toggle Pause,Screenshot",
			"default": "exit"
		},
		{
			"name": "screenshot_path", "required": true, "required_label": "a screenshot path", "required_if": {"action": "screenshot"},
			"type": TYPE_STRING,
			"default": "user://screenshot.png"
		}
	]


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var action = properties.get("action", "exit")

	# Normalize
	if typeof(action) == TYPE_STRING:
		action = action.to_lower()

	# Show/hide fields based on action
	for child in _get_field_names():
		if true:
			var prop_name = child
			match prop_name:
				"save_path":
					shown[child] = (action == "save" or action == "load")
				"screenshot_path":
					shown[child] = (action == "screenshot")
	return shown


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var action = properties.get("action", "exit")
	var screenshot_path = properties.get("screenshot_path", "user://screenshot.png")

	# Normalize action
	if typeof(action) == TYPE_STRING:
		action = action.to_lower().replace(" ", "_")

	var code_lines: Array[String] = []

	match action:
		"exit":
			code_lines.append("# Exit game")
			code_lines.append("get_tree().quit()")

		"reload_scene":
			# Reloads whichever scene is currently running.
			# To go to a specific scene use the Scene Actuator in Set Scene mode instead.
			code_lines.append("# Reload current scene")
			code_lines.append("get_tree().reload_current_scene()")

		"pause":
			code_lines.append("# Pause game")
			code_lines.append("get_tree().paused = true")

		"unpause":
			code_lines.append("# Unpause game")
			code_lines.append("get_tree().paused = false")

		"toggle_pause":
			code_lines.append("# Toggle pause")
			code_lines.append("get_tree().paused = !get_tree().paused")

		"screenshot":
			# In Godot 4, get_image() returns null if called before the frame has
			# finished rendering. We must await frame_post_draw first.
			code_lines.append("# Take screenshot (waits for frame to finish rendering)")
			code_lines.append("await RenderingServer.frame_post_draw")
			code_lines.append("var _viewport = get_viewport()")
			code_lines.append("var _image = _viewport.get_texture().get_image()")
			code_lines.append("if _image:")
			code_lines.append("\tvar _error = _image.save_png(\"%s\")" % _gd_string(str(screenshot_path)))
			code_lines.append("\tif _error == OK:")
			code_lines.append("\t\tprint(\"Screenshot saved to: %s\")" % _gd_string(str(screenshot_path)))
			code_lines.append("\telse:")
			code_lines.append("\t\tpush_error(\"Failed to save screenshot: \" + str(_error))")
			code_lines.append("else:")
			code_lines.append("\tpush_error(\"Failed to capture viewport image\")")

		_:
			code_lines.append("push_warning(\"Game Actuator: Unknown action '%s'\")" % _gd_string(str(action)))

	return {
		"actuator_code": "\n".join(code_lines)
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Game-level actions: quit, restart, or pause the game.",
		"action": "What to do: Quit Game, Restart Scene, Pause, or Unpause.",
	}
