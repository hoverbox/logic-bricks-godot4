@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Surface Check Trigger - Detects CharacterBody2D contact state.
## Useful for platformers: on floor, touching wall, or touching ceiling.


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Surface Check"


func _initialize_properties() -> void:
	properties = {
		"contact_type": "On Floor", # On Floor, On Wall, On Ceiling, Landed
		"invert": false,
		"require_contact_loss_first": false,
		"minimum_landing_speed": 0.0,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "contact_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "On Floor,On Wall,On Ceiling,Landed",
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
		{
			"name": "minimum_landing_speed",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,10000,0.01",
			"default": 0.0
		},
	]


func renamed_properties() -> Dictionary:
	return {"minimum_impact_speed": "minimum_landing_speed"}


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Checks CharacterBody2D collision state: on floor, on wall, on ceiling, or just landed.\nUse Landed for landing sounds, camera shake, particles, and other impact effects.",
		"contact_type": "Which contact state to check.\nOn Floor: true when the character is standing on a floor.\nOn Wall: true when the character is touching a wall.\nOn Ceiling: true when the character is touching a ceiling.\nLanded: triggers once after the character was airborne and touches down.",
		"minimum_landing_speed": "Minimum downward speed immediately before landing.\n0 accepts any landing. Select Landed to trigger once at the chosen minimum speed.\nRequires the Character action to capture speed before collision handling.",
		"invert": "Invert the result.\nExample: NOT On Floor is useful for airborne or falling logic.",
		"require_contact_loss_first": "Legacy contact-return setting. Wait for contact to be lost before triggering once when it returns. For new landing effects, select Landed instead.",
	}


## Member variables this brick declares that keep their value when the node
## changes state (other state-specific variables are reset on state entry).
## Written by the Character 2D brick before move_and_slide().
func get_kept_member_vars() -> PackedStringArray:
	return PackedStringArray(["_logic_brick_pre_slide_velocity*"])


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var contact_type = str(properties.get("contact_type", "On Floor")).to_lower().replace(" ", "_")
	var landed = contact_type == "landed"
	var landing_check = landed or (contact_type in ["floor", "on_floor"] and bool(properties.get("require_contact_loss_first", false)) and not bool(properties.get("invert", false)))
	for child in _get_field_names():
		var property_name = child
		if property_name == "minimum_landing_speed":
			shown[child] = landing_check
		elif property_name in ["require_contact_loss_first", "invert"]:
			shown[child] = not landed
	return shown


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var contact_type = str(properties.get("contact_type", "floor")).to_lower().replace(" ", "_")
	var landed = contact_type == "landed"
	# Landed is a one-shot event; legacy contact-loss and invert settings do not alter it.
	var invert = properties.get("invert", false) and not landed
	var require_contact_loss_first = properties.get("require_contact_loss_first", false) or landed
	# A variable/math speed is compared at runtime (as absf(value); 0 accepts any landing).
	var minimum_landing_speed = _literal_number("minimum_landing_speed", 0.0)
	var landing_speed_code := "absf(%s)" % _num("minimum_landing_speed")
	if minimum_landing_speed != null:
		minimum_landing_speed = absf(minimum_landing_speed)
		if not is_finite(minimum_landing_speed):
			minimum_landing_speed = 0.0
		landing_speed_code = "%.6f" % minimum_landing_speed

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
	var filter_landing = method_name == "is_on_floor" and require_contact_loss_first and not invert and (minimum_landing_speed == null or minimum_landing_speed > 0.0)
	if filter_landing:
		# Shared with the Character action, which captures this before move_and_slide().
		member_vars.append("var _logic_brick_pre_slide_velocity_2d: Vector2 = Vector2.ZERO")

	var code_lines: Array[String] = []
	code_lines.append("# Physics sensor: %s" % _gd_string(str(method_name)))
	code_lines.append("var sensor_active = false")
	code_lines.append("if has_method(\"%s\"):" % _gd_string(str(method_name)))
	code_lines.append("\tvar _physics_contact_active = %s()" % method_name)
	if invert:
		code_lines.append("\tsensor_active = not _physics_contact_active")
	elif require_contact_loss_first:
		code_lines.append("\tif not _physics_contact_active:")
		code_lines.append("\t\t%s = true" % armed_var)
		code_lines.append("\telif %s:" % armed_var)
		if filter_landing:
			code_lines.append("\t\tsensor_active = maxf(0.0, -_logic_brick_pre_slide_velocity_2d.dot(up_direction.normalized())) >= %s" % landing_speed_code)
		else:
			code_lines.append("\t\tsensor_active = true")
		code_lines.append("\t\t%s = false" % armed_var)
	else:
		code_lines.append("\tsensor_active = _physics_contact_active")
	code_lines.append("else:")
	code_lines.append("\tsensor_active = false")
	code_lines.append("\tif not %s:" % warned_var)
	code_lines.append("\t\tpush_warning(\"Physics Sensor: This node does not support %s(). Use it on a CharacterBody2D/CharacterBody2D.\")" % _gd_string(str(method_name)))
	code_lines.append("\t\t%s = true" % warned_var)

	return {
		"sensor_code": "\n".join(code_lines),
		"member_vars": member_vars
	}


func get_brick_info() -> Dictionary:
	return {"class":"Physics2DSensor","name":"Physics 2D","type":"sensor","category":"","domain":"2d","menu_order":120}
