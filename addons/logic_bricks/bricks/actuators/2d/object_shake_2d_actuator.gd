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
		"target_node_name": "",
		"intensity": "8.0",
		"duration": "0.25",
		"rotation_intensity": "2.0",
	}


func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": ""},
		{"name": "intensity", "type": TYPE_STRING, "default": "8.0"},
		{"name": "duration", "type": TYPE_STRING, "default": "0.25"},
		{"name": "rotation_intensity", "type": TYPE_STRING, "default": "2.0"},
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_name = str(properties.get("target_node_name", "")).strip_edges()
	var intensity_expr = _to_expr(properties.get("intensity", "8.0"))
	var duration_expr = _to_expr(properties.get("duration", "0.25"))
	var rotation_expr = _to_expr(properties.get("rotation_intensity", "2.0"))

	var stem = instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	stem = stem.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	stem = regex.sub(stem, "", true)
	if stem.is_empty():
		stem = chain_name

	var suffix = "%s_%s" % [stem, chain_name]
	var tween_var = "_object_shake_2d_tween_%s" % suffix
	var baseline_var = "_object_shake_2d_baselines_%s" % suffix
	var target_var = "_object_shake_2d_target_%s" % suffix

	var methods: Array[String] = []
	methods.append(('''
func _resolve_object_shake_2d_target_{suffix}(target_name: String) -> Node2D:
	if target_name.is_empty() or target_name == "self":
		return self as Node2D
	var found = get_tree().current_scene.find_child(target_name, true, false)
	if found is Node2D:
		return found as Node2D
	return null
''').format({"suffix": suffix}).strip_edges())

	methods.append(('''
func _run_object_shake_2d_{suffix}(target: Node2D, intensity: float, duration: float, rotation_degrees: float) -> void:
	if not is_instance_valid(target):
		return

	var target_key = str(target.get_instance_id())
	var baseline: Dictionary
	if {baseline_var}.has(target_key):
		baseline = {baseline_var}[target_key]
	else:
		baseline = Dictionary()
		baseline["position"] = target.position
		baseline["rotation"] = target.rotation
		{baseline_var}[target_key] = baseline

	# A repeated activation must never capture a currently shaken transform.
	# Restore the original baseline before killing and restarting the shake.
	if is_instance_valid({tween_var}):
		{tween_var}.kill()
	target.position = baseline["position"]
	target.rotation = baseline["rotation"]

	var safe_duration = max(duration, 0.01)
	var step_time = min(0.04, safe_duration)
	var step_count = max(1, int(ceil(safe_duration / step_time)))
	step_time = safe_duration / float(step_count)

	{tween_var} = create_tween()
	for index in range(step_count):
		var falloff = 1.0 - (float(index) / float(step_count))
		var position_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		) * falloff
		var rotation_offset = deg_to_rad(randf_range(-rotation_degrees, rotation_degrees) * falloff)
		{tween_var}.tween_property(target, "position", baseline["position"] + position_offset, step_time)
		{tween_var}.parallel().tween_property(target, "rotation", baseline["rotation"] + rotation_offset, step_time)

	{tween_var}.tween_property(target, "position", baseline["position"], step_time)
	{tween_var}.parallel().tween_property(target, "rotation", baseline["rotation"], step_time)
	{tween_var}.tween_callback(func():
		if is_instance_valid(target):
			target.position = baseline["position"]
			target.rotation = baseline["rotation"]
		{baseline_var}.erase(target_key)
	)
''').format({
		"suffix": suffix,
		"tween_var": tween_var,
		"baseline_var": baseline_var,
	}).strip_edges())

	var code_lines: Array[String] = []
	code_lines.append("# Object Shake 2D Actuator")
	code_lines.append("var %s = _resolve_object_shake_2d_target_%s(\"%s\")" % [target_var, suffix, _gd(target_name)])
	code_lines.append("if is_instance_valid(%s):" % target_var)
	code_lines.append("\t_run_object_shake_2d_%s(%s, float(%s), float(%s), float(%s))" % [suffix, target_var, intensity_expr, duration_expr, rotation_expr])
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Object Shake 2D Actuator: could not find a Node2D named '%s'\")" % _gd(target_name))

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": [
			"var %s: Tween = null" % tween_var,
			"var %s: Dictionary = {}" % baseline_var,
		],
		"methods": methods,
	}


func _to_expr(value) -> String:
	var text = str(value).strip_edges()
	return "0.0" if text.is_empty() else text


func _gd(text: String) -> String:
	return text.replace("\\", "\\\\").replace("\"", "\\\"")
