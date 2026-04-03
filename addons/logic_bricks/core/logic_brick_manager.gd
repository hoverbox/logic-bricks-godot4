@tool
extends RefCounted

## Manages logic brick chains and generates GDScript code

const LogicBrick = preload("res://addons/logic_bricks/core/logic_brick.gd")

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


## Add a new chain to the node
func add_chain(node: Node, chain_name: String = "") -> Dictionary:
	var chains = get_chains(node)
	
	# Generate unique name if not provided
	if chain_name.is_empty():
		chain_name = _generate_unique_chain_name(chains)
	else:
		chain_name = _sanitize_chain_name(chain_name)
	
	var new_chain = {
		"name": chain_name,
		"bricks": []
	}
	
	chains.append(new_chain)
	save_chains(node, chains)
	regenerate_script(node)
	
	return new_chain


## Remove a chain by index
func remove_chain(node: Node, chain_index: int) -> void:
	var chains = get_chains(node)
	if chain_index >= 0 and chain_index < chains.size():
		chains.remove_at(chain_index)
		save_chains(node, chains)
		regenerate_script(node)


## Rename a chain
func rename_chain(node: Node, chain_index: int, new_name: String) -> void:
	var chains = get_chains(node)
	if chain_index >= 0 and chain_index < chains.size():
		chains[chain_index]["name"] = _sanitize_chain_name(new_name)
		save_chains(node, chains)
		regenerate_script(node)


## Add a brick to a chain
func add_brick_to_chain(node: Node, chain_index: int, brick: LogicBrick) -> void:
	var chains = get_chains(node)
	if chain_index >= 0 and chain_index < chains.size():
		chains[chain_index]["bricks"].append(brick.serialize())
		save_chains(node, chains)
		regenerate_script(node)


## Remove a brick from a chain
func remove_brick_from_chain(node: Node, chain_index: int, brick_index: int) -> void:
	var chains = get_chains(node)
	if chain_index >= 0 and chain_index < chains.size():
		var bricks = chains[chain_index]["bricks"]
		if brick_index >= 0 and brick_index < bricks.size():
			bricks.remove_at(brick_index)
			save_chains(node, chains)
			regenerate_script(node)


## Update a brick's properties
func update_brick_properties(node: Node, chain_index: int, brick_index: int, properties: Dictionary) -> void:
	var chains = get_chains(node)
	if chain_index >= 0 and chain_index < chains.size():
		var bricks = chains[chain_index]["bricks"]
		if brick_index >= 0 and brick_index < bricks.size():
			bricks[brick_index]["properties"] = properties.duplicate()
			save_chains(node, chains)
			regenerate_script(node)


## Regenerate the script for a node based on its brick chains
func regenerate_script(node: Node, variables_code: String = "") -> void:
	var chains = get_chains(node)
	
	# If no variables code was passed, generate it from node metadata
	if variables_code.is_empty() and node.has_meta("logic_bricks_variables"):
		variables_code = _get_variables_code_from_metadata(node)
	
	# Generate the new logic bricks code
	var generated_code = _generate_code_for_chains(node, chains, variables_code)
	
	# Get or create the script
	var script_path = ""
	if node.get_script():
		script_path = node.get_script().resource_path
	else:
		script_path = _create_new_script(node)
	
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
	
	#print("Logic Bricks: Script regenerated at: " + script_path)


## Generate code for all chains
## Generate variables code from node metadata (same format as panel's get_variables_code)
func _get_variables_code_from_metadata(node: Node) -> String:
	if not node.has_meta("logic_bricks_variables"):
		return ""
	
	var variables_data = node.get_meta("logic_bricks_variables")
	if variables_data.is_empty():
		return ""
	
	var lines: Array[String] = []
	lines.append("# Variables")
	
	for var_data in variables_data:
		var var_name = var_data.get("name", "")
		var var_type = var_data.get("type", "float")
		var var_value = var_data.get("value", "0.0")
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
			lines.append("var %s: %s:" % [var_name, var_type])
			lines.append("\tget: return GlobalVars.%s" % var_name)
			if has_range:
				var clamp_fn = "clampi" if var_type == "int" else "clampf"
				var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
				var hi = max_val if use_max else ("9999999"  if var_type == "int" else "9999999.0")
				lines.append("\tset(val): GlobalVars.%s = %s(val, %s, %s)" % [var_name, clamp_fn, lo, hi])
			else:
				lines.append("\tset(val): GlobalVars.%s = val" % var_name)
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
	
	lines.append("")  # Empty line after variables
	return "\n".join(lines)


func _generate_code_for_chains(node: Node, chains: Array, variables_code: String = "") -> String:
	var code_lines: Array[String] = []
	
	# Add variables code first (if any)
	if not variables_code.is_empty():
		code_lines.append(variables_code)
	
	# First pass: collect any member variables from all sensors AND actuators across all chains.
	# These need to live at script scope (above the functions) because they persist across frames.
	# Also collect per-chain member vars so we can reset them on state entry.
	var member_vars: Array[String] = []
	var chain_member_vars: Dictionary = {}  # chain_name -> Array[String] of reset lines
	var ready_code: Array[String] = []
	var pre_process_code: Array[String] = []
	var post_process_code: Array[String] = []
	var extra_methods: Array[String] = []
	var input_handler_bodies: Array[String] = []  # Body lines for shared _input()
	
	# Check if any actuator has an instance name — if so, we need the flags dict
	# and must clear it at the start of every frame so stale values don't linger.
	var has_named_actuators = false
	for chain in chains:
		for actuator_data in chain.get("actuators", []):
			if not actuator_data.get("instance_name", "").is_empty():
				has_named_actuators = true
				break
		if has_named_actuators:
			break
	if has_named_actuators:
		member_vars.append("var _actuator_active_flags: Dictionary = {}  # Actuator Sensor: tracks which actuators fired this frame")
		pre_process_code.append("_actuator_active_flags.clear()")
	for chain in chains:
		var this_chain_resets: Array[String] = []
		
		# Check if this chain is an all-states chain — if so, its member vars
		# should NOT be reset on state entry (they need to persist across states)
		var is_all_states_chain = false
		var controllers = chain.get("controllers", [])
		if controllers.size() > 0:
			var ctrl_brick = _instantiate_brick(controllers[0])
			if ctrl_brick and ctrl_brick.properties.get("all_states", false):
				is_all_states_chain = true
		
		# Collect from sensors
		for sensor_data in chain.get("sensors", []):
			var sensor_brick = _instantiate_brick(sensor_data)
			if sensor_brick:
				var generated = sensor_brick.generate_code(node, chain["name"])
				if generated.has("member_vars"):
					for mv in generated["member_vars"]:
						if mv not in member_vars:
							member_vars.append(mv)
						# Only collect resets for state-specific chains
						if not is_all_states_chain:
							var reset = _member_var_to_reset(mv)
							if not reset.is_empty() and reset not in this_chain_resets:
								this_chain_resets.append(reset)
				if generated.has("ready_code"):
					for rc in generated["ready_code"]:
						ready_code.append(rc)
				if generated.has("pre_process_code"):
					for pc in generated["pre_process_code"]:
						if pc not in pre_process_code:
							pre_process_code.append(pc)
				if generated.has("post_process_code"):
					for pc in generated["post_process_code"]:
						if pc not in post_process_code:
							post_process_code.append(pc)
				if generated.has("methods"):
					for method in generated["methods"]:
						if method.begins_with("input_handler::"):
							var _body = method.substr(len("input_handler::"))
							if _body not in input_handler_bodies:
								input_handler_bodies.append(_body)
						elif method not in extra_methods:
							extra_methods.append(method)
		
		# Collect from actuators (they can also have member vars like RNG instances)
		for actuator_data in chain.get("actuators", []):
			var actuator_brick = _instantiate_brick(actuator_data)
			if actuator_brick:
				var generated = actuator_brick.generate_code(node, chain["name"])
				if generated.has("member_vars"):
					for mv in generated["member_vars"]:
						if mv not in member_vars:
							member_vars.append(mv)
						# Only collect resets for state-specific chains
						if not is_all_states_chain:
							var reset = _member_var_to_reset(mv)
							if not reset.is_empty() and reset not in this_chain_resets:
								this_chain_resets.append(reset)
				if generated.has("ready_code"):
					for rc in generated["ready_code"]:
						ready_code.append(rc)
				if generated.has("pre_process_code"):
					for pc in generated["pre_process_code"]:
						if pc not in pre_process_code:
							pre_process_code.append(pc)
				if generated.has("post_process_code"):
					for pc in generated["post_process_code"]:
						if pc not in post_process_code:
							post_process_code.append(pc)
				if generated.has("methods"):
					for method in generated["methods"]:
						if method.begins_with("input_handler::"):
							var _body = method.substr(len("input_handler::"))
							if _body not in input_handler_bodies:
								input_handler_bodies.append(_body)
						elif method not in extra_methods:
							extra_methods.append(method)
		
		if this_chain_resets.size() > 0:
			chain_member_vars[chain["name"]] = this_chain_resets
	
	if member_vars.size() > 0:
		for mv in member_vars:
			code_lines.append(mv)
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
	
	if ready_code.size() > 0 or export_checks.size() > 0:
		code_lines.append("func _ready() -> void:")
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
	
	# Add state variable and previous-state tracker for reset-on-enter
	code_lines.append("# Logic brick state (1-30)")
	code_lines.append("var _logic_brick_state: int = 1")
	code_lines.append("var _logic_brick_prev_state: int = -1  # Used to detect state transitions")
	code_lines.append("")
	
	# Group chains by state
	# Chains with all_states=true are stored in all_state_chains and run in every state
	var chains_by_state: Dictionary = {}
	var all_state_chains: Array = []  # Chains that run in every state
	for chain in chains:
		var state = 1  # Default state
		var is_all_states = false
		
		# Get state from controller
		var controllers = chain.get("controllers", [])
		if controllers.size() > 0:
			var controller_data = controllers[0]
			var controller_brick = _instantiate_brick(controller_data)
			if controller_brick:
				if controller_brick.properties.get("all_states", false):
					is_all_states = true
				elif controller_brick.properties.has("state"):
					state = int(controller_brick.properties.get("state", 1))
		
		if is_all_states:
			all_state_chains.append(chain)
		else:
			if not chains_by_state.has(state):
				chains_by_state[state] = []
			chains_by_state[state].append(chain)
	
	# Pre-generate all chain functions — this is the single source of truth for
	# whether a chain produces valid output. Calls are only emitted if the function
	# is non-empty, preventing mismatches between call sites and definitions.
	var generated_chain_functions: Dictionary = {}  # chain_name -> code string
	for chain in chains:
		var chain_code = _generate_chain_function(node, chain)
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

	# Generate process functions with state matching
	if has_process:
		code_lines.append("func _process(delta: float) -> void:")
		
		# State transition detection — reset sensor vars for chains in the newly entered state
		code_lines.append("\tif _logic_brick_state != _logic_brick_prev_state:")
		code_lines.append("\t\t_on_logic_brick_state_enter(_logic_brick_state)")
		code_lines.append("\t\t_logic_brick_prev_state = _logic_brick_state")
		code_lines.append("\t")
		
		# Pre-process code runs before any chains (e.g., reset horizontal velocity)
		if pre_process_code.size() > 0:
			for pc in pre_process_code:
				code_lines.append("\t" + pc)
			code_lines.append("\t")
		
		# All-state chains run unconditionally, before the state match
		if all_state_chains.size() > 0:
			code_lines.append("\t# All-state chains (run in every state)")
			for chain in all_state_chains:
				if generated_chain_functions.has(chain["name"]) and not _chain_needs_physics_process(chain):
					code_lines.append("\t_logic_brick_%s(delta)" % chain["name"])
			code_lines.append("\t")
		
		code_lines.append("\tmatch _logic_brick_state:")
		
		# Generate case for each state
		var states = chains_by_state.keys()
		states.sort()
		var has_any_process_arm = false
		for state in states:
			var state_chains = chains_by_state[state]
			var has_process_chain = false
			
			# Check if this state has any _process chains
			for chain in state_chains:
				if generated_chain_functions.has(chain["name"]) and not _chain_needs_physics_process(chain):
					has_process_chain = true
					break
			
			if has_process_chain:
				has_any_process_arm = true
				code_lines.append("\t\t%d:" % state)
				for chain in state_chains:
					if generated_chain_functions.has(chain["name"]) and not _chain_needs_physics_process(chain):
						code_lines.append("\t\t\t_logic_brick_%s(delta)" % chain["name"])
		
		# Ensure the match block is never empty (GDScript requires at least one arm)
		if not has_any_process_arm:
			code_lines.append("\t\t_:")
			code_lines.append("\t\t\tpass")
		
		# Post-process code runs after all chains (e.g., move_and_slide)
		if post_process_code.size() > 0:
			code_lines.append("\t")
			for pc in post_process_code:
				code_lines.append("\t" + pc)
		
		code_lines.append("")
	
	if has_physics_process:
		code_lines.append("func _physics_process(delta: float) -> void:")
		
		# State transition detection — reset sensor vars for chains in the newly entered state
		code_lines.append("\tif _logic_brick_state != _logic_brick_prev_state:")
		code_lines.append("\t\t_on_logic_brick_state_enter(_logic_brick_state)")
		code_lines.append("\t\t_logic_brick_prev_state = _logic_brick_state")
		code_lines.append("\t")
		
		# Pre-process code for physics
		if pre_process_code.size() > 0:
			for pc in pre_process_code:
				code_lines.append("\t" + pc)
			code_lines.append("\t")
		
		# All-state chains run unconditionally, before the state match
		if all_state_chains.size() > 0:
			code_lines.append("\t# All-state chains (run in every state)")
			for chain in all_state_chains:
				if generated_chain_functions.has(chain["name"]) and _chain_needs_physics_process(chain):
					code_lines.append("\t_logic_brick_%s(delta)" % chain["name"])
			code_lines.append("\t")
		
		code_lines.append("\tmatch _logic_brick_state:")
		
		# Generate case for each state
		var states = chains_by_state.keys()
		states.sort()
		var has_any_physics_arm = false
		for state in states:
			var state_chains = chains_by_state[state]
			var has_physics_chain = false
			
			# Check if this state has any _physics_process chains
			for chain in state_chains:
				if generated_chain_functions.has(chain["name"]) and _chain_needs_physics_process(chain):
					has_physics_chain = true
					break
			
			if has_physics_chain:
				has_any_physics_arm = true
				code_lines.append("\t\t%d:" % state)
				for chain in state_chains:
					if generated_chain_functions.has(chain["name"]) and _chain_needs_physics_process(chain):
						code_lines.append("\t\t\t_logic_brick_%s(delta)" % chain["name"])
		
		# Ensure the match block is never empty (GDScript requires at least one arm)
		if not has_any_physics_arm:
			code_lines.append("\t\t_:")
			code_lines.append("\t\t\tpass")
		
		# Post-process code for physics
		if post_process_code.size() > 0:
			code_lines.append("\t")
			for pc in post_process_code:
				code_lines.append("\t" + pc)
		
		code_lines.append("")
	
	# Append pre-generated chain functions
	for chain in chains:
		if generated_chain_functions.has(chain["name"]):
			code_lines.append(generated_chain_functions[chain["name"]])
			code_lines.append("")
	
	# Generate _on_logic_brick_state_enter — resets sensor/actuator state vars for chains
	# in the newly entered state so they behave as if running for the first time.
	# Always emitted since _process always calls it; body is empty if nothing needs resetting.
	code_lines.append("func _on_logic_brick_state_enter(state: int) -> void:")
	
	var has_any_resets = false
	for chain_name in chain_member_vars:
		if chain_member_vars[chain_name].size() > 0:
			has_any_resets = true
			break
	
	if has_any_resets:
		code_lines.append("\tmatch state:")
		
		# Emit a case for each state that has resettable chains
		var all_states_seen: Array = []
		for state in chains_by_state.keys():
			var reset_lines: Array[String] = []
			for chain in chains_by_state[state]:
				var cname = chain["name"]
				if chain_member_vars.has(cname):
					for rl in chain_member_vars[cname]:
						reset_lines.append(rl)
			if reset_lines.size() > 0:
				code_lines.append("\t\t%d:" % int(state))
				for rl in reset_lines:
					code_lines.append("\t\t\t" + rl)
				all_states_seen.append(state)
		
		if all_states_seen.is_empty():
			code_lines.append("\t\t_:")
			code_lines.append("\t\t\tpass")
	else:
		code_lines.append("\tpass")
	
	code_lines.append("")
	
	# Emit assembled _input() if any sensors contributed handler bodies
	if input_handler_bodies.size() > 0:
		code_lines.append("func _input(event: InputEvent) -> void:")
		for _body_block in input_handler_bodies:
			for _body_line in _body_block.split("\n"):
				code_lines.append(_body_line)
		code_lines.append("")
	
	# Append extra methods (e.g. message handlers)
	for method in extra_methods:
		code_lines.append(method)
		code_lines.append("")
	
	return "\n".join(code_lines)


## Generate code for a single chain
func _generate_chain_function(node: Node, chain: Dictionary) -> String:
	var chain_name = chain["name"]
	var sensors = chain.get("sensors", [])
	var controller_data = null
	var controllers = chain.get("controllers", [])
	if controllers.size() > 0:
		controller_data = controllers[0]
	else:
		# Legacy: try singular key
		controller_data = chain.get("controller", null)
	var actuators = chain.get("actuators", [])
	
	var lines: Array[String] = []
	lines.append("func _logic_brick_%s(_delta: float) -> void:" % chain_name)
	
	if sensors.is_empty() or actuators.is_empty() or not controller_data:
		return ""  # Incomplete chain — skip entirely, generate nothing
	
	# Collect @export var node names from this chain's bricks so we can
	# guard against freed instances (e.g. object pool recycling nodes).
	# Primitive types (float, int, bool, etc.) are skipped — is_instance_valid
	# always returns false for them, which would incorrectly kill the function.
	var _guard_primitive_types = ["float", "int", "bool", "String", "Vector2", "Vector3", "Color", "Basis", "Transform3D"]
	var _chain_export_vars: Array[String] = []
	for _sd in sensors:
		var _sb = _instantiate_brick(_sd)
		if _sb:
			var _sg = _sb.generate_code(node, chain_name)
			for _mv in _sg.get("member_vars", []):
				if _mv.begins_with("@export var "):
					var _parts = _mv.replace("@export var ", "").split(":")
					var _vname = _parts[0].strip_edges()
					var _vtype = _parts[1].strip_edges().split(" ")[0] if _parts.size() > 1 else ""
					if _vtype in _guard_primitive_types:
						continue
					if _vname not in _chain_export_vars:
						_chain_export_vars.append(_vname)
	for _ad in actuators:
		var _ab = _instantiate_brick(_ad)
		if _ab:
			var _ag = _ab.generate_code(node, chain_name)
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
	
	# Generate sensor code for ALL sensors
	lines.append("\t# Sensor evaluation")
	var sensor_vars = []
	var sensor_index = 0
	
	for sensor_data in sensors:
		var sensor_brick = _instantiate_brick(sensor_data)
		if sensor_brick:
			var generated = sensor_brick.generate_code(node, chain_name)
			if generated.has("sensor_code"):
				var sensor_code = generated["sensor_code"]
				# Use instance name if available, otherwise use index
				var instance_name = sensor_data.get("instance_name", "")
				var sensor_var = ""
				if instance_name.is_empty():
					sensor_var = "sensor_%d_active" % sensor_index
				else:
					sensor_var = _sanitize_chain_name(instance_name) + "_active"
				sensor_code = sensor_code.replace("sensor_active", sensor_var)
				
				# Handle multi-line sensor code properly (same pattern as actuators)
				var sensor_code_lines = sensor_code.split("\n")
				for code_line in sensor_code_lines:
					if code_line.strip_edges() != "":
						lines.append("\t" + code_line)
				
				# Add debug print if enabled
				var debug_code = sensor_brick.get_debug_code()
				if not debug_code.is_empty():
					lines.append("\t" + debug_code)
				
				sensor_vars.append(sensor_var)
				sensor_index += 1
	
	# Generate controller code
	lines.append("\t")
	lines.append("\t# Controller logic")
	
	if controller_data:
		var controller_brick = _instantiate_brick(controller_data)
		if controller_brick:
			# Determine logic mode from properties, fall back to class name for legacy bricks
			var logic_mode = "and"
			if controller_brick.properties.has("logic_mode"):
				logic_mode = controller_brick.properties.get("logic_mode", "and")
				if typeof(logic_mode) == TYPE_STRING:
					logic_mode = logic_mode.to_lower()
			elif controller_data["type"] == "ANDController":
				logic_mode = "and"
			
			if sensor_vars.size() > 0:
				var condition = ""
				match logic_mode:
					"or":
						condition = " or ".join(sensor_vars)
					"nand":
						condition = "not (" + " and ".join(sensor_vars) + ")"
					"nor":
						condition = "not (" + " or ".join(sensor_vars) + ")"
					"xor":
						# Exactly one sensor active: int(a) + int(b) + ... == 1
						var int_vars: Array[String] = []
						for sv in sensor_vars:
							int_vars.append("int(%s)" % sv)
						condition = "(" + " + ".join(int_vars) + ") == 1"
					_:  # "and" and default
						condition = " and ".join(sensor_vars)
				lines.append("\tvar controller_active = " + condition)
			else:
				lines.append("\tvar controller_active = false")
	else:
		# No controller - default to AND logic
		if sensor_vars.size() > 0:
			var condition = " and ".join(sensor_vars)
			lines.append("\tvar controller_active = " + condition)
		else:
			lines.append("\tvar controller_active = false")
	
	# Generate actuator code for ALL actuators
	lines.append("\t")
	lines.append("\t# Actuator execution")
	lines.append("\tif controller_active:")
	
	if actuators.is_empty():
		return ""  # No actuators — incomplete chain
	else:
		var actuator_lines_written = 0
		for actuator_data in actuators:
			var actuator_brick = _instantiate_brick(actuator_data)
			if actuator_brick:
				var generated = actuator_brick.generate_code(node, chain_name)
				if generated.has("actuator_code"):
					var actuator_code = generated["actuator_code"]
					var code_lines_array = actuator_code.split("\n")
					for code_line in code_lines_array:
						if code_line.strip_edges() != "":
							lines.append("\t\t" + code_line)
							actuator_lines_written += 1
					
					var debug_code = actuator_brick.get_debug_code()
					if not debug_code.is_empty():
						lines.append("\t\t" + debug_code)
						actuator_lines_written += 1
		
		# If all actuators produced empty code, treat as incomplete — skip entirely
		if actuator_lines_written == 0:
			return ""
	
	# Write active flags for any named actuators so the Actuator Sensor can read them.
	# Flags are written both when active (true) and when not (false) so the sensor
	# always has an up-to-date value regardless of which branch ran.
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


## Check if a chain is complete enough to generate code for
## Requires at least one sensor, one controller, and one actuator
func _chain_is_complete(chain: Dictionary) -> bool:
	if chain.get("sensors", []).is_empty():
		return false
	if chain.get("actuators", []).is_empty():
		return false
	var controllers = chain.get("controllers", [])
	if controllers.is_empty():
		# Legacy: try singular key
		if not chain.has("controller") or chain.get("controller") == null:
			return false
	return true


## Check if a chain needs physics process (has force/torque actuators)
func _chain_needs_physics_process(chain: Dictionary) -> bool:
	var actuators = chain.get("actuators", [])
	for actuator_data in actuators:
		var brick_type = actuator_data.get("type", "")
		if brick_type in ["ForceActuator", "TorqueActuator", "ImpulseActuator", "LinearVelocityActuator"]:
			return true
	return false


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


## Get the script path for a brick type
func _get_brick_script_path(brick_type: String) -> String:
	match brick_type:
		"ActuatorSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/actuator_sensor.gd"
		"AlwaysSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/always_sensor.gd"
		"AnimationTreeSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/animation_tree_sensor.gd"
		"DelaySensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/delay_sensor.gd"
		"KeyboardSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/keyboard_sensor.gd"  # Legacy
		"InputMapSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/input_map_sensor.gd"
		"MessageSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/message_sensor.gd"
		"VariableSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/variable_sensor.gd"
		"ProximitySensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/proximity_sensor.gd"
		"RandomSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/random_sensor.gd"
		"RaycastSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/raycast_sensor.gd"
		"MovementSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/movement_sensor.gd"
		"MouseSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/mouse_sensor.gd"
		"CollisionSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/collision_sensor.gd"
		"ANDController", "Controller":
			return "res://addons/logic_bricks/bricks/controllers/controller.gd"
		"MotionActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/motion_actuator.gd"
		"LocationActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/location_actuator.gd"
		"LinearVelocityActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/linear_velocity_actuator.gd"
		"RotationActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/rotation_actuator.gd"
		"ForceActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/force_actuator.gd"
		"TorqueActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/torque_actuator.gd"
		"EditObjectActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/edit_object_actuator.gd"
		"CharacterActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/character_actuator.gd"
		"GravityActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/gravity_actuator.gd"  # Legacy
		"JumpActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/jump_actuator.gd"  # Legacy
		"MoveTowardsActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/move_towards_actuator.gd"
		"AnimationActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/animation_actuator.gd"
		"AnimationTreeActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/animation_tree_actuator.gd"
		"SoundActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/sound_actuator.gd"
		"MessageActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/message_actuator.gd"
		"LookAtMovementActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/look_at_movement_actuator.gd"
		"RotateTowardsActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/rotate_towards_actuator.gd"
		"WaypointPathActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd"
		"VariableActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/variable_actuator.gd"
		"RandomActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/random_actuator.gd"
		"StateActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/state_actuator.gd"
		"TeleportActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/teleport_actuator.gd"
		"PropertyActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/property_actuator.gd"
		"TextActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/text_actuator.gd"
		"SoundActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/sound_actuator.gd"
		"SceneActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/scene_actuator.gd"
		"SaveLoadActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/save_load_actuator.gd"
		"CameraActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/camera_actuator.gd"
		"SetCameraActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/set_camera_actuator.gd"
		"SmoothFollowCameraActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/smooth_follow_camera_actuator.gd"
		"CollisionActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/collision_actuator.gd"
		"ParentActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/parent_actuator.gd"
		"PhysicsActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/physics_actuator.gd"
		"MouseActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/mouse_actuator.gd"
		"GameActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/game_actuator.gd"
		"PrintActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/print_actuator.gd"
		"EnvironmentActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/environment_actuator.gd"
		"Audio2DActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/audio_2d_actuator.gd"
		"ModulateActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/modulate_actuator.gd"
		"VisibilityActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/visibility_actuator.gd"
		"ProgressBarActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/progress_bar_actuator.gd"
		"TweenActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/tween_actuator.gd"
		"ImpulseActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/impulse_actuator.gd"
		"MusicActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/music_actuator.gd"
		"ScreenShakeActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/screen_shake_actuator.gd"
		"ScreenFlashActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/screen_flash_actuator.gd"
		"RumbleActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/rumble_actuator.gd"
		"UIFocusActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/ui_focus_actuator.gd"
		"ShaderParamActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/shader_param_actuator.gd"
		"LightActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/light_actuator.gd"
		"ThirdPersonCameraActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/third_person_camera_actuator.gd"
		"SplitScreenActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/split_screen_actuator.gd"
		"CameraZoomActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/camera_zoom_actuator.gd"
		"ObjectPoolActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/object_pool_actuator.gd"
		"ANDController", "Controller":
			return "res://addons/logic_bricks/bricks/controllers/controller.gd"
	return ""


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
	
	# Insert markers before any existing functions
	var insert_pos = existing_code.length()
	var func_pos = existing_code.find("\nfunc ")
	if func_pos != -1:
		insert_pos = func_pos + 1
	
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
	var scene_path = node.get_tree().edited_scene_root.scene_file_path
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
