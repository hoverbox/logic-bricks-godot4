@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Proximity Sensor - Detect objects within range and angle
## Uses collision shape or sphere detection
## Uses groups to filter detected objects

func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Proximity"


func _initialize_properties() -> void:
	properties = {
		"target_group": "",          # Group to detect (empty = detect all)
		"use_collision_shape": true, # Use node's collision shape as detection volume
		"distance": 10.0,            # Detection distance in meters (only if use_collision_shape is false)
		"angle": 360.0,              # Detection angle in degrees (0-360, 360 = full circle)
		"axis": "all",               # Axis to measure angle from: all, +x, -x, +y, -y, +z, -z
		"detection_mode": "any",     # any = detect any object, all = detect all objects, none = detect no objects
		"inverse": false,            # Invert the result (triggers when NOT in range)
		"store_object": false,       # If true, stores the first detected object in a variable
		"object_variable": ""        # Variable name to store detected object (only if store_object is true)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_group",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "use_collision_shape",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "distance",
			"type": TYPE_FLOAT,
			"default": 10.0
		},
		{
			"name": "angle",
			"type": TYPE_FLOAT,
			"default": 360.0
		},
		{
			"name": "axis",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "All,+X,-X,+Y,-Y,+Z,-Z",
			"default": "all"
		},
		{
			"name": "detection_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Any,All,None",
			"default": "any"
		},
		{
			"name": "inverse",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "store_object",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "object_variable",
			"type": TYPE_STRING,
			"default": ""
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_group = properties.get("target_group", "")
	var use_collision_shape = properties.get("use_collision_shape", true)
	var distance = properties.get("distance", 10.0)
	var angle = properties.get("angle", 360.0)
	var axis = properties.get("axis", "forward")
	var detection_mode = properties.get("detection_mode", "any")
	var inverse = properties.get("inverse", false)
	var store_object = properties.get("store_object", false)
	var object_var = properties.get("object_variable", "")
	
	# Normalize axis
	if typeof(axis) == TYPE_STRING:
		axis = axis.to_lower()
	
	# Normalize detection_mode
	if typeof(detection_mode) == TYPE_STRING:
		detection_mode = detection_mode.to_lower()
	
	print("Proximity Sensor Debug - group: '%s', use_shape: %s, distance: %.2f, angle: %.2f, inverse: %s" % [target_group, use_collision_shape, distance, angle, inverse])
	
	var code_lines: Array[String] = []
	
	# Start the sensor function
	code_lines.append("var _proximity_check = func():")
	
	# Two different approaches based on use_collision_shape
	if use_collision_shape:
		# Use PhysicsDirectSpaceState3D with the node's collision shape
		code_lines.append("\t# Use collision shape for detection")
		code_lines.append("\tvar space_state = get_world_3d().direct_space_state")
		code_lines.append("\tvar query = PhysicsShapeQueryParameters3D.new()")
		code_lines.append("\t")
		code_lines.append("\t# Find CollisionShape3D child")
		code_lines.append("\tvar collision_shape = null")
		code_lines.append("\tfor child in get_children():")
		code_lines.append("\t\tif child is CollisionShape3D:")
		code_lines.append("\t\t\tcollision_shape = child")
		code_lines.append("\t\t\tbreak")
		code_lines.append("\t")
		code_lines.append("\tif not collision_shape or not collision_shape.shape:")
		code_lines.append("\t\tpush_warning(\"Proximity Sensor: Node has no CollisionShape3D child!\")")
		code_lines.append("\t\treturn false")
		code_lines.append("\t")
		code_lines.append("\t# Set up query")
		code_lines.append("\tquery.shape = collision_shape.shape")
		code_lines.append("\tquery.transform = collision_shape.global_transform")
		code_lines.append("\tquery.collision_mask = 0xFFFFFFFF  # Detect all layers")
		code_lines.append("\tquery.exclude = [self]")
		code_lines.append("\t")
		code_lines.append("\t# Query for overlapping bodies")
		code_lines.append("\tvar results = space_state.intersect_shape(query, 32)")
		code_lines.append("\t")
		code_lines.append("\t# Filter results")
		code_lines.append("\tvar _detected_objects = []")
		code_lines.append("\tfor result in results:")
		code_lines.append("\t\tvar obj = result.collider")
		code_lines.append("\t\tif not obj:")
		code_lines.append("\t\t\tcontinue")
		code_lines.append("\t\t")
		code_lines.append("\t\t# Check distance from this object")
		code_lines.append("\t\tvar dist = global_position.distance_to(obj.global_position)")
		code_lines.append("\t\tif dist > %.2f:" % distance)
		code_lines.append("\t\t\tcontinue")
		code_lines.append("\t\t")
		
		# Apply group filter if specified
		if not target_group.is_empty():
			code_lines.append("\t\tif obj.is_in_group(\"%s\"):" % target_group)
			code_lines.append("\t\t\t_detected_objects.append(obj)")
		else:
			code_lines.append("\t\t_detected_objects.append(obj)")
		
		code_lines.append("\t")
	else:
		# Original distance-based detection
		# Get all nodes in the scene tree or in a specific group
		if target_group.is_empty():
			code_lines.append("\tvar _potential_targets = get_tree().get_nodes_in_group(\"\")")
			code_lines.append("\tif _potential_targets.is_empty():")
			code_lines.append("\t\t# No group specified, scan all Node3D objects in scene")
			code_lines.append("\t\t_potential_targets = []")
			code_lines.append("\t\tfor child in get_tree().root.get_children():")
			code_lines.append("\t\t\t_potential_targets.append_array(_get_all_node3d_recursive(child))")
		else:
			code_lines.append("\tvar _potential_targets = get_tree().get_nodes_in_group(\"%s\")" % target_group)
	
		code_lines.append("\t")
		code_lines.append("\tvar _detected_objects = []")
		code_lines.append("\t")
		
		# Determine the forward vector based on axis
		var forward_vector = "Vector3.ZERO"
		var skip_angle_check = false
		match axis:
			"all":
				# Don't check angle for "all" - detect in all directions
				skip_angle_check = true
			"+x":
				forward_vector = "Vector3.RIGHT"  # Positive X
			"-x":
				forward_vector = "Vector3.LEFT"   # Negative X
			"+y":
				forward_vector = "Vector3.UP"     # Positive Y
			"-y":
				forward_vector = "Vector3.DOWN"   # Negative Y
			"+z":
				forward_vector = "Vector3.BACK"   # Positive Z
			"-z":
				forward_vector = "Vector3.FORWARD"  # Negative Z (Godot's forward)
		
		# Detection loop
		code_lines.append("\tfor target in _potential_targets:")
		code_lines.append("\t\tif target == self or not target is Node3D:")
		code_lines.append("\t\t\tcontinue")
		code_lines.append("\t\t")
		code_lines.append("\t\tvar target_pos = target.global_position")
		code_lines.append("\t\tvar self_pos = global_position")
		code_lines.append("\t\tvar to_target = target_pos - self_pos")
		code_lines.append("\t\tvar dist = to_target.length()")
		code_lines.append("\t\t")
		code_lines.append("\t\t# Check distance")
		code_lines.append("\t\tif dist > %.2f or dist < 0.01:" % distance)
		code_lines.append("\t\t\tcontinue")
		code_lines.append("\t\t")
		
		# Only check angle if not 360 degrees AND not "all" axis
		if angle < 360.0 and not skip_angle_check:
			code_lines.append("\t\t# Check angle")
			code_lines.append("\t\tvar forward = global_transform.basis * %s" % forward_vector)
			code_lines.append("\t\tvar direction = to_target.normalized()")
			code_lines.append("\t\tvar angle_to_target = rad_to_deg(forward.angle_to(direction))")
			code_lines.append("\t\t")
			code_lines.append("\t\tif angle_to_target > %.2f:" % (angle / 2.0))
			code_lines.append("\t\t\tcontinue")
			code_lines.append("\t\t")
		
		code_lines.append("\t\t_detected_objects.append(target)")
		code_lines.append("\t")
	
	# Store detected object if requested
	if store_object and not object_var.is_empty():
		# Sanitize variable name
		var sanitized_var = object_var.strip_edges().to_lower().replace(" ", "_")
		var regex = RegEx.new()
		regex.compile("[^a-z0-9_]")
		sanitized_var = regex.sub(sanitized_var, "", true)
		
		code_lines.append("\t# Store first detected object")
		code_lines.append("\tif _detected_objects.size() > 0:")
		code_lines.append("\t\tself.%s = _detected_objects[0]" % sanitized_var)
		code_lines.append("\telse:")
		code_lines.append("\t\tself.%s = null" % sanitized_var)
		code_lines.append("\t")
	
	# Return based on detection mode
	match detection_mode:
		"any":
			code_lines.append("\tvar _result = _detected_objects.size() > 0")
		"all":
			if target_group.is_empty():
				code_lines.append("\tvar _result = false # Cannot use 'all' mode without a target group")
			else:
				code_lines.append("\tvar _total_in_group = get_tree().get_nodes_in_group(\"%s\").size()" % target_group)
				code_lines.append("\tvar _result = _detected_objects.size() == _total_in_group and _total_in_group > 0")
		"none":
			code_lines.append("\tvar _result = _detected_objects.size() == 0")
	
	# Apply inverse if enabled
	if inverse:
		code_lines.append("\treturn not _result  # Inverse enabled")
	else:
		code_lines.append("\treturn _result")
	
	code_lines.append("var sensor_active = _proximity_check.call()")
	
	# Add helper function for recursive Node3D search (only if no group specified)
	var member_vars = []
	if target_group.is_empty():
		code_lines.append("")
		code_lines.append("# Helper function for radar sensor")
		code_lines.append("func _get_all_node3d_recursive(node: Node) -> Array:")
		code_lines.append("\tvar result = []")
		code_lines.append("\tif node is Node3D and node != self:")
		code_lines.append("\t\tresult.append(node)")
		code_lines.append("\tfor child in node.get_children():")
		code_lines.append("\t\tresult.append_array(_get_all_node3d_recursive(child))")
		code_lines.append("\treturn result")
	
	return {
		"sensor_code": "\n".join(code_lines)
	}
