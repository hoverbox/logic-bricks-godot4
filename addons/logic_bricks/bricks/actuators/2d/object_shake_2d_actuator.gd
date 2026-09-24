@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

func get_brick_info() -> Dictionary:
	return {
		"class": "ObjectShake2DActuator",
		"name": "Object Shake",
		"type": "actuator",
		"category": "Game Feel",
		"domain": "2d",
		"menu_order": 510,
	}

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Object Shake"

func _initialize_properties() -> void:
	properties = {
		"shake_type": "translate",
		"target_node_name": "self",
		"preset": "medium",
		"x": "8.0",
		"y": "8.0",
		"rotation_degrees": "8.0",
	}

func get_property_definitions() -> Array:
	return [
		{"name":"shake_type","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Translate,Rotate,Scale","default":"translate"},
		{"name":"target_node_name","type":TYPE_STRING,"default":"self","node_reference":true,"node_picker_scope":"scene","accepted_node_types":["Node2D"]},
		{"name":"preset","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Tiny,Light,Medium,Heavy,Side Hit,Vertical Hit,Scale Pop","default":"medium"},
		{"name":"x","type":TYPE_STRING,"default":"8.0"},
		{"name":"y","type":TYPE_STRING,"default":"8.0"},
		{"name":"rotation_degrees","type":TYPE_STRING,"default":"8.0"},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Shakes a Node2D by position, rotation, or scale, then returns it to its starting transform.",
		"shake_type": "Translate shakes position. Rotate shakes the single 2D rotation axis. Scale shakes X/Y scale.",
		"target_node_name": "Node2D to shake. Use self for the node running the brick chain, or select another Node2D anywhere in the scene.",
		"preset": "Fills the shake amount fields with useful starting values. You can edit them afterward.",
		"x": "Translate: horizontal pixel offset. Scale: temporary X scale offset.",
		"y": "Translate: vertical pixel offset. Scale: temporary Y scale offset.",
		"rotation_degrees": "Maximum temporary rotation in degrees.",
	}

const PRESETS_BY_TYPE = {
	"translate": {
		"tiny": ["2.0", "2.0"], "light": ["4.0", "4.0"], "medium": ["8.0", "8.0"], "heavy": ["16.0", "16.0"],
		"side_hit": ["12.0", "2.0"], "vertical_hit": ["2.0", "12.0"], "scale_pop": ["8.0", "8.0"],
	},
	"rotate": {
		"tiny": ["2.0"], "light": ["4.0"], "medium": ["8.0"], "heavy": ["16.0"],
		"side_hit": ["10.0"], "vertical_hit": ["10.0"], "scale_pop": ["8.0"],
	},
	"scale": {
		"tiny": ["0.01", "0.01"], "light": ["0.025", "0.025"], "medium": ["0.05", "0.05"], "heavy": ["0.12", "0.12"],
		"side_hit": ["0.08", "0.01"], "vertical_hit": ["0.01", "0.08"], "scale_pop": ["0.15", "0.15"],
	},
}

func get_preset_values(preset_name: String) -> Array:
	var shake_type := str(properties.get("shake_type", "translate")).to_lower().replace(" ", "_")
	var preset_key := preset_name.to_lower().replace(" ", "_")
	if not PRESETS_BY_TYPE.has(shake_type):
		shake_type = "translate"
	return PRESETS_BY_TYPE[shake_type].get(preset_key, [])

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var shake_type := str(properties.get("shake_type", "translate")).to_lower().replace(" ", "_")
	var target_name := str(properties.get("target_node_name", "self")).strip_edges()
	var x_expr := _expr(properties.get("x", "8.0"))
	var y_expr := _expr(properties.get("y", "8.0"))
	var rotation_expr := _expr(properties.get("rotation_degrees", "8.0"))
	if shake_type not in ["translate", "rotate", "scale"]:
		shake_type = "translate"
	if target_name.is_empty():
		target_name = "self"

	var stem := instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	stem = stem.to_lower().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^a-z0-9_]")
	stem = regex.sub(stem, "", true)
	var suffix := "%s_%s" % [stem, chain_name]
	var tween_var := "_object_shake_2d_tween_%s" % suffix
	var baseline_var := "_object_shake_2d_baselines_%s" % suffix
	var target_var := "_object_shake_2d_target_%s" % suffix

	var methods: Array[String] = []
	methods.append(('''
func _resolve_object_shake_2d_target_{suffix}(target_name: String) -> Node2D:
	if target_name.is_empty() or target_name == "self":
		return self as Node2D
	var found: Node = null
	if get_tree().current_scene:
		found = get_tree().current_scene.find_child(target_name, true, false)
	if found == null:
		found = get_tree().root.find_child(target_name, true, false)
	return found as Node2D
''').format({"suffix":suffix}).strip_edges())

	methods.append(('''
func _run_object_shake_2d_{suffix}(target: Node2D, shake_mode: String, amount: Vector2, rotation_amount_degrees: float) -> void:
	if not is_instance_valid(target):
		return
	var target_key = str(target.get_instance_id()) + ":" + shake_mode
	var baseline
	match shake_mode:
		"rotate": baseline = target.rotation
		"scale": baseline = target.scale
		_: baseline = target.position
	if {baseline_var}.has(target_key):
		baseline = {baseline_var}[target_key]
	else:
		{baseline_var}[target_key] = baseline

	if is_instance_valid({tween_var}):
		{tween_var}.kill()
	match shake_mode:
		"rotate": target.rotation = float(baseline)
		"scale": target.scale = baseline
		_: target.position = baseline

	{tween_var} = create_tween()
	var steps := 8
	var step_time := 0.035
	for i in range(steps):
		var falloff := 1.0 - float(i) / float(steps)
		match shake_mode:
			"rotate":
				var rot_offset := deg_to_rad(randf_range(-rotation_amount_degrees, rotation_amount_degrees) * falloff)
				{tween_var}.tween_property(target, "rotation", float(baseline) + rot_offset, step_time)
			"scale":
				var scale_offset := Vector2(randf_range(-amount.x, amount.x), randf_range(-amount.y, amount.y)) * falloff
				{tween_var}.tween_property(target, "scale", baseline + scale_offset, step_time)
			_:
				var pos_offset := Vector2(randf_range(-amount.x, amount.x), randf_range(-amount.y, amount.y)) * falloff
				{tween_var}.tween_property(target, "position", baseline + pos_offset, step_time)
	match shake_mode:
		"rotate": {tween_var}.tween_property(target, "rotation", float(baseline), step_time)
		"scale": {tween_var}.tween_property(target, "scale", baseline as Vector2, step_time)
		_: {tween_var}.tween_property(target, "position", baseline as Vector2, step_time)
	{tween_var}.tween_callback(func():
		if is_instance_valid(target):
			match shake_mode:
				"rotate": target.rotation = float(baseline)
				"scale": target.scale = baseline
				_: target.position = baseline
		{baseline_var}.erase(target_key)
	)
''').format({"suffix":suffix,"tween_var":tween_var,"baseline_var":baseline_var}).strip_edges())

	var lines: Array[String] = []
	lines.append("var %s = _resolve_object_shake_2d_target_%s(\"%s\")" % [target_var, suffix, target_name.c_escape()])
	lines.append("if is_instance_valid(%s):" % target_var)
	lines.append("\t_run_object_shake_2d_%s(%s, \"%s\", Vector2(float(%s), float(%s)), float(%s))" % [suffix,target_var,shake_type,x_expr,y_expr,rotation_expr])
	lines.append("else:")
	lines.append("\tpush_warning(\"Object Shake 2D: target Node2D not found\")")
	return {
		"actuator_code":"\n".join(lines),
		"member_vars":["var %s: Tween = null" % tween_var, "var %s: Dictionary = {}" % baseline_var],
		"methods":methods,
	}
