@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Surface Attachment"

func get_brick_info() -> Dictionary:
	return {"class": "SurfaceAttachmentActuator", "name": "Surface Attachment", "type": "actuator", "category": "Physics", "domain": "common", "menu_order": 150}

func get_compatibility_error(node: Node) -> String:
	return "" if node is RigidBody3D or node is CharacterBody3D or node is RigidBody2D or node is CharacterBody2D else "Requires a RigidBody or CharacterBody"

func _initialize_properties() -> void:
	properties = {"mode": "attach", "align_to_surface": false, "surface_offset": 0.0, "follow_surface": true, "allow_movement": false, "push_off_speed": 0.0, "balance_assist": false, "balance_path": "", "balance_strength": 0.75}

func get_property_definitions() -> Array:
	return [
		{"name": "mode", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Attach:attach,Detach:detach", "default": "attach"},
		{"name": "align_to_surface", "type": TYPE_BOOL, "default": false},
		{"name": "surface_offset", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,10000,0.01", "default": 0.0},
		{"name": "follow_surface", "type": TYPE_BOOL, "default": true},
		{"name": "allow_movement", "type": TYPE_BOOL, "default": false},
		{"name": "balance_assist", "type": TYPE_BOOL, "default": false},
		{"name": "balance_path", "type": TYPE_STRING, "default": "", "node_reference": true, "accepted_node_types": ["Path3D"]},
		{"name": "balance_strength", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,1,0.05", "default": 0.75},
		{"name": "push_off_speed", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0,10000,0.01", "default": 0.0},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Attach to a physically touching surface, or detach. Supports rigid bodies and characters in 3D and 2D. Use a Collision or Surface Check trigger to choose when to attach.",
		"mode": "Attach: stick to a touching physics body. Detach: release and resume normal movement.",
		"align_to_surface": "Rigid bodies: point local -Z (3D) or +X (2D) into the surface. Leave off to keep orientation.",
		"surface_offset": "Extra gap outward from the current contact position. World units in 3D; pixels in 2D.",
		"follow_surface": "Follow the attached surface's movement and rotation. Off: hold the attachment in world space.",
		"allow_movement": "Characters: allow existing movement bricks to move along the surface. Gravity is suspended while attached. Leaving the surface releases the character.",
		"balance_assist": "3D characters: gently guide movement toward a railing's center Path. Requires Allow Movement. Steering remains available; strength 1 removes sideways input.",
		"balance_path": "Choose a Path3D along the railing's center. For moving railings, make the Path a child of the railing. The curve needs at least two points.",
		"balance_strength": "0: no assistance. Higher values reduce sideways drift and pull toward the center more strongly. Default 0.75; try 1 for a thin railing.",
		"push_off_speed": "Characters: speed away from the surface when detaching. 0 releases without a push. World units/sec in 3D; pixels/sec in 2D.",
	}

func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings = super.get_configuration_warnings(node)
	if node is CharacterBody3D and bool(properties.get("balance_assist", false)) and bool(properties.get("allow_movement", false)) and str(properties.get("mode", "attach")) == "attach":
		if str(properties.get("balance_path", "")).strip_edges().is_empty():
			warnings.append("Select a Path3D along the railing's center for Balance Assist.")
	return warnings

## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var attaching = str(properties.get("mode", "attach")).to_lower() == "attach"
	var character = context_node is CharacterBody3D or context_node is CharacterBody2D
	for child in _get_field_names():
		match str(child):
			"align_to_surface":
				shown[child] = attaching and not character
			"surface_offset", "follow_surface":
				shown[child] = attaching
			"allow_movement":
				shown[child] = attaching and character
			"balance_assist":
				shown[child] = attaching and context_node is CharacterBody3D and bool(properties.get("allow_movement", false))
			"balance_path", "balance_strength":
				shown[child] = attaching and context_node is CharacterBody3D and bool(properties.get("allow_movement", false)) and bool(properties.get("balance_assist", false))
			"push_off_speed":
				shown[child] = not attaching and character
	return shown


func generate_code(node: Node, _chain_name: String) -> Dictionary:
	if not get_compatibility_error(node).is_empty():
		return {"actuator_code": "pass # Surface Attachment requires a rigid body or character"}
	var lines: Array[String] = ["var _surface_attachment = get_node_or_null(\"_LogicBricksSurfaceAttachment\")"]
	lines.append("if _surface_attachment == null:")
	lines.append("\t_surface_attachment = preload(\"res://addons/logic_bricks/runtime/surface_attachment.gd\").new()")
	lines.append("\t_surface_attachment.name = \"_LogicBricksSurfaceAttachment\"")
	lines.append("\tadd_child(_surface_attachment)")
	if str(properties.get("mode", "attach")).to_lower() == "detach":
		lines.append("_surface_attachment.detach(%s)" % _num("push_off_speed"))
	else:
		var offset_number = _literal_number("surface_offset", 0.0)
		var strength_number = _literal_number("balance_strength", 0.75)
		var options = {"align_to_surface": bool(properties.get("align_to_surface", false)), "surface_offset": maxf(0.0, offset_number if offset_number != null else 0.0), "follow_surface": bool(properties.get("follow_surface", true)), "allow_movement": bool(properties.get("allow_movement", false)), "balance_assist": bool(properties.get("balance_assist", false)), "balance_path": str(properties.get("balance_path", "")), "balance_strength": clampf(strength_number if strength_number != null else 0.75, 0.0, 1.0)}
		# Variable/math values go into the options as code; the runtime clamps them
		# (offset >= 0, strength 0-1) the same way the literals are clamped here.
		var expressions := {}
		for key in ["surface_offset", "balance_strength"]:
			if _is_number_expression(key):
				options[key] = "__lb_expr_%s__" % key
				expressions["\"__lb_expr_%s__\"" % key] = _num(key)
		var options_code := var_to_str(options).replace("\n", " ").replace("\t", " ")
		for placeholder in expressions:
			options_code = options_code.replace(placeholder, expressions[placeholder])
		lines.append("_surface_attachment.attach(self, %s)" % options_code)
	return {"actuator_code": "\n".join(lines)}
