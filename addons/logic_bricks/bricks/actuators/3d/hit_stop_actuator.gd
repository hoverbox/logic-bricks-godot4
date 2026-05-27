@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Hit Stop Actuator
## Briefly slows or freezes game time when an impact lands.
## Use for attacks, damage, blocks, heavy landings, and object breaks.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Hit Stop"


func _initialize_properties() -> void:
	properties = {
		"preset": "medium",
		"duration": "0.06",
		"time_scale": "0.0",
		"restart_if_active": false,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "preset",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Tiny,Light,Medium,Heavy,Custom",
			"default": "medium"
		},
		{
			"name": "duration",
			"type": TYPE_STRING,
			"default": "0.06"
		},
		{
			"name": "time_scale",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "restart_if_active",
			"type": TYPE_BOOL,
			"default": false
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Briefly pauses or slows game time when an impact lands.\nUse for attacks, damage, blocks, heavy landings, and breaks.\nThis is also called hit pause or impact freeze.",
		"preset": "Starting feel for the hit stop.\nTiny: subtle tap.\nLight: small hit.\nMedium: normal attack impact.\nHeavy: big hit or explosion.\nCustom: use your own Duration and Time Scale values.",
		"duration": "How long the stop lasts in real seconds.\nTypical values are 0.03 to 0.12 seconds.\nAccepts a number, variable, or expression.",
		"time_scale": "How frozen the game becomes during hit stop.\n0.0 = full freeze.\n0.05 = almost frozen.\n0.2 = slow motion instead of a hard freeze.\nAccepts a number, variable, or expression.",
		"restart_if_active": "Off: ignore repeated triggers while hit stop is already running.\nOn: a new hit can restart/replace the current hit stop.",
	}


## Preset values: {preset: [duration, time_scale]}
const PRESETS = {
	"tiny":   ["0.025", "0.0"],
	"light":  ["0.04",  "0.0"],
	"medium": ["0.06",  "0.0"],
	"heavy":  ["0.10",  "0.0"],
	"custom": [],
}


func get_preset_values(preset_name: String) -> Array:
	var key = preset_name.to_lower().replace(" ", "_")
	return PRESETS.get(key, [])


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var preset = str(properties.get("preset", "medium")).to_lower().replace(" ", "_")
	var duration = _to_expr(properties.get("duration", "0.06"))
	var time_scale = _to_expr(properties.get("time_scale", "0.0"))
	var restart_if_active = properties.get("restart_if_active", false) == true

	if preset != "custom" and PRESETS.has(preset):
		var preset_values = PRESETS[preset]
		if preset_values.size() >= 2:
			duration = preset_values[0]
			time_scale = preset_values[1]

	var label = instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	label = label.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	if label.is_empty():
		label = chain_name

	var active_var = "_hit_stop_active_%s" % label
	var token_var = "_hit_stop_token_%s" % label
	var previous_scale_var = "_hit_stop_previous_scale_%s" % label
	var method_name = "_run_hit_stop_%s" % label

	var code_lines: Array[String] = []
	code_lines.append("# Hit Stop Actuator")
	if restart_if_active:
		code_lines.append("%s += 1" % token_var)
		code_lines.append("%s(%s, %s, %s)" % [method_name, duration, time_scale, token_var])
	else:
		code_lines.append("if not %s:" % active_var)
		code_lines.append("\t%s += 1" % token_var)
		code_lines.append("\t%s(%s, %s, %s)" % [method_name, duration, time_scale, token_var])

	var methods: Array[String] = []
	methods.append(('''
func {method_name}(duration_seconds: float, stopped_time_scale: float, token: int) -> void:
	if not {active_var}:
		{previous_scale_var} = Engine.time_scale
	{active_var} = true
	Engine.time_scale = clampf(stopped_time_scale, 0.0, 1.0)
	await get_tree().create_timer(maxf(duration_seconds, 0.001), true, false, true).timeout
	if token != {token_var}:
		return
	Engine.time_scale = {previous_scale_var}
	{active_var} = false
''').format({
		"method_name": method_name,
		"active_var": active_var,
		"previous_scale_var": previous_scale_var,
		"token_var": token_var,
	}).strip_edges())

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": [
			"var %s: bool = false" % active_var,
			"var %s: int = 0" % token_var,
			"var %s: float = 1.0" % previous_scale_var,
		],
		"methods": methods,
	}


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.0"
	if s.is_valid_float() or s.is_valid_int():
		return s
	return s
