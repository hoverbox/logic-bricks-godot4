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
			"default": "self"
		},
		{
			"name": "y_target",
			"type": TYPE_STRING,
			"default": "self"
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
			"default": "self"
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


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "cursor_visibility")
	var cursor_visible = properties.get("cursor_visible", false)
	var use_x_axis = properties.get("use_x_axis", true)
	var use_y_axis = properties.get("use_y_axis", true)
	var x_target = properties.get("x_target", "self")
	var y_target = properties.get("y_target", "self")
	var x_sensitivity = float(properties.get("x_sensitivity", 0.1))
	var y_sensitivity = float(properties.get("y_sensitivity", 0.1))
	var x_invert = properties.get("x_invert", false)
	var y_invert = properties.get("y_invert", false)
	var x_threshold = float(properties.get("x_threshold", 0.0))
	var y_threshold = float(properties.get("y_threshold", 0.0))
	var x_min = float(properties.get("x_min_degrees", 0.0))
	var x_max = float(properties.get("x_max_degrees", 0.0))
	var y_min = float(properties.get("y_min_degrees", -90.0))
	var y_max = float(properties.get("y_max_degrees", 90.0))
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
				code_lines.append("Input.mouse_mode = Input.MOUSE_MODE_VISIBLE")
			else:
				code_lines.append("Input.mouse_mode = Input.MOUSE_MODE_HIDDEN")

		"mouse_look":
			code_lines.append("# Mouse look rotation")
			code_lines.append("var _viewport = get_viewport()")
			code_lines.append("var _viewport_size = _viewport.get_visible_rect().size")
			code_lines.append("var _mouse_pos = _viewport.get_mouse_position()")
			code_lines.append("var _center = _viewport_size / 2.0")
			code_lines.append("var _mouse_delta = _mouse_pos - _center")
			code_lines.append("")

			if use_x_axis:
				code_lines.append("# X axis (horizontal) mouse movement")

				# Determine target node and indentation
				var x_indent = ""
				var x_node_ref = "self" if x_target == "self" else ("get_node_or_null(\"%s\")" % x_target)
				if x_target != "self":
					code_lines.append("var _x_target = %s" % x_node_ref)
					code_lines.append("if _x_target:")
					x_indent = "\t"

				code_lines.append("%sif abs(_mouse_delta.x) > %.3f:" % [x_indent, x_threshold])
				var x_mult = 1.0 if x_invert else -1.0
				code_lines.append("%s\tvar _x_rotation = _mouse_delta.x * %.3f * %.1f" % [x_indent, x_sensitivity, x_mult])

				# Apply limits if set
				if x_min != 0.0 or x_max != 0.0:
					var axis_index = {"x": "0", "y": "1", "z": "2"}[x_rot_axis]
					var target_prefix = "_x_target." if x_target != "self" else ""
					if x_use_local:
						code_lines.append("%s\tvar _current_rot = %srotation_degrees[%s]" % [x_indent, target_prefix, axis_index])
					else:
						code_lines.append("%s\tvar _current_rot = %sglobal_rotation_degrees[%s]" % [x_indent, target_prefix, axis_index])

					code_lines.append("%s\tvar _new_rot = _current_rot + _x_rotation" % x_indent)
					if x_min != 0.0:
						code_lines.append("%s\t_new_rot = max(_new_rot, %.2f)" % [x_indent, x_min])
					if x_max != 0.0:
						code_lines.append("%s\t_new_rot = min(_new_rot, %.2f)" % [x_indent, x_max])
					code_lines.append("%s\t_x_rotation = _new_rot - _current_rot" % x_indent)

				# Apply rotation
				var x_axis_vector = {"x": "Vector3.RIGHT", "y": "Vector3.UP", "z": "Vector3.BACK"}[x_rot_axis]
				var target_prefix = "_x_target." if x_target != "self" else ""
				if x_use_local:
					code_lines.append("%s\t%srotate_object_local(%s, deg_to_rad(_x_rotation))" % [x_indent, target_prefix, x_axis_vector])
				else:
					code_lines.append("%s\t%srotate(%s, deg_to_rad(_x_rotation))" % [x_indent, target_prefix, x_axis_vector])
				code_lines.append("")

			if use_y_axis:
				code_lines.append("# Y axis (vertical) mouse movement")

				# Determine target node and indentation
				var y_indent = ""
				var y_node_ref = "self" if y_target == "self" else ("get_node_or_null(\"%s\")" % y_target)
				if y_target != "self":
					code_lines.append("var _y_target = %s" % y_node_ref)
					code_lines.append("if _y_target:")
					y_indent = "\t"

				code_lines.append("%sif abs(_mouse_delta.y) > %.3f:" % [y_indent, y_threshold])
				var y_mult = 1.0 if y_invert else -1.0
				code_lines.append("%s\tvar _y_rotation = _mouse_delta.y * %.3f * %.1f" % [y_indent, y_sensitivity, y_mult])

				# Apply limits
				if y_min != 0.0 or y_max != 0.0:
					var axis_index = {"x": "0", "y": "1", "z": "2"}[y_rot_axis]
					var target_prefix = "_y_target." if y_target != "self" else ""
					if y_use_local:
						code_lines.append("%s\tvar _current_rot = %srotation_degrees[%s]" % [y_indent, target_prefix, axis_index])
					else:
						code_lines.append("%s\tvar _current_rot = %sglobal_rotation_degrees[%s]" % [y_indent, target_prefix, axis_index])

					code_lines.append("%s\tvar _new_rot = _current_rot + _y_rotation" % y_indent)
					code_lines.append("%s\t_new_rot = clamp(_new_rot, %.2f, %.2f)" % [y_indent, y_min, y_max])
					code_lines.append("%s\t_y_rotation = _new_rot - _current_rot" % y_indent)

				# Apply rotation
				var y_axis_vector = {"x": "Vector3.RIGHT", "y": "Vector3.UP", "z": "Vector3.BACK"}[y_rot_axis]
				var target_prefix = "_y_target." if y_target != "self" else ""
				if y_use_local:
					code_lines.append("%s\t%srotate_object_local(%s, deg_to_rad(_y_rotation))" % [y_indent, target_prefix, y_axis_vector])
				else:
					code_lines.append("%s\t%srotate(%s, deg_to_rad(_y_rotation))" % [y_indent, target_prefix, y_axis_vector])
				code_lines.append("")

			if recenter:
				code_lines.append("# Recenter cursor")
				code_lines.append("_viewport.warp_mouse(_center)")

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
			code_lines.append("\tif _mouse_node and _mouse_node.global_position.distance_to(%s) <= (%s):" % [click_pos_var, _to_expr(mouse_arrival_distance)])
			code_lines.append("\t\t%s = false" % click_has_var)

	var result = {
		"actuator_code": "\n".join(code_lines)
	}
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
func _to_expr(val) -> String:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return "%.3f" % val
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s


## True only when the user entered a literal numeric value greater than zero.
## Variable/expression values are treated as potentially non-zero so generated code preserves them.
func _literal_gt_zero(val) -> bool:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return float(val) > 0.0
	var s = str(val).strip_edges()
	if s.is_valid_float() or s.is_valid_int():
		return float(s) > 0.0
	return true


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
		var escaped = str(target_name).replace("\"", "\\\"")
		lines.append("var _mouse_node = get_node_or_null(\"%s\")" % escaped)
	lines.append("if _mouse_node and _mouse_node is Node3D:")
	return "\n".join(lines)


func _generate_look_at_code(target_pos: String, axis: String, turn_speed, lock_y: bool, node_ref: String) -> String:
	var lines: Array[String] = []
	var turn_expr = _to_expr(turn_speed)
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
	var arrival_expr = _to_expr(arrival_distance)
	var velocity_expr = _to_expr(velocity)
	var accel_expr = _to_expr(acceleration)
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
	return "\n".join(lines)
