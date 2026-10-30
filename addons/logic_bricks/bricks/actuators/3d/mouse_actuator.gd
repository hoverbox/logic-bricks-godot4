@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Mouse Actuator - Control mouse cursor and mouse look rotation
## Toggle cursor visibility or rotate object based on mouse movement

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Mouse"


func _initialize_properties() -> void:
	properties = {
		"mode": "cursor_visibility",    # cursor_visibility, mouse_look
		"cursor_visible": false,        # Show/hide cursor
		# Mouse look properties
		"use_x_axis": true,
		"use_y_axis": true,
		"x_target": "self",              # "self" or child node name
		"y_target": "self",              # "self" or child node name
		"x_sensitivity": 0.1,
		"y_sensitivity": 0.1,
		"x_invert": false,               # Invert X axis
		"y_invert": false,               # Invert Y axis
		"x_threshold": 0.0,
		"y_threshold": 0.0,
		"x_min_degrees": 0.0,           # 0 = no limit
		"x_max_degrees": 0.0,           # 0 = no limit
		"y_min_degrees": -90.0,
		"y_max_degrees": 90.0,
		"x_rotation_axis": "y",         # Which object axis to rotate for X mouse movement
		"y_rotation_axis": "x",         # Which object axis to rotate for Y mouse movement
		"x_use_local": false,
		"y_use_local": false,
		"recenter_cursor": true,
		"enable_physics_interpolation": true,
		# Mouse cursor world interaction properties
		"mouse_target": "self",              # self or child node name to rotate/move
		"mouse_velocity": "5.0",            # Movement speed; accepts numbers, variables, or expressions
		"mouse_acceleration": "0.0",        # 0 = instant full speed, >0 = gradual
		"mouse_turn_speed": "0.0",          # Turn smoothing speed, 0 = instant rotation
		"mouse_arrival_distance": "0.1",    # Distance considered reached for move modes
		"mouse_facing_axis": "+z",          # Which local axis points at the cursor
		"mouse_lock_y": true,               # Keep movement/aiming flat on the XZ plane
		"click_button": "left"              # left, right, middle
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Cursor Visibility,Mouse Look,Look Towards,Move Towards Cursor,Move To Mouse Click",
			"default": "cursor_visibility"
		},
		{
			"name": "cursor_visible",
			"type": TYPE_BOOL,
			"default": false
		},
		{"name": "enable_physics_interpolation", "type": TYPE_BOOL, "default": true},
		{
			"name": "use_x_axis",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "use_y_axis",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "x_target",
			"type": TYPE_STRING,
			"default": "self",
			"node_reference": true,
			"node_picker_scope": "scene",
			"accepted_node_types": ["Node3D"]
		},
		{
			"name": "y_target",
			"type": TYPE_STRING,
			"default": "self",
			"node_reference": true,
			"node_picker_scope": "scene",
			"accepted_node_types": ["Node3D"]
		},
		{
			"name": "x_sensitivity",
			"type": TYPE_FLOAT,
			"default": 0.1
		},
		{
			"name": "y_sensitivity",
			"type": TYPE_FLOAT,
			"default": 0.1
		},
		{
			"name": "x_invert",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "y_invert",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "x_threshold",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "y_threshold",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "x_min_degrees",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "x_max_degrees",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "y_min_degrees",
			"type": TYPE_FLOAT,
			"default": -90.0
		},
		{
			"name": "y_max_degrees",
			"type": TYPE_FLOAT,
			"default": 90.0
		},
		{
			"name": "x_rotation_axis",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "X,Y,Z",
			"default": "y"
		},
		{
			"name": "y_rotation_axis",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "X,Y,Z",
			"default": "x"
		},
		{
			"name": "x_use_local",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "y_use_local",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "recenter_cursor",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "mouse_target",
			"type": TYPE_STRING,
			"default": "self",
			"node_reference": true,
			"node_picker_scope": "scene",
			"accepted_node_types": ["Node3D"]
		},
		{
			"name": "mouse_velocity",
			"type": TYPE_STRING,
			"default": "5.0"
		},
		{
			"name": "mouse_acceleration",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "mouse_turn_speed",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "mouse_arrival_distance",
			"type": TYPE_STRING,
			"default": "0.1"
		},
		{
			"name": "mouse_facing_axis",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "+X,-X,+Y,-Y,+Z,-Z",
			"default": "+z"
		},
		{
			"name": "mouse_lock_y",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "click_button",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Left,Right,Middle",
			"default": "left"
		}
	]


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var mode = properties.get("mode", "cursor_visibility")

	# Normalize
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")

	# Show/hide fields based on mode
	for child in _get_field_names():
		if true:
			var prop_name = child
			match prop_name:
				"cursor_visible":
					shown[child] = (mode == "cursor_visibility")
				"use_x_axis", "use_y_axis", "x_target", "y_target", "x_sensitivity", "y_sensitivity", "x_invert", "y_invert", "x_threshold", "y_threshold", "x_min_degrees", "x_max_degrees", "y_min_degrees", "y_max_degrees", "x_rotation_axis", "y_rotation_axis", "x_use_local", "y_use_local", "recenter_cursor", "enable_physics_interpolation":
					shown[child] = (mode == "mouse_look")
				"mouse_turn_speed", "mouse_facing_axis":
					shown[child] = (mode == "look_towards")
				"mouse_target", "mouse_lock_y":
					shown[child] = (mode in ["look_towards", "move_towards_cursor", "move_to_mouse_click"])
				"mouse_velocity", "mouse_acceleration", "mouse_arrival_distance":
					shown[child] = (mode in ["move_towards_cursor", "move_to_mouse_click"])
				"click_button":
					shown[child] = (mode == "move_to_mouse_click")
	return shown



## Mouse look turns the view on physics ticks (smoothed by physics
## interpolation). Ticks fall 2 or 3 rendered frames apart, so handing a tick
## "everything since the last tick" made each tick turn by a different amount
## even when the mouse moved steadily, which showed as jitter. Each tick now
## takes only the motion that arrived during its own slice of real time.
## Mouse Look with "Enable Physics Interpolation" needs it on for the project.
func get_required_project_settings() -> Dictionary:
	if str(properties.get("mode", "")).to_lower().replace(" ", "_") == "mouse_look" and bool(properties.get("enable_physics_interpolation", true)):
		return {"physics/common/physics_interpolation": true}
	return {}


const MOUSE_TICK_INPUT_METHOD := """
func _logic_mouse_record_motion(relative: Vector2) -> void:
	# Godot delivers mouse motion once per rendered frame; spread it over the
	# real time since the previous delivery.
	var now := Time.get_ticks_usec()
	var start := _logic_mouse_clock_usec if _logic_mouse_events.is_empty() else int(_logic_mouse_events[-1][1])
	if start <= 0 or now - start > 100000:
		start = now - 16667
	_logic_mouse_events.append([start, now, relative])


func _logic_mouse_take_tick_input() -> void:
	var now := Time.get_ticks_usec()
	var tick_usec := 1000000 / maxi(1, Engine.physics_ticks_per_second)
	if _logic_mouse_clock_usec == 0:
		_logic_mouse_clock_usec = now - tick_usec
	_logic_mouse_clock_usec = clampi(_logic_mouse_clock_usec + tick_usec, now - 2 * tick_usec, now)
	while not _logic_mouse_events.is_empty():
		var slice: Array = _logic_mouse_events[0]
		var start: int = slice[0]
		var end: int = slice[1]
		if end <= _logic_mouse_clock_usec:
			_logic_mouse_delta += slice[2]
			_logic_mouse_events.pop_front()
			continue
		if start < _logic_mouse_clock_usec:
			var part := float(_logic_mouse_clock_usec - start) / float(maxi(1, end - start))
			_logic_mouse_delta += slice[2] * part
			slice[2] = slice[2] * (1.0 - part)
			slice[0] = _logic_mouse_clock_usec
		break
"""

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "cursor_visibility")
	var cursor_visible = properties.get("cursor_visible", false)
	var use_x_axis = properties.get("use_x_axis", true)
	var use_y_axis = properties.get("use_y_axis", true)
	var x_target = properties.get("x_target", "self")
	var y_target = properties.get("y_target", "self")
	var x_sensitivity := _num("x_sensitivity", 0.1, 3)
	var y_sensitivity := _num("y_sensitivity", 0.1, 3)
	var x_sensitivity_check := _num("x_sensitivity", 0.1, 6)
	var y_sensitivity_check := _num("y_sensitivity", 0.1, 6)
	var x_invert = properties.get("x_invert", false)
	var y_invert = properties.get("y_invert", false)
	var x_threshold := _num("x_threshold", 0.0, 3)
	var y_threshold := _num("y_threshold", 0.0, 3)
	# Limits in degrees, 0 = no limit. A literal number decides now; a variable/math
	# (null here) is checked at runtime. *_code is the generated value.
	var x_min = _literal_number("x_min_degrees", 0.0)
	var x_max = _literal_number("x_max_degrees", 0.0)
	var y_min = _literal_number("y_min_degrees", -90.0)
	var y_max = _literal_number("y_max_degrees", 90.0)
	var x_min_code := _num("x_min_degrees", 0.0, 2)
	var x_max_code := _num("x_max_degrees", 0.0, 2)
	var y_min_code := _num("y_min_degrees", -90.0, 2)
	var y_max_code := _num("y_max_degrees", 90.0, 2)
	var x_rot_axis = properties.get("x_rotation_axis", "y")
	var y_rot_axis = properties.get("y_rotation_axis", "x")
	var x_use_local = properties.get("x_use_local", false)
	var y_use_local = properties.get("y_use_local", false)
	var recenter = properties.get("recenter_cursor", true)
	var mouse_target = properties.get("mouse_target", "self")
	var mouse_velocity = properties.get("mouse_velocity", "5.0")
	var mouse_acceleration = properties.get("mouse_acceleration", "0.0")
	var mouse_turn_speed = properties.get("mouse_turn_speed", "0.0")
	var mouse_arrival_distance = properties.get("mouse_arrival_distance", "0.1")
	var mouse_facing_axis = properties.get("mouse_facing_axis", "+z")
	var mouse_lock_y = properties.get("mouse_lock_y", true)
	var click_button = properties.get("click_button", "left")

	# Normalize
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")
	if typeof(x_rot_axis) == TYPE_STRING:
		x_rot_axis = x_rot_axis.to_lower()
	if typeof(y_rot_axis) == TYPE_STRING:
		y_rot_axis = y_rot_axis.to_lower()
	if typeof(mouse_facing_axis) == TYPE_STRING:
		mouse_facing_axis = mouse_facing_axis.to_lower()
	if typeof(click_button) == TYPE_STRING:
		click_button = click_button.to_lower()


	var code_lines: Array[String] = []

	match mode:
		"cursor_visibility":
			code_lines.append("# Set cursor visibility")
			if cursor_visible:
				code_lines.append('if not get_meta("_logic_mouse_look_enabled", false):')
				code_lines.append("\tInput.mouse_mode = Input.MOUSE_MODE_VISIBLE")
			else:
				code_lines.append('if not get_meta("_logic_mouse_look_enabled", false):')
				code_lines.append("\tInput.mouse_mode = Input.MOUSE_MODE_HIDDEN")

		"mouse_look":
			code_lines.append("# Mouse look rotation")
			code_lines.append("var _mouse_delta = _logic_mouse_delta if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Vector2.ZERO")
			code_lines.append("")

			if use_x_axis:
				code_lines.append("# X axis (horizontal) mouse movement")

				# Determine target node and indentation
				var x_indent = ""
				if x_target != "self":
					code_lines.append("var _x_target = _logic_mouse_look_target(%s)" % ('"%s"' % str(x_target).c_escape()))
					code_lines.append("if _x_target:")
					x_indent = "\t"

				code_lines.append("%sif abs(_mouse_delta.x) > %s and not is_zero_approx(%s):" % [x_indent, x_threshold, x_sensitivity_check])
				var x_mult = 1.0 if x_invert else -1.0
				code_lines.append("%s\tvar _x_rotation = _mouse_delta.x * %s * %.1f" % [x_indent, x_sensitivity, x_mult])

				# Apply limits if set
				if x_min != 0.0 or x_max != 0.0:
					var axis_index = {"x": "0", "y": "1", "z": "2"}[x_rot_axis]
					var target_prefix = "_x_target." if x_target != "self" else ""
					code_lines.append("%s\tvar _current_rot = %srotation_degrees[%s]" % [x_indent, target_prefix, axis_index])

					code_lines.append("%s\tvar _new_rot = _current_rot + _x_rotation" % x_indent)
					_append_limit(code_lines, x_indent + "\t", "max", x_min, x_min_code, "_min_deg")
					_append_limit(code_lines, x_indent + "\t", "min", x_max, x_max_code, "_max_deg")
					code_lines.append("%s\t_x_rotation = _new_rot - _current_rot" % x_indent)

				# Apply rotation
				var x_axis_vector = {"x": "Vector3.RIGHT", "y": "Vector3.UP", "z": "Vector3.BACK"}[x_rot_axis]
				var target_prefix = "_x_target." if x_target != "self" else ""
				# Do not touch transforms on a zero/clamped rotation: that can invalidate
				# physics interpolation even when mouse sensitivity is zero.
				code_lines.append("%s\tif not is_zero_approx(_x_rotation):" % x_indent)
				if x_use_local:
					code_lines.append("%s\t\t%srotate_object_local(%s, deg_to_rad(_x_rotation))" % [x_indent, target_prefix, x_axis_vector])
				else:
					code_lines.append("%s\t\t%srotate(%s, deg_to_rad(_x_rotation))" % [x_indent, target_prefix, x_axis_vector])
				code_lines.append("")

			if use_y_axis:
				code_lines.append("# Y axis (vertical) mouse movement")

				# Determine target node and indentation
				var y_indent = ""
				if y_target != "self":
					code_lines.append("var _y_target = _logic_mouse_look_target(%s)" % ('"%s"' % str(y_target).c_escape()))
					code_lines.append("if _y_target:")
					y_indent = "\t"

				code_lines.append("%sif abs(_mouse_delta.y) > %s and not is_zero_approx(%s):" % [y_indent, y_threshold, y_sensitivity_check])
				var y_mult = 1.0 if y_invert else -1.0
				code_lines.append("%s\tvar _y_rotation = _mouse_delta.y * %s * %.1f" % [y_indent, y_sensitivity, y_mult])

				# Apply limits
				var y_limit_indent = y_indent + "\t"
				var y_has_limits = y_min != 0.0 or y_max != 0.0
				if y_min == null or y_max == null:
					# Limits are variables/math: only clamp when one of them is not 0 at runtime
					code_lines.append("%svar _min_deg = %s" % [y_limit_indent, y_min_code])
					code_lines.append("%svar _max_deg = %s" % [y_limit_indent, y_max_code])
					code_lines.append("%sif _min_deg != 0.0 or _max_deg != 0.0:" % y_limit_indent)
					y_limit_indent += "\t"
					y_min_code = "_min_deg"
					y_max_code = "_max_deg"
					y_has_limits = true
				if y_has_limits:
					var axis_index = {"x": "0", "y": "1", "z": "2"}[y_rot_axis]
					var target_prefix = "_y_target." if y_target != "self" else ""
					code_lines.append("%svar _current_rot = %srotation_degrees[%s]" % [y_limit_indent, target_prefix, axis_index])

					code_lines.append("%svar _new_rot = _current_rot + _y_rotation" % y_limit_indent)
					code_lines.append("%s_new_rot = clamp(_new_rot, %s, %s)" % [y_limit_indent, y_min_code, y_max_code])
					code_lines.append("%s_y_rotation = _new_rot - _current_rot" % y_limit_indent)

				# Apply rotation
				var y_axis_vector = {"x": "Vector3.RIGHT", "y": "Vector3.UP", "z": "Vector3.BACK"}[y_rot_axis]
				var target_prefix = "_y_target." if y_target != "self" else ""
				# Do not touch transforms on a zero/clamped rotation: that can invalidate
				# physics interpolation even when mouse sensitivity is zero.
				code_lines.append("%s\tif not is_zero_approx(_y_rotation):" % y_indent)
				if y_use_local:
					code_lines.append("%s\t\t%srotate_object_local(%s, deg_to_rad(_y_rotation))" % [y_indent, target_prefix, y_axis_vector])
				else:
					code_lines.append("%s\t\t%srotate(%s, deg_to_rad(_y_rotation))" % [y_indent, target_prefix, y_axis_vector])
				code_lines.append("")

			if not use_x_axis and not use_y_axis:
				code_lines.append("pass")
			# Avoid target lookups entirely when there is no input.
			for i in range(2, code_lines.size()):
				code_lines[i] = "\t" + code_lines[i]
			code_lines.insert(2, "if _mouse_delta != Vector2.ZERO:")

			# Captured mouse mode handles recentering without synthetic cursor motion.

		"look_towards":
			var mouse_world_suffix = _safe_var_suffix(chain_name)
			var mouse_world_hit_var = "_mouse_world_hit_%s" % mouse_world_suffix
			var mouse_world_pos_var = "_mouse_world_pos_%s" % mouse_world_suffix
			code_lines.append(_generate_mouse_world_point_code(mouse_world_suffix))
			code_lines.append("if %s:" % mouse_world_hit_var)
			for line in _generate_mouse_target_ref(mouse_target).split("\n"):
				code_lines.append("\t" + line)
			for line in _generate_look_at_code(mouse_world_pos_var, mouse_facing_axis, mouse_turn_speed, mouse_lock_y, "_mouse_node").split("\n"):
				code_lines.append("\t" + line)

		"move_towards_cursor":
			var mouse_world_suffix = _safe_var_suffix(chain_name)
			var mouse_world_hit_var = "_mouse_world_hit_%s" % mouse_world_suffix
			var mouse_world_pos_var = "_mouse_world_pos_%s" % mouse_world_suffix
			code_lines.append(_generate_mouse_world_point_code(mouse_world_suffix))
			code_lines.append("if %s:" % mouse_world_hit_var)
			for line in _generate_mouse_target_ref(mouse_target).split("\n"):
				code_lines.append("\t" + line)
			for line in _generate_move_to_point_code(mouse_world_pos_var, mouse_velocity, mouse_acceleration, mouse_arrival_distance, mouse_lock_y, "_mouse_node").split("\n"):
				code_lines.append("\t" + line)

		"move_to_mouse_click":
			var button_code = _mouse_button_code(click_button)
			var click_pos_var = "_mouse_click_target_%s" % chain_name
			var click_has_var = "_mouse_click_has_target_%s" % chain_name
			var click_pressed_var = "_mouse_click_pressed_%s" % chain_name
			var mouse_world_suffix = _safe_var_suffix("%s_click" % chain_name)
			var mouse_world_hit_var = "_mouse_world_hit_%s" % mouse_world_suffix
			var mouse_world_pos_var = "_mouse_world_pos_%s" % mouse_world_suffix
			code_lines.append("var _mouse_click_now = Input.is_mouse_button_pressed(%s)" % button_code)
			code_lines.append("if _mouse_click_now and not %s:" % click_pressed_var)
			for line in _generate_mouse_world_point_code(mouse_world_suffix).split("\n"):
				code_lines.append("\t" + line)
			code_lines.append("\tif %s:" % mouse_world_hit_var)
			code_lines.append("\t\t%s = %s" % [click_pos_var, mouse_world_pos_var])
			code_lines.append("\t\t%s = true" % click_has_var)
			code_lines.append("%s = _mouse_click_now" % click_pressed_var)
			code_lines.append("if %s:" % click_has_var)
			for line in _generate_mouse_target_ref(mouse_target).split("\n"):
				code_lines.append("\t" + line)
			for line in _generate_move_to_point_code(click_pos_var, mouse_velocity, mouse_acceleration, mouse_arrival_distance, mouse_lock_y, "_mouse_node").split("\n"):
				code_lines.append("\t" + line)
			code_lines.append("\tif _mouse_node and _mouse_node.global_position.distance_to(%s) <= (%s):" % [click_pos_var, _numeric_expr(mouse_arrival_distance)])
			code_lines.append("\t\t%s = false" % click_has_var)

	var result = {
		"actuator_code": "\n".join(code_lines)
	}
	if mode == "mouse_look":
		result["member_vars"] = [
			"var _logic_mouse_delta: Vector2 = Vector2.ZERO",
			"var _logic_mouse_events: Array = []  # [start usec, end usec, motion still to apply]",
			"var _logic_mouse_clock_usec: int = 0",
			"var _logic_mouse_look_targets: Dictionary = {}"
		]
		# Hand each physics tick the mouse motion that arrived during its own
		# slice of real time (see _logic_mouse_take_tick_input()).
		result["pre_process_code"] = ["_logic_mouse_take_tick_input()"]
		result["ready_code"] = ["Input.mouse_mode = Input.MOUSE_MODE_CAPTURED", "set_meta(\"_logic_mouse_look_enabled\", true)"]
		# Clear once per tick, including ticks with inactive look chains.
		result["post_process_code"] = ["_logic_mouse_delta = Vector2.ZERO"]
		if properties.get("enable_physics_interpolation", true):
			# Physics interpolation itself is switched on in Project Settings by
			# Apply Code (get_required_project_settings()); doing it here, while
			# the scene is already running, drew scenery at the world origin.
			result["ready_code"].append("physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON")
			result["ready_code"].append("if not get_tree().physics_interpolation: push_warning(\"Mouse Look: turn on Project Settings > Physics > Common > Physics Interpolation (Apply Code does this) for smooth turning.\")")
		result["methods"] = ["input_handler::if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:\n\t_logic_mouse_record_motion(event.relative)\nelif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:\n\t_logic_mouse_delta = Vector2.ZERO\n\t_logic_mouse_events.clear()\n\tInput.mouse_mode = Input.MOUSE_MODE_VISIBLE\nelif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:\n\t_logic_mouse_delta = Vector2.ZERO\n\t_logic_mouse_events.clear()\n\tInput.mouse_mode = Input.MOUSE_MODE_CAPTURED"]
		result["methods"].append(MOUSE_TICK_INPUT_METHOD)
		result["methods"].append("\nfunc _logic_mouse_look_target(path: String) -> Node3D:\n\tvar cached: Dictionary = _logic_mouse_look_targets.get(path, {})\n\tvar target = cached.get(\"node\")\n\tif is_instance_valid(target):\n\t\treturn target\n\tvar now := Time.get_ticks_msec()\n\tif now < int(cached.get(\"retry_at\", 0)):\n\t\treturn null\n\ttarget = get_node_or_null(NodePath(path))\n\tif target == null and get_tree().current_scene:\n\t\ttarget = get_tree().current_scene.find_child(path, true, false)\n\tif target == null:\n\t\ttarget = get_tree().root.find_child(path, true, false)\n\tif not target is Node3D:\n\t\ttarget = null\n\t_logic_mouse_look_targets[path] = {\"node\": target, \"retry_at\": now + 1000}\n\treturn target\n")
	if mode == "move_to_mouse_click":
		result["member_vars"] = [
			"var _mouse_click_target_%s: Vector3 = Vector3.ZERO" % chain_name,
			"var _mouse_click_has_target_%s: bool = false" % chain_name,
			"var _mouse_click_pressed_%s: bool = false" % chain_name
		]
	return result


## Convert a value to a code expression.
## If it's a number (or string of a number), returns the numeric literal.
## Otherwise returns it as-is (a variable name or expression).
## True only when the user entered a literal numeric value greater than zero.
## Variable/expression values are treated as potentially non-zero so generated code preserves them.

## One mouse-look limit: op is "max" for a minimum, "min" for a maximum.
## A literal 0 means no limit (nothing added); a variable/math limit is
## checked at runtime (0 = no limit).
func _append_limit(lines: Array[String], indent: String, op: String, literal, code: String, var_name: String) -> void:
	if literal == null:
		lines.append("%svar %s = %s" % [indent, var_name, code])
		lines.append("%sif %s != 0.0:" % [indent, var_name])
		lines.append("%s\t_new_rot = %s(_new_rot, %s)" % [indent, op, var_name])
	elif literal != 0.0:
		lines.append("%s_new_rot = %s(_new_rot, %s)" % [indent, op, code])


func _mouse_button_code(button: String) -> String:
	match button:
		"right": return "MOUSE_BUTTON_RIGHT"
		"middle": return "MOUSE_BUTTON_MIDDLE"
		_: return "MOUSE_BUTTON_LEFT"


func _safe_var_suffix(raw_value) -> String:
	var suffix = str(raw_value).strip_edges()
	if suffix.is_empty():
		return "default"
	# Chain names produced by the add-on are already identifier-safe. These
	# replacements keep manually supplied or legacy suffixes from producing
	# invalid generated variable names.
	return suffix.replace(" ", "_").replace("-", "_").replace(".", "_").replace("/", "_").replace(":", "_")


func _generate_mouse_world_point_code(suffix: String) -> String:
	var safe_suffix = _safe_var_suffix(suffix)
	var hit_var = "_mouse_world_hit_%s" % safe_suffix
	var pos_var = "_mouse_world_pos_%s" % safe_suffix
	var viewport_var = "_mouse_viewport_%s" % safe_suffix
	var camera_var = "_mouse_camera_%s" % safe_suffix
	var screen_pos_var = "_mouse_screen_pos_%s" % safe_suffix
	var ray_origin_var = "_ray_origin_%s" % safe_suffix
	var ray_dir_var = "_ray_dir_%s" % safe_suffix
	var ray_params_var = "_ray_params_%s" % safe_suffix
	var ray_hit_var = "_ray_hit_%s" % safe_suffix
	var plane_var = "_plane_%s" % safe_suffix
	var plane_hit_var = "_plane_hit_%s" % safe_suffix
	var lines: Array[String] = []
	lines.append("var %s = false" % hit_var)
	lines.append("var %s = Vector3.ZERO" % pos_var)
	lines.append("var %s = get_viewport()" % viewport_var)
	lines.append("var %s = %s.get_camera_3d()" % [camera_var, viewport_var])
	lines.append("if %s:" % camera_var)
	lines.append("\tvar %s = %s.get_mouse_position()" % [screen_pos_var, viewport_var])
	lines.append("\tvar %s = %s.project_ray_origin(%s)" % [ray_origin_var, camera_var, screen_pos_var])
	lines.append("\tvar %s = %s.project_ray_normal(%s)" % [ray_dir_var, camera_var, screen_pos_var])
	lines.append("\tvar %s = PhysicsRayQueryParameters3D.new()" % ray_params_var)
	lines.append("\t%s.from = %s" % [ray_params_var, ray_origin_var])
	lines.append("\t%s.to = %s + %s * 10000.0" % [ray_params_var, ray_origin_var, ray_dir_var])
	lines.append("\tif self is CollisionObject3D:")
	lines.append("\t\t%s.exclude = [(self as CollisionObject3D).get_rid()]" % ray_params_var)
	lines.append("\tvar %s = get_world_3d().direct_space_state.intersect_ray(%s)" % [ray_hit_var, ray_params_var])
	lines.append("\tif %s:" % ray_hit_var)
	lines.append("\t\t%s = %s.position" % [pos_var, ray_hit_var])
	lines.append("\t\t%s = true" % hit_var)
	lines.append("\telse:")
	lines.append("\t\tvar %s = Plane(Vector3.UP, global_position.y)" % plane_var)
	lines.append("\t\tvar %s = %s.intersects_ray(%s, %s)" % [plane_hit_var, plane_var, ray_origin_var, ray_dir_var])
	lines.append("\t\tif %s != null:" % plane_hit_var)
	lines.append("\t\t\t%s = %s" % [pos_var, plane_hit_var])
	lines.append("\t\t\t%s = true" % hit_var)
	return "\n".join(lines)


func _generate_mouse_target_ref(target_name: String) -> String:
	var lines: Array[String] = []
	if target_name == "self" or str(target_name).strip_edges().is_empty():
		lines.append("var _mouse_node = self")
	else:
		var escaped = _gd_string(str(target_name))
		lines.append("var _mouse_node = get_node_or_null(\"%s\")" % escaped)
		lines.append("if _mouse_node == null and get_tree().current_scene:")
		lines.append("\t_mouse_node = get_tree().current_scene.find_child(\"%s\", true, false)" % escaped)
		lines.append("if _mouse_node == null:")
		lines.append("\t_mouse_node = get_tree().root.find_child(\"%s\", true, false)" % escaped)
	lines.append("if _mouse_node and _mouse_node is Node3D:")
	return "\n".join(lines)


func _generate_look_at_code(target_pos: String, axis: String, turn_speed, lock_y: bool, node_ref: String) -> String:
	var lines: Array[String] = []
	var turn_expr = _numeric_expr(turn_speed)
	lines.append("\tvar _look_dir = %s - %s.global_position" % [target_pos, node_ref])
	if lock_y:
		# Flat player-style aiming is most reliable when we solve yaw directly.
		# This avoids Basis/looking_at edge cases on CharacterBody3D and keeps pitch/roll unchanged.
		lines.append("\t_look_dir.y = 0.0")
		lines.append("\tif _look_dir.length() > 0.001:")
		lines.append("\t\t_look_dir = _look_dir.normalized()")
		lines.append("\t\tvar _target_yaw = atan2(-_look_dir.x, -_look_dir.z)")
		match axis:
			"+z":
				lines.append("\t\t_target_yaw += PI")
			"+x":
				lines.append("\t\t_target_yaw += PI * 0.5")
			"-x":
				lines.append("\t\t_target_yaw -= PI * 0.5")
			_:
				pass
		if _literal_gt_zero(turn_speed):
			lines.append("\t\t%s.global_rotation.y = lerp_angle(%s.global_rotation.y, _target_yaw, clamp((%s) * _delta, 0.0, 1.0))" % [node_ref, node_ref, turn_expr])
		else:
			lines.append("\t\t%s.global_rotation.y = _target_yaw" % node_ref)
	else:
		# Full 3D aiming uses looking_at. Smoothing speed is a response rate per second; 0 snaps instantly.
		lines.append("\tif _look_dir.length() > 0.001:")
		lines.append("\t\tvar _axis_offset = Basis()")
		match axis:
			"+z":
				lines.append("\t\t_axis_offset = Basis(Vector3.UP, PI)")
			"+x":
				lines.append("\t\t_axis_offset = Basis(Vector3.UP, PI * 0.5)")
			"-x":
				lines.append("\t\t_axis_offset = Basis(Vector3.UP, -PI * 0.5)")
			_:
				pass
		lines.append("\t\tvar _target_basis = Transform3D().looking_at(_look_dir.normalized(), Vector3.UP).basis * _axis_offset")
		if _literal_gt_zero(turn_speed):
			lines.append("\t\t%s.global_basis = %s.global_basis.slerp(_target_basis, clamp((%s) * _delta, 0.0, 1.0))" % [node_ref, node_ref, turn_expr])
		else:
			lines.append("\t\t%s.global_basis = _target_basis" % node_ref)
	return "\n".join(lines)

func _generate_move_to_point_code(target_pos: String, velocity, acceleration, arrival_distance, lock_y: bool, node_ref: String) -> String:
	var lines: Array[String] = []
	var arrival_expr = _numeric_expr(arrival_distance)
	var velocity_expr = _numeric_expr(velocity)
	var accel_expr = _numeric_expr(acceleration)
	lines.append("\tvar _to_mouse_target = %s - %s.global_position" % [target_pos, node_ref])
	if lock_y:
		lines.append("\t_to_mouse_target.y = 0.0")
	lines.append("\tvar _mouse_dist = _to_mouse_target.length()")
	lines.append("\tif _mouse_dist > (%s):" % arrival_expr)
	lines.append("\t\tvar _move_dir = _to_mouse_target.normalized()")
	if _literal_gt_zero(acceleration):
		lines.append("\t\tvar _target_vel = _move_dir * (%s)" % velocity_expr)
		lines.append("\t\tvar _current_vel = Vector3.ZERO")
		lines.append("\t\tvar _cb3d = (%s as Node) as CharacterBody3D" % node_ref)
		lines.append("\t\tif _cb3d:")
		lines.append("\t\t\t_current_vel = _cb3d.velocity")
		if lock_y:
			lines.append("\t\t\t_current_vel.y = 0.0")
		lines.append("\t\tvar _new_vel = _current_vel.move_toward(_target_vel, (%s) * _delta)" % accel_expr)
	else:
		lines.append("\t\tvar _new_vel = _move_dir * (%s)" % velocity_expr)
		lines.append("\t\tvar _cb3d = (%s as Node) as CharacterBody3D" % node_ref)
	lines.append("\t\tif _cb3d:")
	lines.append("\t\t\t_cb3d.velocity.x = _new_vel.x")
	if not lock_y:
		lines.append("\t\t\t_cb3d.velocity.y = _new_vel.y")
	lines.append("\t\t\t_cb3d.velocity.z = _new_vel.z")
	lines.append("\t\telse:")
	lines.append("\t\t\t%s.global_position += _new_vel * _delta" % node_ref)
	lines.append("\telse:")
	lines.append("\t\tvar _arrived_cb3d = (%s as Node) as CharacterBody3D" % node_ref)
	lines.append("\t\tif _arrived_cb3d:")
	lines.append("\t\t\t_arrived_cb3d.velocity.x = 0.0")
	if not lock_y:
		lines.append("\t\t\t_arrived_cb3d.velocity.y = 0.0")
	lines.append("\t\t\t_arrived_cb3d.velocity.z = 0.0")
	return "\n".join(lines)

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Controls cursor visibility, mouse-look rotation, and mouse cursor world interactions.",
		"enable_physics_interpolation": "Turn on physics interpolation in Project Settings (done when you press Apply Code) for smooth physics-tick mouse look. This affects the whole scene and adds up to one physics tick of visual delay. Disable if your project manages interpolation itself. Camera targets should use Inherit or On.",
		"mode": "Cursor Visibility: show/hide the OS cursor.\nMouse Look: rotate from mouse movement.\nLook Towards: face the world point under the cursor.\nMove Towards Cursor: continuously move toward the world point under the cursor.\nMove To Mouse Click: store the clicked world point and move to it.",
		"cursor_visible": "Show or hide the OS mouse cursor.",
		"x_sensitivity": "Horizontal mouse-look sensitivity. Higher = faster turning.",
		"y_sensitivity": "Vertical mouse-look sensitivity. Higher = faster looking up/down.",
		"x_threshold": "Minimum horizontal mouse movement to register.",
		"y_threshold": "Minimum vertical mouse movement to register.",
		"x_invert": "Invert horizontal mouse-look direction.",
		"y_invert": "Invert vertical mouse-look direction.",
		"mouse_target": "Node to rotate or move. Use self, or a child node path/name.",
		"mouse_velocity": "Movement speed in units per second. Accepts numbers, variables, or expressions.",
		"mouse_acceleration": "Acceleration rate. 0 = instant full speed. Accepts numbers, variables, or expressions.",
		"mouse_turn_speed": "Rotation speed in degrees/sec. 0 = instant. Accepts numbers, variables, or expressions.",
		"mouse_arrival_distance": "Distance at which the move-to point is considered reached.",
		"mouse_facing_axis": "Which local axis points toward the cursor world point.",
		"mouse_lock_y": "Keep movement/aiming flat on the XZ plane.",
		"click_button": "Mouse button that stores the Move To Mouse Click destination.",
	}
