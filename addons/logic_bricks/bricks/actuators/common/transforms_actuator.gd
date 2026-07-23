@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Transforms Actuator - Sets position, rotation, and scale on a Node2D or Node3D.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Set Transforms"

func get_brick_info() -> Dictionary:
	return {
		"class": "TransformsActuator",
		"name": "Set Transforms",
		"type": "actuator",
		"category": "Object",
		"description": "Sets position, rotation, and scale from entered values or variables, instantly or over time.",
		"menu_order": 240,
		"domain": "common"
	}

func _initialize_properties() -> void:
	properties = {
		"target_mode": "self", "target_node_name": "", "use_global_transform": false,
		"set_position": true, "position_mode": "values", "position_x": 0.0, "position_y": 0.0, "position_z": 0.0, "position_variable": "",
		"set_rotation": false, "rotation_mode": "values", "rotation_x": 0.0, "rotation_y": 0.0, "rotation_z": 0.0, "rotation_variable": "",
		"set_scale": false, "scale_mode": "values", "scale_x": 1.0, "scale_y": 1.0, "scale_z": 1.0, "scale_variable": "",
		"use_tween": false, "duration": 1.0, "transition": "Sine", "ease": "In Out"
	}

func get_property_definitions() -> Array:
	return [
		{"name":"target_mode","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Self,Node Name","default":"self"},
		{"name":"target_node_name","type":TYPE_STRING,"default":"","placeholder":"Node2D or Node3D name","visible_if":{"target_mode":"node_name"}},
		{"name":"use_global_transform","type":TYPE_BOOL,"default":false},
		{"name":"set_position","type":TYPE_BOOL,"default":true},
		{"name":"position_mode","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Values,Vector Variable","default":"values","visible_if":{"set_position":true}},
		{"name":"position_x","type":TYPE_FLOAT,"default":0.0,"visible_if":{"position_mode":"values"}},
		{"name":"position_y","type":TYPE_FLOAT,"default":0.0,"visible_if":{"position_mode":"values"}},
		{"name":"position_z","type":TYPE_FLOAT,"default":0.0,"visible_if":{"position_mode":"values"}},
		{"name":"position_variable","type":TYPE_STRING,"default":"","visible_if":{"position_mode":"vector_variable"}},
		{"name":"set_rotation","type":TYPE_BOOL,"default":false},
		{"name":"rotation_mode","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Values,Variable","default":"values","visible_if":{"set_rotation":true}},
		{"name":"rotation_x","type":TYPE_FLOAT,"default":0.0,"visible_if":{"rotation_mode":"values"}},
		{"name":"rotation_y","type":TYPE_FLOAT,"default":0.0,"visible_if":{"rotation_mode":"values"}},
		{"name":"rotation_z","type":TYPE_FLOAT,"default":0.0,"visible_if":{"rotation_mode":"values"}},
		{"name":"rotation_variable","type":TYPE_STRING,"default":"","visible_if":{"rotation_mode":"variable"}},
		{"name":"set_scale","type":TYPE_BOOL,"default":false},
		{"name":"scale_mode","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Values,Vector Variable","default":"values","visible_if":{"set_scale":true}},
		{"name":"scale_x","type":TYPE_FLOAT,"default":1.0,"visible_if":{"scale_mode":"values"}},
		{"name":"scale_y","type":TYPE_FLOAT,"default":1.0,"visible_if":{"scale_mode":"values"}},
		{"name":"scale_z","type":TYPE_FLOAT,"default":1.0,"visible_if":{"scale_mode":"values"}},
		{"name":"scale_variable","type":TYPE_STRING,"default":"","visible_if":{"scale_mode":"vector_variable"}},
		{"name":"use_tween","type":TYPE_BOOL,"default":false},
		{"name":"duration","type":TYPE_FLOAT,"default":1.0,"visible_if":{"use_tween":true}},
		{"name":"transition","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Linear,Sine,Quad,Cubic,Quart,Quint,Expo,Circ,Back,Elastic,Bounce","default":"Sine","visible_if":{"use_tween":true}},
		{"name":"ease","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"In,Out,In Out,Out In","default":"In Out","visible_if":{"use_tween":true}}
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":"Changes any combination of position, rotation, and scale on a Node2D or Node3D.",
		"use_global_transform":"Use global transform properties instead of values relative to the parent.",
		"position_variable":"Node2D requires Vector2. Node3D requires Vector3.",
		"rotation_variable":"Node2D accepts a float in radians. Node3D requires Vector3 rotation in radians.",
		"scale_variable":"Node2D requires Vector2. Node3D requires Vector3.",
		"use_tween":"Smoothly changes all selected transform properties instead of applying them instantly.",
		"duration":"Seconds taken to reach the selected transform values."
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_mode := _key(properties.get("target_mode", "self"))
	var node_name := str(properties.get("target_node_name", "")).strip_edges()
	var use_global := bool(properties.get("use_global_transform", false))
	var set_position := bool(properties.get("set_position", true))
	var set_rotation := bool(properties.get("set_rotation", false))
	var set_scale := bool(properties.get("set_scale", false))
	var position_mode := _key(properties.get("position_mode", "values"))
	var rotation_mode := _key(properties.get("rotation_mode", "values"))
	var scale_mode := _key(properties.get("scale_mode", "values"))
	var position_variable := _sanitize_identifier(str(properties.get("position_variable", "")))
	var rotation_variable := _sanitize_identifier(str(properties.get("rotation_variable", "")))
	var scale_variable := _sanitize_identifier(str(properties.get("scale_variable", "")))
	var use_tween := bool(properties.get("use_tween", false))
	var duration := maxf(float(properties.get("duration", 1.0)), 0.001)
	var label := _unique_label(chain_name)
	var errors: Array[String] = []
	if not set_position and not set_rotation and not set_scale: errors.append("select Position, Rotation, and/or Scale")
	if target_mode == "node_name" and node_name.is_empty(): errors.append("enter a target node name")
	if set_position and position_mode == "vector_variable" and position_variable.is_empty(): errors.append("enter a Position variable")
	if set_rotation and rotation_mode == "variable" and rotation_variable.is_empty(): errors.append("enter a Rotation variable")
	if set_scale and scale_mode == "vector_variable" and scale_variable.is_empty(): errors.append("enter a Scale variable")
	if not errors.is_empty():
		return {"actuator_code":"push_warning(\"Transforms Actuator: %s.\")" % ", ".join(errors)}

	var lines: Array[String] = ["# Transforms Actuator", "var _transform_target_%s: Node = self" % label]
	if target_mode == "node_name":
		lines.append("var _transform_root_%s = get_tree().current_scene" % label)
		lines.append("_transform_target_%s = _transform_root_%s.find_child(\"%s\", true, false) if _transform_root_%s else null" % [label,label,_gd_string(node_name),label])
	for item in [["position",set_position,position_mode,position_variable],["rotation",set_rotation,rotation_mode,rotation_variable],["scale",set_scale,scale_mode,scale_variable]]:
		if item[1] and item[2] != "values": _append_variable_lookup(lines, label, item[0], item[3])
	if set_position and position_mode == "values": lines.append("var _position_value_%s = Vector3(%.6f, %.6f, %.6f)" % [label,float(properties.get("position_x",0.0)),float(properties.get("position_y",0.0)),float(properties.get("position_z",0.0))])
	if set_rotation and rotation_mode == "values": lines.append("var _rotation_value_%s = Vector3(deg_to_rad(%.6f), deg_to_rad(%.6f), deg_to_rad(%.6f))" % [label,float(properties.get("rotation_x",0.0)),float(properties.get("rotation_y",0.0)),float(properties.get("rotation_z",0.0))])
	if set_scale and scale_mode == "values": lines.append("var _scale_value_%s = Vector3(%.6f, %.6f, %.6f)" % [label,float(properties.get("scale_x",1.0)),float(properties.get("scale_y",1.0)),float(properties.get("scale_z",1.0))])
	lines.append("if _transform_target_%s is Node2D:" % label)
	_append_node2d(lines,label,use_global,set_position,set_rotation,set_scale,use_tween,duration,position_variable,rotation_variable,scale_variable)
	lines.append("elif _transform_target_%s is Node3D:" % label)
	_append_node3d(lines,label,use_global,set_position,set_rotation,set_scale,use_tween,duration,position_variable,rotation_variable,scale_variable)
	lines.append("else:")
	lines.append("\tpush_warning(\"Transforms Actuator: target was not found or is not a Node2D/Node3D\")")
	return {"actuator_code":"\n".join(lines)}

func _append_variable_lookup(lines:Array[String], label:String, prefix:String, variable_name:String) -> void:
	lines.append("var _%s_value_%s = null" % [prefix,label])
	lines.append("if \"%s\" in self:" % variable_name)
	lines.append("\t_%s_value_%s = get(\"%s\")" % [prefix,label,variable_name])
	lines.append("else:")
	lines.append("\tvar _%s_globals_%s = get_node_or_null(\"/root/GlobalVars\")" % [prefix,label])
	lines.append("\tif _%s_globals_%s and \"%s\" in _%s_globals_%s:" % [prefix,label,variable_name,prefix,label])
	lines.append("\t\t_%s_value_%s = _%s_globals_%s.get(\"%s\")" % [prefix,label,prefix,label,variable_name])

func _append_node2d(lines:Array[String], label:String, use_global:bool, sp:bool, sr:bool, ss:bool, tween:bool, duration:float, pv:String, rv:String, sv:String) -> void:
	var props:Array[String] = []
	if sp:
		lines.append("\tvar _p2_%s = _position_value_%s if _position_value_%s is Vector2 else Vector2(_position_value_%s.x, _position_value_%s.y) if _position_value_%s is Vector3 else null" % [label,label,label,label,label,label])
		lines.append("\tif _p2_%s == null: push_warning(\"Transforms Actuator: Position variable '%s' must be Vector2 or Vector3\")" % [label,pv])
		props.append("[\"%s\", _p2_%s]" % ["global_position" if use_global else "position",label])
	if sr:
		lines.append("\tvar _r2_%s = _rotation_value_%s if _rotation_value_%s is float or _rotation_value_%s is int else _rotation_value_%s.z if _rotation_value_%s is Vector3 else null" % [label,label,label,label,label,label])
		lines.append("\tif _r2_%s == null: push_warning(\"Transforms Actuator: Rotation variable '%s' must be a number or Vector3\")" % [label,rv])
		props.append("[\"%s\", _r2_%s]" % ["global_rotation" if use_global else "rotation",label])
	if ss:
		lines.append("\tvar _s2_%s = _scale_value_%s if _scale_value_%s is Vector2 else Vector2(_scale_value_%s.x, _scale_value_%s.y) if _scale_value_%s is Vector3 else null" % [label,label,label,label,label,label])
		lines.append("\tif _s2_%s == null: push_warning(\"Transforms Actuator: Scale variable '%s' must be Vector2 or Vector3\")" % [label,sv])
		props.append("[\"%s\", _s2_%s]" % ["global_scale" if use_global else "scale",label])
	_append_apply(lines,label,props,tween,duration)

func _append_node3d(lines:Array[String], label:String, use_global:bool, sp:bool, sr:bool, ss:bool, tween:bool, duration:float, pv:String, rv:String, sv:String) -> void:
	var props:Array[String] = []
	if sp:
		lines.append("\tvar _p3_%s = _position_value_%s if _position_value_%s is Vector3 else null" % [label,label,label])
		lines.append("\tif _p3_%s == null: push_warning(\"Transforms Actuator: Position variable '%s' must be Vector3\")" % [label,pv])
		props.append("[\"%s\", _p3_%s]" % ["global_position" if use_global else "position",label])
	if sr:
		lines.append("\tvar _r3_%s = _rotation_value_%s if _rotation_value_%s is Vector3 else null" % [label,label,label])
		lines.append("\tif _r3_%s == null: push_warning(\"Transforms Actuator: Rotation variable '%s' must be Vector3\")" % [label,rv])
		props.append("[\"%s\", _r3_%s]" % ["global_rotation" if use_global else "rotation",label])
	if ss:
		lines.append("\tvar _s3_%s = _scale_value_%s if _scale_value_%s is Vector3 else null" % [label,label,label])
		lines.append("\tif _s3_%s == null: push_warning(\"Transforms Actuator: Scale variable '%s' must be Vector3\")" % [label,sv])
		props.append("[\"scale\", _s3_%s]" % label)
	_append_apply(lines,label,props,tween,duration)

func _append_apply(lines:Array[String], label:String, props:Array[String], tween:bool, duration:float) -> void:
	lines.append("\tvar _transform_values_%s = [%s]" % [label,", ".join(props)])
	if tween:
		lines.append("\tvar _transform_tween_%s = create_tween().set_parallel(true)" % label)
		lines.append("\t_transform_tween_%s.set_trans(%s).set_ease(%s)" % [label,_transition_const(),_ease_const()])
		lines.append("\tfor _entry_%s in _transform_values_%s:" % [label,label])
		lines.append("\t\tif _entry_%s[1] != null: _transform_tween_%s.tween_property(_transform_target_%s, _entry_%s[0], _entry_%s[1], %.6f)" % [label,label,label,label,label,duration])
	else:
		lines.append("\tfor _entry_%s in _transform_values_%s:" % [label,label])
		lines.append("\t\tif _entry_%s[1] != null: _transform_target_%s.set(_entry_%s[0], _entry_%s[1])" % [label,label,label,label])

func _transition_const() -> String:
	var m={"linear":"Tween.TRANS_LINEAR","sine":"Tween.TRANS_SINE","quad":"Tween.TRANS_QUAD","cubic":"Tween.TRANS_CUBIC","quart":"Tween.TRANS_QUART","quint":"Tween.TRANS_QUINT","expo":"Tween.TRANS_EXPO","circ":"Tween.TRANS_CIRC","back":"Tween.TRANS_BACK","elastic":"Tween.TRANS_ELASTIC","bounce":"Tween.TRANS_BOUNCE"}
	return m.get(_key(properties.get("transition","Sine")),"Tween.TRANS_SINE")
func _ease_const() -> String:
	var m={"in":"Tween.EASE_IN","out":"Tween.EASE_OUT","in_out":"Tween.EASE_IN_OUT","out_in":"Tween.EASE_OUT_IN"}
	return m.get(_key(properties.get("ease","In Out")),"Tween.EASE_IN_OUT")
func _key(v) -> String: return str(v).to_lower().replace(" ","_")
func _sanitize_identifier(value:String)->String:
	var s=value.strip_edges().replace(" ","_"); var r=RegEx.new(); r.compile("[^a-zA-Z0-9_]"); return r.sub(s,"",true)
func _unique_label(chain_name:String)->String:
	var s="%s_%s"%[chain_name,str(abs(str(properties).hash()))]; var r=RegEx.new(); r.compile("[^a-zA-Z0-9_]"); return r.sub(s,"",true)
func _gd_string(value:String)->String: return value.replace("\\","\\\\").replace("\"","\\\"")
