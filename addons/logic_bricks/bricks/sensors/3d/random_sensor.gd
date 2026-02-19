@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Radar Sensor - Detect objects within range and angle
## Combination of UPBGE's Near and Radar sensors
## Uses groups to filter detected objects

func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Radar"


func _initialize_properties() -> void:
	properties = {
		"target_group": "",          # Group to detect (empty = detect all)
		"distance": 10.0,            # Detection distance in meters
		"angle": 360.0,              # Detection angle in degrees (0-360, 360 = full circle like Near)
		"axis": "forward",           # Axis to measure angle from: forward (-Z), up (Y), right (X)
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
			"hint_string": "Forward,Up,Right",
			"default": "forward"
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
	
	print("Radar Sensor Debug - group: '%s', distance: %.2f, angle: %.2f, axis: %s, inverse: %s" % [target_group, distance, angle, axis, inverse])
	
	var code_lines: Array[String] = []
	
	# Start the sensor function
	code_lines.append("var sensor_active = (func():")
	
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
	var forward_vector = "Vector3.FORWARD"
	match axis:
		"forward":
			forward_vector = "Vector3.FORWARD"  # -Z axis (Godot's forward)
		"up":
			forward_vector = "Vector3.UP"
		"right":
			forward_vector = "Vector3.RIGHT"
	
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
	
	# Only check angle if not 360 degrees
	if angle < 360.0:
		code_lines.append("\t\t# Check angle (only if not 360 degrees)")
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
	
	code_lines.append(").call()")
	
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
