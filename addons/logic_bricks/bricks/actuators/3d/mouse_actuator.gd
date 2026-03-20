@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Mouse Actuator - Control mouse cursor and mouse look rotation
## Toggle cursor visibility or rotate object based on mouse movement

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Mouse"


func _initialize_properties() -> void:
	properties = {
		"mode": "cursor_visibility",    # cursor_visibility, mouse_look
		"cursor_visible": false,        # Show/hide cursor
		# Mouse look properties
		"use_x_axis": true,
		"use_y_axis": true,
		"x_target": "self",              # "self" or child node name
		"y_target": "self",              # "self" or child node name
		"x_sensitivity": 0.1,
		"y_sensitivity": 0.1,
		"x_invert": false,               # Invert X axis
		"y_invert": false,               # Invert Y axis
		"x_threshold": 0.0,
		"y_threshold": 0.0,
		"x_min_degrees": 0.0,           # 0 = no limit
		"x_max_degrees": 0.0,           # 0 = no limit
		"y_min_degrees": -90.0,
		"y_max_degrees": 90.0,
		"x_rotation_axis": "y",         # Which object axis to rotate for X mouse movement
		"y_rotation_axis": "x",         # Which object axis to rotate for Y mouse movement
		"x_use_local": false,
		"y_use_local": false,
		"recenter_cursor": true
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Cursor Visibility,Mouse Look",
			"default": "cursor_visibility"
		},
		{
			"name": "cursor_visible",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "use_x_axis",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "use_y_axis",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "x_target",
			"type": TYPE_STRING,
			"default": "self"
		},
		{
			"name": "y_target",
			"type": TYPE_STRING,
			"default": "self"
		},
		{
			"name": "x_sensitivity",
			"type": TYPE_FLOAT,
			"default": 0.1
		},
		{
			"name": "y_sensitivity",
			"type": TYPE_FLOAT,
			"default": 0.1
		},
		{
			"name": "x_invert",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "y_invert",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "x_threshold",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "y_threshold",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "x_min_degrees",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "x_max_degrees",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "y_min_degrees",
			"type": TYPE_FLOAT,
			"default": -90.0
		},
		{
			"name": "y_max_degrees",
			"type": TYPE_FLOAT,
			"default": 90.0
		},
		{
			"name": "x_rotation_axis",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "X,Y,Z",
			"default": "y"
		},
		{
			"name": "y_rotation_axis",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "X,Y,Z",
			"default": "x"
		},
		{
			"name": "x_use_local",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "y_use_local",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "recenter_cursor",
			"type": TYPE_BOOL,
			"default": true
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "cursor_visibility")
	var cursor_visible = properties.get("cursor_visible", false)
	var use_x_axis = properties.get("use_x_axis", true)
	var use_y_axis = properties.get("use_y_axis", true)
	var x_target = properties.get("x_target", "self")
	var y_target = properties.get("y_target", "self")
	var x_sensitivity = float(properties.get("x_sensitivity", 0.1))
	var y_sensitivity = float(properties.get("y_sensitivity", 0.1))
	var x_invert = properties.get("x_invert", false)
	var y_invert = properties.get("y_invert", false)
	var x_threshold = float(properties.get("x_threshold", 0.0))
	var y_threshold = float(properties.get("y_threshold", 0.0))
	var x_min = float(properties.get("x_min_degrees", 0.0))
	var x_max = float(properties.get("x_max_degrees", 0.0))
	var y_min = float(properties.get("y_min_degrees", -90.0))
	var y_max = float(properties.get("y_max_degrees", 90.0))
	var x_rot_axis = properties.get("x_rotation_axis", "y")
	var y_rot_axis = properties.get("y_rotation_axis", "x")
	var x_use_local = properties.get("x_use_local", false)
	var y_use_local = properties.get("y_use_local", false)
	var recenter = properties.get("recenter_cursor", true)
	
	# Normalize
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")
	if typeof(x_rot_axis) == TYPE_STRING:
		x_rot_axis = x_rot_axis.to_lower()
	if typeof(y_rot_axis) == TYPE_STRING:
		y_rot_axis = y_rot_axis.to_lower()
	
	
	var code_lines: Array[String] = []
	
	match mode:
		"cursor_visibility":
			code_lines.append("# Set cursor visibility")
			if cursor_visible:
				code_lines.append("Input.mouse_mode = Input.MOUSE_MODE_VISIBLE")
			else:
				code_lines.append("Input.mouse_mode = Input.MOUSE_MODE_HIDDEN")
		
		"mouse_look":
			code_lines.append("# Mouse look rotation")
			code_lines.append("var _viewport = get_viewport()")
			code_lines.append("var _viewport_size = _viewport.get_visible_rect().size")
			code_lines.append("var _mouse_pos = _viewport.get_mouse_position()")
			code_lines.append("var _center = _viewport_size / 2.0")
			code_lines.append("var _mouse_delta = _mouse_pos - _center")
			code_lines.append("")
			
			if use_x_axis:
				code_lines.append("# X axis (horizontal) mouse movement")
				
				# Determine target node and indentation
				var x_indent = ""
				var x_node_ref = "self" if x_target == "self" else ("get_node_or_null(\"%s\")" % x_target)
				if x_target != "self":
					code_lines.append("var _x_target = %s" % x_node_ref)
					code_lines.append("if _x_target:")
					x_indent = "\t"
				
				code_lines.append("%sif abs(_mouse_delta.x) > %.3f:" % [x_indent, x_threshold])
				var x_mult = 1.0 if x_invert else -1.0
				code_lines.append("%s\tvar _x_rotation = _mouse_delta.x * %.3f * %.1f" % [x_indent, x_sensitivity, x_mult])
				
				# Apply limits if set
				if x_min != 0.0 or x_max != 0.0:
					var axis_index = {"x": "0", "y": "1", "z": "2"}[x_rot_axis]
					var target_prefix = "_x_target." if x_target != "self" else ""
					if x_use_local:
						code_lines.append("%s\tvar _current_rot = %srotation_degrees[%s]" % [x_indent, target_prefix, axis_index])
					else:
						code_lines.append("%s\tvar _current_rot = %sglobal_rotation_degrees[%s]" % [x_indent, target_prefix, axis_index])
					
					code_lines.append("%s\tvar _new_rot = _current_rot + _x_rotation" % x_indent)
					if x_min != 0.0:
						code_lines.append("%s\t_new_rot = max(_new_rot, %.2f)" % [x_indent, x_min])
					if x_max != 0.0:
						code_lines.append("%s\t_new_rot = min(_new_rot, %.2f)" % [x_indent, x_max])
					code_lines.append("%s\t_x_rotation = _new_rot - _current_rot" % x_indent)
				
				# Apply rotation
				var x_axis_vector = {"x": "Vector3.RIGHT", "y": "Vector3.UP", "z": "Vector3.BACK"}[x_rot_axis]
				var target_prefix = "_x_target." if x_target != "self" else ""
				if x_use_local:
					code_lines.append("%s\t%srotate_object_local(%s, deg_to_rad(_x_rotation))" % [x_indent, target_prefix, x_axis_vector])
				else:
					code_lines.append("%s\t%srotate(%s, deg_to_rad(_x_rotation))" % [x_indent, target_prefix, x_axis_vector])
				code_lines.append("")
			
			if use_y_axis:
				code_lines.append("# Y axis (vertical) mouse movement")
				
				# Determine target node and indentation
				var y_indent = ""
				var y_node_ref = "self" if y_target == "self" else ("get_node_or_null(\"%s\")" % y_target)
				if y_target != "self":
					code_lines.append("var _y_target = %s" % y_node_ref)
					code_lines.append("if _y_target:")
					y_indent = "\t"
				
				code_lines.append("%sif abs(_mouse_delta.y) > %.3f:" % [y_indent, y_threshold])
				var y_mult = 1.0 if y_invert else -1.0
				code_lines.append("%s\tvar _y_rotation = _mouse_delta.y * %.3f * %.1f" % [y_indent, y_sensitivity, y_mult])
				
				# Apply limits
				if y_min != 0.0 or y_max != 0.0:
					var axis_index = {"x": "0", "y": "1", "z": "2"}[y_rot_axis]
					var target_prefix = "_y_target." if y_target != "self" else ""
					if y_use_local:
						code_lines.append("%s\tvar _current_rot = %srotation_degrees[%s]" % [y_indent, target_prefix, axis_index])
					else:
						code_lines.append("%s\tvar _current_rot = %sglobal_rotation_degrees[%s]" % [y_indent, target_prefix, axis_index])
					
					code_lines.append("%s\tvar _new_rot = _current_rot + _y_rotation" % y_indent)
					code_lines.append("%s\t_new_rot = clamp(_new_rot, %.2f, %.2f)" % [y_indent, y_min, y_max])
					code_lines.append("%s\t_y_rotation = _new_rot - _current_rot" % y_indent)
				
				# Apply rotation
				var y_axis_vector = {"x": "Vector3.RIGHT", "y": "Vector3.UP", "z": "Vector3.BACK"}[y_rot_axis]
				var target_prefix = "_y_target." if y_target != "self" else ""
				if y_use_local:
					code_lines.append("%s\t%srotate_object_local(%s, deg_to_rad(_y_rotation))" % [y_indent, target_prefix, y_axis_vector])
				else:
					code_lines.append("%s\t%srotate(%s, deg_to_rad(_y_rotation))" % [y_indent, target_prefix, y_axis_vector])
				code_lines.append("")
			
			if recenter:
				code_lines.append("# Recenter cursor")
				code_lines.append("_viewport.warp_mouse(_center)")
	
	return {
		"actuator_code": "\n".join(code_lines)
	}
