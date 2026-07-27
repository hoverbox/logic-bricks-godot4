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
		# Light type
		"light_type":         "omni",

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
		# ── Light Type ──
		{"name": "light_type_group", "type": TYPE_NIL, "hint": 999, "hint_string": "Light Type"},
		{
			"name": "light_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "OmniLight3D,SpotLight3D,DirectionalLight3D",
			"default": "omni"
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
		"_description":        "Control a light node's properties and apply animated FX effects.\nSelect the light type to expose its specific properties.",
		"light_type":          "The type of light node this actuator targets.\nMust match the actual node type in your scene.",
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


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var light_type         = str(properties.get("light_type", "omni")).to_lower().replace(" ", "_")
	var fx                 = str(properties.get("fx", "normal")).to_lower().replace(" ", "_")

	var set_color          = properties.get("set_color", false)
	var color              = properties.get("color", Color(1, 1, 1, 1))
	var set_energy         = properties.get("set_energy", false)
	var energy             = float(properties.get("energy", 1.0))
	var set_indirect       = properties.get("set_indirect_energy", false)
	var indirect_energy    = float(properties.get("indirect_energy", 1.0))
	var set_specular       = properties.get("set_specular", false)
	var specular           = float(properties.get("specular", 0.5))
	var set_shadow         = properties.get("set_shadow", false)
	var shadow_enabled     = properties.get("shadow_enabled", false)
	var set_visible        = properties.get("set_visible", false)
	var light_visible      = properties.get("light_visible", true)
	var set_range          = properties.get("set_range", false)
	var light_range        = float(properties.get("light_range", 10.0))
	var set_spot_angle     = properties.get("set_spot_angle", false)
	var spot_angle         = float(properties.get("spot_angle", 45.0))
	var set_spot_atten     = properties.get("set_spot_attenuation", false)
	var spot_atten         = float(properties.get("spot_attenuation", 1.0))

	var flicker_normal     = float(properties.get("flicker_normal_energy", 1.0))
	var flicker_min        = float(properties.get("flicker_min", 0.0))
	var flicker_max        = float(properties.get("flicker_max", 0.8))
	var flicker_idle_min   = float(properties.get("flicker_idle_min", 1.0))
	var flicker_idle_max   = float(properties.get("flicker_idle_max", 4.0))
	var flicker_burst      = float(properties.get("flicker_burst_duration", 0.3))
	var strobe_freq        = float(properties.get("strobe_frequency", 10.0))
	var strobe_on          = float(properties.get("strobe_on_energy", 1.0))
	var strobe_off         = float(properties.get("strobe_off_energy", 0.0))
	var pulse_min          = float(properties.get("pulse_min", 0.2))
	var pulse_max          = float(properties.get("pulse_max", 1.0))
	var pulse_speed        = float(properties.get("pulse_speed", 2.0))
	var fade_target        = float(properties.get("fade_target", 1.0))
	var fade_speed         = float(properties.get("fade_speed", 2.0))

	# Unique per-chain variable names
	var light_var  = "_light_%s" % chain_name
	var timer_var  = "_light_timer_%s" % chain_name

	var member_vars:  Array[String] = []
	var code_lines:   Array[String] = []

	# FX modes that need per-frame state
	if fx == "flicker":
		member_vars.append("var %s: bool = false" % ("_flicker_bursting_%s" % chain_name))
		member_vars.append("var %s: float = randf_range(%s, %s)" % ["_flicker_idle_%s" % chain_name, _f(flicker_idle_min), _f(flicker_idle_max)])
		member_vars.append("var %s: float = 0.0" % ("_flicker_burst_%s" % chain_name))
	if fx in ["strobe", "pulse"]:
		member_vars.append("var %s: float = 0.0" % timer_var)

	# Resolve the light node — it IS self (the actuator is added to the light node directly)
	code_lines.append("# Light Actuator")
	code_lines.append("var %s = self as %s" % [light_var, _godot_class(light_type)])
	code_lines.append("if not %s:" % light_var)
	code_lines.append("\tpush_warning(\"Light Actuator: This node is not a %s\")" % _godot_class(light_type))
	code_lines.append("else:")

	# ── Static property sets ──
	if set_color:
		code_lines.append("\t%s.light_color = %s" % [light_var, _color_expr(color)])
	if set_energy:
		code_lines.append("\t%s.light_energy = %s" % [light_var, _f(energy)])
	if set_indirect:
		code_lines.append("\t%s.light_indirect_energy = %s" % [light_var, _f(indirect_energy)])
	if set_specular:
		code_lines.append("\t%s.light_specular = %s" % [light_var, _f(specular)])
	if set_shadow:
		code_lines.append("\t%s.shadow_enabled = %s" % [light_var, str(shadow_enabled).to_lower()])
	if set_visible:
		code_lines.append("\t%s.visible = %s" % [light_var, str(light_visible).to_lower()])
	if set_range and light_type in ["omnilight3d", "spotlight3d"]:
		var range_prop = "omni_range" if light_type == "omnilight3d" else "spot_range"
		code_lines.append("\t%s.%s = %s" % [light_var, range_prop, _f(light_range)])
	if set_spot_angle and light_type == "spotlight3d":
		code_lines.append("\t%s.spot_angle = %s" % [light_var, _f(spot_angle)])
	if set_spot_atten and light_type == "spotlight3d":
		code_lines.append("\t%s.spot_angle_attenuation = %s" % [light_var, _f(spot_atten)])

	# ── FX ──
	match fx:
		"normal":
			pass  # Static sets above are sufficient

		"flicker":
			var bursting_var  = "_flicker_bursting_%s" % chain_name
			var idle_var      = "_flicker_idle_%s" % chain_name
			var burst_var     = "_flicker_burst_%s" % chain_name
			code_lines.append("\tif %s:" % bursting_var)
			code_lines.append("\t\t# During burst: randomise energy each frame")
			code_lines.append("\t\t%s.light_energy = randf_range(%s, %s)" % [light_var, _f(flicker_min), _f(flicker_max)])
			code_lines.append("\t\t%s -= _delta" % burst_var)
			code_lines.append("\t\tif %s <= 0.0:" % burst_var)
			code_lines.append("\t\t\t%s = false" % bursting_var)
			code_lines.append("\t\t\t%s.light_energy = %s" % [light_var, _f(flicker_normal)])
			code_lines.append("\t\t\t%s = randf_range(%s, %s)" % [idle_var, _f(flicker_idle_min), _f(flicker_idle_max)])
			code_lines.append("\telse:")
			code_lines.append("\t\t# Idle: hold normal energy, count down to next burst")
			code_lines.append("\t\t%s.light_energy = %s" % [light_var, _f(flicker_normal)])
			code_lines.append("\t\t%s -= _delta" % idle_var)
			code_lines.append("\t\tif %s <= 0.0:" % idle_var)
			code_lines.append("\t\t\t%s = true" % bursting_var)
			code_lines.append("\t\t\t%s = %s" % [burst_var, _f(flicker_burst)])

		"strobe":
			code_lines.append("\t%s += _delta" % timer_var)
			code_lines.append("\tvar _strobe_cycle_%s = 1.0 / %s" % [chain_name, _f(strobe_freq)])
			code_lines.append("\tif fmod(%s, _strobe_cycle_%s) < _strobe_cycle_%s * 0.5:" % [timer_var, chain_name, chain_name])
			code_lines.append("\t\t%s.light_energy = %s" % [light_var, _f(strobe_on)])
			code_lines.append("\telse:")
			code_lines.append("\t\t%s.light_energy = %s" % [light_var, _f(strobe_off)])

		"pulse":
			code_lines.append("\t%s += _delta * %s" % [timer_var, _f(pulse_speed)])
			code_lines.append("\tvar _pulse_t_%s = (sin(%s) + 1.0) * 0.5" % [chain_name, timer_var])
			code_lines.append("\t%s.light_energy = lerpf(%s, %s, _pulse_t_%s)" % [light_var, _f(pulse_min), _f(pulse_max), chain_name])

		"fade_in":
			code_lines.append("\t%s.light_energy = lerpf(%s.light_energy, %s, %s * _delta)" % [light_var, light_var, _f(fade_target), _f(fade_speed)])

		"fade_out":
			code_lines.append("\t%s.light_energy = lerpf(%s.light_energy, %s, %s * _delta)" % [light_var, light_var, _f(fade_target), _f(fade_speed)])

	var result: Dictionary = {"actuator_code": "\n".join(code_lines)}
	if member_vars.size() > 0:
		result["member_vars"] = member_vars
	return result


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


func _color_expr(c: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [_f(c.r), _f(c.g), _f(c.b), _f(c.a)]
