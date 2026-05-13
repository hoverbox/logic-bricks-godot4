@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Rotates the object around its axes


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Rotation"


func _initialize_properties() -> void:
	properties = {
		"x": "0.0",
		"y": "0.0",
		"z": "0.0",
		"space": "local"  # "local" or "global"
	}


func get_property_definitions() -> Array:
	return [
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
	var x = properties.get("x", "0.0")
	var y = properties.get("y", "0.0")
	var z = properties.get("z", "0.0")
	var space = properties.get("space", "local")
	
	var code_lines = []
	var vx = _to_expr(x)
	var vy = _to_expr(y)
	var vz = _to_expr(z)
	
	if space == "local":
		# Only add rotation for non-zero values
		if not _is_zero(x):
			code_lines.append("rotate_x(deg_to_rad(%s))" % vx)
		if not _is_zero(y):
			code_lines.append("rotate_y(deg_to_rad(%s))" % vy)
		if not _is_zero(z):
			code_lines.append("rotate_z(deg_to_rad(%s))" % vz)
	else:
		# Global rotation - only if at least one axis is non-zero
		if not _is_zero(x) or not _is_zero(y) or not _is_zero(z):
			code_lines.append("global_rotation += Vector3(deg_to_rad(%s), deg_to_rad(%s), deg_to_rad(%s))" % [vx, vy, vz])
	
	# Join lines or return pass if no rotation
	var code = "\n".join(code_lines) if code_lines.size() > 0 else "pass"
	
	return {
		"actuator_code": code
	}
