@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Scale 2D Actuator - Changes Node2D scale, instantly or with a tween.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Scale 2D"

func get_brick_info() -> Dictionary:
	return {
		"class": "Scale2DActuator",
		"name": "Scale 2D",
		"type": "actuator",
		"category": "Motion",
		"description": "Changes a 2D object's scale, instantly or with a tween.",
		"menu_order": 50,
		"domain": "2d"
	}

func _initialize_properties() -> void:
	properties = {
		"target_node_name": "",
		"x": "1.0",
		"y": "1.0",
		"use_tween": false,
		"duration": 1.0,
		"transition": "Sine",
		"ease": "In Out"
	}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": "", "placeholder": "blank = self, or child/node name"},
		{"name": "x", "type": TYPE_STRING, "default": "1.0"},
		{"name": "y", "type": TYPE_STRING, "default": "1.0"},
		{"name": "use_tween", "type": TYPE_BOOL, "default": false},
		{"name": "duration", "type": TYPE_FLOAT, "default": 1.0},
		{"name": "transition", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Linear,Sine,Quad,Cubic,Quart,Quint,Expo,Circ,Back,Elastic,Bounce", "default": "Sine"},
		{"name": "ease", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "In,Out,In Out,Out In", "default": "In Out"}
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Changes only the scale of a 2D object. Enable Tween to animate to the target scale.",
		"target_node_name": "Leave blank to scale this node, or enter a child/node name.",
		"x": "Target X scale.",
		"y": "Target Y scale.",
		"use_tween": "Animate smoothly from the current scale to the target scale.",
		"duration": "Tween duration in seconds.",
		"transition": "Tween transition curve.",
		"ease": "Tween easing direction."
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var lines: Array[String] = []
	var members: Array[String] = []
	var target := _build_target(lines, members, chain_name)
	var scale_value := "Vector2(%s, %s)" % [_value_expression(properties.get("x", "1.0"), "1.0"), _value_expression(properties.get("y", "1.0"), "1.0")]
	var use_tween := bool(properties.get("use_tween", false))
	var duration := maxf(float(properties.get("duration", 1.0)), 0.0)
	if use_tween and duration > 0.0:
		var label := _unique_label(chain_name)
		var tween_var := "_scale2d_tween_%s" % label
		members.append("var %s: Tween = null" % tween_var)
		lines.append("\tif not %s.scale.is_equal_approx(%s):" % [target, scale_value])
		lines.append("\t\tif %s == null or not %s.is_running():" % [tween_var, tween_var])
		lines.append("\t\t\t%s = create_tween()" % tween_var)
		lines.append("\t\t\t%s.set_trans(%s).set_ease(%s)" % [tween_var, _transition_constant(), _ease_constant()])
		lines.append("\t\t\t%s.tween_property(%s, \"scale\", %s, %.6f)" % [tween_var, target, scale_value, duration])
	else:
		lines.append("\t%s.scale = %s" % [target, scale_value])
	return {"actuator_code": "\n".join(lines), "member_vars": members}

func _build_target(lines: Array[String], members: Array[String], chain_name: String) -> String:
	var target_name := str(properties.get("target_node_name", "")).strip_edges()
	if target_name.is_empty():
		lines.append("if not (self is Node2D):")
		lines.append("\tpush_warning(\"Scale 2D: self is not a Node2D\")")
		lines.append("else:")
		return "self"
	var label := _unique_label(chain_name)
	var target_var := "_scale2d_target_%s" % label
	members.append("var %s = null" % target_var)
	lines.append("var _scale2d_name_%s = \"%s\"" % [label, _gd_string(target_name)])
	lines.append("if %s == null or %s.name != _scale2d_name_%s:" % [target_var, target_var, label])
	lines.append("\t%s = find_child(_scale2d_name_%s, true, false)" % [target_var, label])
	lines.append("\tif %s == null and get_tree().current_scene:" % target_var)
	lines.append("\t\t%s = get_tree().current_scene.find_child(_scale2d_name_%s, true, false)" % [target_var, label])
	lines.append("if not (%s is Node2D):" % target_var)
	lines.append("\tpush_warning(\"Scale 2D target is missing or is not Node2D\")")
	lines.append("else:")
	return target_var

func _value_expression(value, fallback: String) -> String:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return str(value)
	var text := str(value).strip_edges()
	return fallback if text.is_empty() else text

func _transition_constant() -> String:
	var values := {"linear":"Tween.TRANS_LINEAR", "sine":"Tween.TRANS_SINE", "quad":"Tween.TRANS_QUAD", "cubic":"Tween.TRANS_CUBIC", "quart":"Tween.TRANS_QUART", "quint":"Tween.TRANS_QUINT", "expo":"Tween.TRANS_EXPO", "circ":"Tween.TRANS_CIRC", "back":"Tween.TRANS_BACK", "elastic":"Tween.TRANS_ELASTIC", "bounce":"Tween.TRANS_BOUNCE"}
	return values.get(str(properties.get("transition", "Sine")).to_lower(), "Tween.TRANS_SINE")

func _ease_constant() -> String:
	var values := {"in":"Tween.EASE_IN", "out":"Tween.EASE_OUT", "in out":"Tween.EASE_IN_OUT", "out in":"Tween.EASE_OUT_IN"}
	return values.get(str(properties.get("ease", "In Out")).to_lower(), "Tween.EASE_IN_OUT")

func _unique_label(chain_name: String) -> String:
	return str(abs((chain_name + str(properties)).hash()))
