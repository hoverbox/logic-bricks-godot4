@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Moves the object by translating its position


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Location"


func _initialize_properties() -> void:
	properties = {
		"movement_method": "translate",  # "translate", "velocity", "position"
		"x": "0.0",
		"y": "0.0",
		"z": "0.0",
		"space": "local"  # "local" or "global"
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "movement_method",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Translate,Velocity,Position",
			"default": "translate"
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
		}
	]


## Convert a value to a code expression.
## If it's a number (or string of a number), returns the numeric literal.
## Otherwise returns it as-is (a variable name or expression).
func _to_expr(val) -> String:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return "%.3f" % val
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.0"
	if s.is_valid_float() or s.is_valid_int():
		return "%.3f" % float(s)
	return s


## Check if a value is a literal zero. Variable/expression values are treated as non-zero.
func _is_zero(val) -> bool:
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return float(val) == 0.0
	var s = str(val).strip_edges()
	if s.is_empty():
		return true
	if s.is_valid_float() or s.is_valid_int():
		return float(s) == 0.0
	return false


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var movement_method = properties.get("movement_method", "translate")
	var x = properties.get("x", "0.0")
	var y = properties.get("y", "0.0")
	var z = properties.get("z", "0.0")
	var space = properties.get("space", "local")
	
	# Normalize values to lowercase
	if typeof(movement_method) == TYPE_STRING:
		movement_method = movement_method.to_lower()
	if typeof(space) == TYPE_STRING:
		space = space.to_lower()
	
	var code = ""
	var vx = _to_expr(x)
	var vy = _to_expr(y)
	var vz = _to_expr(z)
	
	match movement_method:
		"translate":
			# Direct translation - works on all Node3D
			if space == "local":
				code = "translate(Vector3(%s, %s, %s))" % [vx, vy, vz]
			else:
				code = "global_position += Vector3(%s, %s, %s)" % [vx, vy, vz]
		
		"velocity":
			# Set velocity - for CharacterBody3D using move_and_slide()
			if space == "local":
				code = "velocity = global_transform.basis * Vector3(%s, %s, %s)\nmove_and_slide()" % [vx, vy, vz]
			else:
				code = "velocity = Vector3(%s, %s, %s)\nmove_and_slide()" % [vx, vy, vz]
		
		"position":
			# Direct position assignment - instant teleport
			if space == "local":
				code = "position += Vector3(%s, %s, %s)" % [vx, vy, vz]
			else:
				code = "global_position = Vector3(%s, %s, %s)" % [vx, vy, vz]
		
		_:
			# Fallback to translate
			code = "translate(Vector3(%s, %s, %s))" % [vx, vy, vz]
	
	return {
		"actuator_code": code
	}
