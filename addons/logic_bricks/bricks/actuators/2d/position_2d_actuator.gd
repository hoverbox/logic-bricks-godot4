@tool
extends "res://addons/logic_bricks/bricks/actuators/2d/motion_2d_actuator.gd"

## Position 2D Actuator - Changes a Node2D's position or CharacterBody2D movement.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Position 2D"

func get_brick_info() -> Dictionary:
	return {
		"class": "Position2DActuator",
		"name": "Position 2D",
		"type": "actuator",
		"category": "Motion",
		"description": "Changes 2D position using character velocity, a translation offset, or an exact position.",
		"menu_order": 30,
		"domain": "2d"
	}

func _initialize_properties() -> void:
	properties = {
		"target_node_name": "",
		"movement_method": "character_velocity",
		"x": "0.0",
		"y": "0.0",
		"space": "local"
	}

func apply_context_defaults(node: Node) -> void:
	properties["movement_method"] = "character_velocity" if node is CharacterBody2D else "translate"

func get_compatibility_error(node: Node) -> String:
	var method = str(properties.get("movement_method", "character_velocity")).to_lower().replace(" ", "_")
	return "" if method != "character_velocity" or node is CharacterBody2D else "Character Velocity requires CharacterBody2D"

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "", "placeholder": "blank = self, or child/node name"},
		{"name": "movement_method", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Character Velocity,Translate,Set Position", "default": "character_velocity"},
		{"name": "x", "type": TYPE_STRING, "default": "0.0"},
		{"name": "y", "type": TYPE_STRING, "default": "0.0"},
		{"name": "space", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Local,Global", "default": "local"}
	]


func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	if _validation_all_numeric_zero(["x", "y"]):
		warnings.append("Put a Value or Variable in X or Y")
	return warnings

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Changes where a 2D object is. Use Character Velocity for CharacterBody2D movement, Translate for an offset, or Set Position for an exact location.",
		"target_node_name": "Leave blank to affect this node, or enter a child/node name.",
		"movement_method": "Character Velocity: requests CharacterBody2D movement.\nTranslate: moves by an offset each frame.\nSet Position: places the object at an exact position.",
		"x": "X axis value. Accepts a number, variable, or expression.",
		"y": "Y axis value. Accepts a number, variable, or expression.",
		"space": "Local uses the object's axes. Global uses world axes."
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	properties["motion_type"] = "location"
	if str(properties.get("movement_method", "character_velocity")).to_lower().replace(" ", "_") == "set_position":
		properties["movement_method"] = "position"
	return super.generate_code(node, chain_name)
