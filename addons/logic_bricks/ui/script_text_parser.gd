@tool
extends RefCounted

## Reads brick settings back out of generated code text by recognising the
## code each brick writes. Used when a student edits generated code by hand
## ("sync" keeps the graph in step) and by Rebuild from Script for scripts
## that have no graph snapshot (made before 3.7.0, or with the snapshot
## setting turned off). Scripts with a snapshot are restored exactly instead.

const FIND_CHILD_RX := "(?:find_child\\(|_lb_find_child_cached\\([^,()]*(?:\\(\\)[^,()]*)*,\\s*)"

const ACTUATOR_SIGNATURES: Array = [
	# ── Animation ──────────────────────────────────────────────────────────
	["# Animation Actuator:",              "AnimationActuator"],
	["# Animation Tree Actuator",          "AnimationTreeActuator"],
	# ── Audio ───────────────────────────────────────────────────────────────
	["# Audio 2D Actuator",                "Audio2DActuator"],
	["# Sound actuator",                   "SoundActuator"],
	["# Music Actuator",                   "MusicActuator"],
	# ── Camera ──────────────────────────────────────────────────────────────
	["# Camera Zoom Actuator",             "CameraZoomActuator"],
	["# 3rd Person Camera",                "ThirdPersonCameraActuator"],
	["# Set camera as active",             "SetCameraActuator"],
	["# Smooth Follow Camera",             "SmoothFollowCameraActuator"],
	["_smooth_follow_",                    "SmoothFollowCameraActuator"],
	["_camera_",                           "CameraActuator"],
	# ── Character / Physics / Motion ───────────────────────────────────────
	["# Ground detection",                 "CharacterActuator"],
	["_on_ground",                         "CharacterActuator"],
	["# Apply custom gravity",             "GravityActuator"],
	["# Soft Body Point Force",            "SoftBodyPointForceActuator"],
	["# Soft Body Point Impulse",          "SoftBodyPointImpulseActuator"],
	["# WARNING: Force actuator",          "ForceActuator"],
	["apply_central_force(",                "ForceActuator"],
	["apply_force(",                        "ForceActuator"],
	["# WARNING: Impulse actuator",        "ImpulseActuator"],
	["# Apply central impulse",            "ImpulseActuator"],
	["apply_central_impulse(",              "ImpulseActuator"],
	["apply_impulse(",                      "ImpulseActuator"],
	["# WARNING: Physics actuator",        "PhysicsActuator"],
	["# Linear Velocity Actuator",         "LinearVelocityActuator"],
	["# Torque requires RigidBody3D",      "TorqueActuator"],
	["apply_torque(",                       "TorqueActuator"],
	["apply_torque_impulse(",               "TorqueActuator"],
	["# Jump",                             "JumpActuator"],
	["# Move in local space",              "MotionActuator"],
	["# Move in global space",             "MotionActuator"],
	["# Set CharacterBody3D velocity",     "MotionActuator"],
	["# Set local position",               "MotionActuator"],
	["# Set global position",              "MotionActuator"],
	["# Camera-relative movement",         "MotionActuator"],
	# LocationActuator uses "%.2f" float formatting (e.g. "translate(Vector3(1.00, 0.00, 0.00))"),
	# while MotionActuator emits the same patterns but is already caught by its comment signatures
	# above.  Matching the "0.00" style ensures we only hit bare LocationActuator code, not
	# MotionActuator code that was already matched by a comment signature.
	["translate(Vector3(", "LocationActuator"],
	["global_position += Vector3(", "LocationActuator"],
	["rotate_x(",                          "RotationActuator"],
	["rotate_y(",                          "RotationActuator"],
	["rotate_z(",                          "RotationActuator"],
	["# Rotate Towards",                   "RotateTowardsActuator"],
	["# Rotate target node to face",       "LookAtMovementActuator"],
	["# Teleport to target node",          "TeleportActuator"],
	["# Steering",                         "MoveTowardsActuator"],
	["# Move Towards",                     "MoveTowardsActuator"],  # legacy generated scripts
	["_mt_stuck_offset_",                  "MoveTowardsActuator"],
	["# Waypoint Path",                    "WaypointPathActuator"],
	# ── Object / Scene ──────────────────────────────────────────────────────
	["# Apply initial velocity",           "EditObjectActuator"],
	["# Object Pool",                      "ObjectPoolActuator"],
	["# Object Flash Actuator",            "ObjectFlashActuator"],
	["# Object Shake Actuator",            "ObjectShakeActuator"],
	["# Hit Stop Actuator",              "HitStopActuator"],
	["_hit_stop_active_",                "HitStopActuator"],
	["# Parent",                           "ParentActuator"],
	["# Search for node by name",          "ParentActuator"],
	["# Restart current scene",            "SceneActuator"],
	["# Set logic brick state",            "StateActuator"],
	["# Visibility Actuator",              "VisibilityActuator"],
	# ── UI / Screen ─────────────────────────────────────────────────────────
	["# Screen Flash Actuator",            "ScreenFlashActuator"],
	["# Screen Shake",                     "ScreenShakeActuator"],
	["_shake_trauma",                      "ScreenShakeActuator"],
	["# Split Screen",                     "SplitScreenActuator"],
	["# UI Focus",                         "UIFocusActuator"],
	["# Update text display",              "TextActuator"],
	["# Progress Bar Actuator",            "ProgressBarActuator"],
	# ── Light / Environment / Shader ────────────────────────────────────────
	["# Light Actuator",                   "LightActuator"],
	["# Environment Actuator",             "EnvironmentActuator"],
	["# Shader Parameter Actuator",        "ShaderParamActuator"],
	["# Modulate Actuator",                "ModulateActuator"],
	# ── Game / Input ────────────────────────────────────────────────────────
	["# Exit game",                        "GameActuator"],
	["# Set cursor visibility",            "MouseActuator"],
	["# Rumble",                           "RumbleActuator"],
	["# Broadcast message",                "MessageActuator"],
	["_msg_targets",                       "MessageActuator"],
	# ── Data / Save ─────────────────────────────────────────────────────────
	["# Modify Variable",                  "VariableActuator"],
	["# Resolve variable (local or global)", "VariableActuator"],
	["_lb_var_",                           "VariableActuator"],
	["_target.set(",                        "VariableActuator"],
	["# Property Actuator",                "PropertyActuator"],
	["# Save game state",                  "SaveGameActuator"],
	["# Save/Load",                        "SaveLoadActuator"],
	["_save_load_",                        "SaveLoadActuator"],
	["# Preload",                          "PreloadActuator"],
	# ── Misc ────────────────────────────────────────────────────────────────
	["# Random",                           "RandomActuator"],
	["_rng_initialized",                   "RandomActuator"],
	["# Tween Actuator",                   "TweenActuator"],
	["# Initialize RNG",                   "RandomActuator"],
	["AnimationPlayer",                     "AnimationActuator"],
	["AnimationTree",                       "AnimationTreeActuator"],
	["AudioStreamPlayer3D",                 "SoundActuator"],
	["AudioStreamPlayer.new()",             "Audio2DActuator"],
	["Camera3D",                            "CameraActuator"],
	["fov",                                 "CameraZoomActuator"],
	["disabled =",                          "CollisionActuator"],
	["WorldEnvironment",                    "EnvironmentActuator"],
	["get_tree().quit",                     "GameActuator"],
	["global_position =",                   "LocationActuator"],
	["visible =",                           "VisibilityActuator"],
	["process_mode =",                      "StateActuator"],
	["Input.set_mouse_mode",                "MouseActuator"],
	["Input.start_joy_vibration",           "RumbleActuator"],
	["_logic_bricks_message_listeners",     "MessageActuator"],
	["ProgressBar",                         "ProgressBarActuator"],
	["set_shader_parameter",                "ShaderParamActuator"],
	["modulate",                            "ModulateActuator"],
	["create_tween()",                      "TweenActuator"],
]
const META_ACTUATOR_PREFIX := "# LB_META_ACTUATOR "
const META_CONTROLLER_PREFIX := "# LB_META_CONTROLLER "
const META_CONTROLLER_PREFIX_B64 := "# LB_META_CONTROLLER_B64 "
const META_SENSOR_PREFIX := "# LB_META_SENSOR "
const META_SENSOR_PREFIX_B64 := "# LB_META_SENSOR_B64 "

var rebuild = null  # panel_script_rebuild_helper.gd


func setup(target_rebuild) -> void:
	rebuild = target_rebuild


## Parse the generated block and return one descriptor per chain.
## Each descriptor:
##   {
##     "name":             String,
##     "is_script_ctrl":   bool,
##     "script_path":      String,
##     "logic_mode":       String,   # "and" | "or" | "nand" | "nor" | "xor"
##     "sensor_count":     int,
##     "all_states":       bool,
##     "state_id":         String,
##     "actuator_classes": Array,  # detected actuators: [{class: String, properties: Dictionary}]
##   }
func _parse_chains(block: String) -> Array[Dictionary]:
	var descs: Array[Dictionary] = []

	# ── Pre-pass: collect ScriptController info from member vars ──────────────
	var sc_script_paths: Dictionary = {}
	var sc_res_rx := RegEx.new()
	sc_res_rx.compile(r'var _sc_res_(\w+)\s*=\s*load\("([^"]+)"\)')
	for m in sc_res_rx.search_all(block):
		sc_script_paths[m.get_string(1)] = m.get_string(2)

	# ── Main pass: find each _logic_brick_{name} function ────────────────────
	var func_rx := RegEx.new()
	func_rx.compile(r'func _logic_brick_(\w+)\(_delta')
	var matches := func_rx.search_all(block)

	for i in range(matches.size()):
		var m      := matches[i]
		var c_name := m.get_string(1)

		if c_name in ["init_states", "chain_state_matches", "get_state_signature"]:
			continue

		var body_start := m.get_start()
		var body_end   := block.length()
		if i + 1 < matches.size():
			body_end = matches[i + 1].get_start()
		var body := block.substr(body_start, body_end - body_start)

		var sensor_infos := _detect_sensors(block, c_name, body)
		var actuator_infos := _detect_actuators(body)
		var controller_meta = rebuild._parse_meta_comment_from_text(body, META_CONTROLLER_PREFIX_B64)
		if controller_meta.is_empty():
			controller_meta = rebuild._parse_meta_comment_from_text(body, META_CONTROLLER_PREFIX)
		var controller_type := str(controller_meta.get("type", ""))
		var controller_props: Dictionary = controller_meta.get("properties", {}) if controller_meta.get("properties", {}) is Dictionary else {}
		var is_script_controller = controller_type == "ScriptController" or (controller_meta.is_empty() and sc_script_paths.has(c_name))
		descs.append({
			"name":             c_name,
			"is_script_ctrl":   is_script_controller,
			"script_path":      str(controller_props.get("script_path", sc_script_paths.get(c_name, ""))),
			"logic_mode":       str(controller_props.get("logic_mode", _detect_logic_mode(body))),
			"sensor_count":     sensor_infos.size(),
			"sensor_infos":     sensor_infos,
			"all_states":       bool(controller_props.get("all_states", _detect_all_states(body))),
			"state_id":         str(controller_props.get("state_id", _detect_state_id(body))),
			"controller_meta":   rebuild._brick_info_from_meta(controller_meta, "ScriptController" if is_script_controller else "Controller") if not controller_meta.is_empty() else {},
			"actuator_classes": actuator_infos,
		})

	return descs


## Detect sensor types + recoverable properties from the sensor evaluation block.
func _detect_sensors(full_block: String, chain_name: String, body: String) -> Array:
	var sensor_start := body.find("# Sensor evaluation")
	var ctrl_start := body.find("# Controller logic")
	if sensor_start == -1 or ctrl_start == -1 or ctrl_start <= sensor_start:
		return [{"class": "AlwaysSensor", "properties": {"enabled": true}}]

	var sensor_block := body.substr(sensor_start, ctrl_start - sensor_start)
	var meta_sensors = rebuild._collect_meta_comments(sensor_block, META_SENSOR_PREFIX_B64)
	if meta_sensors.is_empty():
		meta_sensors = rebuild._collect_meta_comments(sensor_block, META_SENSOR_PREFIX)
	if not meta_sensors.is_empty():
		return meta_sensors

	var assign_rx := RegEx.new()
	assign_rx.compile(r'var\s+(\w+_active)\s*=')
	var matches := assign_rx.search_all(sensor_block)
	if matches.is_empty():
		return [{"class": "AlwaysSensor", "properties": {"enabled": true}}]

	var sensors: Array = []
	var prev_end := 0
	for i in range(matches.size()):
		var m = matches[i]
		var seg_start := prev_end
		var seg_end := sensor_block.length()
		if i + 1 < matches.size():
			seg_end = matches[i + 1].get_start()
		var segment := sensor_block.substr(seg_start, seg_end - seg_start)
		prev_end = seg_end
		sensors.append(_parse_sensor_segment(full_block, chain_name, segment))

	return sensors


func _parse_sensor_segment(full_block: String, chain_name: String, segment: String) -> Dictionary:
	var meta_info = rebuild._parse_meta_comment_from_text(segment, META_SENSOR_PREFIX_B64)
	if meta_info.is_empty():
		meta_info = rebuild._parse_meta_comment_from_text(segment, META_SENSOR_PREFIX)
	if not meta_info.is_empty():
		return rebuild._brick_info_from_meta(meta_info, "AlwaysSensor")

	# Ordered from most-specific to least-specific. The goal is to recover the
	# concrete brick class whenever generated metadata is not available, never to
	# silently collapse an unknown concrete sensor into AlwaysSensor.
	if "_actuator_active_flags.get(" in segment or "# Actuator Sensor" in segment:
		return {"class": "ActuatorSensor", "properties": _parse_actuator_sensor_props(segment)}
	if "# Animation Tree sensor" in segment or "AnimationNodeStateMachinePlayback" in segment or "parameters/conditions/" in segment:
		return {"class": "AnimationTreeSensor", "properties": _parse_animation_tree_sensor_props(segment)}
	if "_collision_" in segment or "_collided_with_" in segment or "get_overlapping_bodies(" in segment or "get_overlapping_areas(" in segment:
		return {"class": "CollisionSensor", "properties": _parse_collision_sensor_props(full_block, chain_name, segment)}
	if "# Delay sensor" in segment or "_delay_phase_" in segment or "_delay_elapsed_" in segment:
		return {"class": "DelaySensor", "properties": _parse_delay_sensor_props(segment)}
	if "Input.is_action_" in segment or "Input.get_axis(" in segment:
		return {"class": "InputMapSensor", "properties": _parse_input_map_sensor_props(segment)}
	if "_msg_received_" in segment or "_msg_pending_" in segment or "# Message sensor" in segment:
		return {"class": "MessageSensor", "properties": _parse_message_sensor_props(segment)}
	if "Input.is_mouse_button_pressed(" in segment or "# Mouse movement detection" in segment or "# Hover over" in segment or "get_mouse_position()" in segment:
		return {"class": "MouseSensor", "properties": _parse_mouse_sensor_props(segment)}
	if "# Calculate velocity from position change" in segment or "_ms_vel" in segment:
		return {"class": "MovementSensor", "properties": _parse_movement_sensor_props(segment)}
	if "# Proximity:" in segment or "_prox_targets" in segment or "_detected_objects" in segment:
		return {"class": "ProximitySensor", "properties": _parse_proximity_sensor_props(segment)}
	if "# Random Sensor" in segment or "_rand_roll" in segment or ".randf()" in segment or ".randi_range(" in segment:
		return {"class": "RandomSensor", "properties": _parse_random_sensor_props(segment)}
	if "# Raycast sensor" in segment or "force_raycast_update()" in segment or "get_collider()" in segment:
		return {"class": "RaycastSensor", "properties": _parse_raycast_sensor_props(segment)}
	if "# Get variable '" in segment or "_lb_get_var_" in segment or "Compare Variable" in segment:
		return {"class": "VariableSensor", "properties": _parse_variable_sensor_props(segment)}

	var simple_rx := RegEx.new()
	simple_rx.compile(r'var\s+\w+_active\s*=\s*(true|false)')
	var sm := simple_rx.search(segment)
	if sm:
		return {"class": "AlwaysSensor", "properties": {"enabled": sm.get_string(1) == "true"}}

	push_warning("Logic Bricks (ScriptRebuild): Unrecognized sensor block in chain '%s'; using disabled AlwaysSensor placeholder instead of pretending it was recovered. Block:\n%s" % [chain_name, segment])
	return {"class": "AlwaysSensor", "properties": {"enabled": false}}


func _parse_actuator_sensor_props(segment: String) -> Dictionary:
	var props: Dictionary = {}
	var rx := RegEx.new()
	rx.compile(r'_actuator_active_flags\.get\("([^"]+)",\s*false\)')
	var m := rx.search(segment)
	if m:
		props["actuator_name"] = m.get_string(1)
	props["invert"] = "not _actuator_active_flags.get(" in segment
	return props


func _parse_animation_tree_sensor_props(segment: String) -> Dictionary:
	var props: Dictionary = {}
	if "get_current_node()" in segment:
		props["mode"] = "state"
		var rx := RegEx.new(); rx.compile(r'get_current_node\(\)\s*==\s*"([^"]*)"')
		var m := rx.search(segment); if m: props["state_name"] = m.get_string(1)
	elif "parameters/conditions/" in segment:
		props["mode"] = "condition"
		var crx := RegEx.new(); crx.compile(r'parameters/conditions/([^"\)]+)')
		var cm := crx.search(segment); if cm: props["condition_name"] = cm.get_string(1)
	elif 'get("parameters/' in segment:
		props["mode"] = "parameter"
	return props


## Recover AnimationTreeActuator properties from previously generated code.
## Handles travel, set_condition, and set_parameter modes.
func _parse_animation_tree_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	# Recover animation tree node name
	var tree_rx := RegEx.new()
	tree_rx.compile(FIND_CHILD_RX + r'"([^"]+)"(?:,\s*true,\s*false)?\)\s+as\s+AnimationTree')
	var tree_m := tree_rx.search(act_block)
	if tree_m:
		props["animation_tree_name"] = tree_m.get_string(1)

	if ".travel(" in act_block:
		# Travel mode
		props["mode"] = "travel"
		var rx := RegEx.new()
		rx.compile(r'\.travel\("([^"]*)"\)')
		var m := rx.search(act_block)
		if m:
			props["state_name"] = m.get_string(1)
		var sm_rx := RegEx.new()
		sm_rx.compile(r'_lb_find_animation_tree_playback\([^,]+,\s*"([^"]*)"\)')
		var sm_m := sm_rx.search(act_block)
		if sm_m and not sm_m.get_string(1).is_empty():
			props["state_machine_path"] = sm_m.get_string(1)
	elif "parameters/conditions/" in act_block:
		# Set Condition mode
		props["mode"] = "set_condition"
		var crx := RegEx.new()
		crx.compile(r'parameters/conditions/([^"]+)"')
		var cm := crx.search(act_block)
		if cm:
			props["condition_name"] = cm.get_string(1)
		# Recover condition value (true/false or variable name)
		var val_rx := RegEx.new()
		val_rx.compile(r'var _condition_value_\w+\s*=\s*(\S+)')
		var val_m := val_rx.search(act_block)
		if val_m:
			props["condition_value"] = val_m.get_string(1)
	elif '.set("parameters/' in act_block:
		# Set Parameter mode
		props["mode"] = "set_parameter"
		var path_rx := RegEx.new()
		path_rx.compile(r'\.set\("(parameters/[^"]+)"')
		var path_m := path_rx.search(act_block)
		if path_m:
			var full_path: String = path_m.get_string(1)
			# Strip the "parameters/" prefix for parameter_name storage
			props["parameter_name"] = full_path.substr("parameters/".length())
		# Try to recover value type
		var bool_rx := RegEx.new()
		bool_rx.compile(r'\.set\("[^"]+",\s*(true|false)\)')
		var bool_m := bool_rx.search(act_block)
		if bool_m:
			props["param_type"] = "bool"
			props["param_bool"] = bool_m.get_string(1) == "true"
		else:
			var float_rx := RegEx.new()
			float_rx.compile(r'\.set\("[^"]+",\s*(-?[0-9]+\.[0-9]+)\)')
			var float_m := float_rx.search(act_block)
			if float_m:
				props["param_type"] = "float"
				props["param_float"] = float(float_m.get_string(1))
			else:
				var int_rx := RegEx.new()
				int_rx.compile(r'\.set\("[^"]+",\s*(-?[0-9]+)\)')
				var int_m := int_rx.search(act_block)
				if int_m:
					props["param_type"] = "int"
					props["param_int"] = int(int_m.get_string(1))
	return props


func _parse_message_sensor_props(segment: String) -> Dictionary:
	var props: Dictionary = {}
	props["consume_message"] = "= false  # Consume" in segment or "= false" in segment
	props["response_delay"] = "0.0"
	var rx := RegEx.new(); rx.compile(r'if\s+\w+\s*>=\s*([0-9.]+):')
	var m := rx.search(segment); if m: props["response_delay"] = m.get_string(1)
	return props


func _parse_mouse_sensor_props(segment: String) -> Dictionary:
	var props: Dictionary = {}
	if "MOUSE_BUTTON_LEFT" in segment: props["mouse_button"] = "left"
	elif "MOUSE_BUTTON_RIGHT" in segment: props["mouse_button"] = "right"
	elif "MOUSE_BUTTON_MIDDLE" in segment: props["mouse_button"] = "middle"
	elif "MOUSE_BUTTON_WHEEL_UP" in segment: props["wheel_direction"] = "up"
	elif "MOUSE_BUTTON_WHEEL_DOWN" in segment: props["wheel_direction"] = "down"
	if "# Mouse movement detection" in segment: props["detection_type"] = "movement"
	elif "# Hover over target object" in segment or "# Hover over this object" in segment: props["detection_type"] = "hover_object"
	elif "# Hover over any object" in segment: props["detection_type"] = "hover_any"
	elif "MOUSE_BUTTON_WHEEL_UP" in segment or "MOUSE_BUTTON_WHEEL_DOWN" in segment: props["detection_type"] = "wheel"
	elif "Input.is_mouse_button_pressed(" in segment: props["detection_type"] = "button"
	if "was_pressed" in segment and "not _is_pressed" in segment: props["button_state"] = "released"
	elif "was_pressed" in segment: props["button_state"] = "pressed"
	elif "Input.is_mouse_button_pressed(" in segment: props["button_state"] = "held"
	var rx := RegEx.new(); rx.compile(r'length\(\)\s*>\s*([0-9.]+)')
	var m := rx.search(segment); if m: props["movement_threshold"] = m.get_string(1)
	var target_rx := RegEx.new(); target_rx.compile(r'var _hover_target = get_node_or_null\("([^"]+)"\)')
	var tm := target_rx.search(segment); if tm: props["target_node_name"] = tm.get_string(1)
	return props


func _parse_proximity_sensor_props(segment: String) -> Dictionary:
	var props: Dictionary = {}
	if "scan all Node3D" in segment: props["target_mode"] = "all"
	var dist_rx := RegEx.new(); dist_rx.compile(r'distance_to\([^\n]+\)\s*<=\s*([0-9.]+)')
	var dm := dist_rx.search(segment); if dm: props["distance"] = dm.get_string(1)
	var group_rx := RegEx.new(); group_rx.compile(r'is_in_group\("([^"]+)"\)')
	var gm := group_rx.search(segment); if gm: props["target_group"] = gm.get_string(1)
	props["invert"] = "var sensor_active = not _prox_result" in segment
	return props


func _parse_random_sensor_props(segment: String) -> Dictionary:
	var props: Dictionary = {}
	if "Chance mode" in segment or ".randf()" in segment:
		props["trigger_mode"] = "chance"
		var rx := RegEx.new(); rx.compile(r'<\s*([0-9.]+)')
		var m := rx.search(segment); if m: props["chance_percent"] = m.get_string(1)
	elif "Range mode" in segment:
		props["trigger_mode"] = "range"
	elif "Value mode" in segment:
		props["trigger_mode"] = "value"
	var store_rx := RegEx.new(); store_rx.compile(r'(\w+)\s*=\s*_rand_roll')
	var sm := store_rx.search(segment); if sm: props["store_variable"] = sm.get_string(1)
	return props


func _parse_raycast_sensor_props(segment: String) -> Dictionary:
	var props: Dictionary = {}
	props["invert"] = "sensor_active = not" in segment
	if "is_in_group(" in segment:
		props["filter_mode"] = "group"
		var groups: Array[String] = []
		var rx := RegEx.new(); rx.compile(r'is_in_group\("([^"]+)"\)')
		for m in rx.search_all(segment):
			groups.append(m.get_string(1))
		props["groups"] = ",".join(groups)
	else:
		props["filter_mode"] = "any"
	return props


func _parse_variable_sensor_props(segment: String) -> Dictionary:
	var props: Dictionary = {}
	var name_rx := RegEx.new(); name_rx.compile(r"# Get variable '([^']+)'")
	var nm := name_rx.search(segment); if nm: props["variable_name"] = nm.get_string(1)
	if " and " in segment and ">=" in segment and "<=" in segment:
		props["evaluation_type"] = "between"
	elif " != " in segment: props["evaluation_type"] = "not_equal"
	elif " >= " in segment: props["evaluation_type"] = "greater_equal"
	elif " <= " in segment: props["evaluation_type"] = "less_equal"
	elif " > " in segment: props["evaluation_type"] = "greater"
	elif " < " in segment: props["evaluation_type"] = "less"
	elif " == " in segment: props["evaluation_type"] = "equal"
	elif "_changed" in segment: props["evaluation_type"] = "changed"
	return props


func _parse_input_map_sensor_props(segment: String) -> Dictionary:
	var props: Dictionary = {}
	var btn_rx := RegEx.new()
	btn_rx.compile(r'var\s+\w+_active\s*=\s*(not\s+)?Input\.is_action_(pressed|just_pressed|just_released)\("([^"]+)"\)')
	var bm := btn_rx.search(segment)
	if bm:
		props["input_mode"] = bm.get_string(2)
		props["action_name"] = bm.get_string(3)
		props["invert"] = not bm.get_string(1).is_empty()
		return props

	var axis_rx := RegEx.new()
	axis_rx.compile(r'Input\.get_axis\("([^"]+)",\s*"([^"]+)"\)')
	var am := axis_rx.search(segment)
	if am:
		props["input_mode"] = "axis"
		props["negative_action"] = am.get_string(1)
		props["positive_action"] = am.get_string(2)
		props["invert"] = "sensor_active = not sensor_active" in segment
		var store_rx := RegEx.new()
		store_rx.compile(r'\n(\w+)\s*=\s*_axis_val')
		var sm := store_rx.search(segment)
		if sm:
			props["store_in"] = sm.get_string(1)
		var dead_rx := RegEx.new()
		dead_rx.compile(r'absf\(_axis_val\)\s*>\s*([^\n]+)')
		var dm := dead_rx.search(segment)
		if dm:
			props["deadzone"] = dm.get_string(1).strip_edges()
		return props

	return props


func _parse_collision_sensor_props(full_block: String, chain_name: String, segment: String) -> Dictionary:
	var props: Dictionary = {
		"detection_mode": "entered",
		"detect_bodies": false,
		"detect_areas": false,
		"filter_type": "any",
		"filter_value": "",
		"invert": false,
	}

	if "_collision_exited_" in segment:
		props["detection_mode"] = "exited"
	elif "_collision_entered_" in segment:
		props["detection_mode"] = "entered"
	elif "get_overlapping_" in segment:
		props["detection_mode"] = "overlapping"

	var area_name_rx := RegEx.new()
	area_name_rx.compile("func _setup_collision_sensor_%s\\(\\) -> void:[\\s\\S]*?" % chain_name + FIND_CHILD_RX + "\"([^\"]+)\"")
	var an := area_name_rx.search(full_block)
	if an:
		props["area_node_name"] = an.get_string(1)

	props["detect_bodies"] = ("body_" in full_block and ("_on_collision_%s_" % chain_name) in full_block)
	props["detect_areas"] = ("area_" in full_block and ("_on_collision_%s_" % chain_name) in full_block)
	if not props["detect_bodies"] and not props["detect_areas"]:
		props["detect_areas"] = true

	var group_rx := RegEx.new()
	group_rx.compile(r'\.is_in_group\("([^"]+)"\)')
	var gm := group_rx.search(segment)
	if gm:
		props["filter_type"] = "group"
		props["filter_value"] = gm.get_string(1)
	else:
		var name_rx := RegEx.new()
		name_rx.compile(r'\.name\s*==\s*"([^"]+)"')
		var nm := name_rx.search(segment)
		if nm:
			props["filter_type"] = "name"
			props["filter_value"] = nm.get_string(1)

	props["invert"] = "return true" in segment and "return false" in segment and "if not _collision_" in segment
	return props


func _parse_movement_sensor_props(segment: String) -> Dictionary:
	var props: Dictionary = {
		"all_axis": false,
		"pos_x": false,
		"neg_x": false,
		"pos_y": false,
		"neg_y": false,
		"pos_z": false,
		"neg_z": false,
		"threshold": "0.1",
		"use_local_axes": "basis.inverse() * _ms_vel" in segment,
		"invert": "var sensor_" in segment and "not (" in segment,
	}

	var cond_rx := RegEx.new()
	cond_rx.compile(r'_ms_vel\.(x|y|z)\s*([<>])\s*(-?\d+\.?\d*)')
	var matches := cond_rx.search_all(segment)
	var dirs: Dictionary = {}
	var thresholds: Array[String] = []
	for m in matches:
		var axis := m.get_string(1)
		var op := m.get_string(2)
		var val := m.get_string(3)
		thresholds.append(val.trim_prefix("-"))
		if axis == "x" and op == ">": props["pos_x"] = true
		if axis == "x" and op == "<": props["neg_x"] = true
		if axis == "y" and op == ">": props["pos_y"] = true
		if axis == "y" and op == "<": props["neg_y"] = true
		if axis == "z" and op == ">": props["pos_z"] = true
		if axis == "z" and op == "<": props["neg_z"] = true
		var key := "%s%s" % [axis, op]
		dirs[key] = true

	if thresholds.size() > 0:
		props["threshold"] = thresholds[0]
	if dirs.size() == 6:
		props["all_axis"] = true
		props["pos_x"] = false
		props["neg_x"] = false
		props["pos_y"] = false
		props["neg_y"] = false
		props["pos_z"] = false
		props["neg_z"] = false

	return props


func _parse_delay_sensor_props(segment: String) -> Dictionary:
	var props: Dictionary = {"delay": "0.0", "duration": "0.0", "repeat": false}
	var delay_rx := RegEx.new()
	delay_rx.compile(r'if\s+\w+\s*>?=\s*([^:\n]+):')
	var matches := delay_rx.search_all(segment)
	if matches.size() >= 1:
		props["delay"] = matches[0].get_string(1).strip_edges()
	if matches.size() >= 2:
		props["duration"] = matches[1].get_string(1).strip_edges()
	props["repeat"] = "# Repeat: back to delay phase" in segment or "phase stays 0" in segment
	return props


## Detect the controller logic mode from the controller's assignment line.
## Used when no stored mode is available (legacy scripts). When several modes
## fit (one input), the first candidate is returned.
func _detect_logic_mode(body: String) -> String:
	var modes := _detect_logic_modes(body)
	return modes[0] if not modes.is_empty() else "and"


## Every logic mode that could have produced the controller's condition.
## Handles both "var controller_active = ..." and nested controllers'
## "var <prefix>_active = ...", including the state-gate wrapper.
## With one input the modes are indistinguishable: "s0" fits and/or and
## "not (s0)" fits nand/nor, so both are returned. Returns [] when the
## condition is not one the generator emits (e.g. hand-written logic), so
## callers can keep the stored mode instead of guessing.
func _detect_logic_modes(code: String) -> Array[String]:
	var assign_rx := RegEx.new()
	assign_rx.compile("(?m)^\\s*var\\s+\\w*active\\s*=\\s*(.+?)\\s*$")
	# Prefer the top-level controller's line; a whole chain body also contains
	# sensor "_active" variables that must not be mistaken for it.
	var top_rx := RegEx.new()
	top_rx.compile("(?m)^\\s*var\\s+controller_active\\s*=\\s*(.+?)\\s*$")
	var m := top_rx.search(code)
	if not m:
		m = assign_rx.search(code)
	if not m:
		return []
	var expr := m.get_string(1).strip_edges()

	# Nested controllers wrap the condition in a state gate.
	var gate_rx := RegEx.new()
	gate_rx.compile("^_logic_brick_chain_state_matches\\(.*?\\)\\s+and\\s+\\((.*)\\)$")
	var gate := gate_rx.search(expr)
	if gate:
		expr = gate.get_string(1).strip_edges()

	if expr == "true":
		return []

	var negated := false
	if expr.begins_with("not (") and expr.ends_with(")"):
		negated = true
		expr = expr.substr(5, expr.length() - 6).strip_edges()

	var xor_rx := RegEx.new()
	xor_rx.compile("^\\(\\s*int\\(\\w+\\)(\\s*\\+\\s*int\\(\\w+\\))*\\s*\\)\\s*==\\s*1$")
	if not negated and xor_rx.search(expr):
		return ["xor"]

	var ident_rx := RegEx.new()
	ident_rx.compile("^\\w+$")
	var has_and := false
	var has_or := false
	for word in expr.split(" ", false):
		if word == "and":
			has_and = true
		elif word == "or":
			has_or = true
		elif not ident_rx.search(word):
			return []  # Not a plain chain of input variables.
	if has_and and has_or:
		return []
	if negated:
		if has_and:
			return ["nand"]
		if has_or:
			return ["nor"]
		return ["nand", "nor"]
	if has_and:
		return ["and"]
	if has_or:
		return ["or"]
	return ["and", "or"]


## Detect all_states flag.
func _detect_all_states(body: String) -> bool:
	var rx := RegEx.new()
	rx.compile(r'_logic_brick_chain_state_matches\([^,]+,\s*(true|false)\)')
	var m := rx.search(body)
	if not m:
		return false
	return m.get_string(1) == "true"


## Extract state_id string.
func _detect_state_id(body: String) -> String:
	var rx := RegEx.new()
	rx.compile(r'_logic_brick_chain_state_matches\("([^"]*)",\s*false\)')
	var m := rx.search(body)
	if not m:
		return ""
	return m.get_string(1)


## Detect which actuator types were generated inside the `if controller_active:`
## block by matching comment and code signatures.
## Returns an Array of Dictionaries: [{class: String, properties: Dictionary}, ...]
## (may be empty for ScriptController chains).
func _detect_actuators(body: String) -> Array:
	# Isolate the actuator execution block (after "# Actuator execution")
	var act_start := body.find("# Actuator execution")
	if act_start == -1:
		act_start = body.find("if controller_active:")
	if act_start == -1:
		return []

	var act_end := body.find("\n	# Actuator Sensor flags", act_start)
	if act_end == -1:
		act_end = body.length()
	var act_block := body.substr(act_start, act_end - act_start)

	var meta_actuators = rebuild._collect_meta_comments(act_block, META_ACTUATOR_PREFIX)
	if not meta_actuators.is_empty():
		return meta_actuators

	var hits: Array = []
	for sig_entry in ACTUATOR_SIGNATURES:
		var sig: String = sig_entry[0]
		var cls: String = sig_entry[1]
		var search_from := 0
		while true:
			var idx := act_block.find(sig, search_from)
			if idx == -1:
				break
			hits.append({"start": idx, "sig": sig, "class": cls, "is_comment": sig.begins_with("#")})
			search_from = idx + max(1, sig.length())

	if hits.is_empty():
		return []

	hits.sort_custom(func(a, b):
		if a["start"] == b["start"]:
			if a["is_comment"] != b["is_comment"]:
				return a["is_comment"]
			return a["sig"].length() > b["sig"].length()
		return a["start"] < b["start"]
	)

	var filtered_hits: Array = []
	var comment_hit_indices: Array = []
	for i in range(hits.size()):
		if bool(hits[i]["is_comment"]):
			comment_hit_indices.append(i)

	for hit_idx in range(hits.size()):
		var hit = hits[hit_idx]
		var skip_hit := false

		# If a raw-code signature lands inside the range already owned by a comment
		# signature, it is part of that actuator's implementation, not a second brick.
		# This fixes duplicated Audio2D/Impulse/etc. when one generated actuator block
		# contains both a readable header comment and lower-level API calls.
		if not bool(hit["is_comment"]):
			for comment_idx in comment_hit_indices:
				if comment_idx >= hit_idx:
					break
				var comment_hit = hits[comment_idx]
				var next_comment_start := act_block.length()
				for future_comment_idx in comment_hit_indices:
					if future_comment_idx > comment_idx:
						next_comment_start = int(hits[future_comment_idx]["start"])
						break
				if int(hit["start"]) >= int(comment_hit["start"]) and int(hit["start"]) < next_comment_start:
					skip_hit = true
					break

		if skip_hit:
			continue

		if not filtered_hits.is_empty():
			var prev = filtered_hits[filtered_hits.size() - 1]
			var gap := int(hit["start"]) - int(prev["start"])
			if hit["class"] == prev["class"] and gap < 240:
				continue
		filtered_hits.append(hit)

	for i in range(filtered_hits.size()):
		var end_pos: int = act_block.length()
		if i + 1 < filtered_hits.size():
			end_pos = int(filtered_hits[i + 1]["start"])
		filtered_hits[i]["end"] = end_pos

	var found: Array = []
	for hit in filtered_hits:
		var start_pos: int = int(hit["start"])
		var end_pos: int = int(hit["end"])
		var cls: String = hit["class"]
		var local_block := act_block.substr(start_pos, end_pos - start_pos)
		var props := _extract_actuator_properties(cls, local_block)
		found.append({"class": cls, "properties": props})

	return found


## Extract recoverable property values for a specific actuator class from the
## generated code block.  Returns a (possibly empty) Dictionary of properties
## that should override the actuator's defaults when rebuilding.
func _extract_actuator_properties(cls: String, act_block: String) -> Dictionary:
	return rebuild._filter_to_declared_properties(cls, _parse_actuator_properties_for_class(cls, act_block))


func _parse_actuator_properties_for_class(cls: String, act_block: String) -> Dictionary:
	match cls:
		"MotionActuator", "PositionActuator":
			return _parse_motion_actuator_props(act_block)
		"Motion2DActuator", "Position2DActuator":
			return _parse_motion_2d_actuator_props(act_block)
		"VariableActuator":
			return _parse_variable_actuator_props(act_block)
		"TextActuator":
			return _parse_text_actuator_props(act_block)
		"ImpulseActuator":
			return _parse_impulse_actuator_props(act_block)
		"Audio2DActuator":
			return _parse_audio2d_actuator_props(act_block)
		"ObjectFlashActuator":
			return _parse_object_flash_actuator_props(act_block)
		"ForceActuator":
			return _parse_force_actuator_props(act_block)
		"SoftBodyPointForceActuator":
			return _parse_soft_body_point_action_props(act_block, "apply_force")
		"SoftBodyPointImpulseActuator":
			return _parse_soft_body_point_action_props(act_block, "apply_impulse")
		"TorqueActuator":
			return _parse_torque_actuator_props(act_block)
		"LocationActuator":
			return _parse_vector3_action_props(act_block)
		"LinearVelocityActuator":
			return _parse_linear_velocity_actuator_props(act_block)
		"RotationActuator":
			return _parse_rotation_actuator_props(act_block)
		"VisibilityActuator":
			return _parse_visibility_actuator_props(act_block)
		"SoundActuator", "MusicActuator":
			return _parse_soundlike_actuator_props(act_block)
		"AnimationActuator":
			return _parse_animation_actuator_props(act_block)
		"CollisionActuator":
			return _parse_collision_actuator_props(act_block)
		"StateActuator":
			return _parse_state_actuator_props(act_block)
		"PropertyActuator":
			return _parse_property_actuator_props(act_block)
		"AnimationTreeActuator":
			return _parse_animation_tree_actuator_props(act_block)
		_:
			return _parse_generic_actuator_props(act_block)


func _parse_motion_2d_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	if ".rotation += deg_to_rad(" in act_block:
		props["motion_type"] = "rotation"
		var rrx := RegEx.new()
		rrx.compile(r'deg_to_rad\(([^\)]+)\)')
		var rm := rrx.search(act_block)
		if rm:
			props["x"] = rm.get_string(1).strip_edges()
		return props
	props["motion_type"] = "location"
	if ".translate(" in act_block:
		props["movement_method"] = "translate"
		props["space"] = "local"
	elif ".global_position +=" in act_block:
		props["movement_method"] = "translate"
		props["space"] = "global"
	elif ".position = Vector2(" in act_block:
		props["movement_method"] = "position"
		props["space"] = "local"
	elif ".global_position = Vector2(" in act_block:
		props["movement_method"] = "position"
		props["space"] = "global"
	elif "_logic_brick_character_2d_target_velocity" in act_block or ".velocity = _motion2d_vec_" in act_block:
		props["movement_method"] = "character_velocity"
		props["space"] = "local" if ".rotated(rotation)" in act_block else "global"
	var vrx := RegEx.new()
	vrx.compile(r'Vector2\(([^,]+),\s*([^\)]+)\)')
	var vm := vrx.search(act_block)
	if vm:
		props["x"] = vm.get_string(1).strip_edges()
		props["y"] = vm.get_string(2).strip_edges()
	var nrx := RegEx.new()
	nrx.compile(r'var _motion2d_name_\w+ = "([^"]*)"')
	var nm := nrx.search(act_block)
	if nm:
		props["target_node_name"] = nm.get_string(1)
	return props


## Parse MotionActuator properties from the generated code lines.
## Handles all movement_method / space combinations plus camera-relative.
func _parse_motion_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}

	# ── Determine movement_method and space ──────────────────────────────────
	if "# Move in local space" in act_block:
		props["movement_method"] = "translate"
		props["space"] = "local"
	elif "# Move in global space" in act_block:
		props["movement_method"] = "translate"
		props["space"] = "global"
	elif "# Set local position" in act_block:
		props["movement_method"] = "position"
		props["space"] = "local"
	elif "# Set global position" in act_block:
		props["movement_method"] = "position"
		props["space"] = "global"
	elif "# Set CharacterBody3D velocity" in act_block:
		props["movement_method"] = "character_velocity"
		# Local space builds a _motion_dir from the rotation-only global basis
		if ("global_transform.basis *" in act_block or "global_transform.basis.orthonormalized() *" in act_block) and "# Camera-relative" not in act_block:
			props["space"] = "local"
		else:
			props["space"] = "global"

	# ── camera_relative ───────────────────────────────────────────────────────
	if "# Camera-relative movement" in act_block:
		props["camera_relative"] = true
		var cam_rx := RegEx.new()
		cam_rx.compile(FIND_CHILD_RX + r'"([^"]+)"')
		var cm := cam_rx.search(act_block)
		if cm:
			props["camera_name"] = cm.get_string(1)

	# ── Extract X / Y / Z values from direct Vector3(...) calls ───────────────
	var vec3_rx := RegEx.new()
	vec3_rx.compile(r'(?:translate\(|global_position \+=\s*|position =\s*|global_position =\s*)Vector3\(([^,)]+),\s*([^,)]+),\s*([^)]+)\)')
	var vm := vec3_rx.search(act_block)
	if vm:
		props["x"] = vm.get_string(1).strip_edges()
		props["y"] = vm.get_string(2).strip_edges()
		props["z"] = vm.get_string(3).strip_edges()

	# character_velocity local space builds var _motion_dir from the rotation-only global basis
	if props.get("movement_method", "") == "character_velocity" and props.get("space", "") == "local":
		var local_vec3_rx := RegEx.new()
		local_vec3_rx.compile(r'global_transform\.basis(?:\.orthonormalized\(\))?\s*\*\s*Vector3\(([^,)]+),\s*([^,)]+),\s*([^)]+)\)')
		var lm := local_vec3_rx.search(act_block)
		if lm:
			props["x"] = lm.get_string(1).strip_edges()
			props["y"] = lm.get_string(2).strip_edges()
			props["z"] = lm.get_string(3).strip_edges()

	# character_velocity global space uses individual velocity.x/y/z = EXPR lines
	if props.get("movement_method", "") == "character_velocity" and props.get("space", "") == "global":
		var vx_rx := RegEx.new(); vx_rx.compile(r'velocity\.x\s*=\s*([^\n]+)')
		var vy_rx := RegEx.new(); vy_rx.compile(r'velocity\.y\s*=\s*([^\n]+)')
		var vz_rx := RegEx.new(); vz_rx.compile(r'velocity\.z\s*=\s*([^\n]+)')
		var mx := vx_rx.search(act_block); if mx: props["x"] = mx.get_string(1).strip_edges()
		var my := vy_rx.search(act_block); if my: props["y"] = my.get_string(1).strip_edges()
		var mz := vz_rx.search(act_block); if mz: props["z"] = mz.get_string(1).strip_edges()

	# ── call_move_and_slide ───────────────────────────────────────────────────
	if "move_and_slide()" in act_block:
		props["call_move_and_slide"] = true

	return props


func _parse_variable_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	var target_rx := RegEx.new()
	target_rx.compile(r'_target\.set\("([^"]+)",\s*([^\n]+)\)')
	var tm := target_rx.search(act_block)
	if not tm:
		return props

	props["variable_name"] = tm.get_string(1)
	var expr := tm.get_string(2).strip_edges()
	if expr == "_src_val":
		props["mode"] = "copy"
		var src_rx := RegEx.new()
		src_rx.compile(r'_src_val\s*=\s*(?:self|_gv_src)\.get\("([^"]+)"\)')
		var sm := src_rx.search(act_block)
		if sm:
			props["source_variable"] = sm.get_string(1)
	elif expr.begins_with('_target.get("%s") + ' % props["variable_name"]):
		props["mode"] = "add"
		props["value"] = expr.trim_prefix('_target.get("%s") + ' % props["variable_name"]).strip_edges()
	elif "not _cur" in act_block:
		props["mode"] = "toggle"
	else:
		props["mode"] = "assign"
		props["value"] = expr
	return props


func _parse_text_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	if "# Set static text" in act_block:
		props["mode"] = "static"
		var static_rx := RegEx.new()
		static_rx.compile(r'\.text\s*=\s*"([^"]*)"')
		var sm := static_rx.search(act_block)
		if sm:
			props["static_text"] = sm.get_string(1)
		return props

	props["mode"] = "variable"
	var value_rx := RegEx.new()
	value_rx.compile(r'var _value = str\(([^)]+)\)')
	var vm := value_rx.search(act_block)
	if vm:
		props["variable_name"] = vm.get_string(1).strip_edges()

	var both_rx := RegEx.new()
	both_rx.compile(r'var _display_text = "([^"]*)" \+ _value \+ "([^"]*)"')
	var bm := both_rx.search(act_block)
	if bm:
		props["prefix"] = bm.get_string(1)
		props["suffix"] = bm.get_string(2)
		return props

	var pre_rx := RegEx.new()
	pre_rx.compile(r'var _display_text = "([^"]*)" \+ _value')
	var pm := pre_rx.search(act_block)
	if pm:
		props["prefix"] = pm.get_string(1)
		return props

	var suf_rx := RegEx.new()
	suf_rx.compile(r'var _display_text = _value \+ "([^"]*)"')
	var xm := suf_rx.search(act_block)
	if xm:
		props["suffix"] = xm.get_string(1)
	return props


func _parse_impulse_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {"impulse_type": "central", "space": "global"}
	if "apply_torque_impulse(" in act_block:
		props["impulse_type"] = "torque"
	elif "apply_impulse(" in act_block:
		props["impulse_type"] = "positional"
	else:
		props["impulse_type"] = "central"

	var basis_rx := RegEx.new()
	basis_rx.compile(r'global_transform\.basis\s*\*\s*Vector3\(([^,)]+),\s*([^,)]+),\s*([^)]+)\)')
	var bm := basis_rx.search(act_block)
	if bm:
		props["space"] = "local"
		props["x"] = bm.get_string(1).strip_edges()
		props["y"] = bm.get_string(2).strip_edges()
		props["z"] = bm.get_string(3).strip_edges()
	else:
		var vec_rx := RegEx.new()
		vec_rx.compile(r'apply_(?:central_)?impulse\(Vector3\(([^,)]+),\s*([^,)]+),\s*([^)]+)\)')
		var vm := vec_rx.search(act_block)
		if not vm:
			vec_rx.compile(r'apply_torque_impulse\(Vector3\(([^,)]+),\s*([^,)]+),\s*([^)]+)\)')
			vm = vec_rx.search(act_block)
		if vm:
			props["x"] = vm.get_string(1).strip_edges()
			props["y"] = vm.get_string(2).strip_edges()
			props["z"] = vm.get_string(3).strip_edges()

	if props["impulse_type"] == "positional":
		var pos_rx := RegEx.new()
		pos_rx.compile(r'apply_impulse\([^,]+,\s*Vector3\(([^,)]+),\s*([^,)]+),\s*([^)]+)\)')
		var pm := pos_rx.search(act_block)
		if pm:
			props["pos_x"] = pm.get_string(1).strip_edges()
			props["pos_y"] = pm.get_string(2).strip_edges()
			props["pos_z"] = pm.get_string(3).strip_edges()
	return props


func _parse_audio2d_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	props["mode"] = "play" if "- Play" in act_block or ".play()" in act_block else "stop"
	var sound_rx := RegEx.new()
	sound_rx.compile(r'load\("([^"]+)"\)')
	var sm := sound_rx.search(act_block)
	if sm:
		props["sound_file"] = sm.get_string(1)
	var vol_rx := RegEx.new()
	vol_rx.compile(r'volume_db\s*=\s*([^\n]+)')
	var vm := vol_rx.search(act_block)
	if vm:
		props["volume"] = vm.get_string(1).strip_edges()
	var pitch_rx := RegEx.new()
	pitch_rx.compile(r'pitch_scale\s*=\s*([^\n]+)')
	var pm := pitch_rx.search(act_block)
	if pm:
		var pitch_expr := pm.get_string(1).strip_edges()
		if "randf_range" in pitch_expr:
			var base_rx := RegEx.new()
			base_rx.compile(r'([^\s+]+)\s*\+\s*randf_range\(([^,]+),\s*([^)]+)\)')
			var bm := base_rx.search(pitch_expr)
			if bm:
				props["pitch"] = bm.get_string(1).strip_edges()
				props["pitch_random"] = bm.get_string(3).strip_edges().trim_prefix("-")
		else:
			props["pitch"] = pitch_expr
	props["loop"] = "_audio2d_loop_enabled" in act_block and "= true" in act_block
	props["play_mode"] = "overlap" if "var _ov2d = AudioStreamPlayer.new()" in act_block else "restart"
	return props


func _parse_object_flash_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	var target_rx := RegEx.new()
	target_rx.compile(r'_resolve_flash_target_[^(]+\("([^"]+)"\)')
	var tm := target_rx.search(act_block)
	if tm:
		props["object_node_name"] = tm.get_string(1)
	var run_rx := RegEx.new()
	run_rx.compile(r'_run_object_flash_[^(]+\([^,]+,\s*"([^"]+)",\s*Color\(([^,]+),\s*([^,]+),\s*([^,]+),\s*([^)]+)\),\s*float\(([^)]+)\)')
	var rm := run_rx.search(act_block)
	if rm:
		props["effect"] = rm.get_string(1)
		props["color"] = "Color(%s, %s, %s, %s)" % [rm.get_string(2), rm.get_string(3), rm.get_string(4), rm.get_string(5)]
		props["speed"] = rm.get_string(6)
	return props


func _parse_force_actuator_props(act_block: String) -> Dictionary:
	var props := _parse_vector3_action_props(act_block)
	props["space"] = "local" if "global_transform.basis" in act_block else "global"
	return props


func _parse_soft_body_point_action_props(act_block: String, method_name: String) -> Dictionary:
	var props := _parse_vector3_action_props(act_block)
	props["space"] = "local" if "global_transform.basis" in act_block else "global"
	var point_rx := RegEx.new()
	point_rx.compile(method_name + r'\(int\(([^)]+)\),')
	var point_match := point_rx.search(act_block)
	if point_match:
		props["point_index"] = point_match.get_string(1).strip_edges()
	return props


func _parse_torque_actuator_props(act_block: String) -> Dictionary:
	var props := _parse_vector3_action_props(act_block)
	props["space"] = "local" if "global_transform.basis" in act_block else "global"
	return props


func _parse_vector3_action_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	var rx := RegEx.new()
	rx.compile(r'Vector3\(([^,)]+),\s*([^,)]+),\s*([^)]+)\)')
	var m := rx.search(act_block)
	if m:
		props["x"] = m.get_string(1).strip_edges()
		props["y"] = m.get_string(2).strip_edges()
		props["z"] = m.get_string(3).strip_edges()
	return props


func _parse_linear_velocity_actuator_props(act_block: String) -> Dictionary:
	var props := _parse_vector3_action_props(act_block)
	props["space"] = "local" if "global_transform.basis" in act_block else "global"
	return props


func _parse_rotation_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	var axes = {"rotate_x(": "x", "rotate_y(": "y", "rotate_z(": "z"}
	for token in axes.keys():
		var idx := act_block.find(token)
		if idx != -1:
			var start := idx + String(token).length()
			var end := act_block.find(")", start)
			if end != -1:
				props[axes[token]] = act_block.substr(start, end - start).strip_edges()
	return props


func _parse_visibility_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	if "visible = true" in act_block:
		props["action"] = "show"
	elif "visible = false" in act_block:
		props["action"] = "hide"
	else:
		props["action"] = "toggle"
	return props


func _parse_soundlike_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	props["mode"] = "stop" if ".stop()" in act_block else "play"
	var load_rx := RegEx.new(); load_rx.compile(r'load\("([^"]+)"\)')
	var lm := load_rx.search(act_block); if lm: props["sound_file"] = lm.get_string(1)
	var vol_rx := RegEx.new(); vol_rx.compile(r'volume_db\s*=\s*([^\n]+)')
	var vm := vol_rx.search(act_block); if vm: props["volume"] = vm.get_string(1).strip_edges()
	var pitch_rx := RegEx.new(); pitch_rx.compile(r'pitch_scale\s*=\s*([^\n]+)')
	var pm := pitch_rx.search(act_block); if pm: props["pitch"] = pm.get_string(1).strip_edges()
	props["loop"] = "loop" in act_block.to_lower() and "true" in act_block
	return props


func _parse_animation_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	var rx := RegEx.new(); rx.compile(r'play\("([^"]+)"')
	var m := rx.search(act_block); if m: props["animation_name"] = m.get_string(1)
	if ".stop" in act_block: props["action"] = "stop"
	elif ".pause" in act_block: props["action"] = "pause"
	else: props["action"] = "play"
	return props


func _parse_collision_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	if "disabled = true" in act_block:
		props["enabled"] = false
	elif "disabled = false" in act_block:
		props["enabled"] = true
	return props


func _parse_state_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	var rx := RegEx.new(); rx.compile(r'_logic_brick_state\s*=\s*"([^"]*)"')
	var m := rx.search(act_block); if m: props["state_id"] = m.get_string(1)
	return props


func _parse_property_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	var set_rx := RegEx.new(); set_rx.compile(r'\.set\("([^"]+)",\s*([^\n]+)\)')
	var m := set_rx.search(act_block)
	if m:
		props["property_name"] = m.get_string(1)
		props["value"] = m.get_string(2).strip_edges()
	return props


func _parse_generic_actuator_props(act_block: String) -> Dictionary:
	var props: Dictionary = {}
	var load_rx := RegEx.new(); load_rx.compile(r'load\("([^"]+)"\)')
	var lm := load_rx.search(act_block); if lm: props["resource_path"] = lm.get_string(1)
	var node_rx := RegEx.new(); node_rx.compile(FIND_CHILD_RX + r'"([^"]+)"')
	var nm := node_rx.search(act_block); if nm: props["node_name"] = nm.get_string(1)
	return props
