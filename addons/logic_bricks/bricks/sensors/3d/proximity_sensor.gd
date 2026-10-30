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
		"store_object": false,       # If true, stores the nearest detected object in a variable
		"object_variable": "",       # Variable name to store detected object (only if store_object is true)
		"check_interval": 0.0        # Seconds between checks; 0 = every frame
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_group",
			"group_picker": true,
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
			"name": "object_variable", "required": true, "required_label": "a variable to store the detected object", "required_if": {"store_object": true},
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "check_interval",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,5.0,0.05",
			"default": 0.0
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
		"check_interval": "Seconds between checks. 0 = check every frame.\nChecking less often saves work when many objects use Proximity; between checks the trigger keeps its last result. 0.2 (five times a second) is usually plenty for enemies noticing the player.",
	}


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var store_obj = properties.get("store_object", false)

	# Show object_variable only when store_object is true
	for child in _get_field_names():
		if true:
			var prop_name = child
			if prop_name == "object_variable":
				shown[child] = store_obj
	return shown


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_group = properties.get("target_group", "")
	var axis = properties.get("axis", "all")
	var detection_mode = properties.get("detection_mode", "any")
	var inverse = properties.get("inverse", false)
	var store_object = properties.get("store_object", false)
	var object_var = properties.get("object_variable", "")

	# Normalize — PROPERTY_HINT_ENUM stores an integer index at runtime
	var axis_names = ["all", "+x", "-x", "+y", "-y", "+z", "-z"]
	if typeof(axis) == TYPE_INT:
		axis = axis_names[axis] if axis < axis_names.size() else "all"
	elif typeof(axis) == TYPE_STRING:
		axis = axis.to_lower()

	var detection_mode_names = ["any", "all", "none"]
	if typeof(detection_mode) == TYPE_INT:
		detection_mode = detection_mode_names[detection_mode] if detection_mode < detection_mode_names.size() else "any"
	elif typeof(detection_mode) == TYPE_STRING:
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
		code_lines.append("var _prox_targets = get_tree().get_nodes_in_group(\"%s\")" % _gd_string(str(target_group)))

	code_lines.append("var _detected_objects: Array[Node] = []")
	var keep_nearest: bool = store_object and not str(object_var).strip_edges().is_empty()
	if keep_nearest:
		code_lines.append("var _prox_nearest: Node = null")
		code_lines.append("var _prox_nearest_dist: float = INF")
	code_lines.append("")

	# Determine forward vector for angle check
	# Use a local-space basis vector that gets transformed to world space at runtime
	var local_axis_vector = "Vector3.ZERO"
	# Angle 360 = no cone. A variable/math angle keeps the check: half of 360+ is never exceeded.
	var angle_number = _literal_number("angle", 360.0)
	var skip_angle_check = angle_number != null and angle_number >= 360.0
	match axis:
		"+x": local_axis_vector = "Vector3.RIGHT"
		"-x": local_axis_vector = "Vector3.LEFT"
		"+y": local_axis_vector = "Vector3.UP"
		"-y": local_axis_vector = "Vector3.DOWN"
		"+z": local_axis_vector = "Vector3.BACK"   # Godot's -Z is local forward, +Z is back
		"-z": local_axis_vector = "Vector3.FORWARD"
		"all": skip_angle_check = true

	# Detection loop
	code_lines.append("for _pt in _prox_targets:")
	code_lines.append("\tif _pt == self or not _pt is Node3D:")
	code_lines.append("\t\tcontinue")
	code_lines.append("\tvar _to_target = _pt.global_position - global_position")
	code_lines.append("\tvar _dist = _to_target.length()")
	code_lines.append("\tif _dist > %s or _dist < 0.01:" % _num("distance", 10.0, 2))
	code_lines.append("\t\tcontinue")

	# Angle check (only if not full circle and not "all" axis)
	# Transform the local axis into world space using global_basis so the
	# cone rotates with the object instead of staying fixed in world space.
	if not skip_angle_check:
		code_lines.append("\tvar _forward = global_basis * %s" % local_axis_vector)
		code_lines.append("\tvar _angle_to = rad_to_deg(_forward.angle_to(_to_target.normalized()))")
		if angle_number == null:
			code_lines.append("\tif _angle_to > %s / 2.0:" % _num("angle", 360.0))
		else:
			code_lines.append("\tif _angle_to > %.2f:" % (angle_number / 2.0))
		code_lines.append("\t\tcontinue")

	code_lines.append("\t_detected_objects.append(_pt)")
	if keep_nearest:
		code_lines.append("\tif _dist < _prox_nearest_dist:")
		code_lines.append("\t\t_prox_nearest_dist = _dist")
		code_lines.append("\t\t_prox_nearest = _pt")
	code_lines.append("")

	# Store detected object if requested
	if store_object and not object_var.is_empty():
		var sanitized_var = object_var.strip_edges().replace(" ", "_")
		var regex = RegEx.new()
		regex.compile("[^a-zA-Z0-9_]")
		sanitized_var = regex.sub(sanitized_var, "", true)

		code_lines.append("# Store the nearest detected object (null when nothing is in range)")
		code_lines.append("%s = _prox_nearest" % sanitized_var)
		code_lines.append("")

	# Determine result based on detection mode
	match detection_mode:
		"any":
			code_lines.append("var _prox_result = _detected_objects.size() > 0")
		"all":
			if target_group.is_empty():
				code_lines.append("var _prox_result = false  # Cannot use 'all' mode without a target group")
			else:
				code_lines.append("var _prox_total = get_tree().get_nodes_in_group(\"%s\").size()" % _gd_string(str(target_group)))
				code_lines.append("var _prox_result = _detected_objects.size() == _prox_total and _prox_total > 0")
		"none":
			code_lines.append("var _prox_result = _detected_objects.size() == 0")

	# Apply inverse
	if inverse:
		code_lines.append("var sensor_active = not _prox_result")
	else:
		code_lines.append("var sensor_active = _prox_result")

	var interval_number = _literal_number("check_interval", 0.0)
	var interval = _num("check_interval") if interval_number == null else maxf(0.0, interval_number)
	var timed := _wrap_sensor_interval(code_lines, interval, chain_name)
	var result := {"sensor_code": "\n".join(timed["code"])}
	if not timed["member_vars"].is_empty():
		result["member_vars"] = timed["member_vars"]
	return result
