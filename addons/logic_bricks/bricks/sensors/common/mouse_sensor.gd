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
		"target_node_name": "self",     # Node to test for Hover Object; self or child node name
		"check_interval": 0.0           # Hover modes: seconds between checks; 0 = every frame
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
			"name": "target_node_name",
			"type": TYPE_STRING,
			"default": "self"
		},
		{
			"name": "check_interval",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,5.0,0.05",
			"default": 0.0
		}
	]


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var detection_type = properties.get("detection_type", "button")

	# Normalize
	if typeof(detection_type) == TYPE_STRING:
		detection_type = detection_type.to_lower().replace(" ", "_")

	# Show/hide fields based on detection type
	for child in _get_field_names():
		if true:
			var prop_name = child
			match prop_name:
				"mouse_button", "button_state":
					shown[child] = (detection_type == "button")
				"wheel_direction":
					shown[child] = (detection_type == "wheel")
				"movement_threshold":
					shown[child] = (detection_type == "movement")
				"target_node_name":
					shown[child] = (detection_type == "hover_object")
				"check_interval":
					shown[child] = (detection_type == "hover_object" or detection_type == "hover_any")
				"area_node_name":
					shown[child] = false
	return shown


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var detection_type = properties.get("detection_type", "button")
	var mouse_button = properties.get("mouse_button", "left")
	var button_state = properties.get("button_state", "pressed")
	var wheel_direction = properties.get("wheel_direction", "up")
	var target_node_name = properties.get("target_node_name", "self")
	# Backward compatibility for older bricks that saved the old Area3D-specific field.
	# Treat the old default as self, but preserve any custom name the user typed.
	if not properties.has("target_node_name") and properties.has("area_node_name"):
		var old_area_name = str(properties.get("area_node_name", "")).strip_edges()
		if not old_area_name.is_empty() and old_area_name != "MouseArea" and old_area_name != "Mouse Area":
			target_node_name = old_area_name

	# Normalize
	if typeof(detection_type) == TYPE_STRING:
		detection_type = detection_type.to_lower().replace(" ", "_")
	if typeof(mouse_button) == TYPE_STRING:
		mouse_button = mouse_button.to_lower()
	if typeof(button_state) == TYPE_STRING:
		button_state = button_state.to_lower()
	if typeof(wheel_direction) == TYPE_STRING:
		wheel_direction = wheel_direction.to_lower()


	var code_lines: Array[String] = []
	var member_vars: Array[String] = []
	var extra_methods: Array[String] = []

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
			# Each wheel sensor contributes handler lines to "input_handlers".
			# The manager assembles them all into one func _input() so multiple
			# wheel sensors on the same node never produce duplicate func declarations.
			var wheel_var    = "_ms_wheel_%s_%s" % [wheel_direction, chain_name]
			var button_const = "MOUSE_BUTTON_WHEEL_UP" if wheel_direction == "up" else "MOUSE_BUTTON_WHEEL_DOWN"
			member_vars.append("var %s: bool = false" % wheel_var)

			# Sensor body: read the flag then clear it (true for one frame only)
			code_lines.append("var sensor_active = %s" % wheel_var)
			code_lines.append("%s = false" % wheel_var)

			# Contribute body lines to the shared _input function.
			# Indented with one tab — the manager wraps them in func _input().
			var handler_lines: Array[String] = []
			handler_lines.append("\tif event is InputEventMouseButton and event.pressed:")
			handler_lines.append("\t\tif event.button_index == %s:" % button_const)
			handler_lines.append("\t\t\t%s = true" % wheel_var)
			extra_methods.append("input_handler::" + "\n".join(handler_lines))

		"movement":
			var movement_var = "_mouse_moved_%s" % chain_name
			var last_pos_var = "_mouse_last_pos_%s" % chain_name

			member_vars.append("var %s: bool = false" % movement_var)
			member_vars.append("var %s: Vector2 = Vector2.ZERO" % last_pos_var)

			code_lines.append("# Mouse movement detection")
			code_lines.append("var _current_pos = get_viewport().get_mouse_position()")
			code_lines.append("var _delta_mouse = _current_pos - %s" % last_pos_var)
			code_lines.append("var sensor_active = _delta_mouse.length() > %s" % _num("movement_threshold", 0.1))
			code_lines.append("%s = _current_pos" % last_pos_var)

		"hover_object":
			code_lines.append("# Hover over target object detection")
			code_lines.append("var sensor_active = false")
			var escaped_target = _gd_string(str(target_node_name)).strip_edges()
			if escaped_target.is_empty() or escaped_target == "self":
				code_lines.append("var _hover_target = self")
			else:
				code_lines.append("var _hover_target = get_node_or_null(\"%s\")" % escaped_target)
				code_lines.append("if _hover_target == null and get_tree().current_scene:")
				code_lines.append("\t_hover_target = get_tree().current_scene.find_child(\"%s\", true, false)" % escaped_target)
				code_lines.append("if _hover_target == null:")
				code_lines.append("\t_hover_target = get_tree().root.find_child(\"%s\", true, false)" % escaped_target)

			if node is Control:
				code_lines.append("if _hover_target is Control and _hover_target.visible:")
				code_lines.append("\tvar _mouse_pos = get_viewport().get_mouse_position()")
				code_lines.append("\tsensor_active = _hover_target.get_global_rect().has_point(_mouse_pos)")
			elif node is Node2D:
				code_lines.append("if _hover_target:")
				code_lines.append("\tvar _query = PhysicsPointQueryParameters2D.new()")
				code_lines.append("\t_query.position = get_global_mouse_position()")
				code_lines.append("\t_query.collide_with_areas = true")
				code_lines.append("\t_query.collide_with_bodies = true")
				code_lines.append("\tvar _results = get_world_2d().direct_space_state.intersect_point(_query, 32)")
				code_lines.append("\tfor _hit in _results:")
				code_lines.append("\t\tvar _hover_collider = _hit.get(\"collider\")")
				code_lines.append("\t\tif _hover_collider == _hover_target or (_hover_collider != null and _hover_target.is_ancestor_of(_hover_collider)):")
				code_lines.append("\t\t\tsensor_active = true")
				code_lines.append("\t\t\tbreak")
			else:
				code_lines.append("if _hover_target:")
				code_lines.append("\tvar _camera = get_viewport().get_camera_3d()")
				code_lines.append("\tif _camera:")
				code_lines.append("\t\tvar _mouse_pos = get_viewport().get_mouse_position()")
				code_lines.append("\t\tvar _from = _camera.project_ray_origin(_mouse_pos)")
				code_lines.append("\t\tvar _to = _from + _camera.project_ray_normal(_mouse_pos) * 1000.0")
				code_lines.append("\t\tvar _space_state = get_world_3d().direct_space_state")
				code_lines.append("\t\tvar _query = PhysicsRayQueryParameters3D.create(_from, _to)")
				code_lines.append("\t\tvar _result = _space_state.intersect_ray(_query)")
				code_lines.append("\t\tif _result:")
				code_lines.append("\t\t\tvar _hover_collider = _result.collider")
				code_lines.append("\t\t\tif _hover_collider == _hover_target or _hover_target.is_ancestor_of(_hover_collider):")
				code_lines.append("\t\t\t\tsensor_active = true")

		"hover_any":
			code_lines.append("# Hover over any object detection")
			if node is Control:
				code_lines.append("var sensor_active = get_viewport().gui_get_hovered_control() != null")
			elif node is Node2D:
				code_lines.append("var _query = PhysicsPointQueryParameters2D.new()")
				code_lines.append("_query.position = get_global_mouse_position()")
				code_lines.append("_query.collide_with_areas = true")
				code_lines.append("_query.collide_with_bodies = true")
				code_lines.append("var sensor_active = not get_world_2d().direct_space_state.intersect_point(_query, 1).is_empty()")
			else:
				code_lines.append("var sensor_active = false")
				code_lines.append("var _camera = get_viewport().get_camera_3d()")
				code_lines.append("if _camera:")
				code_lines.append("\tvar _mouse_pos = get_viewport().get_mouse_position()")
				code_lines.append("\tvar _from = _camera.project_ray_origin(_mouse_pos)")
				code_lines.append("\tvar _to = _from + _camera.project_ray_normal(_mouse_pos) * 1000.0")
				code_lines.append("\tvar _space_state = get_world_3d().direct_space_state")
				code_lines.append("\tvar _query = PhysicsRayQueryParameters3D.create(_from, _to)")
				code_lines.append("\tvar _result = _space_state.intersect_ray(_query)")
				code_lines.append("\tif _result:")
				code_lines.append("\t\tsensor_active = true")

	if detection_type == "hover_object" or detection_type == "hover_any":
		var interval_number = _literal_number("check_interval", 0.0)
		var interval = _num("check_interval") if interval_number == null else maxf(0.0, interval_number)
		var timed := _wrap_sensor_interval(code_lines, interval, chain_name)
		code_lines = timed["code"]
		member_vars.append_array(timed["member_vars"])

	var result = {
		"sensor_code": "\n".join(code_lines)
	}

	if member_vars.size() > 0:
		result["member_vars"] = member_vars
	if extra_methods.size() > 0:
		result["methods"] = extra_methods

	return result

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Detects mouse buttons, wheel movement, mouse motion, and mouse hover ray hits.",
		"detection_type": "What mouse event to detect: Button, Wheel, Movement, Hover Object, or Hover Any.",
		"mouse_button": "Which mouse button to detect: Left, Right, or Middle.",
		"button_state": "When to activate: Pressed, Released, or Held.",
		"wheel_direction": "Which wheel direction to detect.",
		"movement_threshold": "Minimum mouse movement before the trigger activates.",
		"target_node_name": "For Hover Object: self, or the name/path of a child node to detect under the mouse. The target or one of its child collision objects must be hit by the ray.",
		"check_interval": "Hover modes: seconds between checks. 0 = check every frame.\nEach hover check casts a ray, so checking less often saves work when many objects use hover; between checks the trigger keeps its last result. 0.05 to 0.1 still feels instant.",
	}
