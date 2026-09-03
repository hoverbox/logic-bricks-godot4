@tool
extends "res://addons/logic_bricks/bricks/actuators/3d/motion_actuator.gd"

## Position Actuator - Changes a Node3D's position or CharacterBody3D movement.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Position"

func get_brick_info() -> Dictionary:
	return {
		"class": "PositionActuator",
		"name": "Position",
		"type": "actuator",
		"category": "Motion",
		"description": "Changes position using character velocity, a translation offset, or an exact position.",
		"menu_order": 30,
		"domain": "3d"
	}

func _initialize_properties() -> void:
	properties = {
		"target_node_name": "",
		"movement_method": "character_velocity",
		"x": "0.0", "y": "0.0", "z": "0.0",
		"space": "local",
		"camera_relative": false,
		"camera_name": "",
		"call_move_and_slide": false
	}

func apply_context_defaults(node: Node) -> void:
	properties["movement_method"] = "character_velocity" if node is CharacterBody3D else "translate"

func get_compatibility_error(node: Node) -> String:
	var method = str(properties.get("movement_method", "character_velocity")).to_lower().replace(" ", "_")
	return "" if method != "character_velocity" or node is CharacterBody3D else "Character Velocity requires CharacterBody3D"

func get_property_definitions() -> Array:
	return [
		{"name":"target_node_name","type":TYPE_STRING,"default":"","placeholder":"blank = self, or child/node name"},
		{"name":"movement_method","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Character Velocity,Translate,Set Position","default":"character_velocity"},
		{"name":"x","type":TYPE_STRING,"default":"0.0"},
		{"name":"y","type":TYPE_STRING,"default":"0.0"},
		{"name":"z","type":TYPE_STRING,"default":"0.0"},
		{"name":"space","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Local,Global","default":"local"},
		{"name":"camera_relative","type":TYPE_BOOL,"default":false},
		{"name":"camera_name","type":TYPE_STRING,"default":"","placeholder":"e.g. Camera3D","node_reference":true,"accepted_node_types":["Camera3D"],"condition":{"property":"camera_relative","value":true}},
		{"name":"call_move_and_slide","type":TYPE_BOOL,"default":false}
	]

func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	if _is_zero(properties.get("x", "0.0")) and _is_zero(properties.get("y", "0.0")) and _is_zero(properties.get("z", "0.0")):
		warnings.append("Put a Value or Variable in X,Y, or Z")
	return warnings


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Changes where a 3D object is. Use Character Velocity for CharacterBody3D movement, Translate for an offset, or Set Position for an exact location.",
		"target_node_name":"Leave blank to affect this node, or enter a child/node name.",
		"movement_method":"Character Velocity: requests CharacterBody3D movement.\nTranslate: moves by an offset each frame.\nSet Position: places the object at an exact position.",
		"x":"X axis value. Accepts a number, variable, or expression.",
		"y":"Y axis value. Accepts a number, variable, or expression.",
		"z":"Z axis value. Accepts a number, variable, or expression.",
		"space":"Local uses the object's axes. Global uses world axes.",
		"camera_relative":"Bases horizontal movement on camera yaw.",
		"camera_name":"Optional Camera3D node name. Leave blank to use the active viewport camera.",
		"call_move_and_slide":"Usually leave off when Character Physics is present, because Character Physics calls move_and_slide()."
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	# Keep compatibility with the legacy internal method key.
	if str(properties.get("movement_method", "character_velocity")).to_lower().replace(" ", "_") == "set_position":
		properties["movement_method"] = "position"
	return _generate_location_code(node, chain_name)
