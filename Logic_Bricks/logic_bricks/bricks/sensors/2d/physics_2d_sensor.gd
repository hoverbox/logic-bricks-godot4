@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Physics Sensor - Detects CharacterBody2D contact state.
## Useful for platformers: on floor, touching wall, or touching ceiling.


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Physics"


func _initialize_properties() -> void:
	properties = {
		"contact_type": "On Floor", # On Floor, On Wall, On Ceiling
		"invert": false,
		"require_contact_loss_first": false,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "contact_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "On Floor,On Wall,On Ceiling",
			"default": "On Floor"
		},
		{
			"name": "invert",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "require_contact_loss_first",
			"type": TYPE_BOOL,
			"default": false
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Checks CharacterBody2D collision state: on floor, on wall, or on ceiling.\nUse this for jump checks, wall checks, ceiling bumps, and platformer logic.",
		"contact_type": "Which contact state to check.\nOn Floor: true when the character is standing on a floor.\nOn Wall: true when the character is touching a wall.\nOn Ceiling: true when the character is touching a ceiling.",
		"invert": "Invert the result.\nExample: NOT On Floor is useful for airborne or falling logic.",
		"require_contact_loss_first": "For On Floor landing checks: ignore the contact until it has become false once, then activate the next time contact becomes true. This prevents a jump from immediately returning to Movement because is_on_floor() can still be true on the first jump frame.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var contact_type = str(properties.get("contact_type", "floor")).to_lower().replace(" ", "_")
	var invert = properties.get("invert", false)
	var require_contact_loss_first = properties.get("require_contact_loss_first", false)

	var method_name = "is_on_floor"
	match contact_type:
		"wall", "on_wall":
			method_name = "is_on_wall"
		"ceiling", "on_ceiling":
			method_name = "is_on_ceiling"
		_:
			method_name = "is_on_floor"

	var warned_var = "_physics_sensor_warned_%s" % chain_name
	var armed_var = "_physics_sensor_contact_loss_armed_%s" % chain_name
	var member_vars: Array[String] = []
	member_vars.append("var %s: bool = false" % warned_var)
	member_vars.append("var %s: bool = false" % armed_var)

	var code_lines: Array[String] = []
	code_lines.append("# Physics sensor: %s" % method_name)
	code_lines.append("var sensor_active = false")
	code_lines.append("if has_method(\"%s\"):" % method_name)
	code_lines.append("\tvar _physics_contact_active = %s()" % method_name)
	if invert:
		code_lines.append("\tsensor_active = not _physics_contact_active")
	elif require_contact_loss_first:
		code_lines.append("\tif not _physics_contact_active:")
		code_lines.append("\t\t%s = true" % armed_var)
		code_lines.append("\telif %s:" % armed_var)
		code_lines.append("\t\tsensor_active = true")
		code_lines.append("\t\t%s = false" % armed_var)
	else:
		code_lines.append("\tsensor_active = _physics_contact_active")
	code_lines.append("else:")
	code_lines.append("\tsensor_active = false")
	code_lines.append("\tif not %s:" % warned_var)
	code_lines.append("\t\tpush_warning(\"Physics Sensor: This node does not support %s(). Use it on a CharacterBody2D/CharacterBody2D.\")" % method_name)
	code_lines.append("\t\t%s = true" % warned_var)

	return {
		"sensor_code": "\n".join(code_lines),
		"member_vars": member_vars
	}


func get_brick_info() -> Dictionary:
	return {"class":"Physics2DSensor","name":"Physics 2D","type":"sensor","category":"","domain":"2d","menu_order":120}
