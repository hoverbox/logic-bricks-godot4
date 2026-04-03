@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Third Person Camera Actuator
## Rotates a pivot Node3D with mouse/joystick input, and positions a Camera3D
## at the pivot's location each frame. Both are assigned via @export in the Inspector,
## so neither node needs to be in any particular place in the hierarchy — the camera
## can live inside a SubViewport (for split screen) or anywhere else and it will still work.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "3rd Person Camera"


func _initialize_properties() -> void:
	properties = {
		"input_mode":         "mouse",   # mouse, joystick, both
		"rotate_character":   true,      # true = yaw turns character, false = yaw turns pivot only
		"align_mode":         "instant", # instant, smooth
		"turn_speed":         10.0,
		"move_actions":       "ui_up,ui_down,ui_left,ui_right",
		# Sensitivity
		"sensitivity_x":      0.3,
		"sensitivity_y":      0.3,
		"export_sensitivity": false,
		# Invert
		"invert_x":           false,
		"invert_y":           false,
		"export_invert":      false,
		# Vertical clamp
		"pitch_min":          -60.0,
		"pitch_max":          30.0,
		# Joystick
		"joystick_device":    0,
		"joy_stick":          "right",  # left, right
		"joy_deadzone":       0.15,
		"joy_sensitivity":    100.0,
		# Mouse capture
		"capture_mouse":      true,
	}


func get_property_definitions() -> Array:
	return [
		# ── Setup ──
		{"name": "setup_group", "type": TYPE_NIL, "hint": 999, "hint_string": "Setup"},
		{
			"name": "input_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Mouse,Joystick,Both",
			"default": "mouse"
		},
		{"name": "rotate_character", "type": TYPE_BOOL, "default": true},
		{
			"name": "align_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Instant,Smooth",
			"default": "instant"
		},
		{"name": "turn_speed",    "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "1.0,30.0,0.5", "default": 10.0},
		{"name": "move_actions",  "type": TYPE_STRING, "default": "ui_up,ui_down,ui_left,ui_right"},
		{"name": "capture_mouse", "type": TYPE_BOOL,  "default": true},

		# ── Sensitivity ──
		{"name": "sensitivity_group", "type": TYPE_NIL, "hint": 999, "hint_string": "Sensitivity"},
		{"name": "sensitivity_x",      "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.01,5.0,0.01", "default": 0.3},
		{"name": "sensitivity_y",      "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.01,5.0,0.01", "default": 0.3},
		{"name": "export_sensitivity", "type": TYPE_BOOL,  "default": false},

		# ── Invert ──
		{"name": "invert_group",  "type": TYPE_NIL, "hint": 999, "hint_string": "Invert"},
		{"name": "invert_x",      "type": TYPE_BOOL, "default": false},
		{"name": "invert_y",      "type": TYPE_BOOL, "default": false},
		{"name": "export_invert", "type": TYPE_BOOL, "default": false},

		# ── Pitch Clamp ──
		{"name": "pitch_group", "type": TYPE_NIL, "hint": 999, "hint_string": "Vertical Clamp"},
		{"name": "pitch_min", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "-90.0,0.0,1.0",  "default": -60.0},
		{"name": "pitch_max", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,90.0,1.0",   "default": 30.0},

		# ── Joystick ──
		{"name": "joy_group",       "type": TYPE_NIL,   "hint": 999, "hint_string": "Joystick"},
		{
			"name": "joystick_device",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,7,1",
			"default": 0
		},
		{
			"name": "joy_stick",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Left Stick,Right Stick",
			"default": "right"
		},
		{"name": "joy_deadzone",    "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,0.9,0.01", "default": 0.15},
		{"name": "joy_sensitivity", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "10.0,360.0,5.0", "default": 100.0},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":       "Orbits a Camera3D around the character via a pivot Node3D.\nAssign both the pivot and the camera in the Inspector.\nThe camera can live anywhere in the scene — including inside a SubViewport for split screen.",
		"input_mode":         "Which input drives the camera.\nMouse: mouse motion only.\nJoystick: right stick only.\nBoth: mouse and joystick together.",
		"rotate_character":   "On: horizontal look rotates the whole character (third-person shooter).\nOff: horizontal look rotates the pivot only, character facing is independent.",
		"align_mode":         "How the character aligns to camera direction when moving.\nInstant: snaps immediately.\nSmooth: lerps over time.",
		"turn_speed":         "How quickly the character rotates toward the camera in Smooth mode.",
		"move_actions":       "Comma-separated input actions that trigger character alignment to camera yaw.\nDefault: ui_up,ui_down,ui_left,ui_right",
		"capture_mouse":      "Re-capture the mouse each frame if released.\nDisable to allow Escape or a pause menu to free the cursor.",
		"sensitivity_x":      "Horizontal look speed.",
		"sensitivity_y":      "Vertical look speed.",
		"export_sensitivity": "Expose sensitivity as @export vars so a settings menu can adjust them at runtime.",
		"invert_x":           "Invert horizontal look.",
		"invert_y":           "Invert vertical look.",
		"export_invert":      "Expose invert flags as @export vars for runtime toggling.",
		"pitch_min":          "Maximum look-down angle in degrees (negative = below horizon).",
		"pitch_max":          "Maximum look-up angle in degrees.",
		"joystick_device":    "Gamepad device slot (0–7). 0 = first connected controller, 1 = second, etc.",
		"joy_stick":          "Which stick drives the camera look.\nLeft Stick: axes 0 (X) and 1 (Y).\nRight Stick: axes 2 (X) and 3 (Y).",
		"joy_deadzone":       "Ignore joystick input below this magnitude.",
		"joy_sensitivity":    "Joystick look speed in degrees per second. Full stick deflection rotates at this rate.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var input_mode       = str(properties.get("input_mode", "mouse")).to_lower()
	var rotate_character = properties.get("rotate_character", true)
	var align_mode       = str(properties.get("align_mode", "instant")).to_lower()
	var turn_speed       = float(properties.get("turn_speed", 10.0))
	var move_actions_str = str(properties.get("move_actions", "ui_up,ui_down,ui_left,ui_right"))
	var capture_mouse    = properties.get("capture_mouse", true)
	var sens_x           = float(properties.get("sensitivity_x", 0.3))
	var sens_y           = float(properties.get("sensitivity_y", 0.3))
	var export_sens      = properties.get("export_sensitivity", false)
	var invert_x         = properties.get("invert_x", false)
	var invert_y         = properties.get("invert_y", false)
	var export_invert    = properties.get("export_invert", false)
	var pitch_min        = float(properties.get("pitch_min", -60.0))
	var pitch_max        = float(properties.get("pitch_max", 30.0))
	var joy_device       = int(properties.get("joystick_device", 0))
	var joy_stick        = str(properties.get("joy_stick", "right")).to_lower()
	# Map stick choice to axis indices (standard Godot JoyAxis layout)
	var joy_axis_x       = 0 if joy_stick in ["left", "left stick"] else 2
	var joy_axis_y       = 1 if joy_stick in ["left", "left stick"] else 3
	var joy_deadzone     = float(properties.get("joy_deadzone", 0.15))
	var joy_sens         = float(properties.get("joy_sensitivity", 100.0))

	# Stable label derived from instance name
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name
	var label = _export_label

	var pivot_var  = "_%s_pivot"  % label
	var camera_var = "_%s_camera" % label
	var yaw_var    = "_%s_yaw"    % label
	var pitch_var  = "_%s_pitch"  % label
	var offset_var     = "_%s_pos_offset"     % label
	var cam_offset_var = "_%s_cam_offset"     % label

	var use_mouse = input_mode in ["mouse", "both"]
	var use_joy   = input_mode in ["joystick", "both"]

	var member_vars: Array[String] = []
	var ready_lines: Array[String] = []
	var code_lines:  Array[String] = []

	# ── @export vars: pivot and camera assigned in the Inspector ──
	member_vars.append("@export var %s: Node3D"   % pivot_var)
	member_vars.append("@export var %s: Camera3D" % camera_var)

	# Sensitivity
	if export_sens:
		member_vars.append("@export var _%s_sens_x: float = %.3f" % [label, sens_x])
		member_vars.append("@export var _%s_sens_y: float = %.3f" % [label, sens_y])
	else:
		member_vars.append("var _%s_sens_x: float = %.3f" % [label, sens_x])
		member_vars.append("var _%s_sens_y: float = %.3f" % [label, sens_y])

	# Invert
	if export_invert:
		member_vars.append("@export var _%s_inv_x: bool = %s" % [label, str(invert_x).to_lower()])
		member_vars.append("@export var _%s_inv_y: bool = %s" % [label, str(invert_y).to_lower()])
	else:
		member_vars.append("var _%s_inv_x: bool = %s" % [label, str(invert_x).to_lower()])
		member_vars.append("var _%s_inv_y: bool = %s" % [label, str(invert_y).to_lower()])

	member_vars.append("var %s: float = 0.0"            % yaw_var)
	member_vars.append("var %s: float = 0.0"            % pitch_var)
	member_vars.append("var %s: Vector3 = Vector3.ZERO" % offset_var)
	member_vars.append("var %s: Vector3 = Vector3.ZERO" % cam_offset_var)

	# ── _ready ──
	ready_lines.append("# 3rd Person Camera: validate pivot and camera")
	ready_lines.append("if not %s:" % pivot_var)
	ready_lines.append("\tpush_warning(\"3rd Person Camera: pivot not assigned — drag a Node3D into '%s' in the Inspector\")" % pivot_var)
	ready_lines.append("if not %s:" % camera_var)
	ready_lines.append("\tpush_warning(\"3rd Person Camera: camera not assigned — drag a Camera3D into '%s' in the Inspector\")" % camera_var)
	ready_lines.append("if %s:" % pivot_var)
	ready_lines.append("\t%s = %s.global_rotation_degrees.y" % [yaw_var, pivot_var])
	ready_lines.append("\t%s = %s.global_rotation_degrees.x" % [pitch_var, pivot_var])
	ready_lines.append("\t%s = %s.global_position - global_position  # Character-to-pivot offset" % [offset_var, pivot_var])
	ready_lines.append("\tif %s:" % camera_var)
	ready_lines.append("\t\t# Camera's offset from pivot in pivot-local space — captured before any reparenting")
	ready_lines.append("\t\t%s = %s.global_basis.inverse() * (%s.global_position - %s.global_position)" % [cam_offset_var, pivot_var, camera_var, pivot_var])
	if use_mouse:
		ready_lines.append("Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)")
	ready_lines.append("await get_tree().process_frame")
	ready_lines.append("if %s:" % camera_var)
	ready_lines.append("\t%s.make_current()" % camera_var)

	# ── Actuator code (runs every frame) ──
	code_lines.append("# 3rd Person Camera")
	code_lines.append("if %s:" % pivot_var)

	# Mouse input
	if use_mouse:
		if capture_mouse:
			code_lines.append("\tif Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:")
			code_lines.append("\t\tInput.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)")
		code_lines.append("\tif Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:")
		code_lines.append("\t\tvar _mouse_vel = Input.get_last_mouse_velocity()")
		code_lines.append("\t\tvar _mx = _mouse_vel.x * _%s_sens_x * 0.001 * (-1.0 if _%s_inv_x else 1.0)" % [label, label])
		code_lines.append("\t\tvar _my = _mouse_vel.y * _%s_sens_y * 0.001 * (-1.0 if _%s_inv_y else 1.0)" % [label, label])
		code_lines.append("\t\t%s -= _mx" % yaw_var)
		code_lines.append("\t\t%s -= _my" % pitch_var)

	# Joystick input
	# joy_sensitivity is degrees/second; axis returns -1.0..1.0, scaled by delta.
	# A value of 100.0 means full stick deflection = 100 degrees/sec.
	if use_joy:
		code_lines.append("\tvar _jx = Input.get_joy_axis(%d, %d)" % [joy_device, joy_axis_x])
		code_lines.append("\tvar _jy = Input.get_joy_axis(%d, %d)" % [joy_device, joy_axis_y])
		code_lines.append("\tif abs(_jx) > %.3f:" % joy_deadzone)
		code_lines.append("\t\t%s -= _jx * %.2f * _delta * (-1.0 if _%s_inv_x else 1.0)" % [yaw_var, joy_sens, label])
		code_lines.append("\tif abs(_jy) > %.3f:" % joy_deadzone)
		code_lines.append("\t\t%s -= _jy * %.2f * _delta * (-1.0 if _%s_inv_y else 1.0)" % [pitch_var, joy_sens, label])

	# Clamp pitch
	code_lines.append("\t%s = clampf(%s, %.2f, %.2f)" % [pitch_var, pitch_var, pitch_min, pitch_max])

	# Apply pivot transform (world-space so hierarchy doesn't matter)
	code_lines.append("\t%s.global_position = global_position + %s" % [pivot_var, offset_var])
	code_lines.append("\t%s.global_rotation_degrees.y = %s" % [pivot_var, yaw_var])
	code_lines.append("\t%s.global_rotation_degrees.x = %s" % [pivot_var, pitch_var])

	# Orbit the camera around the pivot:
	# rotate the camera's local offset by the pivot's new orientation,
	# then place the camera at pivot_world_pos + rotated_offset.
	# This works regardless of where the camera lives in the hierarchy.
	code_lines.append("\tif %s:" % camera_var)
	code_lines.append("\t\t%s.global_position = %s.global_position + %s.global_basis * %s" % [camera_var, pivot_var, pivot_var, cam_offset_var])
	code_lines.append("\t\t%s.global_basis = %s.global_basis" % [camera_var, pivot_var])

	# Character alignment
	if rotate_character:
		var actions = []
		for a in move_actions_str.split(","):
			a = a.strip_edges()
			if not a.is_empty():
				actions.append("Input.is_action_pressed(\"%s\")" % a)
		var move_condition = " or ".join(actions) if actions.size() > 0 else "false"
		code_lines.append("\tvar _moving = %s" % move_condition)
		code_lines.append("\tif _moving:")
		if align_mode == "smooth":
			code_lines.append("\t\tvar _target_yaw = %s" % yaw_var)
			code_lines.append("\t\tvar _cur_yaw = global_rotation_degrees.y")
			code_lines.append("\t\tvar _diff = fmod(_target_yaw - _cur_yaw + 540.0, 360.0) - 180.0")
			code_lines.append("\t\tglobal_rotation_degrees.y += _diff * clampf(%.1f * _delta, 0.0, 1.0)" % turn_speed)
		else:
			code_lines.append("\t\tglobal_rotation_degrees.y = %s" % yaw_var)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars":   member_vars,
		"ready_code":    ready_lines,
	}
