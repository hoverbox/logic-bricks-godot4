@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Object Flash Actuator - flashes a GeometryInstance3D using a temporary overlay material.
## Target the node by name (not path). "self" affects the node the generated script is on.
## If the generated script is attached to a physics body or other non-mesh node,
## "self" will automatically try to find a GeometryInstance3D child beneath it.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Object Flash"


func _initialize_properties() -> void:
	properties = {
		"object_node_name": "self",
		"color":            Color(1, 0, 0, 0.8),
		"effect":           "single_flash",
		"speed":            "0.08",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "object_node_name",
			"type": TYPE_STRING,
			"default": "self"
		},
		{
			"name": "color",
			"type": TYPE_COLOR,
			"default": Color(1, 0, 0, 0.8)
		},
		{
			"name": "effect",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Single Flash,Strobe,Color Strobe",
			"default": "single_flash"
		},
		{
			"name": "speed",
			"type": TYPE_STRING,
			"default": "0.08"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Flashes a mesh/object with a temporary color overlay.\nType a node name, not a path.\n\"self\" also works on physics bodies by searching for a mesh child.",
		"object_node_name": "Name of the object to flash.\nUse \"self\" to flash this node or one of its mesh children.\nOr type another node name to search for anywhere in the scene tree.",
		"color": "Main flash color. Alpha controls intensity.",
		"effect": "Single Flash: one quick burst.\nStrobe: repeated on/off flashes using the chosen color.\nColor Strobe: repeated flashes with changing colors.",
		"speed": "Seconds per flash step. Lower = faster.\nAccepts a number or variable.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var object_node_name = str(properties.get("object_node_name", "self")).strip_edges()
	var effect = str(properties.get("effect", "single_flash")).to_lower().replace(" ", "_")
	var speed_expr = _to_expr(properties.get("speed", "0.08"))
	var flash_color = properties.get("color", Color(1, 0, 0, 0.8))

	if object_node_name.is_empty():
		object_node_name = "self"
	if typeof(flash_color) != TYPE_COLOR:
		flash_color = Color(1, 0, 0, 0.8)

	var color_str = "Color(%.4f, %.4f, %.4f, %.4f)" % [flash_color.r, flash_color.g, flash_color.b, flash_color.a]
	var stem = instance_name if not instance_name.is_empty() else brick_name
	stem = stem.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	stem = regex.sub(stem, "", true)
	if stem.is_empty():
		stem = chain_name

	var helper_suffix = "%s_%s" % [stem, chain_name]
	var target_var = "_flash_target_%s" % helper_suffix
	var overlay_var = "_flash_overlay_%s" % helper_suffix
	var prev_overlay_var = "_flash_prev_overlay_%s" % helper_suffix
	var tween_var = "_flash_tween_%s" % helper_suffix
	var code_lines: Array[String] = []

	var methods: Array[String] = []
	methods.append(('''
func _find_geometry_child_{helper_suffix}(search_root: Node) -> GeometryInstance3D:
	if not is_instance_valid(search_root):
		return null
	for _flash_child in search_root.get_children():
		if _flash_child is GeometryInstance3D:
			return _flash_child as GeometryInstance3D
		var _flash_found = _find_geometry_child_{helper_suffix}(_flash_child)
		if is_instance_valid(_flash_found):
			return _flash_found
	return null
''').format({"helper_suffix": helper_suffix}).strip_edges())

	methods.append(('''
func _resolve_flash_target_{helper_suffix}(target_name: String) -> GeometryInstance3D:
	if target_name == "self":
		var _self_node: Node = self
		if _self_node is GeometryInstance3D:
			return _self_node as GeometryInstance3D
		return _find_geometry_child_{helper_suffix}(self)
	var _flash_node = get_tree().root.find_child(target_name, true, false)
	if _flash_node is GeometryInstance3D:
		return _flash_node as GeometryInstance3D
	if is_instance_valid(_flash_node):
		return _find_geometry_child_{helper_suffix}(_flash_node)
	return null
''').format({"helper_suffix": helper_suffix}).strip_edges())

	methods.append(('''
func _ensure_flash_overlay_{helper_suffix}(target: GeometryInstance3D) -> StandardMaterial3D:
	if not is_instance_valid(target):
		return null
	if not is_instance_valid({overlay_var}):
		{overlay_var} = StandardMaterial3D.new()
		{overlay_var}.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		{overlay_var}.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		{overlay_var}.cull_mode = BaseMaterial3D.CULL_DISABLED
		{overlay_var}.emission_enabled = true
		{overlay_var}.emission_energy_multiplier = 1.5
	if target.material_overlay != {overlay_var}:
		{prev_overlay_var} = target.material_overlay
	target.material_overlay = {overlay_var}
	return {overlay_var}
''').format({
		"helper_suffix": helper_suffix,
		"overlay_var": overlay_var,
		"prev_overlay_var": prev_overlay_var,
	}).strip_edges())

	methods.append(('''
func _restore_flash_overlay_{helper_suffix}(target: GeometryInstance3D) -> void:
	if not is_instance_valid(target):
		return
	if is_instance_valid({overlay_var}) and target.material_overlay == {overlay_var}:
		target.material_overlay = {prev_overlay_var}
	{prev_overlay_var} = null
''').format({
		"helper_suffix": helper_suffix,
		"overlay_var": overlay_var,
		"prev_overlay_var": prev_overlay_var,
	}).strip_edges())

	methods.append(('''
func _flash_overlay_step_{helper_suffix}(target: GeometryInstance3D, color_value: Color, hold_time: float) -> void:
	var _flash_overlay = _ensure_flash_overlay_{helper_suffix}(target)
	if not is_instance_valid(_flash_overlay):
		return
	var _flash_visible = color_value
	var _flash_hidden = Color(color_value.r, color_value.g, color_value.b, 0.0)
	_flash_overlay.albedo_color = _flash_hidden
	_flash_overlay.emission = Color(color_value.r, color_value.g, color_value.b, 1.0)
	if is_instance_valid({tween_var}):
		{tween_var}.tween_property(_flash_overlay, "albedo_color", _flash_visible, max(hold_time, 0.001))
		{tween_var}.tween_property(_flash_overlay, "albedo_color", _flash_hidden, max(hold_time, 0.001))
''').format({
		"helper_suffix": helper_suffix,
		"tween_var": tween_var,
	}).strip_edges())

	methods.append(('''
func _run_object_flash_{helper_suffix}(target: GeometryInstance3D, effect_mode: String, base_color: Color, step_time: float) -> void:
	if not is_instance_valid(target):
		return
	if is_instance_valid({tween_var}):
		{tween_var}.kill()
	{tween_var} = create_tween()
	var _step = max(step_time, 0.001)
	match effect_mode:
		"strobe":
			for _strobe_idx in range(4):
				_flash_overlay_step_{helper_suffix}(target, base_color, _step)
		"color_strobe":
			for _color_strobe_idx in range(4):
				var _strobe_color = Color.from_hsv(randf(), max(base_color.s, 0.75), max(base_color.v, 0.85), base_color.a)
				_flash_overlay_step_{helper_suffix}(target, _strobe_color, _step)
		_:
			_flash_overlay_step_{helper_suffix}(target, base_color, _step)
	{tween_var}.finished.connect(func(): _restore_flash_overlay_{helper_suffix}(target))
''').format({
		"helper_suffix": helper_suffix,
		"tween_var": tween_var,
	}).strip_edges())

	code_lines.append("# Object Flash Actuator")
	code_lines.append("var %s = _resolve_flash_target_%s(\"%s\")" % [target_var, helper_suffix, object_node_name.c_escape()])
	code_lines.append("if is_instance_valid(%s):" % target_var)
	code_lines.append("\t_run_object_flash_%s(%s, \"%s\", %s, float(%s))" % [helper_suffix, target_var, effect, color_str, speed_expr])
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Object Flash Actuator: could not find a GeometryInstance3D for node name '%s'\")" % object_node_name)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": [
			"var %s: GeometryInstance3D = null" % target_var,
			"var %s: StandardMaterial3D = null" % overlay_var,
			"var %s: Material = null" % prev_overlay_var,
			"var %s: Tween = null" % tween_var,
		],
		"methods": methods,
	}


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty():
		return "0.08"
	if s.is_valid_float() or s.is_valid_int():
		return s
	return s
