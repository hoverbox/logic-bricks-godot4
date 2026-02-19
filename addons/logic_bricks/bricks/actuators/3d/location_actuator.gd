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
		"x": 0.0,
		"y": 0.0,
		"z": 0.0,
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
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "y",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "z",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "space",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Local,Global",
			"default": "local"
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var movement_method = properties.get("movement_method", "translate")
	var x = properties.get("x", 0.0)
	var y = properties.get("y", 0.0)
	var z = properties.get("z", 0.0)
	var space = properties.get("space", "local")
	
	# Normalize values to lowercase
	if typeof(movement_method) == TYPE_STRING:
		movement_method = movement_method.to_lower()
	if typeof(space) == TYPE_STRING:
		space = space.to_lower()
	
	var code = ""
	
	match movement_method:
		"translate":
			# Direct translation - works on all Node3D
			if space == "local":
				code = "translate(Vector3(%.2f, %.2f, %.2f))" % [x, y, z]
			else:
				code = "global_position += Vector3(%.2f, %.2f, %.2f)" % [x, y, z]
		
		"velocity":
			# Set velocity - for CharacterBody3D using move_and_slide()
			if space == "local":
				code = "velocity = global_transform.basis * Vector3(%.2f, %.2f, %.2f)\nmove_and_slide()" % [x, y, z]
			else:
				code = "velocity = Vector3(%.2f, %.2f, %.2f)\nmove_and_slide()" % [x, y, z]
		
		"position":
			# Direct position assignment - instant teleport
			if space == "local":
				code = "position += Vector3(%.2f, %.2f, %.2f)" % [x, y, z]
			else:
				code = "global_position = Vector3(%.2f, %.2f, %.2f)" % [x, y, z]
		
		_:
			# Fallback to translate
			code = "translate(Vector3(%.2f, %.2f, %.2f))" % [x, y, z]
	
	return {
		"actuator_code": code
	}
