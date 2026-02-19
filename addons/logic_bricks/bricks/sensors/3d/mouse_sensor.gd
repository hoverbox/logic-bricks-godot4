@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Mouse Sensor - Detect mouse input, movement, and hover
## Detects mouse buttons, wheel, movement, and object hover

func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Mouse"


func _initialize_properties() -> void:
	properties = {
		"detection_type": "button",     # button, wheel, movement, hover_object, hover_any
		"mouse_button": "left",         # left, right, middle (for button type)
		"button_state": "pressed",      # pressed, released, held (for button type)
		"wheel_direction": "up",        # up, down (for wheel type)
		"movement_threshold": 0.1,      # Minimum movement to trigger (for movement type)
		"area_node_name": "MouseArea"   # Area3D child for hover detection
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "detection_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Button,Wheel,Movement,Hover Object,Hover Any",
			"default": "button"
		},
		{
			"name": "mouse_button",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Left,Right,Middle",
			"default": "left"
		},
		{
			"name": "button_state",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Pressed,Released,Held",
			"default": "pressed"
		},
		{
			"name": "wheel_direction",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Up,Down",
			"default": "up"
		},
		{
			"name": "movement_threshold",
			"type": TYPE_FLOAT,
			"default": 0.1
		},
		{
			"name": "area_node_name",
			"type": TYPE_STRING,
			"default": "MouseArea"
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var detection_type = properties.get("detection_type", "button")
	var mouse_button = properties.get("mouse_button", "left")
	var button_state = properties.get("button_state", "pressed")
	var wheel_direction = properties.get("wheel_direction", "up")
	var movement_threshold = properties.get("movement_threshold", 0.1)
	var area_node_name = properties.get("area_node_name", "MouseArea")
	
	# Normalize
	if typeof(detection_type) == TYPE_STRING:
		detection_type = detection_type.to_lower().replace(" ", "_")
	if typeof(mouse_button) == TYPE_STRING:
		mouse_button = mouse_button.to_lower()
	if typeof(button_state) == TYPE_STRING:
		button_state = button_state.to_lower()
	if typeof(wheel_direction) == TYPE_STRING:
		wheel_direction = wheel_direction.to_lower()
	
	print("Mouse Sensor Debug - type: %s, button: %s, state: %s" % [detection_type, mouse_button, button_state])
	
	var code_lines: Array[String] = []
	var member_vars: Array[String] = []
	
	match detection_type:
		"button":
			var button_code = ""
			match mouse_button:
				"left":
					button_code = "MOUSE_BUTTON_LEFT"
				"right":
					button_code = "MOUSE_BUTTON_RIGHT"
				"middle":
					button_code = "MOUSE_BUTTON_MIDDLE"
			
			match button_state:
				"pressed":
					# Just pressed - only true for one frame when clicked
					var pressed_var = "_mouse_%s_was_pressed_%s" % [mouse_button, chain_name]
					member_vars.append("var %s: bool = false" % pressed_var)
					
					code_lines.append("var sensor_active = false")
					code_lines.append("var _is_pressed = Input.is_mouse_button_pressed(%s)" % button_code)
					code_lines.append("if _is_pressed and not %s:" % pressed_var)
					code_lines.append("\tsensor_active = true")
					code_lines.append("%s = _is_pressed" % pressed_var)
				"released":
					# Just released - only true for one frame when released
					var pressed_var = "_mouse_%s_was_pressed_%s" % [mouse_button, chain_name]
					member_vars.append("var %s: bool = false" % pressed_var)
					
					code_lines.append("var sensor_active = false")
					code_lines.append("var _is_pressed = Input.is_mouse_button_pressed(%s)" % button_code)
					code_lines.append("if %s and not _is_pressed:" % pressed_var)
					code_lines.append("\tsensor_active = true")
					code_lines.append("%s = _is_pressed" % pressed_var)
				"held":
					# Held - continuously true while button is down
					code_lines.append("var sensor_active = Input.is_mouse_button_pressed(%s)" % button_code)
		
		"wheel":
			# Wheel needs input event handling - use member variable to track
			var wheel_var = "_mouse_wheel_%s_%s" % [wheel_direction, chain_name]
			member_vars.append("var %s: bool = false" % wheel_var)
			
			code_lines.append("# Mouse wheel detection happens in _input()")
			code_lines.append("var sensor_active = %s" % wheel_var)
			code_lines.append("%s = false  # Reset after check" % wheel_var)
			
			# Add input function
			var input_func = []
			input_func.append("")
			input_func.append("func _input(event):")
			input_func.append("\tif event is InputEventMouseButton:")
			if wheel_direction == "up":
				input_func.append("\t\tif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:")
			else:
				input_func.append("\t\tif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:")
			input_func.append("\t\t\t%s = true" % wheel_var)
			
			code_lines.append("\n".join(input_func))
		
		"movement":
			var movement_var = "_mouse_moved_%s" % chain_name
			var last_pos_var = "_mouse_last_pos_%s" % chain_name
			
			member_vars.append("var %s: bool = false" % movement_var)
			member_vars.append("var %s: Vector2 = Vector2.ZERO" % last_pos_var)
			
			code_lines.append("# Mouse movement detection")
			code_lines.append("var _current_pos = get_viewport().get_mouse_position()")
			code_lines.append("var _delta_mouse = _current_pos - %s" % last_pos_var)
			code_lines.append("var sensor_active = _delta_mouse.length() > %.3f" % movement_threshold)
			code_lines.append("%s = _current_pos" % last_pos_var)
		
		"hover_object":
			code_lines.append("# Hover over this object detection")
			code_lines.append("var sensor_active = false")
			code_lines.append("if has_node(\"%s\"):" % area_node_name)
			code_lines.append("\tvar _area = get_node(\"%s\")" % area_node_name)
			code_lines.append("\tif _area is Area3D:")
			code_lines.append("\t\tvar _camera = get_viewport().get_camera_3d()")
			code_lines.append("\t\tif _camera:")
			code_lines.append("\t\t\tvar _mouse_pos = get_viewport().get_mouse_position()")
			code_lines.append("\t\t\tvar _from = _camera.project_ray_origin(_mouse_pos)")
			code_lines.append("\t\t\tvar _to = _from + _camera.project_ray_normal(_mouse_pos) * 1000.0")
			code_lines.append("\t\t\t")
			code_lines.append("\t\t\tvar _space_state = get_world_3d().direct_space_state")
			code_lines.append("\t\t\tvar _query = PhysicsRayQueryParameters3D.create(_from, _to)")
			code_lines.append("\t\t\tvar _result = _space_state.intersect_ray(_query)")
			code_lines.append("\t\t\t")
			code_lines.append("\t\t\tif _result and _result.collider == self:")
			code_lines.append("\t\t\t\tsensor_active = true")
		
		"hover_any":
			code_lines.append("# Hover over any object detection")
			code_lines.append("var sensor_active = false")
			code_lines.append("var _camera = get_viewport().get_camera_3d()")
			code_lines.append("if _camera:")
			code_lines.append("\tvar _mouse_pos = get_viewport().get_mouse_position()")
			code_lines.append("\tvar _from = _camera.project_ray_origin(_mouse_pos)")
			code_lines.append("\tvar _to = _from + _camera.project_ray_normal(_mouse_pos) * 1000.0")
			code_lines.append("\t")
			code_lines.append("\tvar _space_state = get_world_3d().direct_space_state")
			code_lines.append("\tvar _query = PhysicsRayQueryParameters3D.create(_from, _to)")
			code_lines.append("\tvar _result = _space_state.intersect_ray(_query)")
			code_lines.append("\t")
			code_lines.append("\tif _result:")
			code_lines.append("\t\tsensor_active = true")
	
	var result = {
		"sensor_code": "\n".join(code_lines)
	}
	
	if member_vars.size() > 0:
		result["member_vars"] = member_vars
	
	return result
