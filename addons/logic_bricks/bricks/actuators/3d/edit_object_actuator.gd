@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Edit object actuator - Add a new object, end (remove) this object, or replace its mesh.
## Similar to UPBGE's Edit Object actuator.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Edit Object"


func _initialize_properties() -> void:
	properties = {
		"edit_type": "end_object",         # "add_object", "end_object", "replace_mesh"
		"spawn_object": "",                # Scene file to spawn (Add mode)
		"spawn_point": NodePath(""),       # Node to spawn at (Add mode)
		"velocity_x": 0.0,                 # Initial velocity X (Add mode)
		"velocity_y": 0.0,                 # Initial velocity Y (Add mode)
		"velocity_z": 0.0,                 # Initial velocity Z (Add mode)
		"velocity_local": false,           # Use local velocity (relative to spawn orientation)
		"lifespan": 0.0,                   # Auto-destroy after seconds, 0 = infinite (Add mode)
		"end_mode": "queue_free",          # "queue_free" or "free" (End mode)
		"end_delay": 0.1,                  # Delay before ending object in seconds (End mode)
		"mesh_path": ""                    # Path to mesh resource (Replace Mesh mode)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "edit_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Add Object,End Object,Replace Mesh",
			"default": "end_object"
		},
		{
			"name": "spawn_object",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.tscn,*.scn",
			"default": "",
			"visible_if": {"edit_type": "add_object"}
		},
		{
			"name": "spawn_point",
			"type": TYPE_NODE_PATH,
			"default": NodePath(""),
			"visible_if": {"edit_type": "add_object"}
		},
		{
			"name": "velocity_x",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"visible_if": {"edit_type": "add_object"}
		},
		{
			"name": "velocity_y",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"visible_if": {"edit_type": "add_object"}
		},
		{
			"name": "velocity_z",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"visible_if": {"edit_type": "add_object"}
		},
		{
			"name": "velocity_local",
			"type": TYPE_BOOL,
			"default": false,
			"visible_if": {"edit_type": "add_object"}
		},
		{
			"name": "lifespan",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"visible_if": {"edit_type": "add_object"}
		},
		{
			"name": "end_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Queue Free (Safe),Free (Immediate)",
			"default": "queue_free",
			"visible_if": {"edit_type": "end_object"}
		},
		{
			"name": "end_delay",
			"type": TYPE_FLOAT,
			"default": 0.1,
			"visible_if": {"edit_type": "end_object"}
		},
		{
			"name": "mesh_path",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.mesh,*.obj",
			"default": "",
			"visible_if": {"edit_type": "replace_mesh"}
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var edit_type = properties.get("edit_type", "end_object")
	var spawn_object = properties.get("spawn_object", "")
	var spawn_point = properties.get("spawn_point", NodePath(""))
	var velocity_x = properties.get("velocity_x", 0.0)
	var velocity_y = properties.get("velocity_y", 0.0)
	var velocity_z = properties.get("velocity_z", 0.0)
	var velocity_local = properties.get("velocity_local", false)
	var lifespan = properties.get("lifespan", 0.0)
	var end_mode = properties.get("end_mode", "queue_free")
	var end_delay = properties.get("end_delay", 0.1)
	var mesh_path = properties.get("mesh_path", "")
	
	# Normalize enums to lowercase
	if typeof(edit_type) == TYPE_STRING:
		edit_type = edit_type.to_lower().replace(" ", "_")
	if typeof(end_mode) == TYPE_STRING:
		end_mode = end_mode.to_lower()
	
	# Convert NodePath to string for code generation
	var spawn_point_str = ""
	if spawn_point is NodePath:
		spawn_point_str = str(spawn_point)
	elif spawn_point is String:
		spawn_point_str = spawn_point
	
	var code = ""
	
	match edit_type:
		"add_object":
			# Instantiate a scene and add it to the scene root (independent of spawner)
			if spawn_object.is_empty():
				code = "pass # No spawn object set"
			else:
				var code_lines: Array[String] = []
				code_lines.append("var _scene = load(\"%s\").instantiate()" % spawn_object)
				
				# Determine spawn position and rotation (but NOT scale)
				if spawn_point_str.is_empty():
					code_lines.append("var _spawn_pos = global_position")
					code_lines.append("var _spawn_basis = global_transform.basis.orthonormalized()")
				else:
					code_lines.append("var _spawn_point = get_node_or_null(\"%s\")" % spawn_point_str)
					code_lines.append("if _spawn_point:")
					code_lines.append("\tvar _spawn_pos = _spawn_point.global_position")
					code_lines.append("\tvar _spawn_basis = _spawn_point.global_transform.basis.orthonormalized()")
					code_lines.append("else:")
					code_lines.append("\tvar _spawn_pos = global_position")
					code_lines.append("\tvar _spawn_basis = global_transform.basis.orthonormalized()")
				
				# Set position and rotation (with uniform scale) before adding to tree
				code_lines.append("_scene.global_transform = Transform3D(_spawn_basis, _spawn_pos)")
				
				# Add to scene root (not as child of spawner - makes it independent)
				code_lines.append("get_tree().root.add_child(_scene)")
				
				# Apply velocity if any axis is non-zero (after adding to tree)
				if velocity_x != 0.0 or velocity_y != 0.0 or velocity_z != 0.0:
					code_lines.append("# Apply initial velocity")
					
					# Calculate velocity (global or local)
					if velocity_local:
						code_lines.append("var _velocity = _spawn_basis * Vector3(%.2f, %.2f, %.2f)" % [velocity_x, velocity_y, velocity_z])
					else:
						code_lines.append("var _velocity = Vector3(%.2f, %.2f, %.2f)" % [velocity_x, velocity_y, velocity_z])
					
					code_lines.append("if _scene is RigidBody3D:")
					code_lines.append("\t_scene.linear_velocity = _velocity")
					code_lines.append("elif _scene.has_method(\"set_velocity\"):")
					code_lines.append("\t# For CharacterBody3D or custom physics")
					code_lines.append("\t_scene.set_velocity(_velocity)")
				
				# Set up auto-destruction if lifespan > 0
				if lifespan > 0.0:
					code_lines.append("# Auto-destroy after %.2f seconds" % lifespan)
					code_lines.append("get_tree().create_timer(%.2f).timeout.connect(_scene.queue_free)" % lifespan)
				
				code = "\n".join(code_lines)
		
		"end_object":
			# Remove this object from the scene with optional delay
			if end_delay > 0.0:
				# Use timer for delayed removal
				if end_mode == "queue_free":
					code = "get_tree().create_timer(%.2f).timeout.connect(queue_free)" % end_delay
				else:
					code = "get_tree().create_timer(%.2f).timeout.connect(free)" % end_delay
			else:
				# Immediate removal
				if end_mode == "queue_free":
					code = "queue_free()"
				else:
					code = "free()"
		
		"replace_mesh":
			# Swap the mesh on this object's MeshInstance3D
			if mesh_path.is_empty():
				code = "pass # No mesh path set"
			else:
				code = "var _mesh_instance = $MeshInstance3D\nif _mesh_instance:\n\t_mesh_instance.mesh = load(\"%s\")" % mesh_path
		
		_:
			code = "pass # Unknown edit type"
	
	return {
		"actuator_code": code
	}
