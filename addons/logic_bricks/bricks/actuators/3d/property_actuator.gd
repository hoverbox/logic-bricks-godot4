@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Property Actuator - Sets a property on this node or a target node
## Can set visibility, scale, color, material parameters, or any other property
## The target node is assigned via @export (drag and drop). Leave empty for self.
## Property name uses Godot's property path syntax (e.g., "visible", "scale", "modulate:a")


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Property"


func _initialize_properties() -> void:
	properties = {
		"property_name": "",         # Property path (e.g., "visible", "scale:x", "modulate:a")
		"value_type": "bool",        # bool, int, float, string, vector3, color
		"value_bool": true,
		"value_int": 0,
		"value_float": 0.0,
		"value_string": "",
		"value_x": 0.0,              # Vector3 / Color components
		"value_y": 0.0,
		"value_z": 0.0,
		"value_w": 1.0,              # Color alpha
		"operation": "set",          # set, add, multiply, toggle
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "property_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "value_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Bool,Int,Float,String,Vector3,Color",
			"default": "bool"
		},
		{
			"name": "operation",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Set,Add,Multiply,Toggle",
			"default": "set"
		},
		{
			"name": "value_bool",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "value_int",
			"type": TYPE_INT,
			"default": 0
		},
		{
			"name": "value_float",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "value_string",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "value_x",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "value_y",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "value_z",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "value_w",
			"type": TYPE_FLOAT,
			"default": 1.0
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Sets a property on this node or a target node.\nCan set visibility, scale, color, or any property.\n\n⚠ Adds an @export in the Inspector — assign the target node there (leave empty for self).",
		"property_name": "Godot property path (e.g. 'visible', 'scale', 'modulate:a').",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var property_name = properties.get("property_name", "")
	var value_type = properties.get("value_type", "bool")
	var operation = properties.get("operation", "set")

	if typeof(value_type) == TYPE_STRING:
		value_type = value_type.to_lower()
	if typeof(operation) == TYPE_STRING:
		operation = operation.to_lower()

	var target_var = "_prop_target_%s" % chain_name
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	# @export target node — drag in the node whose property you want to change
	member_vars.append("@export var %s: Node" % target_var)

	if property_name.strip_edges().is_empty():
		return {
			"actuator_code": "pass  # Property Actuator: no property name set",
			"member_vars": member_vars
		}

	# Build the value expression
	var value_expr = ""
	match value_type:
		"bool":
			value_expr = "true" if properties.get("value_bool", true) else "false"
		"int":
			value_expr = "%d" % properties.get("value_int", 0)
		"float":
			value_expr = "%.3f" % properties.get("value_float", 0.0)
		"string":
			value_expr = "\"%s\"" % properties.get("value_string", "")
		"vector3":
			var vx = properties.get("value_x", 0.0)
			var vy = properties.get("value_y", 0.0)
			var vz = properties.get("value_z", 0.0)
			value_expr = "Vector3(%.3f, %.3f, %.3f)" % [vx, vy, vz]
		"color":
			var cx = properties.get("value_x", 0.0)
			var cy = properties.get("value_y", 0.0)
			var cz = properties.get("value_z", 0.0)
			var cw = properties.get("value_w", 1.0)
			value_expr = "Color(%.3f, %.3f, %.3f, %.3f)" % [cx, cy, cz, cw]

	var prop = property_name.strip_edges()

	# Determine target: exported node, must be assigned
	code_lines.append("# Set property '%s'" % prop)
	code_lines.append("if not %s:" % target_var)
	code_lines.append("\tpush_warning(\"Property Actuator: No target node assigned to '%s' — drag a node into the inspector\")" % target_var)
	code_lines.append("else:")

	match operation:
		"set":
			code_lines.append("\t%s.set_indexed(\"%s\", %s)" % [target_var, prop, value_expr])
		"add":
			code_lines.append("\t%s.set_indexed(\"%s\", %s.get_indexed(\"%s\") + %s)" % [target_var, prop, target_var, prop, value_expr])
		"multiply":
			code_lines.append("\t%s.set_indexed(\"%s\", %s.get_indexed(\"%s\") * %s)" % [target_var, prop, target_var, prop, value_expr])
		"toggle":
			code_lines.append("\t%s.set_indexed(\"%s\", not %s.get_indexed(\"%s\"))" % [target_var, prop, target_var, prop])
		_:
			code_lines.append("\t%s.set_indexed(\"%s\", %s)" % [target_var, prop, value_expr])

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
