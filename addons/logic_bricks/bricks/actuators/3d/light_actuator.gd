@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Light Actuator - Control light properties and apply animated FX effects
## Works with OmniLight3D, SpotLight3D, and DirectionalLight3D
## Select the light type to expose the correct properties


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Light"


func _initialize_properties() -> void:
	properties = {
		# Target light. Blank means this node.
		"target_node_name":   "",

		# Light type
		"light_type":         "omnilight3d",

		# Common properties
		"set_color":          false,
		"color":              Color(1, 1, 1, 1),
		"set_energy":         false,
		"energy":             1.0,
		"set_indirect_energy": false,
		"indirect_energy":    1.0,
		"set_specular":       false,
		"specular":           0.5,
		"set_shadow":         false,
		"shadow_enabled":     false,
		"set_visible":        false,
		"light_visible":      true,

		# OmniLight3D / SpotLight3D only
		"set_range":          false,
		"light_range":        10.0,

		# SpotLight3D only
		"set_spot_angle":     false,
		"spot_angle":         45.0,
		"set_spot_attenuation": false,
		"spot_attenuation":   1.0,

		# FX
		"fx":                 "normal",

		# Flicker params
		"flicker_normal_energy": 1.0,
		"flicker_min":           0.0,
		"flicker_max":           0.8,
		"flicker_idle_min":      1.0,
		"flicker_idle_max":      4.0,
		"flicker_burst_duration": 0.3,

		# Strobe params
		"strobe_frequency":   10.0,
		"strobe_on_energy":   1.0,
		"strobe_off_energy":  0.0,

		# Pulse params
		"pulse_min":          0.2,
		"pulse_max":          1.0,
		"pulse_speed":        2.0,

		# Fade params
		"fade_target":        1.0,
		"fade_speed":         2.0,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_node_name",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "blank = self, or light node name",
			"node_reference": true,
			"accepted_node_types": ["OmniLight3D", "SpotLight3D", "DirectionalLight3D"]
		},

		# ── Light Type ──
		{"name": "light_type_group", "type": TYPE_NIL, "hint": 999, "hint_string": "Light Type"},
		{
			"name": "light_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "OmniLight3D,SpotLight3D,DirectionalLight3D",
			"default": "omnilight3d"
		},

		# ── Common Properties ──
		{"name": "common_group", "type": TYPE_NIL, "hint": 999, "hint_string": "Properties"},
		{"name": "set_color",          "type": TYPE_BOOL,  "default": false},
		{"name": "color",              "type": TYPE_COLOR, "default": Color(1, 1, 1, 1)},
		{"name": "set_energy",         "type": TYPE_BOOL,  "default": false},
		{"name": "energy",             "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,16.0,0.01", "default": 1.0},
		{"name": "set_indirect_energy","type": TYPE_BOOL,  "default": false},
		{"name": "indirect_energy",    "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,16.0,0.01", "default": 1.0},
		{"name": "set_specular",       "type": TYPE_BOOL,  "default": false},
		{"name": "specular",           "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,1.0,0.01", "default": 0.5},
		{"name": "set_shadow",         "type": TYPE_BOOL,  "default": false},
		{"name": "shadow_enabled",     "type": TYPE_BOOL,  "default": false},
		{"name": "set_visible",        "type": TYPE_BOOL,  "default": false},
		{"name": "light_visible",      "type": TYPE_BOOL,  "default": true},

		# ── OmniLight / Spot only ──
		{"name": "set_range",          "type": TYPE_BOOL,  "default": false},
		{"name": "light_range",        "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,100.0,0.1", "default": 10.0},

		# ── SpotLight only ──
		{"name": "set_spot_angle",     "type": TYPE_BOOL,  "default": false},
		{"name": "spot_angle",         "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,90.0,0.1", "default": 45.0},
		{"name": "set_spot_attenuation","type": TYPE_BOOL, "default": false},
		{"name": "spot_attenuation",   "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,8.0,0.01", "default": 1.0},

		# ── FX ──
		{"name": "fx_group", "type": TYPE_NIL, "hint": 999, "hint_string": "FX"},
		{
			"name": "fx",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Normal,Flicker,Strobe,Pulse,Fade In,Fade Out",
			"default": "normal"
		},

		# FX params group (shown when fx != normal)
		{"name": "fx_params_group", "type": TYPE_NIL, "hint": 999, "hint_string": "FX Parameters", "collapsed": true},

		# Flicker
		{"name": "flicker_normal_energy", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,16.0,0.01", "default": 1.0},
		{"name": "flicker_min",           "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,16.0,0.01", "default": 0.0},
		{"name": "flicker_max",           "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,16.0,0.01", "default": 0.8},
		{"name": "flicker_idle_min",      "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,30.0,0.1",  "default": 1.0},
		{"name": "flicker_idle_max",      "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,30.0,0.1",  "default": 4.0},
		{"name": "flicker_burst_duration","type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.05,5.0,0.05", "default": 0.3},

		# Strobe
		{"name": "strobe_frequency",   "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,60.0,0.1", "default": 10.0},
		{"name": "strobe_on_energy",   "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,16.0,0.01", "default": 1.0},
		{"name": "strobe_off_energy",  "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,16.0,0.01", "default": 0.0},

		# Pulse
		{"name": "pulse_min",   "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,16.0,0.01", "default": 0.2},
		{"name": "pulse_max",   "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,16.0,0.01", "default": 1.0},
		{"name": "pulse_speed", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,20.0,0.1",  "default": 2.0},

		# Fade
		{"name": "fade_target", "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.0,16.0,0.01", "default": 1.0},
		{"name": "fade_speed",  "type": TYPE_FLOAT, "hint": PROPERTY_HINT_RANGE, "hint_string": "0.1,20.0,0.1",  "default": 2.0},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description":        "Control a light node's properties and apply animated FX effects.\nLeave Target Light blank to affect this node, or enter another light node name.",
		"target_node_name":     "Leave blank to affect this node, or enter/drag an OmniLight3D, SpotLight3D, or DirectionalLight3D node name.",
		"light_type":          "The type of light node this actuator targets.\nMust match the actual target light type in your scene.",
		"set_color":           "Enable to set the light's color.",
		"color":               "The color to set on the light.",
		"set_energy":          "Enable to set the light's energy (brightness).",
		"energy":              "Light energy/brightness value.",
		"set_indirect_energy": "Enable to set how much this light contributes to indirect (GI) lighting.",
		"indirect_energy":     "Indirect lighting energy multiplier.",
		"set_specular":        "Enable to set the specular highlight intensity.",
		"specular":            "Specular highlight multiplier (0 = no highlights, 1 = full).",
		"set_shadow":          "Enable to toggle shadow casting on or off.",
		"shadow_enabled":      "Whether the light casts shadows.",
		"set_visible":         "Enable to show or hide the light node.",
		"light_visible":       "Whether the light node is visible.",
		"set_range":           "Enable to set the light's range (OmniLight3D / SpotLight3D only).",
		"light_range":         "How far the light reaches in world units.",
		"set_spot_angle":      "Enable to set the spot cone angle (SpotLight3D only).",
		"spot_angle":          "Half-angle of the spot cone in degrees.",
		"set_spot_attenuation":"Enable to set spot cone edge softness (SpotLight3D only).",
		"spot_attenuation":    "How quickly the spot light fades at the cone edge. Higher = sharper.",
		"fx":                  "Animated lighting effect.\nNormal = static property sets only.\nOther modes animate light energy each frame.",
		"flicker_normal_energy": "Light energy during the calm idle period between bursts.",
		"flicker_min":           "Minimum energy during a flicker burst.",
		"flicker_max":           "Maximum energy during a flicker burst.",
		"flicker_idle_min":      "Minimum seconds the light stays calm between bursts.",
		"flicker_idle_max":      "Maximum seconds the light stays calm between bursts.",
		"flicker_burst_duration":"How long each flicker burst lasts in seconds.",
		"strobe_frequency":    "Strobe flashes per second.",
		"strobe_on_energy":    "Light energy when the strobe is on.",
		"strobe_off_energy":   "Light energy when the strobe is off.",
		"pulse_min":           "Minimum energy of the sine pulse.",
		"pulse_max":           "Maximum energy of the sine pulse.",
		"pulse_speed":         "Oscillation speed in cycles per second.",
		"fade_target":         "Target energy to fade toward.",
		"fade_speed":          "Lerp speed toward the target. Higher = faster.",
	}


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var light_type = _light_type()
	var fx         = properties.get("fx", "normal").to_lower().replace(" ", "_")
	var is_spot    = (light_type == "spotlight3d")
	var is_omni_or_spot = (light_type in ["omnilight3d", "spotlight3d"])
	for node in _get_field_names():
		var prop_name = node
		match prop_name:
			"set_range", "light_range":
				shown[node] = is_omni_or_spot
			"set_spot_angle", "spot_angle", "set_spot_attenuation", "spot_attenuation":
				shown[node] = is_spot
			"fx_params_group":
				shown[node] = (fx != "normal")
			"flicker_normal_energy", "flicker_min", "flicker_max", "flicker_idle_min", "flicker_idle_max", "flicker_burst_duration":
				shown[node] = (fx == "flicker")
			"strobe_frequency", "strobe_on_energy", "strobe_off_energy":
				shown[node] = (fx == "strobe")
			"pulse_min", "pulse_max", "pulse_speed":
				shown[node] = (fx == "pulse")
			"fade_target", "fade_speed":
				shown[node] = (fx in ["fade_in", "fade_out"])
	return shown


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name   = str(properties.get("target_node_name", "")).strip_edges()
	var light_type         = _light_type()
	# On its own node the light's type is known, so use it: a type that does
	# not match the node (an old "omni" default on a SpotLight3D, or a wrong
	# pick in the dropdown) would make `self as <type>` a cast GDScript
	# rejects, and the whole script would fail to load.
	if target_node_name.is_empty() and node != null:
		var node_type := _light_type_of(node)
		if node_type.is_empty():
			return {"actuator_code": "push_warning(\"Light Actuator: this node is not a light. Put it on an OmniLight3D, SpotLight3D or DirectionalLight3D, or set Target Node.\")"}
		light_type = node_type
	var fx                 = str(properties.get("fx", "normal")).to_lower().replace(" ", "_")

	var set_color          = properties.get("set_color", false)
	var color              = properties.get("color", Color(1, 1, 1, 1))
	var set_energy         = properties.get("set_energy", false)
	var energy             = _fv("energy", 1.0)
	var set_indirect       = properties.get("set_indirect_energy", false)
	var indirect_energy    = _fv("indirect_energy", 1.0)
	var set_specular       = properties.get("set_specular", false)
	var specular           = _fv("specular", 0.5)
	var set_shadow         = properties.get("set_shadow", false)
	var shadow_enabled     = properties.get("shadow_enabled", false)
	var set_visible        = properties.get("set_visible", false)
	var light_visible      = properties.get("light_visible", true)
	var set_range          = properties.get("set_range", false)
	var light_range        = _fv("light_range", 10.0)
	var set_spot_angle     = properties.get("set_spot_angle", false)
	var spot_angle         = _fv("spot_angle", 45.0)
	var set_spot_atten     = properties.get("set_spot_attenuation", false)
	var spot_atten         = _fv("spot_attenuation", 1.0)

	var flicker_normal     = _fv("flicker_normal_energy", 1.0)
	var flicker_min        = _fv("flicker_min", 0.0)
	var flicker_max        = _fv("flicker_max", 0.8)
	var flicker_idle_min   = _fv("flicker_idle_min", 1.0)
	var flicker_idle_max   = _fv("flicker_idle_max", 4.0)
	var flicker_burst      = _fv("flicker_burst_duration", 0.3)
	var strobe_freq        = _fv("strobe_frequency", 10.0)
	var strobe_on          = _fv("strobe_on_energy", 1.0)
	var strobe_off         = _fv("strobe_off_energy", 0.0)
	var pulse_min          = _fv("pulse_min", 0.2)
	var pulse_max          = _fv("pulse_max", 1.0)
	var pulse_speed        = _fv("pulse_speed", 2.0)
	var fade_target        = _fv("fade_target", 1.0)
	var fade_speed         = _fv("fade_speed", 2.0)

	# Unique per-chain variable names
	var light_var  = "_light_%s" % chain_name
	var timer_var  = "_light_timer_%s" % chain_name

	var member_vars:  Array[String] = []
	var code_lines:   Array[String] = []

	# FX modes that need per-frame state
	if fx == "flicker":
		member_vars.append("var %s: bool = false" % ("_flicker_bursting_%s" % chain_name))
		if _is_number_expression("flicker_idle_min") or _is_number_expression("flicker_idle_max"):
			# Variables are not ready yet when member variables are created:
			# pick the first idle time the first time the brick runs instead.
			member_vars.append("var %s: float = -1.0" % ("_flicker_idle_%s" % chain_name))
		else:
			member_vars.append("var %s: float = randf_range(%s, %s)" % ["_flicker_idle_%s" % chain_name, flicker_idle_min, flicker_idle_max])
		member_vars.append("var %s: float = 0.0" % ("_flicker_burst_%s" % chain_name))
	if fx in ["strobe", "pulse"]:
		member_vars.append("var %s: float = 0.0" % timer_var)

	# Resolve the target light. Blank target means self.
	var light_class = _godot_class(light_type)
	code_lines.append("# Light Actuator")
	if target_node_name.is_empty():
		code_lines.append("var %s = self as %s" % [light_var, light_class])
		code_lines.append("if not %s:" % light_var)
		code_lines.append("\tpush_warning(\"Light Actuator: This node is not a %s\")" % _gd_string(str(light_class)))
	else:
		var escaped_target = _gd_string(target_node_name)
		var target_var = "_light_target_%s" % chain_name
		code_lines.append("var %s = find_child(\"%s\", true, false)" % [target_var, escaped_target])
		code_lines.append("if %s == null and get_tree().current_scene:" % target_var)
		code_lines.append("\t%s = get_tree().current_scene.find_child(\"%s\", true, false)" % [target_var, escaped_target])
		code_lines.append("var %s = %s as %s" % [light_var, target_var, light_class])
		code_lines.append("if not %s:" % light_var)
		code_lines.append("\tpush_warning(\"Light Actuator: Could not find %s named '%s'\")" % [_gd_string(str(light_class)), escaped_target])
	code_lines.append("else:")

	# ── Static property sets ──
	if set_color:
		code_lines.append("\t%s.light_color = %s" % [light_var, _color_expr(color)])
	if set_energy:
		code_lines.append("\t%s.light_energy = %s" % [light_var, energy])
	if set_indirect:
		code_lines.append("\t%s.light_indirect_energy = %s" % [light_var, indirect_energy])
	if set_specular:
		code_lines.append("\t%s.light_specular = %s" % [light_var, specular])
	if set_shadow:
		code_lines.append("\t%s.shadow_enabled = %s" % [light_var, str(shadow_enabled).to_lower()])
	if set_visible:
		code_lines.append("\t%s.visible = %s" % [light_var, str(light_visible).to_lower()])
	if set_range and light_type in ["omnilight3d", "spotlight3d"]:
		var range_prop = "omni_range" if light_type == "omnilight3d" else "spot_range"
		code_lines.append("\t%s.%s = %s" % [light_var, range_prop, light_range])
	if set_spot_angle and light_type == "spotlight3d":
		code_lines.append("\t%s.spot_angle = %s" % [light_var, spot_angle])
	if set_spot_atten and light_type == "spotlight3d":
		code_lines.append("\t%s.spot_angle_attenuation = %s" % [light_var, spot_atten])

	# ── FX ──
	match fx:
		"normal":
			pass  # Static sets above are sufficient

		"flicker":
			var bursting_var  = "_flicker_bursting_%s" % chain_name
			var idle_var      = "_flicker_idle_%s" % chain_name
			var burst_var     = "_flicker_burst_%s" % chain_name
			if _is_number_expression("flicker_idle_min") or _is_number_expression("flicker_idle_max"):
				code_lines.append("\tif %s < 0.0 and not %s:" % [idle_var, bursting_var])
				code_lines.append("\t\t%s = randf_range(%s, %s)" % [idle_var, flicker_idle_min, flicker_idle_max])
			code_lines.append("\tif %s:" % bursting_var)
			code_lines.append("\t\t# During burst: randomise energy each frame")
			code_lines.append("\t\t%s.light_energy = randf_range(%s, %s)" % [light_var, flicker_min, flicker_max])
			code_lines.append("\t\t%s -= _delta" % burst_var)
			code_lines.append("\t\tif %s <= 0.0:" % burst_var)
			code_lines.append("\t\t\t%s = false" % bursting_var)
			code_lines.append("\t\t\t%s.light_energy = %s" % [light_var, flicker_normal])
			code_lines.append("\t\t\t%s = randf_range(%s, %s)" % [idle_var, flicker_idle_min, flicker_idle_max])
			code_lines.append("\telse:")
			code_lines.append("\t\t# Idle: hold normal energy, count down to next burst")
			code_lines.append("\t\t%s.light_energy = %s" % [light_var, flicker_normal])
			code_lines.append("\t\t%s -= _delta" % idle_var)
			code_lines.append("\t\tif %s <= 0.0:" % idle_var)
			code_lines.append("\t\t\t%s = true" % bursting_var)
			code_lines.append("\t\t\t%s = %s" % [burst_var, flicker_burst])

		"strobe":
			code_lines.append("\t%s += _delta" % timer_var)
			code_lines.append("\tvar _strobe_cycle_%s = 1.0 / %s" % [chain_name, strobe_freq])
			code_lines.append("\tif fmod(%s, _strobe_cycle_%s) < _strobe_cycle_%s * 0.5:" % [timer_var, chain_name, chain_name])
			code_lines.append("\t\t%s.light_energy = %s" % [light_var, strobe_on])
			code_lines.append("\telse:")
			code_lines.append("\t\t%s.light_energy = %s" % [light_var, strobe_off])

		"pulse":
			code_lines.append("\t%s += _delta * %s" % [timer_var, pulse_speed])
			code_lines.append("\tvar _pulse_t_%s = (sin(%s) + 1.0) * 0.5" % [chain_name, timer_var])
			code_lines.append("\t%s.light_energy = lerpf(%s, %s, _pulse_t_%s)" % [light_var, pulse_min, pulse_max, chain_name])

		"fade_in":
			code_lines.append("\t%s.light_energy = lerpf(%s.light_energy, %s, %s * _delta)" % [light_var, light_var, fade_target, fade_speed])

		"fade_out":
			code_lines.append("\t%s.light_energy = lerpf(%s.light_energy, %s, %s * _delta)" % [light_var, light_var, fade_target, fade_speed])

	if code_lines[-1] == "else:":
		# No Set option ticked and FX is Normal: the brick has nothing to change
		# yet. Keep the block valid (an empty else: stops the script loading).
		code_lines.append("\tpass  # Nothing to change yet: tick a Set option or choose an FX")

	var result: Dictionary = {"actuator_code": "\n".join(code_lines)}
	if member_vars.size() > 0:
		result["member_vars"] = member_vars
	return result


## The light type as the generator compares it ("omnilight3d", ...).
## Older graphs saved the short names "omni", "spot" and "directional".
func _light_type() -> String:
	var light_type := str(properties.get("light_type", "omnilight3d")).to_lower().replace(" ", "_")
	match light_type:
		"omni", "omni_light", "omnilight":
			return "omnilight3d"
		"spot", "spot_light", "spotlight":
			return "spotlight3d"
		"directional", "directional_light", "directionallight":
			return "directionallight3d"
	return light_type


## "omnilight3d", "spotlight3d" or "directionallight3d" for a light node,
## "" for anything else.
static func _light_type_of(node: Node) -> String:
	if node is SpotLight3D:
		return "spotlight3d"
	if node is DirectionalLight3D:
		return "directionallight3d"
	if node is OmniLight3D:
		return "omnilight3d"
	return ""


## When the brick is added to a light, pick that light's type.
func apply_context_defaults(node: Node) -> void:
	var node_type := _light_type_of(node)
	if not node_type.is_empty():
		properties["light_type"] = node_type


func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	var any_set := false
	for key in ["set_color", "set_energy", "set_indirect_energy", "set_specular", "set_shadow", "set_visible", "set_range", "set_spot_angle", "set_spot_attenuation"]:
		if properties.get(key, false):
			any_set = true
			break
	if not any_set and str(properties.get("fx", "normal")).to_lower().replace(" ", "_") == "normal":
		warnings.append("Tick a Set option or choose an FX so this brick changes the light")
	return warnings


func _godot_class(light_type: String) -> String:
	match light_type:
		"spotlight3d": return "SpotLight3D"
		"directionallight3d": return "DirectionalLight3D"
		_: return "OmniLight3D"


func _f(val: float) -> String:
	# Emit a clean float literal
	var s = "%.4f" % val
	# Strip trailing zeros after decimal, but keep at least one decimal place
	while s.ends_with("0") and not s.ends_with(".0"):
		s = s.left(s.length() - 1)
	return s


## Generated code for a number field: a clean literal ("0.8") or float(expression).
func _fv(key: String, fallback: float) -> String:
	if _is_number_expression(key):
		return _num(key, fallback)
	return _f(float(_literal_number(key, fallback)))


func _color_expr(c: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [_f(c.r), _f(c.g), _f(c.b), _f(c.a)]
