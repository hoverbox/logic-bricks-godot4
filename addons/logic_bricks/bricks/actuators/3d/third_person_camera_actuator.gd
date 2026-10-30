@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Third Person Camera Actuator
## The camera itself lives in res://addons/logic_bricks/runtime/third_person_camera.gd.
## The generated code makes one, sets the settings that differ from its
## defaults (variables and math are passed in every frame), calls setup() in
## _ready and update() every frame. See that file for how the orbit and
## Avoid Walls work.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "3rd Person Camera"


func _initialize_properties() -> void:
	properties = {
		"camera_node_name": "Camera3D",
		"pivot_node_name": "CameraPivot",
		"input_mode":         "mouse",   # mouse, joystick, both
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
		# Wall avoidance (SpringArm3D)
		"avoid_walls":        false,
		"camera_distance":    0.0,      # 0 = keep the camera's distance from the scene
		"collision_mask":     "1",      # layer numbers or names, comma separated
		"collision_margin":   0.2,
		"probe_radius":       0.25,     # sphere instead of a thin ray; 0 = ray
		"return_smoothing":   0.3,      # seconds to ease back out; 0 = snap
		"narrow_obstacle_width": 1.0,   # pillars/posts narrower than this don't pull the camera in; 0 = off
		# Smooth motion
		"smooth_physics_motion": true,
		# Mouse capture
		"capture_mouse":      true,
		"release_mouse_escape": true,
		"recapture_mouse_click": true,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "camera_node_name", "required": true, "required_label": "a Camera3D node name",
			"type": TYPE_STRING,
			"default": "Camera3D",
			"placeholder": "Camera3D node name",
			"node_reference": true,
			"accepted_node_types": ["Camera3D"],
			"node_picker_scope": "scene"
		},
		{
			"name": "pivot_node_name", "required": true, "required_label": "a camera pivot node name",
			"type": TYPE_STRING,
			"default": "CameraPivot",
			"placeholder": "Camera pivot Node3D node name",
			"node_reference": true,
			"accepted_node_types": ["Node3D"],
			"node_picker_scope": "scene"
		},
		# ── Setup ──
		{"name": "setup_group", "type": TYPE_NIL, "hint": 999, "hint_string": "Setup"},
		{
			"name": "input_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Mouse,Joystick,Both",
			"default": "mouse"
		},
		{"name": "smooth_physics_motion", "type": TYPE_BOOL, "default": true},
		{"name": "capture_mouse", "type": TYPE_BOOL,  "default": true},
		{"name": "release_mouse_escape", "type": TYPE_BOOL, "default": true},
		{"name": "recapture_mouse_click", "type": TYPE_BOOL, "default": true},

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

		# ── Wall Avoidance ──
		{"name": "wall_group", "type": TYPE_NIL, "hint": 999, "hint_string": "Wall Avoidance"},
		{"name": "avoid_walls", "type": TYPE_BOOL, "default": false},
		{"name": "camera_distance", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,50.0,0.1", "default": 0.0, "visible_if": {"avoid_walls": true}},
		{"name": "collision_mask", "type": TYPE_STRING, "default": "1", "placeholder": "1  or  1, 3  or  World", "visible_if": {"avoid_walls": true}},
		{"name": "collision_margin", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,2.0,0.01", "default": 0.2, "visible_if": {"avoid_walls": true}},
		{"name": "probe_radius", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01", "default": 0.25, "visible_if": {"avoid_walls": true}},
		{"name": "return_smoothing", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,2.0,0.05", "default": 0.3, "visible_if": {"avoid_walls": true}},
		{"name": "narrow_obstacle_width", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,5.0,0.1", "default": 1.0, "visible_if": {"avoid_walls": true}},

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
		"_description":       "Third-person camera setup:\n1. Add a Node3D named CameraPivot near the character's head/shoulders.\n2. Add a Camera3D and place it behind/above the pivot.\n3. Choose both nodes with the dropdowns below. They may live anywhere in the scene.\n4. Run this action continuously (for example Always → AND → 3rd Person Camera).\nThe brick handles mouse/gamepad orbit and pitch clamp. Turn on Avoid Walls (Wall Avoidance group) so walls never block the view.",
		"camera_node_name":    "Camera3D used by the third-person rig. Choose it from anywhere in the edited scene.",
		"pivot_node_name":     "Node3D used as the orbit pivot. Place it near head/shoulder height and choose it from anywhere in the edited scene.",
		"input_mode":         "Which input drives the camera.\nMouse: mouse motion only.\nJoystick: right stick only.\nBoth: mouse and joystick together.",
		"smooth_physics_motion": "Turn on physics interpolation in Project Settings (done when you press Apply Code) so the character moves smoothly between physics ticks, and have the camera follow that smoothed position. Without it the view stutters on high-refresh screens. Affects the whole scene and adds up to one physics tick of visual delay.",
		"capture_mouse":      "Capture the mouse when the camera starts.",
		"release_mouse_escape": "Press Escape to release the cursor and pause mouse orbit.",
		"recapture_mouse_click": "Left-click to capture the cursor again.",
		"sensitivity_x":      "Horizontal look speed.",
		"sensitivity_y":      "Vertical look speed.",
		"export_sensitivity": "Expose sensitivity as @export vars so a settings menu can adjust them at runtime.",
		"invert_x":           "Invert horizontal look.",
		"invert_y":           "Invert vertical look.",
		"export_invert":      "Expose invert flags as @export vars for runtime toggling.",
		"pitch_min":          "Maximum look-down angle in degrees (negative = below horizon).",
		"pitch_max":          "Maximum look-up angle in degrees.",
		"avoid_walls":        "Pull the camera in front of walls and other obstacles between it and the pivot (uses a SpringArm3D added when the game starts). The character's own colliders are ignored.\nTip: put small props and foliage on a layer that is not in Collision Mask so the camera ignores them.",
		"camera_distance":    "Normal distance from the pivot to the camera when nothing is in the way.\n0 = keep the distance the camera already has in the scene.",
		"collision_mask":     "Which physics layers block the camera: layer numbers (1, 3) or layer names from Project Settings > Layer Names > 3D Physics, separated by commas.",
		"collision_margin":   "How far the camera stays from the surface it hits, so it does not clip into walls.",
		"probe_radius":       "Size of the sphere swept from the pivot to the camera to find obstacles. A sphere does not flicker on thin things like fence posts the way a single line does, and keeps the camera's edge out of walls. 0 = a thin line.",
		"narrow_obstacle_width": "Obstacles narrower than this (pillars, posts, trees) do not pull the camera in when they pass between it and the player: the view is only blocked for a moment. The camera still never goes inside one. 0 = every obstacle pulls the camera in.",
		"return_smoothing":   "Seconds the camera takes to ease back out once the view is clear. It always moves in instantly when something blocks the view, so it never ends up inside a wall. 0 = snap back immediately.",
		"joystick_device":    "Gamepad device slot (0–7). 0 = first connected controller, 1 = second, etc.",
		"joy_stick":          "Which stick drives the camera look.\nLeft Stick: axes 0 (X) and 1 (Y).\nRight Stick: axes 2 (X) and 3 (Y).",
		"joy_deadzone":       "Ignore joystick input below this magnitude.",
		"joy_sensitivity":    "Joystick look speed in degrees per second. Full stick deflection rotates at this rate.",
	}


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var input_mode = properties.get("input_mode", "mouse").to_lower()
	var use_joy = input_mode in ["joystick", "both"]
	for node in _get_field_names():
		var prop_name = node
		match prop_name:
			"joy_group", "joystick_device", "joy_stick", "joy_deadzone", "joy_sensitivity":
				shown[node] = use_joy
			"capture_mouse":
				shown[node] = input_mode in ["mouse", "both"]
	return shown


## Smooth Physics Motion needs physics interpolation on for the project.
func get_required_project_settings() -> Dictionary:
	if bool(properties.get("smooth_physics_motion", true)):
		return {"physics/common/physics_interpolation": true}
	return {}


func get_kept_member_vars() -> PackedStringArray:
	# The camera object keeps its orbit and wall state across state changes.
	return PackedStringArray(["_*_rig"])


## Collision mask from "1, 3" (layer numbers) or "World, Walls" (names from
## Project Settings > Layer Names > 3D Physics). Unknown entries are skipped.
static func collision_mask_value(text: String) -> int:
	var mask := 0
	for raw in text.split(",", false):
		var entry := raw.strip_edges()
		if entry.is_empty():
			continue
		var layer := _physics_layer_number(entry)
		if layer >= 1 and layer <= 32:
			mask |= 1 << (layer - 1)
	return mask


static func _physics_layer_number(entry: String) -> int:
	if entry.is_valid_int():
		return entry.to_int()
	for layer in range(1, 33):
		var layer_name := str(ProjectSettings.get_setting("layer_names/3d_physics/layer_%d" % layer, ""))
		if not layer_name.is_empty() and layer_name.to_lower() == entry.to_lower():
			return layer
	return -1


func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	if bool(properties.get("avoid_walls", false)):
		var text := str(properties.get("collision_mask", "1"))
		for raw in text.split(",", false):
			var entry := raw.strip_edges()
			var layer := _physics_layer_number(entry)
			if not entry.is_empty() and (layer < 1 or layer > 32):
				warnings.append("Collision Mask: '%s' is not a layer number (1-32) or a 3D physics layer name." % entry)
		if collision_mask_value(text) == 0:
			warnings.append("Avoid Walls is on, but Collision Mask has no layers, so nothing will block the camera.")
	if bool(properties.get("export_sensitivity", false)) and (_is_number_expression("sensitivity_x") or _is_number_expression("sensitivity_y")):
		warnings.append("Export Sensitivity: a sensitivity that uses a variable or math is not exported; change that variable instead.")
	return warnings


const RIG_SCRIPT := "res://addons/logic_bricks/runtime/third_person_camera.gd"

## Number settings: [property, rig setting, default, decimals]. Defaults match
## the rig's, so only changed values are written into the student's script.
const NUMBER_SETTINGS := [
	["sensitivity_x", "sensitivity_x", 0.3, 3], ["sensitivity_y", "sensitivity_y", 0.3, 3],
	["pitch_min", "pitch_min", -60.0, 2], ["pitch_max", "pitch_max", 30.0, 2],
	["joy_deadzone", "joy_deadzone", 0.15, 3], ["joy_sensitivity", "joy_sensitivity", 100.0, 2],
]
const WALL_SETTINGS := [
	["camera_distance", "camera_distance", 0.0, 3], ["collision_margin", "collision_margin", 0.2, 3],
	["probe_radius", "probe_radius", 0.25, 3], ["return_smoothing", "return_smoothing", 0.3, 3],
	["narrow_obstacle_width", "narrow_obstacle_width", 1.0, 3],
]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var pivot_node_name = str(properties.get("pivot_node_name", "CameraPivot")).strip_edges()
	var camera_node_name = str(properties.get("camera_node_name", "Camera3D")).strip_edges()
	var input_mode = str(properties.get("input_mode", "mouse")).to_lower()
	var use_mouse = input_mode in ["mouse", "both"]
	var use_joy = input_mode in ["joystick", "both"]
	var export_sens = bool(properties.get("export_sensitivity", false))
	var export_invert = bool(properties.get("export_invert", false))
	var avoid_walls = bool(properties.get("avoid_walls", false))

	# Stable label derived from the instance name
	var label = instance_name if not instance_name.is_empty() else brick_name
	label = label.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	if label.is_empty():
		label = chain_name
	var rig = "_%s_rig" % label

	var member_vars: Array[String] = []
	var ready_lines: Array[String] = []
	var code_lines: Array[String] = []
	var settings: Array[String] = []   # set once in _ready
	var every_frame: Array[String] = []  # variables, math and exported values

	member_vars.append("var %s = null  # the camera; its code is in %s" % [rig, RIG_SCRIPT.trim_prefix("res://")])

	# On/off settings that differ from the rig's defaults
	var flags := {
		"use_mouse": [use_mouse, true], "use_joystick": [use_joy, false],
		"capture_mouse": [bool(properties.get("capture_mouse", true)), true],
		"release_mouse_escape": [bool(properties.get("release_mouse_escape", true)), true],
		"recapture_mouse_click": [bool(properties.get("recapture_mouse_click", true)), true],
		"smooth_physics_motion": [bool(properties.get("smooth_physics_motion", true)), true],
	}
	if avoid_walls:
		flags["avoid_walls"] = [true, false]
	for key in flags:
		if flags[key][0] != flags[key][1]:
			settings.append("%s.%s = %s" % [rig, key, str(flags[key][0]).to_lower()])

	# Sensitivity: exported vars are copied in every frame so a settings menu
	# (or the Inspector) can change them while the game runs.
	for axis in ["x", "y"]:
		var key = "sensitivity_" + axis
		if export_sens and not _is_number_expression(key):
			member_vars.append("@export var _%s_sens_%s: float = %s" % [label, axis, _num(key, 0.3)])
			every_frame.append("%s.%s = _%s_sens_%s" % [rig, key, label, axis])
	for axis in ["x", "y"]:
		var key = "invert_" + axis
		var value = bool(properties.get(key, false))
		if export_invert:
			member_vars.append("@export var _%s_inv_%s: bool = %s" % [label, axis, str(value).to_lower()])
			every_frame.append("%s.%s = _%s_inv_%s" % [rig, key, label, axis])
		elif value:
			settings.append("%s.%s = true" % [rig, key])

	var numbers: Array = NUMBER_SETTINGS.duplicate()
	if avoid_walls:
		numbers.append_array(WALL_SETTINGS)
	for entry in numbers:
		var key: String = entry[0]
		if not use_joy and key.begins_with("joy_"):
			continue
		if export_sens and key.begins_with("sensitivity_") and not _is_number_expression(key):
			continue  # handled by the exported var above
		if _is_number_expression(key):
			var line = "%s.%s = %s" % [rig, entry[1], _num(key, entry[2], entry[3])]
			settings.append(line)
			every_frame.append(line)
		elif not is_equal_approx(float(_literal_number(key, entry[2])), float(entry[2])):
			settings.append("%s.%s = %s" % [rig, entry[1], _num(key, entry[2], entry[3])])
	if use_joy:
		if _is_number_expression("joystick_device"):
			settings.append("%s.joystick_device = %s" % [rig, _int_num("joystick_device")])
			every_frame.append("%s.joystick_device = %s" % [rig, _int_num("joystick_device")])
		elif int(_literal_number("joystick_device", 0)) != 0:
			settings.append("%s.joystick_device = %s" % [rig, _int_num("joystick_device")])
		if str(properties.get("joy_stick", "right")).to_lower() in ["left", "left stick", "left_stick"]:
			settings.append("%s.joy_axis_x = 0  # left stick" % rig)
			settings.append("%s.joy_axis_y = 1" % rig)
	if avoid_walls:
		var mask := collision_mask_value(str(properties.get("collision_mask", "1")))
		if mask != 1:
			settings.append("%s.collision_mask = %d  # %s" % [rig, mask, str(properties.get("collision_mask", "1")).strip_edges()])

	# ── _ready ──
	ready_lines.append("# 3rd Person Camera")
	ready_lines.append("%s = preload(\"%s\").new()" % [rig, RIG_SCRIPT])
	ready_lines.append_array(settings)
	ready_lines.append("%s.setup(self, \"%s\", \"%s\")" % [rig, _gd_string(pivot_node_name), _gd_string(camera_node_name)])
	ready_lines.append("await get_tree().process_frame")
	ready_lines.append("%s.make_current()" % rig)

	# ── Every frame ──
	code_lines.append("# 3rd Person Camera")
	code_lines.append_array(every_frame)
	code_lines.append("%s.update(_delta)" % rig)

	var result := {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars,
		"ready_code": ready_lines,
	}
	if use_mouse:
		result["methods"] = ["input_handler::if %s: %s.input(event)" % [rig, rig]]
	return result
