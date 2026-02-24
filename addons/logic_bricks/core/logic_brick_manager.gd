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
		
		if is_global:
			# Global variable: property that proxies to GlobalVars autoload
			lines.append("var %s: %s:" % [var_name, var_type])
			lines.append("\tget: return GlobalVars.%s" % var_name)
			lines.append("\tset(val): GlobalVars.%s = val" % var_name)
		else:
			# Local variable
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
	var member_vars: Array[String] = []
	var ready_code: Array[String] = []
	var pre_process_code: Array[String] = []
	var post_process_code: Array[String] = []
	var extra_methods: Array[String] = []
	for chain in chains:
		# Collect from sensors
		for sensor_data in chain.get("sensors", []):
			var sensor_brick = _instantiate_brick(sensor_data)
			if sensor_brick:
				var generated = sensor_brick.generate_code(node, chain["name"])
				if generated.has("member_vars"):
					for mv in generated["member_vars"]:
						if mv not in member_vars:
							member_vars.append(mv)
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
						if method not in extra_methods:
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
						if method not in extra_methods:
							extra_methods.append(method)
	
	if member_vars.size() > 0:
		for mv in member_vars:
			code_lines.append(mv)
		code_lines.append("")
	
	# Generate _ready() function
	# Collect export validation checks from member vars
	var export_checks: Array[String] = []
	for mv in member_vars:
		if mv.begins_with("@export var "):
			# Extract variable name: "@export var _nav_agent__33: NavigationAgent3D" -> "_nav_agent__33"
			var parts = mv.replace("@export var ", "").split(":")
			if parts.size() >= 1:
				var var_name = parts[0].strip_edges()
				# Generate a readable label from the var name
				var label = var_name
				export_checks.append("if not %s:" % var_name)
				export_checks.append("\tpush_warning(\"Logic Bricks: '%s' is not assigned! Drag a node into the inspector.\")" % label)
	
	if ready_code.size() > 0 or export_checks.size() > 0:
		code_lines.append("func _ready() -> void:")
		# Export validation first
		for ec in export_checks:
			code_lines.append("\t" + ec)
		# Then other ready code
		for rc in ready_code:
			code_lines.append("\t" + rc)
		code_lines.append("")
	
	# Add state variable
	code_lines.append("# Logic brick state (1-30)")
	code_lines.append("var _logic_brick_state: int = 1")
	code_lines.append("")
	
	# Group chains by state
	var chains_by_state: Dictionary = {}
	for chain in chains:
		var state = 1  # Default state
		
		# Get state from controller
		var controllers = chain.get("controllers", [])
		if controllers.size() > 0:
			var controller_data = controllers[0]
			var controller_brick = _instantiate_brick(controller_data)
			if controller_brick:
				#print("Chain '%s' - Controller class: %s" % [chain["name"], controller_data.get("class_name", "Unknown")])
				if controller_brick.properties.has("state"):
					state = controller_brick.properties.get("state", 1)
					#print("  -> State property found: %d" % state)
				else:
					pass  #print("  -> No state property found, using default state 1")
			else:
				pass  #print("Chain '%s' - Failed to instantiate controller" % chain["name"])
		else:
			pass  #print("Chain '%s' - No controller, using default state 1" % chain["name"])
		
		if not chains_by_state.has(state):
			chains_by_state[state] = []
		chains_by_state[state].append(chain)
		#print("Chain '%s' assigned to state %d" % [chain["name"], state])
	
	# Determine if we need process or physics process
	var has_process = false
	var has_physics_process = false
	
	for chain in chains:
		var needs_physics = _chain_needs_physics_process(chain)
		
		if needs_physics:
			has_physics_process = true
		else:
			has_process = true
	
	# Generate process functions with state matching
	if has_process:
		code_lines.append("func _process(delta: float) -> void:")
		
		# Pre-process code runs before any chains (e.g., reset horizontal velocity)
		if pre_process_code.size() > 0:
			for pc in pre_process_code:
				code_lines.append("\t" + pc)
			code_lines.append("\t")
		
		code_lines.append("\tmatch _logic_brick_state:")
		
		# Generate case for each state
		var states = chains_by_state.keys()
		states.sort()
		for state in states:
			var state_chains = chains_by_state[state]
			var has_process_chain = false
			
			# Check if this state has any _process chains
			for chain in state_chains:
				if not _chain_needs_physics_process(chain):
					has_process_chain = true
					break
			
			if has_process_chain:
				code_lines.append("\t\t%d:" % state)
				for chain in state_chains:
					if not _chain_needs_physics_process(chain):
						code_lines.append("\t\t\t_logic_brick_%s(delta)" % chain["name"])
		
		# Post-process code runs after all chains (e.g., move_and_slide)
		if post_process_code.size() > 0:
			code_lines.append("\t")
			for pc in post_process_code:
				code_lines.append("\t" + pc)
		
		code_lines.append("")
	
	if has_physics_process:
		code_lines.append("func _physics_process(delta: float) -> void:")
		
		# Pre-process code for physics
		if pre_process_code.size() > 0:
			for pc in pre_process_code:
				code_lines.append("\t" + pc)
			code_lines.append("\t")
		
		code_lines.append("\tmatch _logic_brick_state:")
		
		# Generate case for each state
		var states = chains_by_state.keys()
		states.sort()
		for state in states:
			var state_chains = chains_by_state[state]
			var has_physics_chain = false
			
			# Check if this state has any _physics_process chains
			for chain in state_chains:
				if _chain_needs_physics_process(chain):
					has_physics_chain = true
					break
			
			if has_physics_chain:
				code_lines.append("\t\t%d:" % state)
				for chain in state_chains:
					if _chain_needs_physics_process(chain):
						code_lines.append("\t\t\t_logic_brick_%s(delta)" % chain["name"])
		
		# Post-process code for physics
		if post_process_code.size() > 0:
			code_lines.append("\t")
			for pc in post_process_code:
				code_lines.append("\t" + pc)
		
		code_lines.append("")
	
	# Generate individual chain functions
	for chain in chains:
		var chain_code = _generate_chain_function(node, chain)
		code_lines.append(chain_code)
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
	
	if sensors.is_empty() or actuators.is_empty():
		lines.append("\tpass")
		return "\n".join(lines)
	
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
		lines.append("\t\tpass")
	else:
		for actuator_data in actuators:
			var actuator_brick = _instantiate_brick(actuator_data)
			if actuator_brick:
				var generated = actuator_brick.generate_code(node, chain_name)
				if generated.has("actuator_code"):
					var actuator_code = generated["actuator_code"]
					# Handle multi-line actuator code properly
					var code_lines_array = actuator_code.split("\n")
					for code_line in code_lines_array:
						if code_line.strip_edges() != "":
							lines.append("\t\t" + code_line)
					
					# Add debug print if enabled
					var debug_code = actuator_brick.get_debug_code()
					if not debug_code.is_empty():
						lines.append("\t\t" + debug_code)
	
	return "\n".join(lines)


## Check if a chain needs physics process (has force/torque actuators)
func _chain_needs_physics_process(chain: Dictionary) -> bool:
	var actuators = chain.get("actuators", [])
	for actuator_data in actuators:
		var brick_type = actuator_data.get("type", "")
		if brick_type == "MotionActuator":
			var props = actuator_data.get("properties", {})
			var motion_type = props.get("motion_type", "location")
			if motion_type in ["force", "torque"]:
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
		"JoystickSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/joystick_sensor.gd"
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
		"TimerSensor":
			return "res://addons/logic_bricks/bricks/sensors/3d/timer_sensor.gd"
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
		"SaveGameActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/save_game_actuator.gd"
		"CameraActuator":
			return "res://addons/logic_bricks/bricks/actuators/3d/camera_actuator.gd"
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
