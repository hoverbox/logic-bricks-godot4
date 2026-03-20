@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Environment Actuator - Modify WorldEnvironment properties at runtime
## Assign a WorldEnvironment node via @export (drag and drop in inspector)
## All numeric/color fields accept a literal value OR a variable name / expression


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Environment"


func _initialize_properties() -> void:
	properties = {
		# --- FOG ---
		"fog_enabled":            false,
		"fog_density":            "0.01",
		"fog_light_color":        Color(0.518, 0.553, 0.608),
		"fog_light_energy":       "1.0",
		"fog_sun_scatter":        "0.0",
		"fog_height":             "0.0",
		"fog_height_density":     "0.0",
		"fog_aerial_perspective": "0.0",
		"fog_sky_affect":         "1.0",

		# --- GLOW ---
		"glow_enabled":           false,
		"glow_level_1":           "0.0",
		"glow_level_2":           "0.0",
		"glow_level_3":           "1.0",
		"glow_level_4":           "0.0",
		"glow_level_5":           "1.0",
		"glow_level_6":           "0.0",
		"glow_level_7":           "0.0",
		"glow_normalized":          false,
		"glow_intensity":           "0.8",
		"glow_strength":            "1.0",
		"glow_mix":                 "0.05",
		"glow_bloom":               "0.0",
		"glow_blend_mode":          2,
		"glow_hdr_luminance_cap":   "12.0",
		"glow_hdr_threshold":       "1.0",
		"glow_hdr_scale":           "2.0",
		"glow_map_strength":        "0.8",

		# --- SSAO ---
		"ssao_enabled":   false,
		"ssao_radius":    "1.0",
		"ssao_intensity": "2.0",
		"ssao_power":     "1.5",
		"ssao_detail":    "0.5",
		"ssao_horizon":   "0.06",
		"ssao_sharpness": "0.98",
		"ssao_light_affect": "0.0",

		# --- SSIL ---
		"ssil_enabled":          false,
		"ssil_radius":           "5.0",
		"ssil_intensity":        "1.0",
		"ssil_sharpness":        "0.98",
		"ssil_normal_rejection": "1.0",

		# --- TONE MAPPING ---
		"tonemap_mode":     0,
		"tonemap_exposure": "1.0",
		"tonemap_white":    "1.0",

		# --- COLOR CORRECTION ---
		"adjustment_enabled":    false,
		"adjustment_brightness": "1.0",
		"adjustment_contrast":   "1.0",
		"adjustment_saturation": "1.0",

		# --- TRANSITION ---
		"transition":       false,
		"transition_speed": "1.0",
	}


func get_property_definitions() -> Array:
	return [
		# === FOG GROUP ===
		{ "name": "_group_fog",           "type": TYPE_NIL, "hint": 999, "hint_string": "Fog" },
		{ "name": "fog_enabled",          "type": TYPE_BOOL, "default": false },
		{ "name": "fog_density",          "type": TYPE_STRING, "default": "0.01" },
		{ "name": "fog_light_color",      "type": TYPE_COLOR, "default": Color(0.518, 0.553, 0.608) },
		{ "name": "fog_light_energy",     "type": TYPE_STRING, "default": "1.0" },
		{ "name": "fog_sun_scatter",      "type": TYPE_STRING, "default": "0.0" },
		{ "name": "fog_height",           "type": TYPE_STRING, "default": "0.0" },
		{ "name": "fog_height_density",   "type": TYPE_STRING, "default": "0.0" },
		{ "name": "fog_aerial_perspective","type": TYPE_STRING, "default": "0.0" },
		{ "name": "fog_sky_affect",       "type": TYPE_STRING, "default": "1.0" },

		# === GLOW GROUP ===
		{ "name": "_group_glow", "type": TYPE_NIL, "hint": 999, "hint_string": "Glow", "collapsed": true },
		{ "name": "glow_enabled",             "type": TYPE_BOOL, "default": false },
		{ "name": "glow_level_1",             "type": TYPE_STRING, "default": "0.0" },
		{ "name": "glow_level_2",             "type": TYPE_STRING, "default": "0.0" },
		{ "name": "glow_level_3",             "type": TYPE_STRING, "default": "1.0" },
		{ "name": "glow_level_4",             "type": TYPE_STRING, "default": "0.0" },
		{ "name": "glow_level_5",             "type": TYPE_STRING, "default": "1.0" },
		{ "name": "glow_level_6",             "type": TYPE_STRING, "default": "0.0" },
		{ "name": "glow_level_7",             "type": TYPE_STRING, "default": "0.0" },
		{ "name": "glow_normalized",          "type": TYPE_BOOL, "default": false },
		{ "name": "glow_intensity",           "type": TYPE_STRING, "default": "0.8" },
		{ "name": "glow_strength",            "type": TYPE_STRING, "default": "1.0" },
		{ "name": "glow_mix",                 "type": TYPE_STRING, "default": "0.05" },
		{ "name": "glow_bloom",               "type": TYPE_STRING, "default": "0.0" },
		{ "name": "glow_blend_mode",          "type": TYPE_INT, "hint": PROPERTY_HINT_ENUM, "hint_string": "Additive,Screen,Softlight,Replace,Mix", "default": 2 },
		{ "name": "glow_hdr_luminance_cap",   "type": TYPE_STRING, "default": "12.0" },
		{ "name": "glow_hdr_threshold",       "type": TYPE_STRING, "default": "1.0" },
		{ "name": "glow_hdr_scale",           "type": TYPE_STRING, "default": "2.0" },
		{ "name": "glow_map_strength",        "type": TYPE_STRING, "default": "0.8" },

		# === SSAO GROUP ===
		{ "name": "_group_ssao", "type": TYPE_NIL, "hint": 999, "hint_string": "SSAO", "collapsed": true },
		{ "name": "ssao_enabled",   "type": TYPE_BOOL, "default": false },
		{ "name": "ssao_radius",    "type": TYPE_STRING, "default": "1.0" },
		{ "name": "ssao_intensity", "type": TYPE_STRING, "default": "2.0" },
		{ "name": "ssao_power",     "type": TYPE_STRING, "default": "1.5" },
		{ "name": "ssao_detail",    "type": TYPE_STRING, "default": "0.5" },
		{ "name": "ssao_horizon",   "type": TYPE_STRING, "default": "0.06" },
		{ "name": "ssao_sharpness", "type": TYPE_STRING, "default": "0.98" },
		{ "name": "ssao_light_affect", "type": TYPE_STRING, "default": "0.0" },

		# === SSIL GROUP ===
		{ "name": "_group_ssil", "type": TYPE_NIL, "hint": 999, "hint_string": "SSIL", "collapsed": true },
		{ "name": "ssil_enabled",          "type": TYPE_BOOL, "default": false },
		{ "name": "ssil_radius",           "type": TYPE_STRING, "default": "5.0" },
		{ "name": "ssil_intensity",        "type": TYPE_STRING, "default": "1.0" },
		{ "name": "ssil_sharpness",        "type": TYPE_STRING, "default": "0.98" },
		{ "name": "ssil_normal_rejection", "type": TYPE_STRING, "default": "1.0" },

		# === TONE MAPPING GROUP ===
		{ "name": "_group_tonemap", "type": TYPE_NIL, "hint": 999, "hint_string": "Tone Mapping", "collapsed": true },
		{ "name": "tonemap_mode",       "type": TYPE_INT, "hint": PROPERTY_HINT_ENUM, "hint_string": "Linear,Reinhardt,Filmic,ACES", "default": 0 },
		{ "name": "tonemap_exposure",   "type": TYPE_STRING, "default": "1.0" },
		{ "name": "tonemap_white",      "type": TYPE_STRING, "default": "1.0" },

		# === COLOR CORRECTION GROUP ===
		{ "name": "_group_adjustment", "type": TYPE_NIL, "hint": 999, "hint_string": "Color Correction", "collapsed": true },
		{ "name": "adjustment_enabled",     "type": TYPE_BOOL, "default": false },
		{ "name": "adjustment_brightness",  "type": TYPE_STRING, "default": "1.0" },
		{ "name": "adjustment_contrast",    "type": TYPE_STRING, "default": "1.0" },
		{ "name": "adjustment_saturation",  "type": TYPE_STRING, "default": "1.0" },

		# === TRANSITION GROUP ===
		{ "name": "_group_transition", "type": TYPE_NIL, "hint": 999, "hint_string": "Transition", "collapsed": true },
		{ "name": "transition",         "type": TYPE_BOOL, "default": false },
		{ "name": "transition_speed",   "type": TYPE_STRING, "default": "1.0" },
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Modifies WorldEnvironment properties at runtime.\nDrag your WorldEnvironment node into the inspector slot.\nAll value fields accept a number or a variable name / expression.",
		# Fog
		"fog_enabled":            "Enable or disable fog.",
		"fog_density":            "Overall fog density.\nAccepts: 0.01  or  fog_var  or  base_density * 2.0",
		"fog_light_color":        "Color of the fog.",
		"fog_light_energy":       "Brightness of the fog color.",
		"fog_sun_scatter":        "How much light scatters toward the sun direction.",
		"fog_height":             "Height at which height fog begins.",
		"fog_height_density":     "Density of height fog. 0 disables it.",
		"fog_aerial_perspective": "Blends sky color into distant objects.",
		"fog_sky_affect":         "How much fog affects the sky.",
		# Glow
		"glow_enabled":           "Enable or disable glow/bloom.",
		"glow_level_1":           "Contribution of blur pass 1 (finest detail).",
		"glow_level_2":           "Contribution of blur pass 2.",
		"glow_level_3":           "Contribution of blur pass 3.",
		"glow_level_4":           "Contribution of blur pass 4.",
		"glow_level_5":           "Contribution of blur pass 5.",
		"glow_level_6":           "Contribution of blur pass 6.",
		"glow_level_7":           "Contribution of blur pass 7 (widest spread).",
		"glow_normalized":        "Normalize glow so total brightness stays constant.",
		"glow_intensity":         "Overall glow brightness multiplier.",
		"glow_strength":          "Strength of the glow blur.",
		"glow_mix":               "Blend amount with original image (Mix mode only).",
		"glow_bloom":             "Sends the entire screen to glow at this strength.",
		"glow_blend_mode":        "How glow is composited over the scene.",
		"glow_hdr_luminance_cap": "Cap on luminance sent to the glow buffer.",
		"glow_hdr_threshold":     "Lower threshold — pixels brighter than this bleed into glow.",
		"glow_hdr_scale":         "Scale applied to pixels above the HDR threshold.",
		"glow_map_strength":      "Strength of the optional glow map texture.",
		# SSAO
		"ssao_enabled":      "Enable Screen Space Ambient Occlusion.",
		"ssao_radius":       "Sampling radius for occlusion.",
		"ssao_intensity":    "Strength of the occlusion darkening.",
		"ssao_power":        "Curve applied to the occlusion.",
		"ssao_detail":       "Extra detail pass for small crevices.",
		"ssao_horizon":      "Reduces halo artifacts near horizon lines.",
		"ssao_sharpness":    "Sharpness of the blur. Lower = softer.",
		"ssao_light_affect": "How much SSAO darkens direct light.",
		# SSIL
		"ssil_enabled":          "Enable Screen Space Indirect Lighting.",
		"ssil_radius":           "Sampling radius for indirect light.",
		"ssil_intensity":        "Strength of the indirect lighting.",
		"ssil_sharpness":        "Sharpness of the SSIL blur.",
		"ssil_normal_rejection": "Reduces bleeding across surface normals.",
		# Tone Mapping
		"tonemap_mode":     "Linear / Reinhardt / Filmic / ACES.",
		"tonemap_exposure": "Scene exposure before tonemapping.",
		"tonemap_white":    "White point value.",
		# Color Correction
		"adjustment_enabled":    "Enable color correction.",
		"adjustment_brightness": "Overall brightness. 1.0 = default.",
		"adjustment_contrast":   "Contrast. 1.0 = default.",
		"adjustment_saturation": "Saturation. 0.0 = greyscale, 1.0 = default.",
		# Transition
		"transition":       "Smoothly lerp to the target values each frame.\nOnly applies to float properties — not bools or enums.",
		"transition_speed": "Lerp speed. 1.0 = ~1 second to reach target. Higher = faster.",
	}


## Map property name to [env_path, use_set_method]
## use_set_method = true for glow levels which use the "glow_levels/N" path syntax
func _get_env_path(prop_name: String) -> Array:
	match prop_name:
		"fog_enabled":            return ["fog_enabled", false]
		"fog_density":            return ["fog_density", false]
		"fog_light_color":        return ["fog_light_color", false]
		"fog_light_energy":       return ["fog_light_energy", false]
		"fog_sun_scatter":        return ["fog_sun_scatter", false]
		"fog_height":             return ["fog_height", false]
		"fog_height_density":     return ["fog_height_density", false]
		"fog_aerial_perspective": return ["fog_aerial_perspective", false]
		"fog_sky_affect":         return ["fog_sky_affect", false]
		"glow_enabled":           return ["glow_enabled", false]
		"glow_level_1":           return ["glow_levels/1", true]
		"glow_level_2":           return ["glow_levels/2", true]
		"glow_level_3":           return ["glow_levels/3", true]
		"glow_level_4":           return ["glow_levels/4", true]
		"glow_level_5":           return ["glow_levels/5", true]
		"glow_level_6":           return ["glow_levels/6", true]
		"glow_level_7":           return ["glow_levels/7", true]
		"glow_normalized":          return ["glow_normalized", false]
		"glow_intensity":           return ["glow_intensity", false]
		"glow_strength":            return ["glow_strength", false]
		"glow_mix":                 return ["glow_mix", false]
		"glow_bloom":               return ["glow_bloom", false]
		"glow_blend_mode":          return ["glow_blend_mode", false]
		"glow_hdr_luminance_cap":   return ["glow_hdr_luminance_cap", false]
		"glow_hdr_threshold":       return ["glow_hdr_threshold", false]
		"glow_hdr_scale":           return ["glow_hdr_scale", false]
		"glow_map_strength":        return ["glow_map_strength", false]
		"ssao_enabled":      return ["ssao_enabled", false]
		"ssao_radius":       return ["ssao_radius", false]
		"ssao_intensity":    return ["ssao_intensity", false]
		"ssao_power":        return ["ssao_power", false]
		"ssao_detail":       return ["ssao_detail", false]
		"ssao_horizon":      return ["ssao_horizon", false]
		"ssao_sharpness":    return ["ssao_sharpness", false]
		"ssao_light_affect": return ["ssao_light_affect", false]
		"ssil_enabled":          return ["ssil_enabled", false]
		"ssil_radius":           return ["ssil_radius", false]
		"ssil_intensity":        return ["ssil_intensity", false]
		"ssil_sharpness":        return ["ssil_sharpness", false]
		"ssil_normal_rejection": return ["ssil_normal_rejection", false]
		"tonemap_mode":     return ["tonemap_mode", false]
		"tonemap_exposure": return ["tonemap_exposure", false]
		"tonemap_white":    return ["tonemap_white", false]
		"adjustment_enabled":    return ["adjustment_enabled", false]
		"adjustment_brightness": return ["adjustment_brightness", false]
		"adjustment_contrast":   return ["adjustment_contrast", false]
		"adjustment_saturation": return ["adjustment_saturation", false]
	return ["", false]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var transition = properties.get("transition", false)
	var speed_raw = properties.get("transition_speed", "1.0")
	var speed = _to_expr(speed_raw)

	# Use instance name if set, otherwise use brick name, sanitized for use as a variable
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name
	var env_var = "_%s" % _export_label

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("@export var %s: WorldEnvironment" % env_var)

	code_lines.append("# Environment Actuator")
	code_lines.append("if %s and %s.environment:" % [env_var, env_var])

	var any_prop = false

	for prop_name in properties:
		if prop_name.begins_with("_group_") or prop_name in ["transition", "transition_speed"]:
			continue

		var resolved = _get_env_path(prop_name)
		var env_path: String = resolved[0]
		var use_set: bool = resolved[1]
		if env_path.is_empty():
			continue

		var val = properties.get(prop_name)
		var is_bool = (typeof(val) == TYPE_BOOL)
		var is_int  = (typeof(val) == TYPE_INT)

		var val_str: String
		if is_bool:
			val_str = "true" if val else "false"
		elif is_int:
			val_str = str(val)
		else:
			val_str = _to_expr(val)

		any_prop = true

		if transition and not is_bool and not is_int:
			var cur = "_env_cur_%s_%s" % [prop_name, chain_name]
			var tgt = "_env_tgt_%s_%s" % [prop_name, chain_name]
			if use_set:
				code_lines.append("\tvar %s = %s.environment.get(\"%s\")" % [cur, env_var, env_path])
			else:
				code_lines.append("\tvar %s = %s.environment.%s" % [cur, env_var, env_path])
			code_lines.append("\tvar %s = %s" % [tgt, val_str])
			var lerped = "_env_lerp_%s_%s" % [prop_name, chain_name]
			# Color strings start with "Color(" — use lerp(), else lerpf()
			if _is_color(val):
				code_lines.append("\tvar %s = %s.lerp(%s, %s * _delta)" % [lerped, cur, tgt, speed])
			else:
				code_lines.append("\tvar %s = lerpf(%s, %s, %s * _delta)" % [lerped, cur, tgt, speed])
			if use_set:
				code_lines.append("\t%s.environment.set(\"%s\", %s)" % [env_var, env_path, lerped])
			else:
				code_lines.append("\t%s.environment.%s = %s" % [env_var, env_path, lerped])
		else:
			if use_set:
				code_lines.append("\t%s.environment.set(\"%s\", %s)" % [env_var, env_path, val_str])
			else:
				code_lines.append("\t%s.environment.%s = %s" % [env_var, env_path, val_str])

	if not any_prop:
		code_lines.append("\tpass")

	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Environment Actuator: No WorldEnvironment assigned to '%s' — drag one into the inspector\")" % env_var)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}


## Convert a value to a code expression, same pattern as MotionActuator
func _to_expr(val) -> String:
	if typeof(val) == TYPE_COLOR:
		return "Color(%.4f, %.4f, %.4f, %.4f)" % [val.r, val.g, val.b, val.a]
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		return str(val)
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.0"
	if s.is_valid_float() or s.is_valid_int():
		return s
	# Variable name, expression, or Color(...) literal — emit as-is
	return s


## Returns true if the value looks like a Color
func _is_color(val) -> bool:
	if typeof(val) == TYPE_COLOR:
		return true
	var s = str(val).strip_edges()
	return s.begins_with("Color(")
