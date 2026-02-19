@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Motion Actuator - Unified actuator for all movement types
## Combines Location, Rotation, Force, Torque, and Linear Velocity


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Motion"


func _initialize_properties() -> void:
	properties = {
		"motion_type": "location",  # location, rotation, force, torque, linear_velocity
		
		# Location properties
		"movement_method": "translate",  # translate, velocity, position
		
		# Linear Velocity properties
		"velocity_mode": "set",  # set, add, average
		
		# Common properties
		"x": "0.0",
		"y": "0.0",
		"z": "0.0",
		"space": "local",  # local or global
		"call_move_and_slide": false  # Set true if no other actuator calls move_and_slide
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "motion_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Location,Rotation,Force,Torque,Linear Velocity",
			"default": "location"
		},
		{
			"name": "movement_method",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Translate,Velocity,Position",
			"default": "translate"
		},
		{
			"name": "velocity_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Set,Add,Average",
			"default": "set"
		},
		{
			"name": "x",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "y",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "z",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "space",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Local,Global",
			"default": "local"
		},
		{
			"name": "call_move_and_slide",
			"type": TYPE_BOOL,
			"default": false
		}
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Moves or rotates the node.\nX/Y/Z fields accept numbers, variable names, or math expressions.",
		"motion_type": "Location: move by offset or set position\nRotation: rotate by degrees\nForce/Torque: physics (RigidBody3D)\nLinear Velocity: set velocity (RigidBody3D)",
		"movement_method": "Translate: move by offset each frame\nVelocity: set velocity on active axes\nPosition: set absolute position",
		"velocity_mode": "Set: replace velocity\nAdd: accumulate\nAverage: blend",
		"x": "X axis value. Accepts:\n• A number: 5.0\n• A variable: speed\n• An expression: input_x * speed",
		"y": "Y axis value. Accepts:\n• A number: 5.0\n• A variable: speed\n• An expression: input_y * speed",
		"z": "Z axis value. Accepts:\n• A number: 5.0\n• A variable: speed\n• An expression: input_z * speed",
		"space": "Local: relative to node's rotation\nGlobal: world axes",
		"call_move_and_slide": "Call move_and_slide() after setting velocity.\nEnable if no other actuator does this.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var motion_type = properties.get("motion_type", "location")
	
	# Normalize motion_type
	if typeof(motion_type) == TYPE_STRING:
		motion_type = motion_type.to_lower().replace(" ", "_")
	
	# Generate code based on motion type
	match motion_type:
		"location":
			return _generate_location_code(node, chain_name)
		"rotation":
			return _generate_rotation_code(node, chain_name)
		"force":
			return _generate_force_code(node, chain_name)
		"torque":
			return _generate_torque_code(node, chain_name)
		"linear_velocity":
			return _generate_linear_velocity_code(node, chain_name)
		_:
			return {"actuator_code": "# Unknown motion type: %s" % motion_type}


## Convert a value to a code expression.
## If it's a number (or string of a number), returns the float literal.
## Otherwise returns it as-is (a variable name).
func _to_expr(val) -> String:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return "%.3f" % val
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s


## Check if a value is a literal zero
func _is_zero(val) -> bool:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return val == 0.0
	var s = str(val).strip_edges()
	if s.is_empty():
		return true
	if s.is_valid_float() or s.is_valid_int():
		return float(s) == 0.0
	# It's a variable name — not zero
	return false


func _generate_location_code(node: Node, chain_name: String) -> Dictionary:
	var x = properties.get("x", 0.0)
	var y = properties.get("y", 0.0)
	var z = properties.get("z", 0.0)
	var space = properties.get("space", "local")
	var movement_method = properties.get("movement_method", "translate")
	
	# Normalize
	if typeof(space) == TYPE_STRING:
		space = space.to_lower()
	if typeof(movement_method) == TYPE_STRING:
		movement_method = movement_method.to_lower()
	
	var code_lines: Array[String] = []
	var call_mas = properties.get("call_move_and_slide", false)
	var vx = _to_expr(x)
	var vy = _to_expr(y)
	var vz = _to_expr(z)
	var vec = "Vector3(%s, %s, %s)" % [vx, vy, vz]
	
	match movement_method:
		"translate":
			if space == "local":
				code_lines.append("# Move in local space")
				code_lines.append("translate(%s)" % vec)
			else:
				code_lines.append("# Move in global space")
				code_lines.append("global_position += %s" % vec)
		
		"velocity":
			code_lines.append("# Set velocity on active axes")
			if space == "local":
				code_lines.append("var _motion_vel = global_transform.basis * %s" % vec)
				if not _is_zero(x):
					code_lines.append("velocity.x = _motion_vel.x")
				if not _is_zero(y):
					code_lines.append("velocity.y = _motion_vel.y")
				if not _is_zero(z):
					code_lines.append("velocity.z = _motion_vel.z")
			else:
				if not _is_zero(x):
					code_lines.append("velocity.x = %s" % vx)
				if not _is_zero(y):
					code_lines.append("velocity.y = %s" % vy)
				if not _is_zero(z):
					code_lines.append("velocity.z = %s" % vz)
			if call_mas:
				code_lines.append("move_and_slide()")
		
		"position":
			if space == "local":
				code_lines.append("# Set local position")
				code_lines.append("position = %s" % vec)
			else:
				code_lines.append("# Set global position")
				code_lines.append("global_position = %s" % vec)
	
	return {"actuator_code": "\n".join(code_lines)}


func _generate_rotation_code(node: Node, chain_name: String) -> Dictionary:
	var x = properties.get("x", 0.0)
	var y = properties.get("y", 0.0)
	var z = properties.get("z", 0.0)
	var space = properties.get("space", "local")
	
	# Normalize
	if typeof(space) == TYPE_STRING:
		space = space.to_lower()
	
	var code_lines: Array[String] = []
	var vx = _to_expr(x)
	var vy = _to_expr(y)
	var vz = _to_expr(z)
	
	if space == "local":
		if not _is_zero(x):
			code_lines.append("rotate_x(deg_to_rad(%s))" % vx)
		if not _is_zero(y):
			code_lines.append("rotate_y(deg_to_rad(%s))" % vy)
		if not _is_zero(z):
			code_lines.append("rotate_z(deg_to_rad(%s))" % vz)
	else:
		if not _is_zero(x) or not _is_zero(y) or not _is_zero(z):
			code_lines.append("global_rotation += Vector3(deg_to_rad(%s), deg_to_rad(%s), deg_to_rad(%s))" % [vx, vy, vz])
	
	var code = "\n".join(code_lines) if code_lines.size() > 0 else "pass"
	
	return {"actuator_code": code}


func _generate_force_code(node: Node, chain_name: String) -> Dictionary:
	var x = properties.get("x", 0.0)
	var y = properties.get("y", 0.0)
	var z = properties.get("z", 0.0)
	var space = properties.get("space", "local")
	
	if typeof(space) == TYPE_STRING:
		space = space.to_lower()
	
	var code_lines: Array[String] = []
	
	if not node is RigidBody3D:
		code_lines.append("# WARNING: Force actuator only works with RigidBody3D!")
		code_lines.append("# Current node type: %s" % node.get_class())
		code_lines.append("push_warning(\"Force actuator requires RigidBody3D, but node '%s' is %s\")" % [node.name, node.get_class()])
		code_lines.append("# Force NOT applied")
		return {"actuator_code": "\n".join(code_lines)}
	
	var vec = "Vector3(%s, %s, %s)" % [_to_expr(x), _to_expr(y), _to_expr(z)]
	
	if space == "local":
		code_lines.append("# Apply force in local space")
		code_lines.append("apply_central_force(global_transform.basis * %s)" % vec)
	else:
		code_lines.append("# Apply force in global space")
		code_lines.append("apply_central_force(%s)" % vec)
	
	return {"actuator_code": "\n".join(code_lines)}


func _generate_torque_code(node: Node, chain_name: String) -> Dictionary:
	var x = properties.get("x", 0.0)
	var y = properties.get("y", 0.0)
	var z = properties.get("z", 0.0)
	var space = properties.get("space", "local")
	
	if typeof(space) == TYPE_STRING:
		space = space.to_lower()
	
	var code_lines: Array[String] = []
	
	if not node is RigidBody3D:
		code_lines.append("# WARNING: Torque actuator only works with RigidBody3D!")
		code_lines.append("# Current node type: %s" % node.get_class())
		code_lines.append("push_warning(\"Torque actuator requires RigidBody3D, but node '%s' is %s\")" % [node.name, node.get_class()])
		code_lines.append("# Torque NOT applied")
		return {"actuator_code": "\n".join(code_lines)}
	
	var vec = "Vector3(%s, %s, %s)" % [_to_expr(x), _to_expr(y), _to_expr(z)]
	
	if space == "local":
		code_lines.append("# Apply torque in local space")
		code_lines.append("apply_torque(global_transform.basis * %s)" % vec)
	else:
		code_lines.append("# Apply torque in global space")
		code_lines.append("apply_torque(%s)" % vec)
	
	return {"actuator_code": "\n".join(code_lines)}


func _generate_linear_velocity_code(node: Node, chain_name: String) -> Dictionary:
	var x = properties.get("x", 0.0)
	var y = properties.get("y", 0.0)
	var z = properties.get("z", 0.0)
	var space = properties.get("space", "local")
	var velocity_mode = properties.get("velocity_mode", "set")
	
	if typeof(space) == TYPE_STRING:
		space = space.to_lower()
	if typeof(velocity_mode) == TYPE_STRING:
		velocity_mode = velocity_mode.to_lower()
	
	var code_lines: Array[String] = []
	
	if not node is RigidBody3D:
		code_lines.append("# WARNING: Linear Velocity actuator only works with RigidBody3D!")
		code_lines.append("# Current node type: %s" % node.get_class())
		code_lines.append("push_warning(\"Linear Velocity actuator requires RigidBody3D, but node '%s' is %s\")" % [node.name, node.get_class()])
		code_lines.append("# Velocity NOT applied")
		return {"actuator_code": "\n".join(code_lines)}
	
	var vec = "Vector3(%s, %s, %s)" % [_to_expr(x), _to_expr(y), _to_expr(z)]
	if space == "local":
		vec = "global_transform.basis * " + vec
	
	match velocity_mode:
		"set":
			code_lines.append("# Set linear velocity")
			code_lines.append("linear_velocity = %s" % vec)
		
		"add":
			code_lines.append("# Add to linear velocity")
			code_lines.append("linear_velocity += %s" % vec)
		
		"average":
			code_lines.append("# Average with current linear velocity")
			code_lines.append("linear_velocity = (linear_velocity + %s) / 2.0" % vec)
	
	return {"actuator_code": "\n".join(code_lines)}
