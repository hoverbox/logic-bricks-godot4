@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Screen Shake Actuator - Trauma-based camera shake
## Presets populate the fields below as starting points for fine-tuning
## When export_params is on, tuning vars become @export on the generated script


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Screen Shake"


func _initialize_properties() -> void:
	properties = {
		"preset":        "medium",
		"trauma":        "1.5",
		"max_offset":    "18.0",
		"decay":         "1.5",
		"noise_speed":   "8.0",
		"export_params": false,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "preset",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Light,Medium,Heavy,Explosion,Subtle Idle",
			"default": "medium"
		},
		{
			"name": "export_params",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "trauma",
			"type": TYPE_STRING,
			"default": "1.5"
		},
		{
			"name": "max_offset",
			"type": TYPE_STRING,
			"default": "18.0"
		},
		{
			"name": "decay",
			"type": TYPE_STRING,
			"default": "1.5"
		},
		{
			"name": "noise_speed",
			"type": TYPE_STRING,
			"default": "8.0"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Trauma-based camera shake.\n⚠ Adds @export in Inspector — assign your Camera3D.",
		"preset":        "Populates the fields below with preset values as a starting point.\nAdjust any field after selecting a preset to fine-tune.",
		"export_params": "When enabled, shake parameters become @export vars on the generated script.\nAllows live tweaking in the Inspector without regenerating.",
		"trauma":        "How much trauma to add per activation.\n1.0 = light, 1.5 = medium, 2.0 = heavy/explosion.",
		"max_offset":    "Maximum camera position offset in world units.\n8.0 = light, 18.0 = medium, 32.0 = heavy, 60.0 = explosion.",
		"decay":         "How fast trauma fades per second. Higher = shorter shake.",
		"noise_speed":   "Speed of noise sampling. Lower = smoother, higher = jittery.",
	}


## Preset values: {preset: [trauma, max_offset, decay, noise_speed]}
## Stronger presets — h_offset/v_offset are in world units; larger values = more visible shake
const PRESETS = {
	"light":       ["1.0",  "8.0",   "2.5", "8.0"],
	"medium":      ["1.5",  "14.0",  "1.5", "8.0"],
	"heavy":       ["2.0",  "20.0",  "1.0", "8.0"],
	"explosion":   ["2.5",  "25.0",  "0.6", "8.0"],
	"subtle_idle": ["0.5",  "3.0",   "0.5", "3.0"],
}


func get_preset_values(preset_name: String) -> Array:
	var key = preset_name.to_lower().replace(" ", "_")
	return PRESETS.get(key, [])


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var export_params = properties.get("export_params", false)
	var trauma        = _to_expr(properties.get("trauma",       "1.5"))
	var max_offset    = _to_expr(properties.get("max_offset",   "3.5"))
	var decay         = _to_expr(properties.get("decay",        "1.5"))
	var noise_speed   = _to_expr(properties.get("noise_speed",  "8.0"))

	# Use instance name if set, otherwise use brick name, sanitized for use as a variable
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name

	var cam_var    = "_%s" % _export_label
	var prefix     = "@export var" if export_params else "var"
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	# Camera export
	member_vars.append("@export var %s: Camera3D" % cam_var)

	# Shake tuning params
	member_vars.append("%s _shake_max_offset: float = %s" % [prefix, max_offset])
	member_vars.append("%s _shake_decay: float = %s" % [prefix, decay])
	member_vars.append("%s _shake_noise_speed: float = %s" % [prefix, noise_speed])

	# Runtime state
	member_vars.append("var _shake_trauma: float = 0.0")
	member_vars.append("var _shake_noise: FastNoiseLite = FastNoiseLite.new()")
	member_vars.append("var _shake_time: float = 0.0")
	# Helper method — drives h_offset/v_offset so shake never conflicts with transform-based camera scripts
	member_vars.append("")
	member_vars.append("func _process_screen_shake(_delta: float) -> void:")
	member_vars.append("\tif not %s: return" % cam_var)
	member_vars.append("\tif _shake_trauma > 0.0:")
	member_vars.append("\t\t_shake_time += _delta")
	member_vars.append("\t\tvar _shake_amount = _shake_trauma * _shake_trauma")
	member_vars.append("\t\t%s.h_offset = _shake_max_offset * _shake_amount * _shake_noise.get_noise_2d(_shake_time * _shake_noise_speed, 0.0)" % cam_var)
	member_vars.append("\t\t%s.v_offset = _shake_max_offset * _shake_amount * _shake_noise.get_noise_2d(0.0, _shake_time * _shake_noise_speed)" % cam_var)
	member_vars.append("\t\t_shake_trauma = maxf(_shake_trauma - _shake_decay * _delta, 0.0)")
	member_vars.append("\telse:")
	member_vars.append("\t\t%s.h_offset = 0.0" % cam_var)
	member_vars.append("\t\t%s.v_offset = 0.0" % cam_var)

	# Actuator code — only triggers if no shake is currently in progress
	code_lines.append("# Screen Shake: only start if not already shaking")
	code_lines.append("if _shake_trauma == 0.0:")
	code_lines.append("\t_shake_trauma = %s" % trauma)
	code_lines.append("\t_shake_time = 0.0")

	# post_process_code runs unconditionally every frame after all chains,
	# so the shake continues to tick and decay even after the sensor goes inactive.
	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars,
		"post_process_code": ["_process_screen_shake(delta)"],
	}


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
