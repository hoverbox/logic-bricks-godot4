@tool
extends RefCounted

## Manages logic brick chains and generates GDScript code

const LogicBrick = preload("res://addons/logic_bricks/core/logic_brick.gd")
const VariableUtils = preload("res://addons/logic_bricks/core/logic_brick_variable_utils.gd")
const BrickRegistry = preload("res://addons/logic_bricks/core/brick_registry.gd")

## Metadata key for storing brick chains
const METADATA_KEY = "logic_bricks"

## Code generation markers
const CODE_START_MARKER = "# === LOGIC BRICKS START ==="
const CODE_END_MARKER = "# === LOGIC BRICKS END ==="

## Reference to editor interface for marking scenes as modified
var editor_interface = null


## Get all brick chains from a node's metadata
func get_chains(node: Node) -> Array:
	if node.has_meta(METADATA_KEY):
		var data = node.get_meta(METADATA_KEY)
		if data is Array:
			return data.duplicate()
	return []


## Save brick chains to node metadata
func save_chains(node: Node, chains: Array) -> void:
	node.set_meta(METADATA_KEY, chains)

	# Mark the scene as modified so changes are saved
	_mark_scene_modified(node)


## Regenerate the script for a node based on its brick chains
func regenerate_script(node: Node, variables_code: String = "") -> void:
	var chains = get_chains(node)

	# If no variables code was passed, generate it from node metadata
	if variables_code.is_empty() and node.has_meta("logic_bricks_variables"):
		variables_code = _get_variables_code_from_metadata(node)

	# Generate the new logic bricks code
	var generated_code = _generate_code_for_chains(node, chains, variables_code)

	# Only regenerate for nodes that already have a user-assigned script.
	# This avoids silently attaching scripts to the wrong node when students
	# accidentally build logic on an unscripted selection.
	if not node.get_script():
		push_warning("Logic Bricks: Node '%s' has no script. Add a script manually before applying Logic Bricks code." % node.name)
		return

	var script_path = node.get_script().resource_path

	# Read existing script
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		push_error("Logic Bricks: Could not open script file: " + script_path)
		return

	var existing_code = file.get_as_text()
	file.close()

	# Replace code between markers
	var new_code = _replace_generated_code(existing_code, generated_code, node)

	# Write the updated script
	file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		push_error("Logic Bricks: Could not write script file: " + script_path)
		return

	file.store_string(new_code)
	file.close()



## Generate code for all chains
## Generate variables code from node metadata (same format as panel's get_variables_code)
func _read_global_vars_from_script() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var script_path = "res://addons/logic_bricks/global_vars.gd"
	if not FileAccess.file_exists(script_path):
		return result

	# Use the GDScript API instead of hand-parsing the source text.
	# get_script_property_list() is authoritative — it handles typed arrays,
	# multi-line declarations, comments, and any other syntax the parser accepts.
	var script = load(script_path)
	if not script:
		return result

	# get_script_property_list() returns the properties defined directly on the
	# script (not inherited ones), exactly what we need for global_vars.gd.
	for prop in script.get_script_property_list():
		var prop_name: String = prop["name"]
		if prop_name.is_empty() or prop_name.begins_with("_") or prop_name.begins_with("@"):
			continue
		# Map Godot Variant type integers to the string type names the rest of the
		# addon uses (e.g. "int", "float", "bool", "String").
		var type_int: int = prop["type"]
		var type_str: String = VariableUtils.gdscript_type_name_from_variant_type(type_int)
		if type_str.is_empty():
			continue  # Skip non-primitive types (Object refs, Arrays, etc.)
		# Read the current default value from a temporary instance so we get the
		# actual initialised value, not just a text representation.
		var tmp = script.new()
		var value = tmp.get(prop_name)
		result.append({
			"name": prop_name,
			"type": type_str,
			"value": str(value) if value != null else VariableUtils.get_default_value_for_variable_type(type_str)
		})
	return result


func _get_selected_global_vars(node: Node) -> Array[Dictionary]:
	var usage_map: Dictionary = {}
	if node.has_meta("logic_bricks_global_usage"):
		var usage = node.get_meta("logic_bricks_global_usage")
		if usage is Dictionary:
			usage_map = usage
	if usage_map.is_empty():
		return []

	var globals_data: Array[Dictionary] = []
	var scene_root = node.get_tree().edited_scene_root if node.get_tree() else null
	if scene_root and scene_root.has_meta("logic_bricks_global_vars"):
		var meta_globals = scene_root.get_meta("logic_bricks_global_vars")
		if meta_globals is Array:
			for var_data in meta_globals:
				globals_data.append(var_data.duplicate())
	if globals_data.is_empty():
		globals_data = _read_global_vars_from_script()

	var selected: Array[Dictionary] = []
	for var_data in globals_data:
		var gid = str(var_data.get("id", ""))
		if not gid.is_empty() and bool(usage_map.get(gid, false)):
			selected.append(var_data)
	return selected


func _get_variables_code_from_metadata(node: Node) -> String:
	var variables_data = []
	if node.has_meta("logic_bricks_variables"):
		variables_data = node.get_meta("logic_bricks_variables")

	var used_globals = _get_selected_global_vars(node)
	var lines: Array[String] = []
	var has_any_vars = false
	for vd in variables_data:
		if not vd.get("global", false) and not vd.get("name", "").is_empty():
			has_any_vars = true
			break
	if not has_any_vars and not used_globals.is_empty():
		has_any_vars = true
	if not has_any_vars:
		return ""
	lines.append("# Variables")

	for var_data in variables_data:
		var var_name = var_data.get("name", "")
		var var_type = VariableUtils.normalize_type(str(var_data.get("type", "float")), "float")
		var var_value = VariableUtils.to_gdscript_value_literal(var_data.get("value", VariableUtils.get_default_value_for_variable_type(var_type)), var_type)
		var exported = var_data.get("exported", false)
		var is_global = var_data.get("global", false)

		if var_name.is_empty():
			continue

		var use_min   = var_data.get("use_min", false)
		var min_val   = var_data.get("min_val", "0")
		var use_max   = var_data.get("use_max", false)
		var max_val   = var_data.get("max_val", "100")
		var has_range = (var_type in ["int", "float"]) and (use_min or use_max)

		if is_global:
			continue
		elif has_range and exported:
			var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
			var hi = max_val if use_max else ("9999999"  if var_type == "int" else "9999999.0")
			lines.append("@export_range(%s, %s) var %s: %s = %s" % [lo, hi, var_name, var_type, var_value])
		elif has_range and not exported:
			var clamp_fn = "clampi" if var_type == "int" else "clampf"
			var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
			var hi = max_val if use_max else ("9999999"  if var_type == "int" else "9999999.0")
			lines.append("var _%s_raw: %s = %s" % [var_name, var_type, var_value])
			lines.append("var %s: %s:" % [var_name, var_type])
			lines.append("\tget: return _%s_raw" % var_name)
			lines.append("\tset(val): _%s_raw = %s(val, %s, %s)" % [var_name, clamp_fn, lo, hi])
		else:
			var declaration = ""
			if exported:
				declaration += "@export "
			declaration += "var %s: %s = %s" % [var_name, var_type, var_value]
			lines.append(declaration)

	for var_data in used_globals:
		var var_name = var_data.get("name", "")
		var var_type = VariableUtils.normalize_type(str(var_data.get("type", "int")), "int")
		var use_min = var_data.get("use_min", false)
		var min_val = var_data.get("min_val", "0")
		var use_max = var_data.get("use_max", false)
		var max_val = var_data.get("max_val", "100")
		if var_name.is_empty():
			continue
		lines.append("var %s: %s:" % [var_name, var_type])
		lines.append("	get:")
		lines.append("		var _gv = get_node_or_null(\"/root/GlobalVars\")")
		lines.append("		return _gv.%s if _gv else null" % var_name)
		lines.append("	set(val):")
		lines.append("		var _gv = get_node_or_null(\"/root/GlobalVars\")")
		if var_type in ["int", "float"] and (use_min or use_max):
			var clamp_fn = "clampi" if var_type == "int" else "clampf"
			var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
			var hi = max_val if use_max else ("9999999" if var_type == "int" else "9999999.0")
			lines.append("		if _gv: _gv.%s = %s(val, %s, %s)" % [var_name, clamp_fn, lo, hi])
		else:
			lines.append("		if _gv: _gv.%s = val" % var_name)

	lines.append("")  # Empty line after variables
	return "\n".join(lines)


func _generate_code_for_chains(node: Node, chains: Array, variables_code: String = "") -> String:
	var code_lines: Array[String] = []

	# Normalize every chain name to its sanitized form before any code is emitted.
	# This guards against hand-edited scene metadata, old saves, or two display names
	# that collapse to the same identifier after sanitization (e.g. "my chain" / "my-chain"
	# both become "my_chain"). We resolve collisions by appending a numeric suffix, mirroring
	# _generate_unique_chain_name, but only touching duplicates — stable names stay stable.
	var seen_sanitized: Dictionary = {}
	for chain in chains:
		var sanitized = _sanitize_chain_name(chain["name"])
		if seen_sanitized.has(sanitized):
			var counter: int = seen_sanitized[sanitized]
			counter += 1
			seen_sanitized[sanitized] = counter
			sanitized = "%s_%d" % [sanitized, counter]
		else:
			seen_sanitized[sanitized] = 0
		chain["name"] = sanitized

	# Add variables code first (if any)
	if not variables_code.is_empty():
		code_lines.append(variables_code)

	var states_data: Array = []
	if node.has_meta("logic_bricks_states"):
		var saved_states = node.get_meta("logic_bricks_states")
		if saved_states is Array:
			for state_data in saved_states:
				states_data.append(state_data.duplicate(true))

	# First pass: collect any member variables from all sensors AND actuators across all chains.
	# These need to live at script scope (above the functions) because they persist across frames.
	# Also collect per-chain member vars so we can reset them on state entry.
	var member_vars: Array[String] = []
	var chain_member_vars: Dictionary = {}  # state_id -> Array[String] of reset lines
	var chain_setup_calls: Dictionary = {}  # state_id -> Array[String] of setup func calls (re-run on state enter)
	var ready_code: Array[String] = []
	var pre_process_code: Array[String] = []
	var post_process_code: Array[String] = []
	var physics_pre_process_code: Array[String] = []
	var physics_post_process_code: Array[String] = []
	var extra_methods: Array[String] = []
	var input_handler_bodies: Array[String] = []  # Body lines for shared _input()
	var message_handler_calls: Array[String] = []  # Call lines for shared _on_message_received()

	# Check if any chain uses an ActuatorSensor — only then do we need the flags dict
	# and the per-frame clear(). Generating it for every named actuator regardless
	# emits an unused member variable and a .clear() call every frame.
	var has_actuator_sensor = false
	for chain in chains:
		for sensor_data in _collect_all_sensors_for_chain(chain):
			if sensor_data.get("type", "") == "ActuatorSensor":
				has_actuator_sensor = true
				break
		if has_actuator_sensor:
			break
	if has_actuator_sensor:
		member_vars.append("var _actuator_active_flags: Dictionary = {}  # Actuator Sensor: tracks which actuators fired this frame")
		pre_process_code.append("_actuator_active_flags.clear()")
		physics_pre_process_code.append("_actuator_active_flags.clear()")
	for chain in chains:
		var this_chain_resets: Array[String] = []
		var chain_needs_physics_process := _chain_needs_physics_process(chain)

		# Check which state this chain belongs to. Member vars for state-specific
		# chains must reset when that state is entered, not when a chain-name-like
		# id is entered. The runtime calls _on_logic_brick_state_enter("state_...").
		# Older code incorrectly keyed resets by chain["name"], so checks like
		# state_id == "_10" never matched actual ids such as "state_2".
		var is_all_states_chain = false
		var chain_state_id := ""
		var controllers = chain.get("controllers", [])
		if controllers.size() > 0:
			var ctrl_props: Dictionary = controllers[0].get("properties", {})
			is_all_states_chain = bool(ctrl_props.get("all_states", false))
			chain_state_id = str(ctrl_props.get("state_id", "")).strip_edges()
			# Fall back to instantiated properties for older/oddly-shaped metadata.
			if chain_state_id.is_empty():
				var ctrl_brick = _instantiate_brick(controllers[0])
				if ctrl_brick:
					is_all_states_chain = bool(ctrl_brick.properties.get("all_states", is_all_states_chain))
					chain_state_id = str(ctrl_brick.properties.get("state_id", "")).strip_edges()

		# Collect from direct sensors and sensors nested inside controller inputs.
		# Each sensor gets its own code namespace so duplicated sensors do not
		# generate duplicate member/local variable names.
		for sensor_entry in _collect_sensor_generation_entries_for_chain(chain):
			var sensor_data: Dictionary = sensor_entry.get("data", {})
			var sensor_namespace: String = _sensor_code_namespace(chain["name"], str(sensor_entry.get("fallback_var", "sensor_active")))
			var sensor_brick = _instantiate_brick(sensor_data)
			if sensor_brick:
				var generated = sensor_brick.generate_code(node, sensor_namespace)
				if generated.has("member_vars"):
					_append_member_var_items(member_vars, generated["member_vars"])
					# Only collect resets for state-specific chains
					if not is_all_states_chain:
						for mv in generated["member_vars"]:
							var reset = _member_var_to_reset(mv)
							if not reset.is_empty() and reset not in this_chain_resets:
								this_chain_resets.append(reset)
					# Track setup helpers (e.g. _setup_collision_sensor_<chain>) so
					# _on_logic_brick_state_enter can re-invoke them after state transitions,
					# re-establishing Area3D refs and signal connections that would otherwise
					# be lost if the area var was nulled on state entry.
					if not is_all_states_chain:
						for mv in generated["member_vars"]:
							if mv.begins_with("func _setup_"):
								var func_name = mv.replace("func ", "").split("(")[0].strip_edges()
								var call_line = "%s()" % func_name
								if not chain_state_id.is_empty():
									if not chain_setup_calls.has(chain_state_id):
										chain_setup_calls[chain_state_id] = []
									if call_line not in chain_setup_calls[chain_state_id]:
										chain_setup_calls[chain_state_id].append(call_line)
				if generated.has("ready_code"):
					for rc in generated["ready_code"]:
						if rc not in ready_code:
							ready_code.append(rc)
				if generated.has("pre_process_code"):
					var _target_pre_process := physics_pre_process_code if chain_needs_physics_process else pre_process_code
					for pc in generated["pre_process_code"]:
						if pc not in _target_pre_process:
							_target_pre_process.append(pc)
				if generated.has("post_process_code"):
					var _target_post_process := physics_post_process_code if chain_needs_physics_process else post_process_code
					for pc in generated["post_process_code"]:
						if pc not in _target_post_process:
							_target_post_process.append(pc)
				if generated.has("methods"):
					for method in generated["methods"]:
						if method.begins_with("input_handler::"):
							var _body = method.substr(len("input_handler::"))
							if _body not in input_handler_bodies:
								input_handler_bodies.append(_body)
						elif method not in extra_methods:
							extra_methods.append(method)
				if generated.has("message_handler_calls"):
					for call_line in generated["message_handler_calls"]:
						if call_line not in message_handler_calls:
							message_handler_calls.append(call_line)

		# Collect from controllers — ScriptController emits a cached instance member var
		# and ready_code to load it once. Standard controllers emit nothing here.
		for controller_data in chain.get("controllers", []):
			var controller_brick = _instantiate_brick(controller_data)
			if controller_brick:
				var generated = controller_brick.generate_code(node, chain["name"])
				if generated.has("member_vars"):
					_append_member_var_items(member_vars, generated["member_vars"])
				if generated.has("ready_code"):
					for rc in generated["ready_code"]:
						if rc not in ready_code:
							ready_code.append(rc)

		# Collect from actuators (they can also have member vars like RNG instances).
		# Use a per-actuator code namespace so multiple actuators of the same type in
		# one chain do not generate duplicate member variable or helper names.
		var actuator_list = chain.get("actuators", [])
		for actuator_index in range(actuator_list.size()):
			var actuator_data = actuator_list[actuator_index]
			var actuator_brick = _instantiate_brick(actuator_data)
			if actuator_brick:
				var actuator_code_name := "%s_%d" % [chain["name"], actuator_index]
				var generated = actuator_brick.generate_code(node, actuator_code_name)
				if generated.has("member_vars"):
					_append_member_var_items(member_vars, generated["member_vars"])
					# Only collect resets for state-specific chains
					if not is_all_states_chain:
						for mv in generated["member_vars"]:
							var reset = _member_var_to_reset(mv)
							if not reset.is_empty() and reset not in this_chain_resets:
								this_chain_resets.append(reset)
				if generated.has("ready_code"):
					for rc in generated["ready_code"]:
						if rc not in ready_code:
							ready_code.append(rc)
				if generated.has("pre_process_code"):
					var _target_pre_process := physics_pre_process_code if chain_needs_physics_process else pre_process_code
					for pc in generated["pre_process_code"]:
						if pc not in _target_pre_process:
							_target_pre_process.append(pc)
				if generated.has("post_process_code"):
					var _target_post_process := physics_post_process_code if chain_needs_physics_process else post_process_code
					for pc in generated["post_process_code"]:
						if pc not in _target_post_process:
							_target_post_process.append(pc)
				if generated.has("methods"):
					for method in generated["methods"]:
						if method.begins_with("input_handler::"):
							var _body = method.substr(len("input_handler::"))
							if _body not in input_handler_bodies:
								input_handler_bodies.append(_body)
						elif method not in extra_methods:
							extra_methods.append(method)

		if this_chain_resets.size() > 0 and not chain_state_id.is_empty():
			if not chain_member_vars.has(chain_state_id):
				chain_member_vars[chain_state_id] = []
			for _reset_line in this_chain_resets:
				if _reset_line not in chain_member_vars[chain_state_id]:
					chain_member_vars[chain_state_id].append(_reset_line)

	if member_vars.size() > 0:
		for mv in member_vars:
			code_lines.append(mv)
		code_lines.append("")

	code_lines.append("")

	# Generate _ready() function
	# Collect export validation checks from member vars
	var export_checks: Array[String] = []
	# Primitive types that should NOT get null-checks
	var primitive_types = ["float", "int", "bool", "String", "Vector2", "Vector3", "Color", "Basis", "Transform3D"]
	for mv in member_vars:
		if mv.begins_with("@export var "):
			# Extract variable name and type: "@export var _cam: Camera3D" -> name="_cam", type="Camera3D"
			var parts = mv.replace("@export var ", "").split(":")
			if parts.size() >= 2:
				var var_name = parts[0].strip_edges()
				var var_type = parts[1].strip_edges()
				# Skip null-checks for primitive types — they always have a value
				if var_type in primitive_types:
					continue
				var label = var_name
				export_checks.append("if not %s:" % var_name)
				export_checks.append("\tpush_warning(\"Logic Bricks: '%s' is not assigned! Drag a node into the inspector.\")" % label)

	if ready_code.size() > 0 or export_checks.size() > 0 or true:
		code_lines.append("func _ready() -> void:")
		code_lines.append("	_logic_brick_init_states()")
		# Defer export validation by one frame so all nodes are in the scene tree.
		# Accessing @export node references before the tree is ready triggers
		# "Cannot get path of node as it is not in a scene tree" errors.
		if export_checks.size() > 0:
			code_lines.append("\tawait get_tree().process_frame")
			for ec in export_checks:
				# Use is_instance_valid instead of plain truthiness —
				# a plain "if not node:" can also trigger the path error.
				var safe_ec = ec.replace("if not ", "if not is_instance_valid(").replace(":", "):")
				if "is_instance_valid" in safe_ec:
					code_lines.append("\t" + safe_ec)
				else:
					code_lines.append("\t" + ec)
		# Other ready code runs immediately (not deferred)
		for rc in ready_code:
			code_lines.append("\t" + rc)
		code_lines.append("")

	# Runtime state
	code_lines.append("var _logic_brick_state: String = \"\"")
	code_lines.append("")
	code_lines.append("func _logic_brick_init_states() -> void:")
	if states_data.is_empty():
		code_lines.append("	_logic_brick_state = \"\"")
	else:
		code_lines.append("	_logic_brick_state = %s" % _gdscript_string_literal(str(states_data[0].get("id", ""))))
	code_lines.append("")
	code_lines.append("func _logic_brick_chain_state_matches(state_id: String, all_states: bool = false) -> bool:")
	code_lines.append("	if all_states:")
	code_lines.append("		return true")
	code_lines.append("	if state_id.is_empty():")
	code_lines.append("		return true")
	code_lines.append("	return _logic_brick_state == state_id")
	code_lines.append("")
	code_lines.append("func _logic_brick_get_state_signature() -> String:")
	code_lines.append("	return _logic_brick_state")
	code_lines.append("")
	code_lines.append("func _logic_brick_set_state(new_state: String) -> void:")
	code_lines.append("\tif _logic_brick_state == new_state:")
	code_lines.append("\t\treturn")
	code_lines.append("\t_logic_brick_state = new_state")
	code_lines.append("\t_on_logic_brick_state_enter(new_state)")
	code_lines.append("")
	code_lines.append("func _on_logic_brick_state_enter(state_id: String) -> void:")
	var _has_state_body := false
	for _chain_name in chain_member_vars:
		var _resets: Array = chain_member_vars[_chain_name]
		var _setups: Array = chain_setup_calls.get(_chain_name, [])
		if _resets.is_empty() and _setups.is_empty():
			continue
		if not _has_state_body:
			_has_state_body = true
		code_lines.append("\tif state_id == %s:" % _gdscript_string_literal(_chain_name))
		for _reset_line in _resets:
			code_lines.append("\t\t" + _reset_line)
		for _setup_call in _setups:
			code_lines.append("\t\t" + _setup_call)
	if not _has_state_body:
		code_lines.append("\tpass")
	code_lines.append("")


	# Pre-generate all chain functions — this is the single source of truth for
	# whether a chain produces valid output. Calls are only emitted if the function
	# is non-empty, preventing mismatches between call sites and definitions.
	var generated_chain_functions: Dictionary = {}  # chain_name -> code string
	for chain in chains:
		# Warn early if the chain mixes physics and non-physics actuators. The whole
		# chain runs in _physics_process when any physics actuator is present, so
		# non-physics actuators (animation, UI, etc.) will run at the wrong time.
		if _chain_has_mixed_actuators(chain):
			push_warning(
				"Logic Bricks: Chain '%s' on node '%s' mixes physics movement with timing-sensitive actuators. The entire chain will run in _physics_process, which may cause incorrect timing for animation, UI, audio, or other time-based actuators. Split only those timing-sensitive actuators into a separate chain." \
				% [chain["name"], node.name]
			)
		var chain_code = _generate_chain_function(node, chain, has_actuator_sensor)
		if not chain_code.is_empty():
			generated_chain_functions[chain["name"]] = chain_code

	# Determine if we need process or physics process
	var has_process = false
	var has_physics_process = false

	for chain in chains:
		if not generated_chain_functions.has(chain["name"]):
			continue
		var needs_physics = _chain_needs_physics_process(chain)
		if needs_physics:
			has_physics_process = true
		else:
			has_process = true

	# Generate process functions
	if has_process:
		code_lines.append("func _process(delta: float) -> void:")
		if pre_process_code.size() > 0:
			for pc in pre_process_code:
				code_lines.append("	" + pc)
			code_lines.append("	")
		var has_any_process_chain = false
		for chain in chains:
			if generated_chain_functions.has(chain["name"]) and not _chain_needs_physics_process(chain) and _chain_is_state_transition_only(chain):
				code_lines.append("	_logic_brick_%s(delta)" % chain["name"])
				has_any_process_chain = true
		for chain in chains:
			if generated_chain_functions.has(chain["name"]) and not _chain_needs_physics_process(chain) and not _chain_is_state_transition_only(chain):
				code_lines.append("	_logic_brick_%s(delta)" % chain["name"])
				has_any_process_chain = true
		if not has_any_process_chain:
			code_lines.append("	pass")
		if post_process_code.size() > 0:
			code_lines.append("	")
			for pc in post_process_code:
				code_lines.append("	" + pc)
		code_lines.append("")

	if has_physics_process:
		code_lines.append("func _physics_process(delta: float) -> void:")
		if physics_pre_process_code.size() > 0:
			for pc in physics_pre_process_code:
				code_lines.append("	" + pc)
			code_lines.append("	")
		var has_any_physics_chain = false
		# Do not run non-physics state-transition-only chains again here. They are
		# already emitted in _process(); emitting them in both loops makes delay
		# sensors advance twice and can switch states in the same frame.
		for chain in chains:
			if generated_chain_functions.has(chain["name"]) and _chain_needs_physics_process(chain):
				code_lines.append("	_logic_brick_%s(delta)" % chain["name"])
				has_any_physics_chain = true
		if not has_any_physics_chain:
			code_lines.append("	pass")
		if physics_post_process_code.size() > 0:
			code_lines.append("	")
			for pc in physics_post_process_code:
				code_lines.append("	" + pc)
		code_lines.append("")

	# Emit assembled _input() if any sensors contributed handler bodies
	if input_handler_bodies.size() > 0:
		code_lines.append("func _input(event: InputEvent) -> void:")
		for _body_block in input_handler_bodies:
			for _body_line in _body_block.split("\n"):
				code_lines.append(_body_line)
		code_lines.append("")

	# Emit single _on_message_received dispatcher that forwards to each chain's
	# scoped handler. This avoids duplicate-function errors when multiple Message
	# Sensors are present on the same node.
	if message_handler_calls.size() > 0:
		code_lines.append("func _on_message_received(subject: String, body: String, sender: Node) -> void:")
		for call_line in message_handler_calls:
			code_lines.append("\t" + call_line)
		code_lines.append("")

	# Append generated chain functions
	for chain in chains:
		if generated_chain_functions.has(chain["name"]):
			code_lines.append(generated_chain_functions[chain["name"]])
			code_lines.append("")

	# Append extra methods (e.g. message handlers)
	for method in extra_methods:
		code_lines.append(method)
		code_lines.append("")

	return "\n".join(code_lines)


## Generate code for a single chain
func _generate_chain_function(node: Node, chain: Dictionary, has_actuator_sensor: bool = false) -> String:
	# Always sanitize at generation time — guards against hand-edited scene metadata
	# or chains saved by older versions of the addon before sanitization was enforced.
	var chain_name = _sanitize_chain_name(chain["name"])
	var sensors = chain.get("sensors", [])
	var controller_inputs = chain.get("controller_inputs", [])
	var controller_data = null
	var controllers = chain.get("controllers", [])
	if controllers.size() > 0:
		controller_data = controllers[0]
	else:
		# Legacy: try singular key — only present in data saved by very old versions of the addon.
		# Remove this fallback once the migration window has passed.
		controller_data = chain.get("controller", null)
	var actuators = chain.get("actuators", [])

	var lines: Array[String] = []
	lines.append("func _logic_brick_%s(_delta: float) -> void:" % chain_name)

	var is_script_controller = controller_data != null and controller_data.get("type", "") == "ScriptController"
	if (sensors.is_empty() and controller_inputs.is_empty()) or not controller_data:
		return ""  # Incomplete chain — skip entirely, generate nothing
	if not is_script_controller and actuators.is_empty():
		return ""  # Standard chains need at least one actuator

	# Collect @export var node names from this chain's bricks so we can
	# guard against freed instances (e.g. object pool recycling nodes).
	# Primitive types (float, int, bool, etc.) are skipped — is_instance_valid
	# always returns false for them, which would incorrectly kill the function.
	var _guard_primitive_types = ["float", "int", "bool", "String", "Vector2", "Vector3", "Color", "Basis", "Transform3D"]
	var _chain_export_vars: Array[String] = []
	for _sensor_entry in _collect_sensor_generation_entries_for_chain(chain):
		var _sd: Dictionary = _sensor_entry.get("data", {})
		var _sensor_namespace: String = _sensor_code_namespace(chain_name, str(_sensor_entry.get("fallback_var", "sensor_active")))
		var _sb = _instantiate_brick(_sd)
		if _sb:
			var _sg = _sb.generate_code(node, _sensor_namespace)
			for _mv in _sg.get("member_vars", []):
				if _mv.begins_with("@export var "):
					var _parts = _mv.replace("@export var ", "").split(":")
					var _vname = _parts[0].strip_edges()
					var _vtype = _parts[1].strip_edges().split(" ")[0] if _parts.size() > 1 else ""
					if _vtype in _guard_primitive_types:
						continue
					if _vname not in _chain_export_vars:
						_chain_export_vars.append(_vname)
	for _actuator_index in range(actuators.size()):
		var _ad = actuators[_actuator_index]
		var _ab = _instantiate_brick(_ad)
		if _ab:
			# Must match the namespace used when member vars and actuator code are generated.
			# Otherwise guards can reference an export var that was never declared,
			# e.g. _screen_shake_<chain> instead of _screen_shake_<chain>_0.
			var _actuator_code_name := "%s_%d" % [chain_name, _actuator_index]
			var _ag = _ab.generate_code(node, _actuator_code_name)
			for _mv in _ag.get("member_vars", []):
				if _mv.begins_with("@export var "):
					var _parts = _mv.replace("@export var ", "").split(":")
					var _vname = _parts[0].strip_edges()
					var _vtype = _parts[1].strip_edges().split(" ")[0] if _parts.size() > 1 else ""
					if _vtype in _guard_primitive_types:
						continue
					if _vname not in _chain_export_vars:
						_chain_export_vars.append(_vname)
	if _chain_export_vars.size() > 0:
		lines.append("\t# Guard: skip if any assigned node has been freed (e.g. by object pool)")
		for _ev in _chain_export_vars:
			lines.append("\tif %s != null and not is_instance_valid(%s): return" % [_ev, _ev])

	var state_id := ""
	var all_states := false
	if controller_data:
		state_id = str(controller_data.get("properties", {}).get("state_id", "")).strip_edges()
		all_states = bool(controller_data.get("properties", {}).get("all_states", false))
	var state_condition := "_logic_brick_chain_state_matches(%s, %s)" % [_gdscript_string_literal(state_id), "true" if all_states else "false"]

	# Gate the whole chain by state before evaluating sensors.
	# This prevents inactive-state sensors such as Delay from counting down
	# immediately at game start and firing later without the intended trigger.
	lines.append("\tvar _chain_state_active = " + state_condition)
	lines.append("\tif not _chain_state_active:")
	lines.append("\t\treturn")
	lines.append("\t")

	# Generate sensor code for ALL direct and nested controller inputs.
	lines.append("\t# Sensor and controller input evaluation")
	var sensor_vars = []
	var sensor_index = 0

	for sensor_data in sensors:
		var sensor_var = _emit_sensor_eval(lines, node, chain_name, sensor_data, "sensor_%d_active" % sensor_index)
		if not sensor_var.is_empty():
			sensor_vars.append(sensor_var)
			sensor_index += 1

	var nested_index = 0
	for nested_controller in controller_inputs:
		var nested_var = _emit_nested_controller_eval(lines, node, chain_name, nested_controller, "controller_%d" % nested_index)
		if not nested_var.is_empty():
			sensor_vars.append(nested_var)
		nested_index += 1

	# Generate controller code
	lines.append("\t")
	lines.append("\t# Controller logic")
	if controller_data:
		var controller_brick = _instantiate_brick(controller_data)
		if controller_brick:
			# ── Script Controller ───────────────────────────────────────────────
			if controller_data["type"] == "ScriptController":
				var condition = controller_brick.get_condition(sensor_vars)
				condition = "_chain_state_active and (" + condition + ")" if sensor_vars.size() > 0 else "_chain_state_active"
				lines.append("\tvar controller_active = " + condition)
				lines.append("\t")
				lines.append("\t# Script Controller — custom code")
				lines.append("\tif controller_active:")
				lines.append(controller_brick.get_script_body(chain_name))
				if has_actuator_sensor:
					lines.append("\t")
					lines.append("\t# Actuator Sensor flags")
					for actuator_data in actuators:
						var inst_name = actuator_data.get("instance_name", "")
						if not inst_name.is_empty():
							lines.append("\tif controller_active:")
							lines.append("\t\t_actuator_active_flags[\"%s\"] = true" % inst_name)
							lines.append("\telse:")
							lines.append("\t\t_actuator_active_flags[\"%s\"] = false" % inst_name)
				return "\n".join(lines)

			# ── Standard Controller ─────────────────────────────────────────────
			# Determine logic mode from properties, fall back to class name for legacy bricks
			var logic_mode = "and"
			if controller_brick.properties.has("logic_mode"):
				logic_mode = controller_brick.properties.get("logic_mode", "and")
				if typeof(logic_mode) == TYPE_STRING:
					logic_mode = logic_mode.to_lower()
			elif controller_data["type"] == "ANDController":
				logic_mode = "and"

			if sensor_vars.size() > 0:
				var condition = _controller_condition_from_vars(logic_mode, sensor_vars)
				condition = state_condition + " and (" + condition + ")"
				lines.append("\tvar controller_active = " + condition)
			else:
				lines.append("\tvar controller_active = " + state_condition)
	else:
		# No controller - default to AND logic plus state gating
		if sensor_vars.size() > 0:
			var condition = " and ".join(sensor_vars)
			condition = state_condition + " and (" + condition + ")"
			lines.append("\tvar controller_active = " + condition)
		else:
			lines.append("\tvar controller_active = " + state_condition)

	# Generate actuator code for ALL actuators
	lines.append("\t")
	lines.append("\t# Actuator execution")
	lines.append("\tif controller_active:")

	if actuators.is_empty():
		return ""  # No actuators — incomplete chain
	else:
		var actuator_lines_written = 0
		for actuator_index in range(actuators.size()):
			var actuator_data = actuators[actuator_index]
			var actuator_brick = _instantiate_brick(actuator_data)
			if actuator_brick:
				var actuator_code_name := "%s_%d" % [chain_name, actuator_index]
				var generated = actuator_brick.generate_code(node, actuator_code_name)
				if generated.has("actuator_code"):
					var actuator_code = str(generated["actuator_code"])
					actuator_code = _uniquify_generated_local_vars(actuator_code, actuator_code_name)
					var code_lines_array = actuator_code.split("\n")
					var wrote_actuator_scope := false
					for code_line in code_lines_array:
						if code_line.strip_edges() != "":
							if not wrote_actuator_scope:
								lines.append("\t\tif true:")
								wrote_actuator_scope = true
							lines.append("\t\t\t" + code_line)
							actuator_lines_written += 1

					var debug_code = actuator_brick.get_debug_code()
					if not debug_code.is_empty():
						if not wrote_actuator_scope:
							lines.append("\t\tif true:")
							wrote_actuator_scope = true
						lines.append("\t\t\t" + debug_code)
						actuator_lines_written += 1

				# inactive_code: code to emit in the else branch (when controller is NOT active).
				# Used by actuators that need to reset state every frame regardless of activation
				# (e.g. AnimationTree conditions, which are consumed by the state machine and must
				# be driven continuously to avoid one-shot race conditions).
				if generated.has("inactive_code") and not str(generated["inactive_code"]).is_empty():
					var inactive = str(generated["inactive_code"])
					inactive = _uniquify_generated_local_vars(inactive, actuator_code_name + "_inactive")
					lines.append("\telse:")
					lines.append("\t\tif true:")
					var inactive_lines = inactive.split("\n")
					for il in inactive_lines:
						if il.strip_edges() != "":
							lines.append("\t\t\t" + il)

		# If all actuators produced empty code, treat as incomplete — skip entirely
		if actuator_lines_written == 0:
			return ""

	# Write active flags for any named actuators so the Actuator Sensor can read them.
	# Flags are written both when active (true) and when not (false) so the sensor
	# always has an up-to-date value regardless of which branch ran.
	if has_actuator_sensor:
		lines.append("\t")
		lines.append("\t# Actuator Sensor flags")
		for actuator_data in actuators:
			var inst_name = actuator_data.get("instance_name", "")
			if not inst_name.is_empty():
				lines.append("\tif controller_active:")
				lines.append("\t\t_actuator_active_flags[\"%s\"] = true" % inst_name)
				lines.append("\telse:")
				lines.append("\t\t_actuator_active_flags[\"%s\"] = false" % inst_name)

	return "\n".join(lines)




func _emit_sensor_eval(lines: Array[String], node: Node, chain_name: String, sensor_data: Dictionary, fallback_var: String) -> String:
	var sensor_brick = _instantiate_brick(sensor_data)
	if not sensor_brick:
		return ""
	var sensor_namespace: String = _sensor_code_namespace(chain_name, fallback_var)
	var generated = sensor_brick.generate_code(node, sensor_namespace)
	if not generated.has("sensor_code"):
		return ""

	var instance_name = sensor_data.get("instance_name", "")
	var sensor_var = fallback_var
	if not instance_name.is_empty():
		# Include the fallback namespace so duplicated/renamed sensors with the same
		# display instance name cannot redeclare the same generated variable.
		sensor_var = _sanitize_chain_name("%s_%s" % [instance_name, fallback_var])

	var sensor_code = str(generated["sensor_code"])
	# First replace the canonical sensor result variable with the public
	# variable name that controller logic will read. Then uniquify only
	# helper locals. Doing this in the opposite order creates unused locals
	# like `sensor_active_sensor_0_active` and leaves `sensor_0_active` false.
	var _rename_rx = RegEx.new()
	_rename_rx.compile("\\bsensor_active\\b")
	sensor_code = _rename_rx.sub(sensor_code, sensor_var, true)
	sensor_code = _uniquify_generated_local_vars(sensor_code, sensor_var, [sensor_var])

	# Predeclare the result outside the isolation block so controller logic can read it.
	# The generated brick code runs inside an `if true` block to prevent duplicated
	# sensors from redeclaring helper locals in the same function scope.
	lines.append("\tvar %s = false" % sensor_var)
	lines.append("\tif true:")
	var first_decl_rx = RegEx.new()
	first_decl_rx.compile("^([\\t ]*)var\\s+" + sensor_var + "(?:\\s*:[^=]+)?\\s*(?::=|=)\\s*(.*)$")
	for code_line in sensor_code.split("\n"):
		if code_line.strip_edges() != "":
			# The result variable is predeclared outside the isolation block so
			# controller code can read it. Convert the brick's first declaration
			# into an assignment to avoid shadowing and UNUSED_VARIABLE errors.
			var isolated_line = first_decl_rx.sub(code_line, "$1" + sensor_var + " = $2", false)
			lines.append("\t\t" + isolated_line)

	var debug_code = sensor_brick.get_debug_code()
	if not debug_code.is_empty():
		lines.append("\t" + debug_code)
	return sensor_var


func _emit_nested_controller_eval(lines: Array[String], node: Node, chain_name: String, controller_tree: Dictionary, prefix: String) -> String:
	if bool(controller_tree.get("cycle", false)):
		var cycle_var = "%s_cycle_active" % prefix
		lines.append("\tvar %s = false  # Controller chain cycle ignored" % cycle_var)
		return cycle_var

	var input_vars: Array[String] = []
	var sensor_index := 0
	for sensor_data in controller_tree.get("sensors", []):
		var sensor_var = _emit_sensor_eval(lines, node, chain_name, sensor_data, "%s_sensor_%d_active" % [prefix, sensor_index])
		if not sensor_var.is_empty():
			input_vars.append(sensor_var)
		sensor_index += 1

	var nested_index := 0
	for nested_tree in controller_tree.get("controller_inputs", []):
		var nested_var = _emit_nested_controller_eval(lines, node, chain_name, nested_tree, "%s_controller_%d" % [prefix, nested_index])
		if not nested_var.is_empty():
			input_vars.append(nested_var)
		nested_index += 1

	var controller_data = controller_tree.get("controller", null)
	var out_var = "%s_active" % prefix
	if controller_data == null:
		lines.append("\tvar %s = false" % out_var)
		return out_var

	var controller_brick = _instantiate_brick(controller_data)
	if controller_brick and controller_data.get("type", "") == "ScriptController":
		lines.append("\tvar %s = %s" % [out_var, controller_brick.get_condition(input_vars) if input_vars.size() > 0 else "true"])
		return out_var

	var logic_mode = "and"
	if controller_brick and controller_brick.properties.has("logic_mode"):
		logic_mode = str(controller_brick.properties.get("logic_mode", "and")).to_lower()
	var condition = _controller_condition_from_vars(logic_mode, input_vars) if input_vars.size() > 0 else "true"

	var state_id = str(controller_data.get("properties", {}).get("state_id", "")).strip_edges()
	var all_states = bool(controller_data.get("properties", {}).get("all_states", false))
	if not state_id.is_empty() or all_states:
		condition = "_logic_brick_chain_state_matches(%s, %s) and (%s)" % [_gdscript_string_literal(state_id), "true" if all_states else "false", condition]

	lines.append("\tvar %s = %s" % [out_var, condition])
	return out_var


func _controller_condition_from_vars(logic_mode: String, input_vars: Array) -> String:
	if input_vars.is_empty():
		return "true"
	match logic_mode:
		"or":
			return " or ".join(input_vars)
		"nand":
			return "not (" + " and ".join(input_vars) + ")"
		"nor":
			return "not (" + " or ".join(input_vars) + ")"
		"xor":
			var int_vars: Array[String] = []
			for sv in input_vars:
				int_vars.append("int(%s)" % sv)
			return "(" + " + ".join(int_vars) + ") == 1"
		_:
			return " and ".join(input_vars)


func _sensor_code_namespace(chain_name: String, fallback_var: String) -> String:
	var code_namespace := "%s_%s" % [chain_name, fallback_var]
	if code_namespace.ends_with("_active"):
		code_namespace = code_namespace.substr(0, code_namespace.length() - len("_active"))
	return _sanitize_chain_name(code_namespace)


func _uniquify_generated_local_vars(code: String, suffix: String, keep_names: Array[String] = []) -> String:
	# Some brick generators emit generic local names such as _node_name_<chain>.
	# Duplicated bricks can then create the same local variable more than once in
	# a generated function. GDScript does not allow redeclaring a local name in
	# the same function scope, even inside nested if blocks, so rewrite generated
	# local vars with a per-brick suffix before inserting the code.
	var safe_suffix := _sanitize_chain_name(suffix)
	if safe_suffix.is_empty():
		return code

	var declarations := RegEx.new()
	declarations.compile("\\bvar\\s+([A-Za-z_][A-Za-z0-9_]*)")

	var replacements: Dictionary = {}
	for result in declarations.search_all(code):
		var local_name := result.get_string(1)
		if local_name in keep_names:
			continue
		if local_name.ends_with("_" + safe_suffix):
			continue
		replacements[local_name] = "%s_%s" % [local_name, safe_suffix]

	var rewritten := code
	for local_name in replacements.keys():
		var rx := RegEx.new()
		rx.compile("\\b" + String(local_name) + "\\b")
		rewritten = rx.sub(rewritten, String(replacements[local_name]), true)
	return rewritten


func _collect_sensor_generation_entries_for_chain(chain: Dictionary) -> Array:
	var entries: Array = []
	var sensors: Array = chain.get("sensors", [])
	for sensor_index in range(sensors.size()):
		entries.append({
			"data": sensors[sensor_index],
			"fallback_var": "sensor_%d_active" % sensor_index
		})
	_collect_sensor_generation_entries_from_controller_inputs(chain.get("controller_inputs", []), entries, "controller")
	return entries


func _collect_sensor_generation_entries_from_controller_inputs(controller_inputs: Array, entries: Array, prefix: String) -> void:
	for controller_index in range(controller_inputs.size()):
		var controller_tree: Dictionary = controller_inputs[controller_index]
		var controller_prefix := "%s_%d" % [prefix, controller_index]
		var sensors: Array = controller_tree.get("sensors", [])
		for sensor_index in range(sensors.size()):
			entries.append({
				"data": sensors[sensor_index],
				"fallback_var": "%s_sensor_%d_active" % [controller_prefix, sensor_index]
			})
		_collect_sensor_generation_entries_from_controller_inputs(controller_tree.get("controller_inputs", []), entries, "%s_controller" % controller_prefix)


func _collect_all_sensors_for_chain(chain: Dictionary) -> Array:
	var sensors: Array = []
	for sensor_data in chain.get("sensors", []):
		sensors.append(sensor_data)
	_collect_sensors_from_controller_inputs(chain.get("controller_inputs", []), sensors)
	return sensors


func _collect_sensors_from_controller_inputs(controller_inputs: Array, sensors: Array) -> void:
	for controller_tree in controller_inputs:
		for sensor_data in controller_tree.get("sensors", []):
			sensors.append(sensor_data)
		_collect_sensors_from_controller_inputs(controller_tree.get("controller_inputs", []), sensors)

func _gdscript_string_literal(value: String) -> String:
	return '"%s"' % value.c_escape()

func _append_member_var_items(target: Array[String], items: Array) -> void:
	# member_vars can contain both plain top-level declarations and entire helper
	# functions flattened into line arrays. Deduplicating them line-by-line corrupts
	# function bodies when two helpers share common lines. Keep function blocks intact
	# and dedupe whole helper functions by signature so repeated bricks can safely
	# share helpers such as _find_anim_player() and _find_sprite_node().
	var existing_function_signatures: Dictionary = {}
	for target_line in target:
		var target_text := str(target_line)
		if target_text.begins_with("func ") or target_text.begins_with("static func "):
			existing_function_signatures[_function_signature_key(target_text)] = true

	var i := 0
	while i < items.size():
		var line := str(items[i])
		if line.begins_with("func ") or line.begins_with("static func "):
			var block: Array[String] = [line]
			i += 1
			while i < items.size():
				var next_line := str(items[i])
				if next_line.begins_with("	") or next_line.is_empty():
					block.append(next_line)
					i += 1
					continue
				break
			var signature_key := _function_signature_key(line)
			if not existing_function_signatures.has(signature_key):
				for block_line in block:
					target.append(block_line)
				existing_function_signatures[signature_key] = true
			continue
		if line not in target:
			target.append(line)
		i += 1


func _function_signature_key(signature_line: String) -> String:
	var text := signature_line.strip_edges()
	var paren_index := text.find("(")
	if paren_index == -1:
		return text
	return text.substr(0, paren_index)


## Check if a chain is complete enough to generate code for
## Requires at least one sensor and one controller.
## ScriptController chains do not require actuators; all others do.
func _chain_is_complete(chain: Dictionary) -> bool:
	if chain.get("sensors", []).is_empty() and chain.get("controller_inputs", []).is_empty():
		return false

	var controllers = chain.get("controllers", [])
	# Legacy: try singular key — only present in data saved by very old versions of the addon.
	# Remove this fallback once the migration window has passed.
	if controllers.is_empty():
		if not chain.has("controller") or chain.get("controller") == null:
			return false

	# ScriptController chains don't require actuators
	var is_script_controller = false
	if controllers.size() > 0:
		is_script_controller = controllers[0].get("type", "") == "ScriptController"

	if not is_script_controller and chain.get("actuators", []).is_empty():
		return false

	return true


## Check if a chain needs physics process (has force/torque actuators)
func _chain_needs_physics_process(chain: Dictionary) -> bool:
	# Physics-dependent sensors must also run in _physics_process.
	# Example: PhysicsSensor uses is_on_floor()/is_on_wall()/is_on_ceiling(),
	# which are only reliable after physics movement has been resolved.
	var sensors = _collect_all_sensors_for_chain(chain)
	for sensor_data in sensors:
		var sensor_type = sensor_data.get("type", "")
		if sensor_type in ["PhysicsSensor"]:
			return true

	var actuators = chain.get("actuators", [])
	for actuator_data in actuators:
		var brick_type = actuator_data.get("type", "")
		if brick_type in ["ForceActuator", "TorqueActuator", "ImpulseActuator", "LinearVelocityActuator", "CharacterActuator", "GravityActuator", "JumpActuator", "WaypointPathActuator"]:
			return true
		if brick_type == "MotionActuator":
			var props = actuator_data.get("properties", {})
			var motion_type = str(props.get("motion_type", "location")).to_lower().replace(" ", "_")
			var movement_method = str(props.get("movement_method", "character_velocity")).to_lower().replace(" ", "_")
			var call_move_and_slide = props.get("call_move_and_slide", false) == true
			if motion_type == "location" or movement_method == "character_velocity" or call_move_and_slide:
				return true
	return false


func _chain_is_state_transition_only(chain: Dictionary) -> bool:
	var actuators = chain.get("actuators", [])
	if actuators.is_empty():
		return false
	for actuator_data in actuators:
		if actuator_data.get("type", "") != "StateActuator":
			return false
	return true

## Returns true if this chain mixes physics actuators with timing-sensitive
## non-physics actuators. Physics-compatible actuators such as LookAtMovement
## are allowed in the same chain, because they should run after the character
## velocity has been resolved in _physics_process.
func _chain_has_mixed_actuators(chain: Dictionary) -> bool:
	var actuators = chain.get("actuators", [])
	var has_physics = false
	var has_timing_sensitive_non_physics = false
	for actuator_data in actuators:
		var brick_type = actuator_data.get("type", "")
		if _logic_brick_actuator_requires_physics(actuator_data):
			has_physics = true
		elif _logic_brick_actuator_is_timing_sensitive_non_physics(brick_type):
			has_timing_sensitive_non_physics = true
	return has_physics and has_timing_sensitive_non_physics


func _logic_brick_actuator_requires_physics(actuator_data: Dictionary) -> bool:
	var brick_type = actuator_data.get("type", "")
	if brick_type in ["ForceActuator", "TorqueActuator", "ImpulseActuator", "LinearVelocityActuator", "CharacterActuator", "GravityActuator", "JumpActuator", "WaypointPathActuator"]:
		return true
	if brick_type == "MotionActuator":
		var props = actuator_data.get("properties", {})
		var motion_type = str(props.get("motion_type", "location")).to_lower().replace(" ", "_")
		var movement_method = str(props.get("movement_method", "character_velocity")).to_lower().replace(" ", "_")
		var call_move_and_slide = props.get("call_move_and_slide", false) == true
		return motion_type == "location" or movement_method == "character_velocity" or call_move_and_slide
	return false


func _logic_brick_actuator_is_timing_sensitive_non_physics(brick_type: String) -> bool:
	# These are the actuators most likely to behave incorrectly if forced into
	# _physics_process by a movement chain. Other actuators, including
	# LookAtMovementActuator, are safe/useful in physics chains.
	return brick_type in [
		"AnimationActuator",
		"AnimationTreeActuator",
		"Audio2DActuator",
		"CameraZoomActuator",
		"EnvironmentActuator",
		"GameActuator",
		"HitStopActuator",
		"MusicActuator",
		"ObjectFlashActuator",
		"ObjectShakeActuator",
		"ProgressBarActuator",
		"ScreenShakeActuator",
		"SpriteFramesActuator",
		"TextActuator",
		"TimerActuator",
		"UIActuator"
	]


## Instantiate a brick from serialized data
func _instantiate_brick(brick_data: Dictionary) -> LogicBrick:
	var brick_type = brick_data.get("type", "")
	var brick_script_path = _get_brick_script_path(brick_type)

	if brick_script_path.is_empty():
		push_error("Logic Bricks: Unknown brick type: " + brick_type)
		return null

	var brick_script = load(brick_script_path)
	if not brick_script:
		push_error("Logic Bricks: Could not load brick script: " + brick_script_path)
		return null

	var brick = brick_script.new()
	brick.deserialize(brick_data)
	return brick


## Get the script path for a brick type.
## Brick scripts are discovered automatically by BrickRegistry.
func _get_brick_script_path(brick_type: String) -> String:
	return BrickRegistry.get_script_path(brick_type)


## Replace the code between markers in the existing script
func _replace_generated_code(existing_code: String, generated_code: String, node: Node) -> String:
	var start_pos = existing_code.find(CODE_START_MARKER)
	var end_pos = existing_code.find(CODE_END_MARKER)

	if start_pos == -1 or end_pos == -1:
		# Markers don't exist, add them
		return _create_script_with_markers(existing_code, generated_code, node)

	# Calculate positions correctly
	# We want to keep everything BEFORE the start marker
	var before = existing_code.substr(0, start_pos)

	# We want to keep everything AFTER the end marker (including the marker itself on its own line)
	# end_pos points to the start of CODE_END_MARKER, so we add its length to skip past it
	var after_marker_pos = end_pos + CODE_END_MARKER.length()
	var after = existing_code.substr(after_marker_pos)

	# Build the new code with proper formatting
	# Keep the start marker on its own line, add generated code, then the end marker
	var new_code = before + CODE_START_MARKER + "\n"

	# Add the generated code (it already has proper indentation)
	if not generated_code.is_empty():
		new_code += generated_code
		if not generated_code.ends_with("\n"):
			new_code += "\n"

	# Add the end marker
	new_code += CODE_END_MARKER + after

	return new_code


## Create a new script with markers
func _create_script_with_markers(existing_code: String, generated_code: String, node: Node) -> String:
	var node_class = node.get_class()

	# If there's existing code without markers, preserve it
	if not existing_code.is_empty() and not existing_code.begins_with("extends"):
		# Has existing code but no extends, add extends
		existing_code = "extends %s\n\n%s" % [node_class, existing_code]
	elif existing_code.is_empty():
		# No existing code, create basic script
		existing_code = "extends %s\n" % node_class

	# Insert markers before the first real function definition.
	# We scan line-by-line so that "func" appearing inside comments (#) or
	# string literals does not trigger a false match.
	var insert_pos = existing_code.length()
	var lines_scan = existing_code.split("\n")
	var char_offset = 0
	for line in lines_scan:
		var stripped = line.strip_edges()
		# A real func declaration: starts with "func " or "@annotation\nfunc"
		# Here we only need to catch bare top-level func lines.
		if stripped.begins_with("func ") or stripped.begins_with("static func "):
			insert_pos = char_offset
			break
		char_offset += line.length() + 1  # +1 for the "\n" that split consumed

	var before = existing_code.substr(0, insert_pos)
	var after = existing_code.substr(insert_pos)

	# Build with proper newline handling
	var marked_code = before
	if not before.ends_with("\n"):
		marked_code += "\n"

	marked_code += "\n" + CODE_START_MARKER + "\n"
	marked_code += generated_code

	if not generated_code.ends_with("\n"):
		marked_code += "\n"

	marked_code += CODE_END_MARKER + "\n"

	if not after.is_empty():
		if not after.begins_with("\n"):
			marked_code += "\n"
		marked_code += after

	return marked_code


## Create a new script file for a node
func _create_new_script(node: Node) -> String:
	var tree := node.get_tree()
	var scene_root := tree.edited_scene_root if tree else null
	if not scene_root or scene_root.scene_file_path.is_empty():
		push_error("Logic Bricks: Scene must be saved before a script can be created.")
		return ""

	var scene_path = scene_root.scene_file_path
	var scene_dir = scene_path.get_base_dir()
	var node_name = node.name.to_snake_case()
	var script_path = "%s/%s.gd" % [scene_dir, node_name]

	# Ensure unique filename
	var counter = 1
	while FileAccess.file_exists(script_path):
		script_path = "%s/%s_%d.gd" % [scene_dir, node_name, counter]
		counter += 1

	# Create basic script
	var node_class = node.get_class()
	var basic_script = "extends %s\n" % node_class

	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		push_error("Logic Bricks: Could not create script file: " + script_path)
		return ""
	file.store_string(basic_script)
	file.close()

	return script_path


## Generate a unique chain name
func _generate_unique_chain_name(existing_chains: Array) -> String:
	var counter = 0
	var name = "chain_%d" % counter

	while _chain_name_exists(existing_chains, name):
		counter += 1
		name = "chain_%d" % counter

	return name


## Check if a chain name already exists
func _chain_name_exists(chains: Array, name: String) -> bool:
	for chain in chains:
		if chain["name"] == name:
			return true
	return false


## Sanitize chain name for use in function names
func _sanitize_chain_name(name: String) -> String:
	# Replace invalid characters with underscores
	var sanitized = ""
	for i in range(name.length()):
		var c = name[i]
		if c.is_valid_identifier() or (i > 0 and c.is_valid_int()):
			sanitized += c
		else:
			sanitized += "_"

	# Ensure it starts with a letter or underscore
	if sanitized.is_empty() or sanitized[0].is_valid_int():
		sanitized = "_" + sanitized

	return sanitized


## Mark the scene as modified so changes are saved
func _mark_scene_modified(node: Node) -> void:
	if not editor_interface:
		return

	# Mark the currently edited scene as unsaved
	# This is the correct way to tell Godot the scene needs saving
	editor_interface.mark_scene_as_unsaved()


## Parse a member variable declaration into a reset statement.
## e.g. "var _delay_elapsed__27: float = 0.0"  ->  "_delay_elapsed__27 = 0.0"
## e.g. "var _on_ground: bool = false"          ->  "_on_ground = false"
## Returns empty string for @export vars or declarations without a default value.
func _member_var_to_reset(member_var_line: String) -> String:
	# Skip exported vars — those are set by the user in the inspector, not reset on state entry
	if member_var_line.begins_with("@export"):
		return ""

	# Must start with "var "
	if not member_var_line.begins_with("var "):
		return ""

	# Skip object pool vars — pools are built once in _ready() and must survive
	# state transitions. Resetting them would empty the pool on the first frame.
	# _pools_*        — the Array-of-Arrays holding live instances
	# _pool_scene_*   — the preloaded PackedScene resources (singular, e.g. _pool_scene_foo_0)
	# _pool_scenes_*  — the PackedScene registry array used by _pool_grow_*
	# _pool_cap_*     — per-sub-pool capacity tracker used by _pool_grow_*
	var after_var = member_var_line.substr(4)  # strip "var "

	# Skip shared CharacterBody runtime state. These values are initialized in
	# _ready() and maintained by Character/Jump actuators across frames. Resetting
	# them on state entry breaks common state flows such as: press jump -> enter
	# jump state -> JumpActuator fires. In that case _max_jumps/_jumps_remaining
	# were being reset to 0 before the jump could execute.
	var protected_runtime_prefixes = [
		"_logic_brick_character_",
		"_on_ground",
		"_moving_platform_",
		"_inherited_platform_velocity",
		"_logic_brick_external_motion_",
		"_logic_brick_pre_slide_velocity",
		"_jumps_remaining",
		"_max_jumps",
	]
	for protected_prefix in protected_runtime_prefixes:
		if after_var.begins_with(protected_prefix):
			return ""
	if after_var.begins_with("_pools_") or after_var.begins_with("_pool_scene_") \
			or after_var.begins_with("_pool_scenes_") or after_var.begins_with("_pool_cap_") \
			or after_var.begins_with("_pool_timers_"):
		return ""

	# Skip music shared state — players are built once in _ready() and must survive
	# state transitions. Resetting them would empty the array on the first frame,
	# silencing music before the Set brick gets a chance to play anything.
	if after_var.begins_with("_music_players") or after_var.begins_with("_music_current") \
			or after_var.begins_with("_music_crossfading") or after_var.begins_with("_music_initialized"):
		return ""

	# Skip any var typed as PackedScene — these are preloaded resources, not runtime state
	if ": PackedScene" in member_var_line:
		return ""

	# Skip Modulate Actuator target color vars — these persist the lerp destination
	# across frames and must not be reset on state entry or the transition never completes.
	if after_var.contains("_target_color"):
		return ""

	# Check there's a "=" to split on
	var eq_pos = member_var_line.find("=")
	if eq_pos == -1:
		return ""

	# Extract default value (trim trailing comments)
	var default_val = member_var_line.substr(eq_pos + 1).strip_edges()
	var comment_pos = default_val.find("  #")
	if comment_pos == -1:
		comment_pos = default_val.find("\t#")
	if comment_pos != -1:
		default_val = default_val.substr(0, comment_pos).strip_edges()

	# Extract variable name: "var _foo: float = ..." or "var _foo = ..."
	var colon_pos = after_var.find(":")
	var var_name = ""
	if colon_pos != -1:
		var_name = after_var.substr(0, colon_pos).strip_edges()
	else:
		var space_pos = after_var.find(" ")
		var_name = after_var.substr(0, space_pos if space_pos != -1 else after_var.length()).strip_edges()

	if var_name.is_empty() or default_val.is_empty():
		return ""

	return "%s = %s" % [var_name, default_val]
