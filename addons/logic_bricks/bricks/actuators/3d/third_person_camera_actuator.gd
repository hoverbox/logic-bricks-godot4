@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Third Person Camera Actuator
## Orbits a Camera3D (via SpringArm3D or pivot node) around the character
## using mouse motion and/or joystick input.
## Attach this actuator to your character node.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "3rd Person Camera"


func _initialize_properties() -> void:
	properties = {
		"input_mode":         "mouse",  # mouse, joystick, both
		"rotate_character":   true,     # true = yaw turns character, false = yaw turns pivot only
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
		"joy_axis_x":         2,
		"joy_axis_y":         3,
		"joy_deadzone":       0.15,
		"joy_sensitivity":    2.0,
		# Mouse capture
		"capture_mouse":      true,    # Re-capture if lost — disable to allow Escape/menu to free cursor
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
		{"name": "capture_mouse",    "type": TYPE_BOOL, "default": true},

		# ── Sensitivity ──
		{"name": "sensitivity_group", "type": TYPE_NIL, "hint": 999, "hint_string": "Sensitivity"},
		{"name": "sensitivity_x",      "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.01,5.0,0.01", "default": 0.3},
		{"name": "sensitivity_y",      "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.01,5.0,0.01", "default": 0.3},
		{"name": "export_sensitivity", "type": TYPE_BOOL,  "default": false},

		# ── Invert ──
		{"name": "invert_group", "type": TYPE_NIL, "hint": 999, "hint_string": "Invert"},
		{"name": "invert_x",     "type": TYPE_BOOL, "default": false},
		{"name": "invert_y",     "type": TYPE_BOOL, "default": false},
		{"name": "export_invert","type": TYPE_BOOL, "default": false},

		# ── Pitch Clamp ──
		{"name": "pitch_group", "type": TYPE_NIL, "hint": 999, "hint_string": "Vertical Clamp"},
		{"name": "pitch_min", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "-90.0,0.0,1.0",  "default": -60.0},
		{"name": "pitch_max", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,90.0,1.0",   "default": 30.0},

		# ── Joystick ──
		{"name": "joy_group", "type": TYPE_NIL, "hint": 999, "hint_string": "Joystick", "collapsed": true},
		{"name": "joystick_device",  "type": TYPE_INT,   "default": 0},
		{"name": "joy_axis_x",       "type": TYPE_INT,   "default": 2},
		{"name": "joy_axis_y",       "type": TYPE_INT,   "default": 3},
		{"name": "joy_deadzone",     "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,0.9,0.01", "default": 0.15},
		{"name": "joy_sensitivity",  "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,10.0,0.1", "default": 2.0},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":       "Orbits a camera around the character using mouse and/or joystick input.\nAttach to the character node. The camera pivot is assigned via @export in the Inspector.",
		"input_mode":         "Which input drives the camera.\nMouse: mouse motion only.\nJoystick: right stick only.\nBoth: mouse and joystick together.",
		"rotate_character":   "On: horizontal look rotates the whole character (third-person shooter).\nOff: horizontal look rotates the pivot only, character facing is independent (isometric, Diablo-style).",
		"capture_mouse":      "Re-capture the mouse each frame if it gets released.\nDisable if you want Escape or a pause menu to be able to free the cursor.",
		"sensitivity_x":      "Horizontal look speed.",
		"sensitivity_y":      "Vertical look speed.",
		"export_sensitivity": "Expose sensitivity as @export variables in the Inspector.\nEnable so a settings menu can read and write them at runtime.",
		"invert_x":           "Invert horizontal look direction.",
		"invert_y":           "Invert vertical look direction.",
		"export_invert":      "Expose invert flags as @export variables in the Inspector.\nEnable so a settings menu can toggle them at runtime.",
		"pitch_min":          "Maximum look-down angle in degrees (negative = below horizon).",
		"pitch_max":          "Maximum look-up angle in degrees.",
		"joystick_device":    "Gamepad device index. 0 = first connected controller.",
		"joy_axis_x":         "Joystick axis for horizontal look. Default 2 = right stick X.",
		"joy_axis_y":         "Joystick axis for vertical look. Default 3 = right stick Y.",
		"joy_deadzone":       "Ignore joystick input below this magnitude.",
		"joy_sensitivity":    "Joystick look speed multiplier.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var input_mode        = str(properties.get("input_mode", "mouse")).to_lower()
	var rotate_character  = properties.get("rotate_character", true)
	var capture_mouse     = properties.get("capture_mouse", true)
	var sens_x            = float(properties.get("sensitivity_x", 0.3))
	var sens_y            = float(properties.get("sensitivity_y", 0.3))
	var export_sens       = properties.get("export_sensitivity", false)
	var invert_x          = properties.get("invert_x", false)
	var invert_y          = properties.get("invert_y", false)
	var export_invert     = properties.get("export_invert", false)
	var pitch_min         = float(properties.get("pitch_min", -60.0))
	var pitch_max         = float(properties.get("pitch_max", 30.0))
	var joy_device        = int(properties.get("joystick_device", 0))
	var joy_axis_x        = int(properties.get("joy_axis_x", 2))
	var joy_axis_y        = int(properties.get("joy_axis_y", 3))
	var joy_deadzone      = float(properties.get("joy_deadzone", 0.15))
	var joy_sens          = float(properties.get("joy_sensitivity", 2.0))

	# Derive var label from instance name, falling back to brick name then chain name —
	# same pattern as other bricks with @export vars
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name
	var label = _export_label

	var pivot_var = "_%s_pivot" % label
	var yaw_var   = "_%s_yaw" % label
	var pitch_var = "_%s_pitch" % label

	var use_mouse = input_mode in ["mouse", "both"]
	var use_joy   = input_mode in ["joystick", "both"]

	var member_vars: Array[String] = []
	var ready_lines: Array[String] = []
	var code_lines:  Array[String] = []

	# Pivot is always @export so it can be dragged in the Inspector
	member_vars.append("@export var %s: Node3D" % pivot_var)

	# Sensitivity — plain or @export
	if export_sens:
		member_vars.append("@export var _%s_sens_x: float = %.3f" % [label, sens_x])
		member_vars.append("@export var _%s_sens_y: float = %.3f" % [label, sens_y])
	else:
		member_vars.append("var _%s_sens_x: float = %.3f" % [label, sens_x])
		member_vars.append("var _%s_sens_y: float = %.3f" % [label, sens_y])

	# Invert — plain or @export
	if export_invert:
		member_vars.append("@export var _%s_inv_x: bool = %s" % [label, str(invert_x).to_lower()])
		member_vars.append("@export var _%s_inv_y: bool = %s" % [label, str(invert_y).to_lower()])
	else:
		member_vars.append("var _%s_inv_x: bool = %s" % [label, str(invert_x).to_lower()])
		member_vars.append("var _%s_inv_y: bool = %s" % [label, str(invert_y).to_lower()])

	member_vars.append("var %s: float = 0.0" % yaw_var)
	member_vars.append("var %s: float = 0.0" % pitch_var)

	# _ready: warn if pivot not assigned, sync initial angles
	ready_lines.append("# 3rd Person Camera: validate pivot")
	ready_lines.append("if not %s:" % pivot_var)
	ready_lines.append("\tpush_warning(\"3rd Person Camera: Camera pivot not assigned — drag a Node3D into the '%s' slot in the Inspector\")" % pivot_var)
	ready_lines.append("else:")
	if rotate_character:
		ready_lines.append("\t%s = rotation_degrees.y" % yaw_var)
	else:
		ready_lines.append("\t%s = %s.rotation_degrees.y" % [yaw_var, pivot_var])
	ready_lines.append("\t%s = %s.rotation_degrees.x" % [pitch_var, pivot_var])
	if use_mouse:
		ready_lines.append("Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)")

	# Actuator code (runs in _process each frame)
	code_lines.append("# 3rd Person Camera")
	code_lines.append("if %s:" % pivot_var)

	if use_mouse:
		if capture_mouse:
			code_lines.append("\t# Re-capture mouse if it was released (e.g. by window losing focus)")
			code_lines.append("\tif Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:")
			code_lines.append("\t\tInput.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)")
		code_lines.append("\t# Mouse input — only when cursor is captured")
		code_lines.append("\tif Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:")
		code_lines.append("\t\tvar _mouse_vel = Input.get_last_mouse_velocity()")
		code_lines.append("\t\tvar _mx = _mouse_vel.x * _%s_sens_x * 0.001 * (-1.0 if _%s_inv_x else 1.0)" % [label, label])
		code_lines.append("\t\tvar _my = _mouse_vel.y * _%s_sens_y * 0.001 * (-1.0 if _%s_inv_y else 1.0)" % [label, label])
		code_lines.append("\t\t%s -= _mx" % yaw_var)
		code_lines.append("\t\t%s -= _my" % pitch_var)

	if use_joy:
		code_lines.append("\t# Joystick input")
		code_lines.append("\tvar _jx = Input.get_joy_axis(%d, %d)" % [joy_device, joy_axis_x])
		code_lines.append("\tvar _jy = Input.get_joy_axis(%d, %d)" % [joy_device, joy_axis_y])
		code_lines.append("\tif abs(_jx) > %.3f:" % joy_deadzone)
		code_lines.append("\t\t%s -= _jx * _%s_sens_x * %.2f * _delta * (1.0 if _%s_inv_x else -1.0)" % [yaw_var, label, joy_sens, label])
		code_lines.append("\tif abs(_jy) > %.3f:" % joy_deadzone)
		code_lines.append("\t\t%s -= _jy * _%s_sens_y * %.2f * _delta * (1.0 if _%s_inv_y else -1.0)" % [pitch_var, label, joy_sens, label])

	# Clamp pitch
	code_lines.append("\t%s = clampf(%s, %.2f, %.2f)" % [pitch_var, pitch_var, pitch_min, pitch_max])

	# Apply yaw — to character or pivot depending on mode
	if rotate_character:
		code_lines.append("\trotation_degrees.y = %s  # Yaw rotates the character" % yaw_var)
		code_lines.append("\t%s.rotation_degrees.x = %s" % [pivot_var, pitch_var])
	else:
		code_lines.append("\t%s.rotation_degrees.y = %s  # Yaw rotates pivot only, character is independent" % [pivot_var, yaw_var])
		code_lines.append("\t%s.rotation_degrees.x = %s" % [pivot_var, pitch_var])

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars":   member_vars,
		"ready_code":    ready_lines,
	}
