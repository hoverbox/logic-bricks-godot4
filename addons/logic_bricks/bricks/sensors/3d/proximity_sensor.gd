@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Proximity Sensor - Detect objects within range and angle
## Uses distance-based or collision shape detection
## Uses groups to filter detected objects

func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Proximity"


func _initialize_properties() -> void:
	properties = {
		"target_group": "",          # Group to detect (empty = detect all)
		"distance": 10.0,            # Detection distance in meters
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


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Detects objects within a distance and optional angle.\nUses groups to filter which objects are detected.",
		"target_group": "Group name to detect.\nLeave empty to detect all Node3D objects.",
		"distance": "Detection radius in meters.",
		"angle": "Detection cone angle in degrees (360 = all directions).",
		"axis": "Which axis the detection cone faces.\nAll = detect in all directions (ignores angle).",
		"detection_mode": "Any: active if at least one object detected\nAll: active if all objects in group detected\nNone: active if no objects detected",
		"inverse": "Invert the result.",
		"store_object": "Store the nearest detected object in a variable.",
		"object_variable": "Variable name to store the detected object.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_group = properties.get("target_group", "")
	var distance = properties.get("distance", 10.0)
	var angle = properties.get("angle", 360.0)
	var axis = properties.get("axis", "all")
	var detection_mode = properties.get("detection_mode", "any")
	var inverse = properties.get("inverse", false)
	var store_object = properties.get("store_object", false)
	var object_var = properties.get("object_variable", "")
	
	# Normalize
	if typeof(axis) == TYPE_STRING:
		axis = axis.to_lower()
	if typeof(detection_mode) == TYPE_STRING:
		detection_mode = detection_mode.to_lower()
	
	var code_lines: Array[String] = []
	
	# Get potential targets
	if target_group.is_empty():
		code_lines.append("# Proximity: scan all Node3D objects")
		code_lines.append("var _prox_targets: Array[Node] = []")
		code_lines.append("for _n in get_tree().root.get_children():")
		code_lines.append("\tif _n is Node3D and _n != self:")
		code_lines.append("\t\t_prox_targets.append(_n)")
		code_lines.append("\tfor _c in _n.get_children():")
		code_lines.append("\t\tif _c is Node3D and _c != self:")
		code_lines.append("\t\t\t_prox_targets.append(_c)")
	else:
		code_lines.append("var _prox_targets = get_tree().get_nodes_in_group(\"%s\")" % target_group)
	
	code_lines.append("var _detected_objects: Array[Node] = []")
	code_lines.append("")
	
	# Determine forward vector for angle check
	var forward_vector = "Vector3.FORWARD"
	var skip_angle_check = (axis == "all" or angle >= 360.0)
	match axis:
		"+x": forward_vector = "Vector3.RIGHT"
		"-x": forward_vector = "Vector3.LEFT"
		"+y": forward_vector = "Vector3.UP"
		"-y": forward_vector = "Vector3.DOWN"
		"+z": forward_vector = "Vector3.BACK"
		"-z": forward_vector = "Vector3.FORWARD"
	
	# Detection loop
	code_lines.append("for _pt in _prox_targets:")
	code_lines.append("\tif _pt == self or not _pt is Node3D:")
	code_lines.append("\t\tcontinue")
	code_lines.append("\tvar _to_target = _pt.global_position - global_position")
	code_lines.append("\tvar _dist = _to_target.length()")
	code_lines.append("\tif _dist > %.2f or _dist < 0.01:" % distance)
	code_lines.append("\t\tcontinue")
	
	# Angle check (only if not full circle and not "all" axis)
	if not skip_angle_check:
		code_lines.append("\tvar _forward = global_transform.basis * %s" % forward_vector)
		code_lines.append("\tvar _angle_to = rad_to_deg(_forward.angle_to(_to_target.normalized()))")
		code_lines.append("\tif _angle_to > %.2f:" % (angle / 2.0))
		code_lines.append("\t\tcontinue")
	
	code_lines.append("\t_detected_objects.append(_pt)")
	code_lines.append("")
	
	# Store detected object if requested
	if store_object and not object_var.is_empty():
		var sanitized_var = object_var.strip_edges().replace(" ", "_")
		var regex = RegEx.new()
		regex.compile("[^a-zA-Z0-9_]")
		sanitized_var = regex.sub(sanitized_var, "", true)
		
		code_lines.append("# Store nearest detected object")
		code_lines.append("if _detected_objects.size() > 0:")
		code_lines.append("\t%s = _detected_objects[0]" % sanitized_var)
		code_lines.append("else:")
		code_lines.append("\t%s = null" % sanitized_var)
		code_lines.append("")
	
	# Determine result based on detection mode
	match detection_mode:
		"any":
			code_lines.append("var _prox_result = _detected_objects.size() > 0")
		"all":
			if target_group.is_empty():
				code_lines.append("var _prox_result = false  # Cannot use 'all' mode without a target group")
			else:
				code_lines.append("var _prox_total = get_tree().get_nodes_in_group(\"%s\").size()" % target_group)
				code_lines.append("var _prox_result = _detected_objects.size() == _prox_total and _prox_total > 0")
		"none":
			code_lines.append("var _prox_result = _detected_objects.size() == 0")
	
	# Apply inverse
	if inverse:
		code_lines.append("var sensor_active = not _prox_result")
	else:
		code_lines.append("var sensor_active = _prox_result")
	
	return {
		"sensor_code": "\n".join(code_lines)
	}
