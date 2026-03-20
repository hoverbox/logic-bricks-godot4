@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Tween Actuator - Animate any property on a node from its current value to a target
## Creates a one-shot Tween each time the actuator fires
## Works with floats, Vector2, Vector3, Color, and any Variant-compatible property


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Tween"


func _initialize_properties() -> void:
	properties = {
		"target_mode":  "self",       # self, node
		"property":     "modulate:a", # property path on the target node
		"target_value": "0.0",        # end value
		"duration":     "0.5",        # seconds
		"trans_type":   "linear",     # linear, sine, quint, quart, quad, expo, elastic, bounce, back, spring, circular, cubic
		"ease_type":    "in_out",     # in, out, in_out, out_in
		"loop":         false,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Self,Node",
			"default": "self"
		},
		{
			"name": "property",
			"type": TYPE_STRING,
			"default": "modulate:a"
		},
		{
			"name": "target_value",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "duration",
			"type": TYPE_STRING,
			"default": "0.5"
		},
		{
			"name": "trans_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Linear,Sine,Quint,Quart,Quad,Expo,Elastic,Bounce,Back,Spring,Circular,Cubic",
			"default": "linear"
		},
		{
			"name": "ease_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "In,Out,In Out,Out In",
			"default": "in_out"
		},
		{
			"name": "loop",
			"type": TYPE_BOOL,
			"default": false
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Animates any property on a node using Godot's Tween system.\nFires a new tween each time the actuator activates.",
		"target_mode":  "Self: tween a property on this node.\nNode: tween a property on an assigned node.\n⚠ Node mode adds @export in inspector.",
		"property":     "Property path to animate.\nExamples:\n  modulate:a  — fade alpha\n  position:y  — move Y\n  scale       — scale XYZ\n  size        — Control size",
		"target_value": "End value of the animation.\nAccepts a number, Vector2(...), Vector3(...), Color(...), or variable.",
		"duration":     "Animation duration in seconds. Accepts a number or variable.",
		"trans_type":   "Easing curve shape.",
		"ease_type":    "Which part of the curve to apply easing to.",
		"loop":         "Repeat the tween indefinitely.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_mode = properties.get("target_mode", "self")
	var property = properties.get("property", "modulate:a")
	var target_value = _to_expr(properties.get("target_value", "0.0"))
	var duration = _to_expr(properties.get("duration", "0.5"))
	var trans_type = properties.get("trans_type", "linear")
	var ease_type = properties.get("ease_type", "in_out")
	var loop = properties.get("loop", false)

	if typeof(target_mode) == TYPE_STRING:
		target_mode = target_mode.to_lower()
	if typeof(trans_type) == TYPE_STRING:
		trans_type = trans_type.to_lower().replace(" ", "_")
	if typeof(ease_type) == TYPE_STRING:
		ease_type = ease_type.to_lower().replace(" ", "_")

	# Map to Tween constants
	var trans_const = _trans_constant(trans_type)
	var ease_const = _ease_constant(ease_type)

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	# Use instance name if set, otherwise use brick name, sanitized for use as a variable
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name

	var tween_var = "_tween_%s" % chain_name
	var target_ref: String

	if target_mode == "node":
		var node_var = "_%s" % _export_label
		member_vars.append("@export var %s: Node" % node_var)
		code_lines.append("# Tween Actuator")
		code_lines.append("if %s:" % node_var)
		code_lines.append("\tvar %s = create_tween()" % tween_var)
		if loop:
			code_lines.append("\t%s.set_loops()" % tween_var)
		code_lines.append("\t%s.set_trans(%s)" % [tween_var, trans_const])
		code_lines.append("\t%s.set_ease(%s)" % [tween_var, ease_const])
		code_lines.append("\t%s.tween_property(%s, \"%s\", %s, %s)" % [tween_var, node_var, property, target_value, duration])
		code_lines.append("else:")
		code_lines.append("\tpush_warning(\"Tween Actuator: No node assigned to '%s' — drag one into the inspector\")" % node_var)
	else:
		code_lines.append("# Tween Actuator")
		code_lines.append("var %s = create_tween()" % tween_var)
		if loop:
			code_lines.append("%s.set_loops()" % tween_var)
		code_lines.append("%s.set_trans(%s)" % [tween_var, trans_const])
		code_lines.append("%s.set_ease(%s)" % [tween_var, ease_const])
		code_lines.append("%s.tween_property(self, \"%s\", %s, %s)" % [tween_var, property, target_value, duration])

	var result = {"actuator_code": "\n".join(code_lines)}
	if member_vars.size() > 0:
		result["member_vars"] = member_vars
	return result


func _trans_constant(trans: String) -> String:
	match trans:
		"sine":     return "Tween.TRANS_SINE"
		"quint":    return "Tween.TRANS_QUINT"
		"quart":    return "Tween.TRANS_QUART"
		"quad":     return "Tween.TRANS_QUAD"
		"expo":     return "Tween.TRANS_EXPO"
		"elastic":  return "Tween.TRANS_ELASTIC"
		"bounce":   return "Tween.TRANS_BOUNCE"
		"back":     return "Tween.TRANS_BACK"
		"spring":   return "Tween.TRANS_SPRING"
		"circular": return "Tween.TRANS_CIRC"
		"cubic":    return "Tween.TRANS_CUBIC"
		_:          return "Tween.TRANS_LINEAR"


func _ease_constant(ease: String) -> String:
	match ease:
		"in":      return "Tween.EASE_IN"
		"out":     return "Tween.EASE_OUT"
		"out_in":  return "Tween.EASE_OUT_IN"
		_:         return "Tween.EASE_IN_OUT"


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
