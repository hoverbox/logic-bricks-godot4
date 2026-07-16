@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Tween Actuator - Animate any property on self or a node found by name

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Tween"

func _initialize_properties() -> void:
	properties = {
		"target_mode": "self",
		"target_node_name": "",
		"node_name_source": "literal",
		"export_node_name": false,
		"property": "modulate:a",
		"target_value": "0.0",
		"duration": "0.5",
		"trans_type": "linear",
		"ease_type": "in_out",
		"loop": false,
	}

func get_property_definitions() -> Array:
	return [
		{"name": "target_mode", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Self,Node", "default": "self"},
		{"name": "target_node_name", "type": TYPE_STRING, "default": ""},
		{"name": "node_name_source", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Literal Node Name,String Variable", "default": "literal"},
		{"name": "export_node_name", "type": TYPE_BOOL, "default": false},
		{"name": "property", "type": TYPE_STRING, "default": "modulate:a"},
		{"name": "target_value", "type": TYPE_STRING, "default": "0.0"},
		{"name": "duration", "type": TYPE_STRING, "default": "0.5"},
		{"name": "trans_type", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Linear,Sine,Quint,Quart,Quad,Expo,Elastic,Bounce,Back,Spring,Circular,Cubic", "default": "linear"},
		{"name": "ease_type", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "In,Out,In Out,Out In", "default": "in_out"},
		{"name": "loop", "type": TYPE_BOOL, "default": false},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Animates any property on self or on a node found by name anywhere in the current scene tree.",
		"target_mode": "Self: tween a property on this node.\nNode: find a node by name and tween a property on it.",
		"target_node_name": "Node mode only. Literal Node Name: type the target node name. String Variable: type the name of a String variable that stores the node name.",
		"node_name_source": "Literal Node Name: use Target Node Name directly.\nString Variable: treat Target Node Name as a variable name and read that String at runtime.",
		"export_node_name": "Literal mode only. Adds an @export String to the generated script so the node name can be edited in the Inspector without exposing a node reference.",
		"property": "Property path to animate. Examples: modulate:a, position:y, scale, size.",
		"target_value": "End value. Accepts a number, Vector2(...), Vector3(...), Color(...), or variable.",
		"duration": "Animation duration in seconds. Accepts a number or variable.",
		"trans_type": "Easing curve shape.",
		"ease_type": "Which part of the curve to apply easing to.",
		"loop": "Repeat the tween indefinitely.",
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_mode = properties.get("target_mode", "self")
	var target_node_name = str(properties.get("target_node_name", "")).strip_edges()
	var node_name_source = str(properties.get("node_name_source", "literal")).to_lower().replace(" ", "_")
	var export_node_name = properties.get("export_node_name", false)
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

	var trans_const = _trans_constant(trans_type)
	var ease_const = _ease_constant(ease_type)
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []
	var label = _unique_label(chain_name)
	var tween_var = "_tween_%s" % label

	if target_mode == "node":
		var node_var = "_%s" % label
		var node_name_var = "_%s_node_name" % label
		member_vars.append("var %s: Node = null" % node_var)
		if export_node_name and node_name_source != "string_variable":
			member_vars.append("@export var %s: String = \"%s\"" % [node_name_var, _gd_string(target_node_name)])
		_append_find_node_helpers(member_vars)
		var name_expr = "\"%s\"" % _gd_string(target_node_name)
		if node_name_source == "string_variable" and not target_node_name.is_empty():
			name_expr = "str(%s)" % target_node_name
		elif export_node_name and node_name_source != "string_variable":
			name_expr = node_name_var
		code_lines.append("# Tween Actuator")
		code_lines.append("var _target_name_%s = %s" % [label, name_expr])
		code_lines.append("if %s == null or %s.name != _target_name_%s:" % [node_var, node_var, label])
		code_lines.append("\t%s = _lb_find_node_in_current_scene(_target_name_%s)" % [node_var, label])
		code_lines.append("if %s:" % node_var)
		code_lines.append("\tvar %s = create_tween()" % tween_var)
		if loop:
			code_lines.append("\t%s.set_loops()" % tween_var)
		code_lines.append("\t%s.set_trans(%s)" % [tween_var, trans_const])
		code_lines.append("\t%s.set_ease(%s)" % [tween_var, ease_const])
		code_lines.append("\t%s.tween_property(%s, \"%s\", %s, %s)" % [tween_var, node_var, property, target_value, duration])
		code_lines.append("else:")
		code_lines.append("\tpush_warning(\"Tween Actuator: could not find node named '\" + str(_target_name_%s) + \"'\")" % label)
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

func _append_find_node_helpers(member_vars: Array[String]) -> void:
	member_vars.append("")
	member_vars.append("func _lb_find_node_by_name_recursive(node: Node, target_name: String) -> Node:")
	member_vars.append("\tif node == null or target_name.is_empty():")
	member_vars.append("\t\treturn null")
	member_vars.append("\tif node.name == target_name:")
	member_vars.append("\t\treturn node")
	member_vars.append("\tfor child in node.get_children():")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(child, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn null")
	member_vars.append("")
	member_vars.append("func _lb_find_node_in_current_scene(target_name: String) -> Node:")
	member_vars.append("\tvar scene_root = get_tree().current_scene")
	member_vars.append("\tif scene_root:")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(scene_root, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn _lb_find_node_by_name_recursive(get_tree().root, target_name)")

func _unique_label(chain_name: String) -> String:
	var label = instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	label = label.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	return label if not label.is_empty() else chain_name

func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")

func _trans_constant(trans: String) -> String:
	match trans:
		"sine": return "Tween.TRANS_SINE"
		"quint": return "Tween.TRANS_QUINT"
		"quart": return "Tween.TRANS_QUART"
		"quad": return "Tween.TRANS_QUAD"
		"expo": return "Tween.TRANS_EXPO"
		"elastic": return "Tween.TRANS_ELASTIC"
		"bounce": return "Tween.TRANS_BOUNCE"
		"back": return "Tween.TRANS_BACK"
		"spring": return "Tween.TRANS_SPRING"
		"circular": return "Tween.TRANS_CIRC"
		"cubic": return "Tween.TRANS_CUBIC"
		_: return "Tween.TRANS_LINEAR"

func _ease_constant(ease: String) -> String:
	match ease:
		"in": return "Tween.EASE_IN"
		"out": return "Tween.EASE_OUT"
		"out_in": return "Tween.EASE_OUT_IN"
		_: return "Tween.EASE_IN_OUT"

func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
