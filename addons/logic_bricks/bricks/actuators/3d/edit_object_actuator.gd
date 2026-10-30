@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Edit Object actuator - Add a new object, end (remove) this object, or replace its mesh.
## Similar to UPBGE's Edit Object actuator.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Edit Object"


func _initialize_properties() -> void:
	properties = {
		"edit_type": "End Object",          # "Add Object", "End Object", "Replace Mesh"
		"spawn_object": "",                # Scene file to spawn (Add mode)
		"spawn_point": NodePath(""),       # Node to spawn at (Add mode)
		"velocity_x": 0.0,                 # Initial velocity X (Add mode)
		"velocity_y": 0.0,                 # Initial velocity Y (Add mode)
		"velocity_z": 0.0,                 # Initial velocity Z (Add mode)
		"velocity_local": false,           # Use local velocity (relative to spawn orientation)
		"lifespan": 0.0,                   # Auto-destroy after seconds, 0 = infinite (Add mode)
		"end_mode": "queue_free",          # "queue_free" or "free" (End mode)
		"end_delay": 0.0,                  # Delay before ending object in seconds (End mode)
		"mesh_path": ""                    # Path to mesh resource (Replace Mesh mode)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "edit_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Add Object,End Object,Replace Mesh",
			"default": "End Object"
		},
		{
			"name": "spawn_object", "required": true, "required_label": "a scene to spawn", "required_if": {"edit_type": "add_object"},
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.tscn,*.scn",
			"default": "",
			"visible_if": {"edit_type": "Add Object"}
		},
		{
			"name": "spawn_point",
			"type": TYPE_STRING,
			"node_reference": true,
			"node_reference_store": "path",
			"node_reference_drop_path": true,
			"accepted_node_types": ["Node3D"],
			"default": "",
			"visible_if": {"edit_type": "Add Object"}
		},
		{
			"name": "velocity_x",
			"type": TYPE_STRING,
			"default": 0.0,
			"visible_if": {"edit_type": "Add Object"}
		},
		{
			"name": "velocity_y",
			"type": TYPE_STRING,
			"default": 0.0,
			"visible_if": {"edit_type": "Add Object"}
		},
		{
			"name": "velocity_z",
			"type": TYPE_STRING,
			"default": 0.0,
			"visible_if": {"edit_type": "Add Object"}
		},
		{
			"name": "velocity_local",
			"type": TYPE_BOOL,
			"default": false,
			"visible_if": {"edit_type": "Add Object"}
		},
		{
			"name": "lifespan",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"visible_if": {"edit_type": "Add Object"}
		},
		{
			"name": "end_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Queue Free,Free Immediate",
			"default": "queue_free",
			"visible_if": {"edit_type": "End Object"}
		},
		{
			"name": "end_delay",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"visible_if": {"edit_type": "End Object"}
		},
		{
			"name": "mesh_path", "required": true, "required_label": "a mesh file", "required_if": {"edit_type": "replace_mesh"},
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.mesh,*.obj",
			"default": "",
			"visible_if": {"edit_type": "Replace Mesh"}
		}
	]


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var edit_type = properties.get("edit_type", "end")

	# Normalize
	if typeof(edit_type) == TYPE_STRING:
		edit_type = edit_type.to_lower().replace(" ", "_")

	# Show/hide fields based on edit_type
	for child in _get_field_names():
		if true:
			var prop_name = child
			match prop_name:
				"spawn_object", "spawn_point", "velocity_x", "velocity_y", "velocity_z", "velocity_local", "lifespan":
					shown[child] = (edit_type == "add_object")
				"end_mode":
					shown[child] = (edit_type == "end_object")
				"mesh_path":
					shown[child] = (edit_type == "replace_mesh")
	return shown


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var edit_type = properties.get("edit_type", "end_object")
	var spawn_object = properties.get("spawn_object", "")
	var spawn_point = properties.get("spawn_point", NodePath(""))
	var velocity_x = properties.get("velocity_x", 0.0)
	var velocity_y = properties.get("velocity_y", 0.0)
	var velocity_z = properties.get("velocity_z", 0.0)
	var velocity_local = properties.get("velocity_local", false)
	var lifespan = _literal_number("lifespan", 0.0)
	var end_mode = properties.get("end_mode", "queue_free")
	var end_delay = _literal_number("end_delay", 0.0)
	var mesh_path = properties.get("mesh_path", "")

	# Normalize edit_type to snake_case
	if typeof(edit_type) == TYPE_STRING:
		edit_type = edit_type.to_lower().replace(" ", "_")

	# FIX (Bug 3): Explicit end_mode normalization — avoids fragile string stripping
	if typeof(end_mode) == TYPE_STRING:
		var em = end_mode.to_lower()
		if "queue" in em:
			end_mode = "queue_free"
		else:
			end_mode = "free"

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
				code_lines.append("var _scene = load(\"%s\").instantiate()" % _gd_string(str(spawn_object)))

				# FIX (Bug 2): Declare vars before the if/else so they stay in scope
				code_lines.append("var _spawn_pos = global_position")
				code_lines.append("var _spawn_basis = global_transform.basis.orthonormalized()")

				if not spawn_point_str.is_empty():
					code_lines.append("var _spawn_point = get_node_or_null(%s)" % var_to_str(spawn_point_str))
					code_lines.append("if _spawn_point == null:")
					code_lines.append("\t_spawn_point = get_tree().current_scene.find_child(%s, true, false) if get_tree().current_scene else null" % var_to_str(spawn_point_str))
					code_lines.append("if _spawn_point:")
					code_lines.append("\t_spawn_pos = _spawn_point.global_position")
					code_lines.append("\t_spawn_basis = _spawn_point.global_transform.basis.orthonormalized()")

				# Set position and rotation (with uniform scale) before adding to tree
				code_lines.append("_scene.global_transform = Transform3D(_spawn_basis, _spawn_pos)")

				# Add to scene root (not as child of spawner - makes it independent)
				code_lines.append("get_tree().root.add_child(_scene)")

				# Numbers, variable names (local or global) and math such as speed * 2.
				var velocity_values = [velocity_x, velocity_y, velocity_z]
				var velocity_expressions: Array[String] = []
				var needs_velocity = false
				for component in velocity_values:
					var value_text = str(component).strip_edges()
					if value_text.is_empty() or _is_literal_zero(value_text):
						velocity_expressions.append("0.0")
					else:
						needs_velocity = true
						if value_text.is_valid_float() or value_text.is_valid_int():
							velocity_expressions.append(_numeric_expr(value_text))
						else:
							velocity_expressions.append("float(%s)" % value_text)
				if needs_velocity:
					code_lines.append("var _velocity = Vector3(%s, %s, %s)" % velocity_expressions)
					if velocity_local:
						code_lines.append("_velocity = _spawn_basis * _velocity")
					code_lines.append("if _scene is RigidBody3D:")
					code_lines.append("\t_scene.linear_velocity = _velocity")
					code_lines.append("elif _scene.has_method(\"set_velocity\"):")
					code_lines.append("\t_scene.set_velocity(_velocity)")

				# Set up auto-destruction if lifespan > 0
				# FIX (Bug 1): Wait a physics frame before freeing so Jolt can flush area events
				if _is_number_expression("lifespan"):
					# Lifespan is a variable/math: check it when the object is added.
					code_lines.append("# Auto-destroy after Lifespan seconds (0 = never)")
					code_lines.append("var _lifespan = %s" % _num("lifespan"))
					code_lines.append("if _lifespan > 0.0:")
					_append_lifespan_timer(code_lines, "_lifespan", "\t")
				elif lifespan > 0.0:
					code_lines.append("# Auto-destroy after %.2f seconds" % lifespan)
					_append_lifespan_timer(code_lines, "%.2f" % lifespan, "")

				code = "\n".join(code_lines)

		"end_object":
			# FIX (Bug 1): Always yield a physics frame before freeing to let Jolt flush
			# area overlap exit events — prevents the ref_count <= 0 Jolt assertion.
			var delayed_code = ("get_tree().create_timer(%s).timeout.connect(func():\n"
				+ "\tawait get_tree().physics_frame\n"
				+ "\tif is_instance_valid(self):\n"
				+ "\t\t%s())")
			var immediate_code = "await get_tree().physics_frame\nif is_instance_valid(self):\n\t%s()" % end_mode
			if _is_number_expression("end_delay"):
				# End Delay is a variable/math: choose delayed or immediate removal at runtime.
				code = "var _end_delay = %s\nif _end_delay > 0.0:\n%s\nelse:\n%s" % [
					_num("end_delay"),
					_indent(delayed_code % ["_end_delay", end_mode]),
					_indent(immediate_code)]
			elif end_delay > 0.0:
				# Delayed removal: timer fires, then wait one physics frame
				code = delayed_code % ["%.2f" % end_delay, end_mode]
			else:
				# Immediate removal: still defer past the physics step
				code = immediate_code

		"replace_mesh":
			# Swap the mesh on this object's MeshInstance3D
			if mesh_path.is_empty():
				code = "pass # No mesh path set"
			else:
				code = "var _mesh_instance = $MeshInstance3D\nif _mesh_instance:\n\t_mesh_instance.mesh = load(\"%s\")" % _gd_string(str(mesh_path))

		_:
			code = "pass # Unknown edit type"

	return {
		"actuator_code": code
	}

## Free the spawned object (_scene) after delay_code seconds, waiting a physics
## frame first so Jolt can flush area events.
func _append_lifespan_timer(code_lines: Array[String], delay_code: String, indent: String) -> void:
	code_lines.append(indent + "var _spawned_ref = weakref(_scene)")
	code_lines.append(indent + "get_tree().create_timer(%s).timeout.connect(func():" % delay_code)
	code_lines.append(indent + "\tawait get_tree().physics_frame")
	code_lines.append(indent + "\tvar _expired_object = _spawned_ref.get_ref()")
	code_lines.append(indent + "\tif is_instance_valid(_expired_object):")
	code_lines.append(indent + "\t\t_expired_object.queue_free())")


func _indent(code: String) -> String:
	return "\t" + code.replace("\n", "\n\t")


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Add, remove, or replace objects in the scene at runtime.\nUseful for spawning enemies, projectiles, or swapping meshes.",
		"edit_type": "Action: Add Object (instance scene), End Object (remove), or Replace Mesh.",
		"end_mode": "How to end the object: Queue Free (deferred) or Free (immediate).",
		"mesh_path": "Path to the mesh resource to swap in (for Replace Mesh).",
		"velocity_x": "Starting speed of the spawned object along X. Accepts a number, a variable, or math (for example: speed * 2).",
		"velocity_y": "Starting speed of the spawned object along Y. Accepts a number, a variable, or math (for example: speed * 2).",
		"velocity_z": "Starting speed of the spawned object along Z. Accepts a number, a variable, or math (for example: speed * 2).",
	}
