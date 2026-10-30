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

const BrickRegistry = preload("res://addons/logic_bricks/core/brick_registry.gd")
const LogicBrickManager = preload("res://addons/logic_bricks/core/logic_brick_manager.gd")
const GraphSnapshot = preload("res://addons/logic_bricks/core/graph_snapshot.gd")
# Marker strings come from the manager, which writes them; keeping one copy
# means the reader and writer cannot drift apart.
const CODE_START_MARKER: String = LogicBrickManager.CODE_START_MARKER
const CODE_END_MARKER: String = LogicBrickManager.CODE_END_MARKER
## Start of a node lookup by name in generated code, before the quoted name:
## find_child("X"...) or the cached form _lb_find_child_cached(root, "X").
const FIND_CHILD_RX := "(?:find_child\\(|_lb_find_child_cached\\([^,()]*(?:\\(\\)[^,()]*)*,\\s*)"
const META_SENSOR_PREFIX := "# LB_META_SENSOR "
const META_CONTROLLER_PREFIX := "# LB_META_CONTROLLER "
const META_ACTUATOR_PREFIX := "# LB_META_ACTUATOR "
const META_SENSOR_PREFIX_B64 := "# LB_META_SENSOR_B64 "
const META_CONTROLLER_PREFIX_B64 := "# LB_META_CONTROLLER_B64 "
const META_ACTUATOR_PREFIX_B64 := "# LB_META_ACTUATOR_B64 "
const BRICK_BEGIN_PREFIX: String = LogicBrickManager.BRICK_BEGIN_PREFIX
const BRICK_END_PREFIX: String = LogicBrickManager.BRICK_END_PREFIX
const SCRIPT_SYNC_HASH_META := "logic_bricks_generated_source_hash"
## Column X positions for a clean Sensor | Controller | Actuator layout
const COL_SENSOR     := 50.0
const COL_CONTROLLER := 350.0
const COL_ACTUATOR   := 650.0
const ROW_SPACING    := 320.0   ## Vertical gap unit between chains
const NODE_V_GAP     := 220.0   ## Vertical gap between nodes in same chain column
const CHAIN_BOTTOM_PAD := 140.0 ## Extra padding under each rebuilt chain block


var panel = null
var _text_parser = preload("res://addons/logic_bricks/ui/script_text_parser.gd").new()

func setup(target_panel) -> void:
	panel = target_panel
	_text_parser.setup(self)


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
		# Parentheses matter: % binds tighter than +, so without them the path
		# would be formatted into the second string, which has no %s.
		push_warning(
			("Logic Bricks (ScriptRebuild): No generated block found in '%s'.\n"
			+ "Apply Code at least once before using Rebuild from Script.") % script_path
		)
		return

	# ── 3. Exact restore from the graph snapshot saved at Apply Code ─────────
	var snapshot: Dictionary = GraphSnapshot.read(block)
	if not snapshot.is_empty():
		await _restore_snapshot(node, snapshot, script_path)
		return

	# ── 3b. Older scripts: parse the block into chain descriptors ────────────
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

	# Snapshot for undo. The regular graph snapshot does not include the chain
	# metadata, which this action also replaces, so it is added here.
	var before_snapshot: Dictionary = panel._take_graph_snapshot(node)
	before_snapshot["chains"] = _copy_meta(node, panel.manager.METADATA_KEY, [])
	var existing_graph: Dictionary = node.get_meta("logic_bricks_graph", {}) if node.get_meta("logic_bricks_graph", {}) is Dictionary else {}

	# ── 4. Build metadata (logic_bricks) from the descriptors ────────────────
	var chains_meta: Array = _build_chains_metadata(chain_descs)
	panel.manager.save_chains(node, chains_meta)

	# ── 5. Build graph data (logic_bricks_graph), keeping existing nodes ──────
	var graph_data: Dictionary = _build_graph_data(chain_descs, existing_graph)
	node.set_meta("logic_bricks_graph", graph_data)
	_mark_scene_modified(node)

	var after_snapshot: Dictionary = panel._take_graph_snapshot(node)
	after_snapshot["chains"] = _copy_meta(node, panel.manager.METADATA_KEY, [])
	panel._record_undo("Rebuild Logic Bricks from Script", before_snapshot, after_snapshot, node, false)

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


## Puts back the whole graph (bricks, layout, frames, variables, states) as it
## was at the last Apply Code. Undoable.
func _restore_snapshot(node: Node, snapshot: Dictionary, script_path: String) -> void:
	# Same undo record as the regular rebuild below (graph snapshot + chains).
	var before_snapshot: Dictionary = panel._take_graph_snapshot(node)
	before_snapshot["chains"] = _copy_meta(node, panel.manager.METADATA_KEY, [])
	GraphSnapshot.restore(node, snapshot)
	var after_snapshot: Dictionary = panel._take_graph_snapshot(node)
	after_snapshot["chains"] = _copy_meta(node, panel.manager.METADATA_KEY, [])
	panel._record_undo("Rebuild Logic Bricks from Script", before_snapshot, after_snapshot, node, false)
	_mark_scene_modified(node)
	await panel._load_graph_from_metadata()
	print("Logic Bricks (ScriptRebuild): Restored the graph of '%s' exactly as it was at the last Apply Code (from '%s')." % [node.name, script_path.get_file()])


# ─────────────────────────────────────────────────────────────────────────────
# Parsing helpers
# ─────────────────────────────────────────────────────────────────────────────

## Read a node's script from disk and return its generated block ("" when the
## node has no saved script or the script has no block). Shared by the sync
## and hash functions.
func _read_generated_block(node: Node) -> String:
	if not node or not node.get_script():
		return ""
	var script_path := str(node.get_script().resource_path)
	if script_path.is_empty() or not FileAccess.file_exists(script_path):
		return ""
	return _extract_generated_block(FileAccess.get_file_as_string(script_path))


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
			controller_info = _brick_info_from_meta(controllers[0], "Controller")
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


func _parse_chains(block: String) -> Array[Dictionary]:
	return _text_parser._parse_chains(block)


func _parse_sensor_segment(full_block: String, chain_name: String, segment: String) -> Dictionary:
	return _text_parser._parse_sensor_segment(full_block, chain_name, segment)


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
		"properties": meta.get("properties", {}) if meta.get("properties", {}) is Dictionary else {},
		# Lets Rebuild from Script keep the brick's existing graph node (id,
		# position, frame membership) instead of minting a new one.
		"graph_node_id": str(meta.get("graph_node_id", "")),
	}


func _detect_logic_mode(body: String) -> String:
	return _text_parser._detect_logic_mode(body)


func _detect_logic_modes(code: String) -> Array[String]:
	return _text_parser._detect_logic_modes(code)

func _detect_all_states(body: String) -> bool:
	return _text_parser._detect_all_states(body)


func _detect_state_id(body: String) -> String:
	return _text_parser._detect_state_id(body)


func _extract_actuator_properties(cls: String, act_block: String) -> Dictionary:
	return _text_parser._extract_actuator_properties(cls, act_block)


## Keep only properties the brick class actually has (its property definitions
## plus its default property keys). The generic and shared parsers recognise
## patterns such as find_child("X") or load("...") in any actuator, and
## without this filter those matches were written into bricks that have no
## such property. Unknown classes are passed through unchanged.
func _filter_to_declared_properties(cls: String, props: Dictionary) -> Dictionary:
	if props.is_empty():
		return props
	var allowed := _declared_property_names(cls)
	if allowed.is_empty():
		return props
	var filtered: Dictionary = {}
	for key in props:
		if allowed.has(str(key)):
			filtered[key] = props[key]
	return filtered


var _declared_property_cache: Dictionary = {}

func _declared_property_names(cls: String) -> Dictionary:
	if _declared_property_cache.has(cls):
		return _declared_property_cache[cls]
	var names: Dictionary = {}
	var script_path := BrickRegistry.get_script_path(cls)
	if not script_path.is_empty():
		var script = load(script_path)
		if script:
			var brick = script.new()
			for definition in brick.get_property_definitions():
				if definition is Dictionary and definition.has("name"):
					names[str(definition["name"])] = true
			for key in brick.properties:
				names[str(key)] = true
	_declared_property_cache[cls] = names
	return names


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
				"type": "Controller",
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

		_copy_graph_node_ids(sensors, sensor_infos)
		if not controller_info.is_empty():
			_copy_graph_node_ids(controllers, [controller_info])
		_copy_graph_node_ids(actuators, desc["actuator_classes"])

		chains.append({
			"name":        desc["name"],
			"sensors":     sensors,
			"controllers": controllers,
			"actuators":   actuators
		})

	return chains


func _copy_graph_node_ids(bricks: Array, infos: Array) -> void:
	for i in mini(bricks.size(), infos.size()):
		var graph_id := str(infos[i].get("graph_node_id", "")) if infos[i] is Dictionary else ""
		if not graph_id.is_empty():
			bricks[i]["graph_node_id"] = graph_id


# ─────────────────────────────────────────────────────────────────────────────
# Graph data builder
# ─────────────────────────────────────────────────────────────────────────────

## Build the logic_bricks_graph metadata dict.
## Layout: sensors column → controller column → actuators column
## When existing_graph is given, a brick whose graph_node_id matches an existing
## node of the same class keeps that node's id and position, so frames stay
## attached to the right bricks. New bricks get ids above every existing id,
## so they can never take over an old brick's frame membership.
func _build_graph_data(descs: Array[Dictionary], existing_graph: Dictionary = {}) -> Dictionary:
	var nodes:       Array = []
	var connections: Array = []
	var existing_nodes: Dictionary = {}
	var next_id: int = int(existing_graph.get("next_id", 0))
	for node_entry in existing_graph.get("nodes", []):
		if not (node_entry is Dictionary):
			continue
		var existing_id := str(node_entry.get("id", ""))
		existing_nodes[existing_id] = node_entry
		var suffix := existing_id.trim_prefix("brick_node_")
		if suffix != existing_id and suffix.is_valid_int():
			next_id = maxi(next_id, int(suffix) + 1)
	var used_ids: Dictionary = {}

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
			var sensor_info: Dictionary = sensors_info[s_i]
			var s_slot := _reuse_or_new_node(sensor_info, str(sensor_info["class"]), Vector2(COL_SENSOR, s_y), existing_nodes, used_ids, next_id)
			var s_id: String = s_slot["id"]
			next_id = s_slot["next_id"]
			nodes.append({
				"id":            s_id,
				"position":      s_slot["position"],
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
		var controller_info: Dictionary = desc.get("controller_meta", {})
		var ctrl_class := str(controller_info.get("class", "")) if not controller_info.is_empty() else ("ScriptController" if desc["is_script_ctrl"] else "Controller")
		var ctrl_slot := _reuse_or_new_node(controller_info, ctrl_class, Vector2(COL_CONTROLLER, ctrl_y), existing_nodes, used_ids, next_id)
		var ctrl_id: String = ctrl_slot["id"]
		next_id = ctrl_slot["next_id"]
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
			"position":      ctrl_slot["position"],
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
			var a_slot := _reuse_or_new_node(actuators_info[a_i], str(actuators_info[a_i]["class"]), Vector2(COL_ACTUATOR, a_y), existing_nodes, used_ids, next_id)
			var a_id: String = a_slot["id"]
			next_id = a_slot["next_id"]
			nodes.append({
				"id":            a_id,
				"position":      a_slot["position"],
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

	var graph := {
		"nodes":       nodes,
		"connections": connections,
		"next_id":     next_id
	}
	if existing_graph.has("connection_style"):
		graph["connection_style"] = existing_graph["connection_style"]
	return graph


## Pick the graph node for one brick: its existing node (same id, same class,
## not already taken) keeps id and position; otherwise a fresh id at the
## layout position. Returns {"id", "position", "next_id"}.
func _reuse_or_new_node(info: Dictionary, brick_class: String, layout_position: Vector2, existing_nodes: Dictionary, used_ids: Dictionary, next_id: int) -> Dictionary:
	var wanted := str(info.get("graph_node_id", ""))
	if not wanted.is_empty() and existing_nodes.has(wanted) and not used_ids.has(wanted):
		var existing: Dictionary = existing_nodes[wanted]
		if str(existing.get("brick_class", "")) == brick_class:
			used_ids[wanted] = true
			var pos = existing.get("position", layout_position)
			return {"id": wanted, "position": pos if pos is Vector2 else layout_position, "next_id": next_id}
	var fresh := "brick_node_%d" % next_id
	while existing_nodes.has(fresh) or used_ids.has(fresh):
		next_id += 1
		fresh = "brick_node_%d" % next_id
	used_ids[fresh] = true
	return {"id": fresh, "position": layout_position, "next_id": next_id + 1}


# ─────────────────────────────────────────────────────────────────────────────
# Utility
# ─────────────────────────────────────────────────────────────────────────────

func _copy_meta(node: Node, key: String, default_value):
	var value = node.get_meta(key, default_value)
	return value.duplicate(true) if value is Dictionary or value is Array else value


func _mark_scene_modified(node: Node) -> void:
	if panel and panel.editor_interface:
		panel.editor_interface.mark_scene_as_unsaved()


# ─────────────────────────────────────────────────────────────────────────────
# Two-way source synchronization
# ─────────────────────────────────────────────────────────────────────────────

## Pull edits made inside generated brick blocks back into the existing visual
## graph. Unlike Rebuild from Script, this never replaces graph topology, node
## positions, reroutes, or frames. It only updates properties that can be
## recovered from the edited GDScript.
func sync_from_script() -> bool:
	if not panel or not panel.current_node or not panel.current_node.get_script():
		return false
	var node: Node = panel.current_node
	var block := _read_generated_block(node)
	if block.is_empty():
		return false

	var records := _extract_sync_records(block)
	if records.is_empty():
		# Legacy generated source has no stable source-map blocks. Keep the old
		# recovery path available rather than risking the existing graph.
		return false
	if not node.has_meta("logic_bricks_graph"):
		return false

	var graph_data: Dictionary = node.get_meta("logic_bricks_graph").duplicate(true)
	var nodes: Array = graph_data.get("nodes", [])
	var by_id: Dictionary = {}
	for i in range(nodes.size()):
		var nd = nodes[i]
		if nd is Dictionary and not bool(nd.get("is_reroute", false)):
			by_id[str(nd.get("id", ""))] = i

	var changed := false
	var changed_properties: Dictionary = {}  # graph node id -> full properties
	for record in records:
		var meta: Dictionary = record.get("meta", {})
		var graph_id := str(meta.get("graph_node_id", ""))
		if graph_id.is_empty() or not by_id.has(graph_id):
			continue
		var index := int(by_id[graph_id])
		var node_data: Dictionary = nodes[index]
		var recovered := _recover_sync_properties(meta, str(record.get("code", "")), block, str(record.get("chain_name", "")))
		# Sensors and controllers go through the same check as actuators.
		recovered = _filter_to_declared_properties(str(meta.get("type", "")), recovered)
		if recovered.is_empty():
			continue
		var props: Dictionary = node_data.get("properties", {}).duplicate(true)
		var brick_changed := false
		for key in recovered:
			if not props.has(key) or props[key] != recovered[key]:
				props[key] = recovered[key]
				brick_changed = true
		if brick_changed:
			changed = true
			changed_properties[graph_id] = props
		node_data["properties"] = props
		nodes[index] = node_data

	if changed:
		# Write everything for this node before any await: the student may
		# select another node while the graph reloads, and the panel's graph
		# would then belong to that other node.
		graph_data["nodes"] = nodes
		node.set_meta("logic_bricks_graph", graph_data)
		_apply_properties_to_chain_meta(node, changed_properties)
		panel._mark_scene_modified()
	node.set_meta(SCRIPT_SYNC_HASH_META, block.sha256_text())

	if changed and panel.current_node == node:
		await panel._load_graph_from_metadata()
		if panel.current_node == node:
			panel._load_variables_from_metadata()
			panel._load_states_from_metadata(true)
			panel._frames_helper.load_frames_from_metadata(panel)
			await panel.get_tree().process_frame
		# Only read chains back from the panel while it still shows this node.
		if panel.current_node == node:
			panel._graph_helper.sync_graph_ui_to_bricks()
			var chains: Array = panel._graph_helper.extract_chains_from_graph(true)
			panel.manager.save_chains(node, chains)

	if changed:
		print("Logic Bricks: Synced edited generated code back into the brick graph for %s." % node.name)
	return true


## Update brick properties inside the node's saved chain metadata, matched by
## graph node id. This keeps the chains in step with the graph without going
## through the panel, so it is correct whichever node is selected.
func _apply_properties_to_chain_meta(node: Node, properties_by_id: Dictionary) -> void:
	if properties_by_id.is_empty() or not node.has_meta(panel.manager.METADATA_KEY):
		return
	var chains = node.get_meta(panel.manager.METADATA_KEY)
	if not (chains is Array):
		return
	chains = chains.duplicate(true)
	for chain in chains:
		if not (chain is Dictionary):
			continue
		for role in ["sensors", "controllers", "actuators"]:
			for brick in chain.get(role, []):
				if brick is Dictionary and properties_by_id.has(str(brick.get("graph_node_id", ""))):
					brick["properties"] = properties_by_id[str(brick["graph_node_id"])].duplicate(true)
	panel.manager.save_chains(node, chains)


## Called before Apply Code. If generated source changed since the last Apply,
## import recoverable edits first so Apply does not overwrite a student's code
## change before it has a chance to reach the brick graph.
func sync_from_script_if_changed() -> bool:
	if not panel or not panel.current_node or not panel.current_node.get_script():
		return false
	var node: Node = panel.current_node
	var block := _read_generated_block(node)
	if block.is_empty() or not block.contains(BRICK_BEGIN_PREFIX):
		return false
	var current_hash := block.sha256_text()
	var previous_hash := str(node.get_meta(SCRIPT_SYNC_HASH_META, ""))
	if previous_hash.is_empty():
		# First run after upgrading: establish a baseline. We do not assume old
		# generated code differs from the graph just because it predates hashing.
		node.set_meta(SCRIPT_SYNC_HASH_META, current_hash)
		return false
	if current_hash == previous_hash:
		return false
	return await sync_from_script()


func record_current_script_hash() -> void:
	if not panel or not panel.current_node or not panel.current_node.get_script():
		return
	var node: Node = panel.current_node
	var block := _read_generated_block(node)
	if not block.is_empty():
		node.set_meta(SCRIPT_SYNC_HASH_META, block.sha256_text())


func _extract_sync_records(block: String) -> Array:
	var records: Array = []
	var search_from := 0
	while true:
		var begin := block.find(BRICK_BEGIN_PREFIX, search_from)
		if begin == -1:
			break
		var payload_start := begin + BRICK_BEGIN_PREFIX.length()
		var payload_end := block.find("\n", payload_start)
		if payload_end == -1:
			break
		var payload := block.substr(payload_start, payload_end - payload_start).strip_edges()
		var raw := Marshalls.base64_to_raw(payload)
		var meta: Dictionary = {}
		if not raw.is_empty():
			var decoded = bytes_to_var(raw)
			if decoded is Dictionary:
				meta = decoded
		var graph_id := str(meta.get("graph_node_id", ""))
		var end_marker := BRICK_END_PREFIX + graph_id
		var end_pos := block.find(end_marker, payload_end + 1)
		if graph_id.is_empty() or end_pos == -1:
			search_from = payload_end + 1
			continue
		var code := block.substr(payload_end + 1, end_pos - (payload_end + 1))
		var chain_name := _chain_name_before(block, begin)
		records.append({"meta": meta, "code": code, "chain_name": chain_name})
		search_from = end_pos + end_marker.length()
	return records


func _chain_name_before(block: String, position: int) -> String:
	var prefix := block.substr(0, position)
	var marker := "func _logic_brick_"
	var func_pos := prefix.rfind(marker)
	if func_pos == -1:
		return ""
	var start := func_pos + marker.length()
	var end := prefix.find("(", start)
	return prefix.substr(start, end - start) if end > start else ""


func _recover_sync_properties(meta: Dictionary, code: String, full_block: String, chain_name: String) -> Dictionary:
	var role := str(meta.get("brick_role", ""))
	var cls := str(meta.get("type", ""))
	match role:
		"actuator":
			return _extract_actuator_properties(cls, code)
		"sensor":
			# Parse the edited code, not the embedded metadata snapshot. The class
			# remains anchored by the source-map record; only recoverable fields move.
			var parsed := _parse_sensor_segment(full_block, chain_name, code)
			return parsed.get("properties", {}) if parsed is Dictionary else {}
		"controller":
			var props: Dictionary = {}
			# Only import a mode change the student actually made. If the code
			# still fits the mode it was generated from, leave the mode alone:
			# one-input gates look the same in several modes (a NOT gate is
			# "not (s0)" for both NAND and NOR), so re-detecting would flip them.
			var generated_mode := str(meta.get("properties", {}).get("logic_mode", "and")).to_lower()
			var possible_modes := _detect_logic_modes(code)
			if not possible_modes.is_empty() and not possible_modes.has(generated_mode):
				props["logic_mode"] = possible_modes[0]
			if "_logic_brick_chain_state_matches" in code:
				props["all_states"] = _detect_all_states(code)
				props["state_id"] = _detect_state_id(code)
			return props
	return {}
