@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Screen Shake Actuator - Trauma-based camera shake
## Finds the Camera3D by node name anywhere in the current scene tree
## Presets populate the fields below as starting points for fine-tuning
## When export_params is on, tuning vars become @export on the generated script


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Screen Shake"


func _initialize_properties() -> void:
	properties = {
		"camera_node_name": "Camera3D",
		"node_name_source": "literal",
		"export_node_name": false,
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
			"name": "camera_node_name",
			"type": TYPE_STRING,
			"default": "Camera3D"
		},
		{
			"name": "node_name_source",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Literal Node Name,String Variable",
			"default": "literal"
		},
		{
			"name": "export_node_name",
			"type": TYPE_BOOL,
			"default": false
		},
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
		"_description": "Trauma-based camera shake.\nType the Camera3D node name. The generated script searches the whole current scene tree, so this brick can live on any 3D node.",
		"camera_node_name": "Literal Node Name: type the Camera3D node name, usually Camera3D.\nString Variable: type the name of a String variable that stores the camera node name.",
		"node_name_source": "Literal Node Name: use Camera Node Name directly.\nString Variable: treat Camera Node Name as a variable name and read that String at runtime.",
		"export_node_name": "Literal mode only. Adds an @export String to the generated script so the camera node name can be edited in the Inspector without exposing a node reference.",
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
	var camera_node_name = str(properties.get("camera_node_name", "Camera3D")).strip_edges()
	var node_name_source = str(properties.get("node_name_source", "literal")).to_lower().replace(" ", "_")
	var export_node_name = properties.get("export_node_name", false)
	var export_params = properties.get("export_params", false)
	var trauma        = _to_expr(properties.get("trauma",       "1.5"))
	var max_offset    = _to_expr(properties.get("max_offset",   "3.5"))
	var decay         = _to_expr(properties.get("decay",        "1.5"))
	var noise_speed   = _to_expr(properties.get("noise_speed",  "8.0"))

	# Use instance name if set; otherwise include the chain name and a settings hash.
	# This prevents multiple Screen Shake actuators from generating the same helper
	# function and runtime variables.
	var _export_label = instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name

	var cam_var    = "_%s" % _export_label
	var helper_func = "_process_screen_shake_%s" % _export_label
	var trauma_var = "_shake_trauma_%s" % _export_label
	var noise_var = "_shake_noise_%s" % _export_label
	var time_var = "_shake_time_%s" % _export_label
	var max_offset_var = "_shake_max_offset_%s" % _export_label
	var decay_var = "_shake_decay_%s" % _export_label
	var noise_speed_var = "_shake_noise_speed_%s" % _export_label
	var camera_name_var = "_screen_shake_camera_name_%s" % _export_label
	var prefix     = "@export var" if export_params else "var"
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	# Runtime camera cache. The actual Camera3D is resolved by name from the whole current scene tree.
	member_vars.append("var %s: Camera3D = null" % cam_var)
	if export_node_name and node_name_source != "string_variable":
		member_vars.append("@export var %s: String = \"%s\"" % [camera_name_var, _gd_string(camera_node_name)])

	# Shake tuning params
	member_vars.append("%s %s: float = %s" % [prefix, max_offset_var, max_offset])
	member_vars.append("%s %s: float = %s" % [prefix, decay_var, decay])
	member_vars.append("%s %s: float = %s" % [prefix, noise_speed_var, noise_speed])

	# Runtime state
	member_vars.append("var %s: float = 0.0" % trauma_var)
	member_vars.append("var %s: FastNoiseLite = FastNoiseLite.new()" % noise_var)
	member_vars.append("var %s: float = 0.0" % time_var)
	# Shared helper: search an entire subtree by node.name. Keeping this helper generic
	# makes Screen Shake work like Collision/Animation-style bricks: users type a name, not a path.
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
	# Helper method — drives h_offset/v_offset so shake never conflicts with transform-based camera scripts
	member_vars.append("")
	member_vars.append("func %s(_delta: float) -> void:" % helper_func)
	var camera_name_expr = "\"%s\"" % _gd_string(camera_node_name)
	if node_name_source == "string_variable" and not camera_node_name.is_empty():
		camera_name_expr = "str(%s)" % camera_node_name
	elif export_node_name and node_name_source != "string_variable":
		camera_name_expr = camera_name_var
	member_vars.append("\tvar _shake_camera_name = %s" % camera_name_expr)
	member_vars.append("\tif _shake_camera_name.is_empty():")
	member_vars.append("\t\tpush_warning(\"Screen Shake Actuator: No camera node name set\")")
	member_vars.append("\t\treturn")
	member_vars.append("\tif %s == null or %s.name != _shake_camera_name:" % [cam_var, cam_var])
	member_vars.append("\t\tvar _shake_target = _lb_find_node_in_current_scene(_shake_camera_name)")
	member_vars.append("\t\tif _shake_target is Camera3D:")
	member_vars.append("\t\t\t%s = _shake_target" % cam_var)
	member_vars.append("\t\telif _shake_target:")
	member_vars.append("\t\t\tpush_warning(\"Screen Shake Actuator: node '%s' is not a Camera3D\" % _shake_camera_name)")
	member_vars.append("\t\telse:")
	member_vars.append("\t\t\tpush_warning(\"Screen Shake Actuator: could not find Camera3D named '%s' in the current scene\" % _shake_camera_name)")
	member_vars.append("\tif not %s:" % cam_var)
	member_vars.append("\t\treturn")
	member_vars.append("\tif %s > 0.0:" % trauma_var)
	member_vars.append("\t\t%s += _delta" % time_var)
	member_vars.append("\t\tvar _shake_amount = %s * %s" % [trauma_var, trauma_var])
	member_vars.append("\t\t%s.h_offset = %s * _shake_amount * %s.get_noise_2d(%s * %s, 0.0)" % [cam_var, max_offset_var, noise_var, time_var, noise_speed_var])
	member_vars.append("\t\t%s.v_offset = %s * _shake_amount * %s.get_noise_2d(0.0, %s * %s)" % [cam_var, max_offset_var, noise_var, time_var, noise_speed_var])
	member_vars.append("\t\t%s = maxf(%s - %s * _delta, 0.0)" % [trauma_var, trauma_var, decay_var])
	member_vars.append("\telse:")
	member_vars.append("\t\t%s.h_offset = 0.0" % cam_var)
	member_vars.append("\t\t%s.v_offset = 0.0" % cam_var)

	# Actuator code — only triggers if no shake is currently in progress
	code_lines.append("# Screen Shake: only start if not already shaking")
	code_lines.append("if %s == 0.0:" % trauma_var)
	code_lines.append("\t%s = %s" % [trauma_var, trauma])
	code_lines.append("\t%s = 0.0" % time_var)

	# post_process_code runs unconditionally every frame after all chains,
	# so the shake continues to tick and decay even after the sensor goes inactive.
	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars,
		"post_process_code": ["%s(delta)" % helper_func],
	}


func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
