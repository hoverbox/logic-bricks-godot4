@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Collision Sensor - Detects collisions via an Area3D node
## The Area3D is located by node path (relative to this node)
## Supports body_entered, body_exited, and continuous overlap detection


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Collision"


func _initialize_properties() -> void:
	properties = {
		"area_node":      "Area3D",    # Node path relative to this node
		"detection_mode": "entered",
		"detect_bodies":  true,
		"detect_areas":   false,
		"filter_type":    "any",
		"filter_value":   "",
		"invert":         false
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "area_node",
			"type": TYPE_STRING,
			"default": "Area3D"
		},
		{
			"name": "detection_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Entered,Exited,Overlapping",
			"default": "entered"
		},
		{
			"name": "detect_bodies",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "detect_areas",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "filter_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Any,Group,Name",
			"default": "any"
		},
		{
			"name": "filter_value",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "invert",
			"type": TYPE_BOOL,
			"default": false
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Detects collisions via an Area3D node.\nType the node path relative to this node.",
		"area_node":      "Path to the Area3D node, relative to this node.\nExamples: Area3D  HitBox/Area3D  ../Area3D",
		"detection_mode": "Entered: fires once when something enters.\nExited: fires once when something leaves.\nOverlapping: active every frame while overlapping.",
		"detect_bodies":  "Detect physics bodies (CharacterBody3D, RigidBody3D, etc.).",
		"detect_areas":   "Detect other Area3D nodes.",
		"filter_type":    "Any: detect everything.\nGroup: only detect nodes in a specific group.\nName: only detect a node with a specific name.",
		"filter_value":   "Group name or node name to filter by.",
		"invert":         "Invert the result.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var area_path    = str(properties.get("area_node", "Area3D")).strip_edges()
	var detection_mode = properties.get("detection_mode", "entered")
	var detect_bodies  = properties.get("detect_bodies", true)
	var detect_areas   = properties.get("detect_areas", false)
	var filter_type    = properties.get("filter_type", "any")
	var filter_value   = properties.get("filter_value", "")
	var invert         = properties.get("invert", false)

	if area_path.is_empty():
		area_path = "Area3D"

	# Normalize
	if typeof(detection_mode) == TYPE_STRING:
		detection_mode = detection_mode.to_lower()
	if typeof(filter_type) == TYPE_STRING:
		filter_type = filter_type.to_lower()

	# Unique variable names per chain
	var area_var     = "_collision_area_%s" % chain_name
	var flag_var     = "_collision_%s_%s" % [detection_mode, chain_name]
	var collided_var = "_collided_with_%s" % chain_name

	var code_lines:  Array[String] = []
	var member_vars: Array[String] = []
	var ready_lines: Array[String] = []

	match detection_mode:
		"entered", "exited":
			# Signal mode needs a persistent Area3D reference at class scope
			member_vars.append("var %s: Area3D = null" % area_var)
			var result = _generate_signal_code(
				detection_mode, area_var, area_path, flag_var, collided_var,
				detect_bodies, detect_areas, filter_type, filter_value, chain_name, invert
			)
			member_vars.append_array(result["member_vars"])
			ready_lines.append_array(result["ready_lines"])
			code_lines.append_array(result["sensor_lines"])

		"overlapping":
			# Overlapping resolves the node per-frame inside a lambda — no member var needed
			code_lines.append_array(
				_generate_overlapping_code(
					area_path, detect_bodies, detect_areas, filter_type, filter_value, invert
				)
			)

	var result = {
		"sensor_code": "\n".join(code_lines),
		"member_vars": member_vars
	}

	if ready_lines.size() > 0:
		result["ready_code"] = ready_lines

	return result


## Generate signal-based detection code (entered / exited)
func _generate_signal_code(detection_mode: String, area_var: String, area_path: String,
							flag_var: String, collided_var: String,
							detect_bodies: bool, detect_areas: bool,
							filter_type: String, filter_value: String, chain_name: String,
							invert: bool = false) -> Dictionary:
	var member_vars: Array[String] = []
	var ready_lines: Array[String] = []
	var sensor_lines: Array[String] = []

	var body_signal  = "body_entered" if detection_mode == "entered" else "body_exited"
	var area_signal  = "area_entered" if detection_mode == "entered" else "area_exited"
	var body_callback = "_on_collision_%s_%s_body" % [chain_name, detection_mode]
	var area_callback = "_on_collision_%s_%s_area" % [chain_name, detection_mode]

	# State tracking vars
	member_vars.append("var %s: bool = false" % flag_var)
	member_vars.append("var %s = null" % collided_var)

	# Signal callback functions
	if detect_bodies:
		member_vars.append("")
		member_vars.append("func %s(body) -> void:" % body_callback)
		member_vars.append("\t%s = true" % flag_var)
		member_vars.append("\t%s = body" % collided_var)

	if detect_areas:
		member_vars.append("")
		member_vars.append("func %s(area) -> void:" % area_callback)
		member_vars.append("\t%s = true" % flag_var)
		member_vars.append("\t%s = area" % collided_var)

	# _ready(): resolve node by path and connect signals
	ready_lines.append("# Collision Sensor: resolve Area3D by path")
	ready_lines.append("%s = get_node_or_null(\"%s\") as Area3D" % [area_var, area_path])
	ready_lines.append("if %s:" % area_var)
	if detect_bodies:
		ready_lines.append("\tif not %s.%s.is_connected(%s):" % [area_var, body_signal, body_callback])
		ready_lines.append("\t\t%s.%s.connect(%s)" % [area_var, body_signal, body_callback])
	if detect_areas:
		ready_lines.append("\tif not %s.%s.is_connected(%s):" % [area_var, area_signal, area_callback])
		ready_lines.append("\t\t%s.%s.connect(%s)" % [area_var, area_signal, area_callback])
	ready_lines.append("else:")
	ready_lines.append("\tpush_warning(\"Collision Sensor: No Area3D found at path '%s'\")" % area_path)

	# Sensor evaluation code (runs each frame)
	sensor_lines.append("var sensor_active = (func():")
	sensor_lines.append("\tif not %s:" % flag_var)
	sensor_lines.append("\t\treturn %s" % ("true" if invert else "false"))

	if filter_type != "any" and not filter_value.is_empty():
		sensor_lines.append("\tif %s:" % collided_var)
		if filter_type == "group":
			sensor_lines.append("\t\tif %s.is_in_group(\"%s\"):" % [collided_var, filter_value])
		elif filter_type == "name":
			sensor_lines.append("\t\tif %s.name == \"%s\":" % [collided_var, filter_value])
		sensor_lines.append("\t\t\t%s = false" % flag_var)
		sensor_lines.append("\t\t\treturn %s" % ("false" if invert else "true"))
		sensor_lines.append("\t%s = false  # Didn't match filter" % flag_var)
		sensor_lines.append("\treturn %s" % ("true" if invert else "false"))
	else:
		sensor_lines.append("\t%s = false" % flag_var)
		sensor_lines.append("\treturn %s" % ("false" if invert else "true"))

	sensor_lines.append(").call()")

	return {
		"member_vars": member_vars,
		"ready_lines": ready_lines,
		"sensor_lines": sensor_lines
	}


## Generate overlap/polling detection code
func _generate_overlapping_code(area_path: String,
								detect_bodies: bool, detect_areas: bool,
								filter_type: String, filter_value: String,
								invert: bool = false) -> Array[String]:
	var lines: Array[String] = []

	lines.append("var sensor_active = (func():")
	lines.append("\tvar _area = get_node_or_null(\"%s\") as Area3D" % area_path)
	lines.append("\tif not _area:")
	lines.append("\t\tpush_warning(\"Collision Sensor: No Area3D found at path '%s'\")" % area_path)
	lines.append("\t\treturn false")
	lines.append("\tvar _detected = []")

	if detect_bodies:
		lines.append("\t_detected.append_array(_area.get_overlapping_bodies())")
	if detect_areas:
		lines.append("\t_detected.append_array(_area.get_overlapping_areas())")

	lines.append("\t")
	_add_filter_code(lines, filter_type, filter_value, invert)
	lines.append(").call()")

	return lines


func _add_filter_code(lines: Array[String], filter_type: String, filter_value: String, invert: bool = false) -> void:
	var t = "true"
	var f = "false"
	if invert:
		t = "false"
		f = "true"
	if filter_type == "any":
		lines.append("\treturn _detected.size() > 0" if not invert else "\treturn _detected.size() == 0")
	elif filter_type == "group" and not filter_value.is_empty():
		if invert:
			lines.append("\treturn not _detected.any(func(obj): return obj.is_in_group(\"%s\"))" % filter_value)
		else:
			lines.append("\treturn _detected.any(func(obj): return obj.is_in_group(\"%s\"))" % filter_value)
	elif filter_type == "name" and not filter_value.is_empty():
		if invert:
			lines.append("\treturn not _detected.any(func(obj): return obj.name == \"%s\")" % filter_value)
		else:
			lines.append("\treturn _detected.any(func(obj): return obj.name == \"%s\")" % filter_value)
	else:
		lines.append("\treturn %s" % f)
