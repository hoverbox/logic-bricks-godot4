@tool
extends RefCounted

## Rebuilds logic_bricks metadata and the visual graph by parsing the node's
## attached GDScript. This is the inverse of code generation:
##
##   Script  ──parse──►  chains (metadata)  ──layout──►  graph (visual)
##
## What we can reliably recover from the generated code:
##   • Chain names           → func _logic_brick_{name}(_delta)
##   • Controller type       → ScriptController (var _sc_obj_{name}) or AND
##   • Script path           → load("res://...") in _ready()
##   • Sensor count/hints    → # Sensor evaluation block + sensor_N_active vars
##   • Logic mode            → var controller_active = s0 and s1 / or / etc.
##   • Actuator types        → comment signatures inside if controller_active:
##
## Recovered chains are added to the graph with an organised columnar layout:
##   [Sensor(s)]  →  [Controller]  →  [Actuator(s)]

const CODE_START_MARKER := "# === LOGIC BRICKS START ==="
const CODE_END_MARKER   := "# === LOGIC BRICKS END ==="
const META_SENSOR_PREFIX := "# LB_META_SENSOR "
const META_CONTROLLER_PREFIX := "# LB_META_CONTROLLER "
const META_ACTUATOR_PREFIX := "# LB_META_ACTUATOR "
const META_SENSOR_PREFIX_B64 := "# LB_META_SENSOR_B64 "
const META_CONTROLLER_PREFIX_B64 := "# LB_META_CONTROLLER_B64 "
const META_ACTUATOR_PREFIX_B64 := "# LB_META_ACTUATOR_B64 "
## Column X positions for a clean Sensor | Controller | Actuator layout
const COL_SENSOR     := 50.0
const COL_CONTROLLER := 350.0
const COL_ACTUATOR   := 650.0
const ROW_SPACING    := 320.0   ## Vertical gap unit between chains
const NODE_V_GAP     := 220.0   ## Vertical gap between nodes in same chain column
const CHAIN_BOTTOM_PAD := 140.0 ## Extra padding under each rebuilt chain block

## Map from comment/code signature → actuator class name.
## Each entry is [signature_string, actuator_class].
## Ordered from most-specific to least-specific so early matches win.
const ACTUATOR_SIGNATURES: Array = [
	# ── Animation ──────────────────────────────────────────────────────────
	["# Animation Actuator:",              "AnimationActuator"],
	["# Animation Tree actuator",          "AnimationTreeActuator"],
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
	["# Apply gravity and detect ground",  "GravityActuator"],
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
	["# Move Towards",                     "MoveTowardsActuator"],
	["_mt_stuck_offset_",                  "MoveTowardsActuator"],
	["# Waypoint Path",                    "WaypointPathActuator"],
	# ── Object / Scene ──────────────────────────────────────────────────────
	["# Apply initial velocity",           "EditObjectActuator"],
	["# Object Pool",                      "ObjectPoolActuator"],
	["# Object Flash Actuator",            "ObjectFlashActuator"],
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

var panel = null

func setup(target_panel) -> void:
	panel = target_panel


## Entry point: called when the user presses "Rebuild from Script".
## Reads the script, extracts chain info, writes metadata, and rebuilds the graph.
func rebuild_from_script() -> void:
	if not panel or not panel.current_node:
		push_error("Logic Bricks (ScriptRebuild): No node selected.")
		return

	var node: Node = panel.current_node

	if not node.get_script():
		push_error("Logic Bricks (ScriptRebuild): Node '%s' has no script attached." % node.name)
		return

	var script_path: String = node.get_script().resource_path
	if script_path.is_empty():
		push_error("Logic Bricks (ScriptRebuild): Script has no saved path (unsaved script?).")
		return

	# ── 1. Read the script text ───────────────────────────────────────────────
	var file := FileAccess.open(script_path, FileAccess.READ)
	if not file:
		push_error("Logic Bricks (ScriptRebuild): Cannot open script: %s" % script_path)
		return
	var source := file.get_as_text()
	file.close()

	# ── 2. Isolate the generated block ───────────────────────────────────────
	var block := _extract_generated_block(source)
	if block.is_empty():
		push_warning(
			"Logic Bricks (ScriptRebuild): No generated block found in '%s'.\n"
			+ "Apply Code at least once before using Rebuild from Script." % script_path
		)
		return

	# ── 3. Parse the block into chain descriptors ─────────────────────────────
	var chain_descs: Array[Dictionary] = []
	var meta_chains: Array = panel.manager.get_chains(node)
	if not meta_chains.is_empty():
		chain_descs = _descs_from_exact_chains(meta_chains)
	else:
		chain_descs = _parse_chains(block)
	if chain_descs.is_empty():
		push_warning(
			"Logic Bricks (ScriptRebuild): No _logic_brick_* functions found in the "
			+ "generated block. Nothing to rebuild."
		)
		return

	# ── 4. Build metadata (logic_bricks) from the descriptors ────────────────
	var chains_meta: Array = _build_chains_metadata(chain_descs)
	panel.manager.save_chains(node, chains_meta)

	# ── 5. Build graph data (logic_bricks_graph) with organised layout ────────
	var graph_data: Dictionary = _build_graph_data(chain_descs)
	node.set_meta("logic_bricks_graph", graph_data)
	_mark_scene_modified(node)

	# ── 6. Reload the visual graph ────────────────────────────────────────────
	await panel._load_graph_from_metadata()
	await panel.get_tree().process_frame
	panel._graph_helper.sync_graph_ui_to_bricks()

	var act_note := ""
	for desc in chain_descs:
		if desc["actuator_classes"].size() > 0:
			act_note = " (actuator types recovered)"
			break

	print(
		"Logic Bricks (ScriptRebuild): Rebuilt %d chain(s) from script '%s' on node '%s'%s."
		% [chain_descs.size(), script_path.get_file(), node.name, act_note]
	)


# ─────────────────────────────────────────────────────────────────────────────
# Parsing helpers
# ─────────────────────────────────────────────────────────────────────────────

## Extract only the text between the LOGIC BRICKS START / END markers.
func _extract_generated_block(source: String) -> String:
	var start_pos := source.find(CODE_START_MARKER)
	var end_pos   := source.find(CODE_END_MARKER)
	if start_pos == -1 or end_pos == -1 or end_pos <= start_pos:
		return ""
	var after_start := start_pos + CODE_START_MARKER.length()
	return source.substr(after_start, end_pos - after_start)


func _descs_from_exact_chains(chains: Array) -> Array[Dictionary]:
	var descs: Array[Dictionary] = []
	for chain_data in chains:
		if not (chain_data is Dictionary):
			continue
		var sensors_info: Array = []
		for sensor_data in chain_data.get("sensors", []):
			if sensor_data is Dictionary:
				sensors_info.append(_brick_info_from_meta(sensor_data, "AlwaysSensor"))
		var controller_info: Dictionary = {}
		var controllers = chain_data.get("controllers", [])
		if controllers is Array and controllers.size() > 0 and controllers[0] is Dictionary:
			controller_info = _brick_info_from_meta(controllers[0], "ANDController")
		var actuator_infos: Array = []
		for actuator_data in chain_data.get("actuators", []):
			if actuator_data is Dictionary:
				actuator_infos.append(_brick_info_from_meta(actuator_data, "MotionActuator"))
		var ctrl_class := str(controller_info.get("class", ""))
		var ctrl_props: Dictionary = controller_info.get("properties", {}) if controller_info.get("properties", {}) is Dictionary else {}
		descs.append({
			"name": str(chain_data.get("name", "")),
			"is_script_ctrl": ctrl_class == "ScriptController",
			"script_path": str(ctrl_props.get("script_path", "")),
			"logic_mode": str(ctrl_props.get("logic_mode", "and")),
			"sensor_count": sensors_info.size(),
			"sensor_infos": sensors_info,
			"all_states": bool(ctrl_props.get("all_states", false)),
			"state_id": str(ctrl_props.get("state_id", "")),
			"controller_meta": controller_info,
			"actuator_classes": actuator_infos,
		})
	return descs


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
		var controller_meta := _parse_meta_comment_from_text(body, META_CONTROLLER_PREFIX_B64)
		if controller_meta.is_empty():
			controller_meta = _parse_meta_comment_from_text(body, META_CONTROLLER_PREFIX)
		var controller_type := str(controller_meta.get("type", ""))
		var controller_props: Dictionary = controller_meta.get("properties", {}) if controller_meta.get("properties", {}) is Dictionary else {}
		var is_script_controller := controller_type == "ScriptController" or (controller_meta.is_empty() and sc_script_paths.has(c_name))
		descs.append({
			"name":             c_name,
			"is_script_ctrl":   is_script_controller,
			"script_path":      str(controller_props.get("script_path", sc_script_paths.get(c_name, ""))),
			"logic_mode":       str(controller_props.get("logic_mode", _detect_logic_mode(body))),
			"sensor_count":     sensor_infos.size(),
			"sensor_infos":     sensor_infos,
			"all_states":       bool(controller_props.get("all_states", _detect_all_states(body))),
			"state_id":         str(controller_props.get("state_id", _detect_state_id(body))),
			"controller_meta":   _brick_info_from_meta(controller_meta, "ScriptController" if is_script_controller else "ANDController") if not controller_meta.is_empty() else {},
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
	var meta_sensors := _collect_meta_comments(sensor_block, META_SENSOR_PREFIX_B64)
	if meta_sensors.is_empty():
		meta_sensors = _collect_meta_comments(sensor_block, META_SENSOR_PREFIX)
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
	var meta_info := _parse_meta_comment_from_text(segment, META_SENSOR_PREFIX_B64)
	if meta_info.is_empty():
		meta_info = _parse_meta_comment_from_text(segment, META_SENSOR_PREFIX)
	if not meta_info.is_empty():
		return _brick_info_from_meta(meta_info, "AlwaysSensor")

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
	if "# Timer sensor" in segment or "_timer_elapsed_" in segment or "_timer_active_" in segment:
		return {"class": "TimerSensor", "properties": _parse_timer_sensor_props(segment)}
	if "# Get variable '" in segment or "_lb_get_var_" in segment or "Compare Variable" in segment:
		return {"class": "VariableSensor", "properties": _parse_variable_sensor_props(segment)}

	var simple_rx := RegEx.new()
	simple_rx.compile(r'var\s+\w+_active\s*=\s*(true|false)')
	var sm := simple_rx.search(segment)
	if sm:
		return {"class": "AlwaysSensor", "properties": {"enabled": sm.get_string(1) == "true"}}

	push_warning("Logic Bricks (ScriptRebuild): Unrecognized sensor block in chain '%s'; using disabled AlwaysSensor placeholder instead of pretending it was recovered. Block:\n%s" % [chain_name, segment])
	return {"class": "AlwaysSensor", "properties": {"enabled": false}}



func _parse_meta_comment_from_text(text: String, prefix: String) -> Dictionary:
	var line_start := text.find(prefix)
	if line_start == -1:
		return {}
	var payload_start := line_start + prefix.length()
	var line_end := text.find("\n", payload_start)
	if line_end == -1:
		line_end = text.length()
	var payload := text.substr(payload_start, line_end - payload_start).strip_edges()
	if payload.is_empty():
		return {}
	var parsed = _parse_meta_payload(prefix, payload)
	if parsed is Dictionary:
		return parsed
	return {}


func _collect_meta_comments(text: String, prefix: String) -> Array:
	var results: Array = []
	var search_from := 0
	while true:
		var line_start := text.find(prefix, search_from)
		if line_start == -1:
			break
		var payload_start := line_start + prefix.length()
		var line_end := text.find("\n", payload_start)
		if line_end == -1:
			line_end = text.length()
		var payload := text.substr(payload_start, line_end - payload_start).strip_edges()
		var parsed = _parse_meta_payload(prefix, payload)
		if parsed is Dictionary:
			results.append(_brick_info_from_meta(parsed, ""))
		search_from = line_end + 1
	return results


func _parse_meta_payload(prefix: String, payload: String):
	if payload.is_empty():
		return {}
	if prefix.ends_with("_B64 "):
		var raw := Marshalls.base64_to_raw(payload)
		if raw.is_empty():
			return {}
		return bytes_to_var(raw)
	return str_to_var(payload)


func _brick_info_from_meta(meta: Dictionary, fallback_class: String) -> Dictionary:
	var cls := str(meta.get("type", fallback_class))
	if cls.is_empty():
		cls = fallback_class
	return {
		"class": cls,
		"instance_name": str(meta.get("instance_name", "")),
		"debug_enabled": bool(meta.get("debug_enabled", false)),
		"debug_message": str(meta.get("debug_message", "")),
		"properties": meta.get("properties", {}) if meta.get("properties", {}) is Dictionary else {}
	}


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
	elif "MOUSE_BUTTON_WHEEL_UP" in segment: props["mouse_button"] = "wheel_up"
	elif "MOUSE_BUTTON_WHEEL_DOWN" in segment: props["mouse_button"] = "wheel_down"
	if "# Mouse movement detection" in segment: props["mouse_event"] = "movement"
	elif "# Hover over this object" in segment: props["mouse_event"] = "hover_object"
	elif "# Hover over any object" in segment: props["mouse_event"] = "hover_any"
	elif "was_pressed" in segment and "not _is_pressed" in segment: props["mouse_event"] = "just_released"
	elif "was_pressed" in segment: props["mouse_event"] = "just_pressed"
	elif "Input.is_mouse_button_pressed(" in segment: props["mouse_event"] = "pressed"
	var rx := RegEx.new(); rx.compile(r'length\(\)\s*>\s*([0-9.]+)')
	var m := rx.search(segment); if m: props["movement_threshold"] = m.get_string(1)
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


func _parse_timer_sensor_props(segment: String) -> Dictionary:
	var props: Dictionary = {}
	var rx := RegEx.new(); rx.compile(r'>=\s*([0-9.]+)')
	var m := rx.search(segment); if m: props["duration"] = m.get_string(1)
	props["repeat"] = "= 0.0" in segment and "sensor_active = true" in segment
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
		props["invert"] = "_axis_val = -_axis_val" in segment
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
	area_name_rx.compile("func _setup_collision_sensor_%s\\(\\) -> void:[\\s\\S]*?find_child\\(\\\"([^\\\"]+)\\\"" % chain_name)
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


## Detect the controller logic mode from the controller_active assignment.
func _detect_logic_mode(body: String) -> String:
	var active_rx := RegEx.new()
	active_rx.compile(r'var controller_active\s*=\s*(.+)')
	var m := active_rx.search(body)
	if not m:
		return "and"
	var expr := m.get_string(1).strip_edges()
	if expr.begins_with("not (") and " and " in expr:
		return "nand"
	if expr.begins_with("not (") and " or " in expr:
		return "nor"
	if "int(" in expr and "== 1" in expr:
		return "xor"
	if " or " in expr:
		return "or"
	return "and"


## Count sensor slots from sensor_N_active variables or named _active vars.
func _count_sensors(body: String) -> int:
	var indexed_rx := RegEx.new()
	indexed_rx.compile(r'\bsensor_(\d+)_active\b')
	var indexed_names: Dictionary = {}
	for m in indexed_rx.search_all(body):
		indexed_names[m.get_string(1)] = true

	var named_rx := RegEx.new()
	named_rx.compile(r'\b(?!controller_active\b)(?!sensor_active\b)(\w+_active)\b')
	var named_count := 0
	for m in named_rx.search_all(body):
		var s := m.get_string(1)
		var ctrl_pos := body.find("# Controller logic")
		if ctrl_pos == -1 or m.get_start() < ctrl_pos:
			named_count += 1

	if not indexed_names.is_empty():
		return indexed_names.size()
	if named_count > 0:
		return named_count
	if "# Sensor evaluation" in body:
		return 1
	return 0


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

	var meta_actuators := _collect_meta_comments(act_block, META_ACTUATOR_PREFIX)
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
	match cls:
		"MotionActuator":
			return _parse_motion_actuator_props(act_block)
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
		_:
			return _parse_generic_actuator_props(act_block)


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
		# Local space builds a _motion_dir from global_transform.basis
		if "global_transform.basis *" in act_block and "# Camera-relative" not in act_block:
			props["space"] = "local"
		else:
			props["space"] = "global"

	# ── camera_relative ───────────────────────────────────────────────────────
	if "# Camera-relative movement" in act_block:
		props["camera_relative"] = true
		var cam_rx := RegEx.new()
		cam_rx.compile(r'find_child\("([^"]+)"')
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

	# character_velocity local space builds var _motion_dir = global_transform.basis * Vector3(...)
	if props.get("movement_method", "") == "character_velocity" and props.get("space", "") == "local":
		var local_vec3_rx := RegEx.new()
		local_vec3_rx.compile(r'global_transform\.basis\s*\*\s*Vector3\(([^,)]+),\s*([^,)]+),\s*([^)]+)\)')
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
	var node_rx := RegEx.new(); node_rx.compile(r'find_child\("([^"]+)"')
	var nm := node_rx.search(act_block); if nm: props["node_name"] = nm.get_string(1)
	return props

## Returns true if the chain has all_states=true.
func _detect_all_states_from_body(body: String) -> bool:
	return _detect_all_states(body)


# ─────────────────────────────────────────────────────────────────────────────
# Metadata builder
# ─────────────────────────────────────────────────────────────────────────────

## Convert chain descriptors into the logic_bricks metadata format.
func _build_chains_metadata(descs: Array[Dictionary]) -> Array:
	var chains: Array = []

	for desc in descs:
		var sensors:     Array = []
		var controllers: Array = []
		var actuators:   Array = []

		# ── Sensors ───────────────────────────────────────────────────────────
		var sensor_infos: Array = desc.get("sensor_infos", [])
		if sensor_infos.is_empty():
			sensor_infos = [{"class": "AlwaysSensor", "properties": {"enabled": true}}]
		for sensor_info in sensor_infos:
			sensors.append({
				"type": sensor_info["class"],
				"instance_name": sensor_info.get("instance_name", ""),
				"debug_enabled": sensor_info.get("debug_enabled", false),
				"debug_message": sensor_info.get("debug_message", ""),
				"properties": sensor_info.get("properties", {})
			})

		# ── Controller ────────────────────────────────────────────────────────
		var controller_info: Dictionary = desc.get("controller_meta", {})
		if not controller_info.is_empty():
			controllers.append({
				"type": controller_info["class"],
				"instance_name": controller_info.get("instance_name", ""),
				"debug_enabled": controller_info.get("debug_enabled", false),
				"debug_message": controller_info.get("debug_message", ""),
				"properties": controller_info.get("properties", {})
			})
		elif desc["is_script_ctrl"]:
			controllers.append({
				"type": "ScriptController",
				"instance_name": "",
				"debug_enabled": false,
				"debug_message": "",
				"properties": {
					"logic_mode":  desc["logic_mode"],
					"script_path": desc["script_path"],
					"all_states":  desc["all_states"],
					"state_id":    desc["state_id"],
				}
			})
		else:
			controllers.append({
				"type": "ANDController",
				"instance_name": "",
				"debug_enabled": false,
				"debug_message": "",
				"properties": {
					"logic_mode": desc["logic_mode"],
					"all_states": desc["all_states"],
					"state_id":   desc["state_id"],
				}
			})

		# ── Actuators (recovered types + properties) ────────────────────────
		for act_info in (desc["actuator_classes"] as Array):
			actuators.append({
				"type": act_info["class"],
				"instance_name": act_info.get("instance_name", ""),
				"debug_enabled": act_info.get("debug_enabled", false),
				"debug_message": act_info.get("debug_message", ""),
				"properties": act_info.get("properties", {})
			})

		chains.append({
			"name":        desc["name"],
			"sensors":     sensors,
			"controllers": controllers,
			"actuators":   actuators
		})

	return chains


# ─────────────────────────────────────────────────────────────────────────────
# Graph data builder
# ─────────────────────────────────────────────────────────────────────────────

## Build the logic_bricks_graph metadata dict.
## Layout: sensors column → controller column → actuators column
func _build_graph_data(descs: Array[Dictionary]) -> Dictionary:
	var nodes:       Array = []
	var connections: Array = []
	var next_id: int       = 0

	var chain_row := 0

	for desc in descs:
		var sensors_info: Array = desc.get("sensor_infos", [])
		if sensors_info.is_empty():
			sensors_info = [{"class": "AlwaysSensor", "properties": {"enabled": true}}]
		var sensor_count:   int = max(1, sensors_info.size())
		var actuators_info: Array = desc["actuator_classes"]
		var actuator_count: int = max(0, actuators_info.size())

		# Height of this chain block is determined by the tallest column
		var rows_needed: int = max(sensor_count, max(1, actuator_count))
		var block_top: float = chain_row * ROW_SPACING

		# ── Sensor nodes ─────────────────────────────────────────────────────
		var sensor_ids: Array[String] = []
		for s_i in range(sensor_count):
			var s_y: float = block_top + s_i * NODE_V_GAP
			var s_id := "brick_node_%d" % next_id
			next_id += 1
			var sensor_info: Dictionary = sensors_info[s_i]
			nodes.append({
				"id":            s_id,
				"position":      Vector2(COL_SENSOR, s_y),
				"brick_type":    "sensor",
				"brick_class":   sensor_info["class"],
				"instance_name": sensor_info.get("instance_name", ""),
				"debug_enabled": sensor_info.get("debug_enabled", false),
				"debug_message": sensor_info.get("debug_message", ""),
				"properties":    sensor_info.get("properties", {})
			})
			sensor_ids.append(s_id)

		# ── Controller node ───────────────────────────────────────────────────
		var ctrl_y: float = block_top + (float(sensor_count - 1) * NODE_V_GAP) / 2.0
		var ctrl_id  := "brick_node_%d" % next_id
		next_id += 1

		var controller_info: Dictionary = desc.get("controller_meta", {})
		var ctrl_class := str(controller_info.get("class", "")) if not controller_info.is_empty() else ("ScriptController" if desc["is_script_ctrl"] else "ANDController")
		var ctrl_props: Dictionary
		if not controller_info.is_empty():
			ctrl_props = controller_info.get("properties", {})
		elif desc["is_script_ctrl"]:
			ctrl_props = {
				"logic_mode":  desc["logic_mode"],
				"script_path": desc["script_path"],
				"all_states":  desc["all_states"],
				"state_id":    desc["state_id"],
			}
		else:
			ctrl_props = {
				"logic_mode": desc["logic_mode"],
				"all_states": desc["all_states"],
				"state_id":   desc["state_id"],
			}

		nodes.append({
			"id":            ctrl_id,
			"position":      Vector2(COL_CONTROLLER, ctrl_y),
			"brick_type":    "controller",
			"brick_class":   ctrl_class,
			"instance_name": controller_info.get("instance_name", ""),
			"debug_enabled": controller_info.get("debug_enabled", false),
			"debug_message": controller_info.get("debug_message", ""),
			"properties":    ctrl_props
		})

		# Sensors → controller
		for s_id in sensor_ids:
			connections.append({
				"from_node": s_id,
				"from_port": 0,
				"to_node":   ctrl_id,
				"to_port":   0
			})

		# ── Actuator nodes ────────────────────────────────────────────────────
		for a_i in range(actuator_count):
			var a_y: float = block_top + a_i * NODE_V_GAP
			var a_id := "brick_node_%d" % next_id
			next_id += 1
			nodes.append({
				"id":            a_id,
				"position":      Vector2(COL_ACTUATOR, a_y),
				"brick_type":    "actuator",
				"brick_class":   actuators_info[a_i]["class"],
				"instance_name": actuators_info[a_i].get("instance_name", ""),
				"debug_enabled": actuators_info[a_i].get("debug_enabled", false),
				"debug_message": actuators_info[a_i].get("debug_message", ""),
				"properties":    actuators_info[a_i].get("properties", {})
			})
			# Controller → actuator
			connections.append({
				"from_node": ctrl_id,
				"from_port": 0,
				"to_node":   a_id,
				"to_port":   0
			})

		var block_height_units := ceil((float(max(1, rows_needed - 1)) * NODE_V_GAP + CHAIN_BOTTOM_PAD) / ROW_SPACING)
		chain_row += int(max(1.0, block_height_units))

	return {
		"nodes":       nodes,
		"connections": connections,
		"next_id":     next_id
	}


# ─────────────────────────────────────────────────────────────────────────────
# Utility
# ─────────────────────────────────────────────────────────────────────────────

func _mark_scene_modified(node: Node) -> void:
	if panel and panel.editor_interface:
		panel.editor_interface.mark_scene_as_unsaved()
