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
		"trauma":        "0.6",
		"max_offset":    "25.0",
		"max_rotation":  "2.0",
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
			"default": "0.6"
		},
		{
			"name": "max_offset",
			"type": TYPE_STRING,
			"default": "25.0"
		},
		{
			"name": "max_rotation",
			"type": TYPE_STRING,
			"default": "2.0"
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
		"trauma":        "How much trauma to add per activation (0.0 - 1.0).\n0.3 = light, 0.6 = medium, 1.0 = maximum.",
		"max_offset":    "Maximum camera position offset. Values around 20-50 are visible in 3D.",
		"max_rotation":  "Maximum rotation in degrees.",
		"decay":         "How fast trauma fades per second. Higher = shorter shake.",
		"noise_speed":   "Speed of noise sampling. Lower = smoother, higher = jittery.",
	}


## Preset values: {preset: [trauma, max_offset, max_rotation, decay, noise_speed]}
const PRESETS = {
	"light":       ["0.3",  "20.0",  "1.0", "2.5", "8.0"],
	"medium":      ["0.6",  "25.0",  "2.0", "1.5", "8.0"],
	"heavy":       ["0.9",  "40.0",  "4.0", "1.0", "8.0"],
	"explosion":   ["1.0",  "60.0",  "8.0", "0.8", "6.0"],
	"subtle_idle": ["0.2",  "20.0",  "0.5", "0.5", "4.0"],
}


func get_preset_values(preset_name: String) -> Array:
	var key = preset_name.to_lower().replace(" ", "_")
	return PRESETS.get(key, [])


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var export_params = properties.get("export_params", false)
	var trauma        = _to_expr(properties.get("trauma",       "0.6"))
	var max_offset    = _to_expr(properties.get("max_offset",   "25.0"))
	var max_rotation  = _to_expr(properties.get("max_rotation", "2.0"))
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
	member_vars.append("%s _shake_max_rotation: float = %s" % [prefix, max_rotation])
	member_vars.append("%s _shake_decay: float = %s" % [prefix, decay])
	member_vars.append("%s _shake_noise_speed: float = %s" % [prefix, noise_speed])

	# Runtime state
	member_vars.append("var _shake_trauma: float = 0.0")
	member_vars.append("var _shake_noise: FastNoiseLite = FastNoiseLite.new()")
	member_vars.append("var _shake_time: float = 0.0")
	member_vars.append("var _shake_rot: Vector3 = Vector3.ZERO  # Current applied shake rotation in degrees")

	# Helper method — applies shake as a rotation delta on top of whatever the camera's current rotation is
	member_vars.append("")
	member_vars.append("func _process_screen_shake(_delta: float) -> void:")
	member_vars.append("\tif not %s: return" % cam_var)
	member_vars.append("\t# Remove last frame's shake rotation before applying the new one")
	member_vars.append("\t%s.rotation_degrees -= _shake_rot" % cam_var)
	member_vars.append("\tif _shake_trauma > 0.0:")
	member_vars.append("\t\t_shake_time += _delta")
	member_vars.append("\t\tvar _shake_amount = _shake_trauma * _shake_trauma")
	member_vars.append("\t\t_shake_rot = Vector3(")
	member_vars.append("\t\t\t_shake_max_rotation * _shake_amount * _shake_noise.get_noise_2d(_shake_time * _shake_noise_speed, 0.0),")
	member_vars.append("\t\t\t_shake_max_rotation * _shake_amount * _shake_noise.get_noise_2d(0.0, _shake_time * _shake_noise_speed),")
	member_vars.append("\t\t\t_shake_max_rotation * _shake_amount * _shake_noise.get_noise_2d(_shake_time * _shake_noise_speed, _shake_time * _shake_noise_speed)")
	member_vars.append("\t\t)")
	member_vars.append("\t\t%s.rotation_degrees += _shake_rot" % cam_var)
	member_vars.append("\t\t_shake_trauma = maxf(_shake_trauma - _shake_decay * _delta, 0.0)")
	member_vars.append("\telse:")
	member_vars.append("\t\t_shake_rot = Vector3.ZERO")

	# Actuator code
	code_lines.append("# Screen Shake: add trauma")
	code_lines.append("_shake_trauma = minf(_shake_trauma + %s, 1.0)" % trauma)
	code_lines.append("_process_screen_shake(_delta)")

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars,
	}


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
