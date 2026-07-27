@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Object Flash 2D Actuator - flashes a CanvasItem using temporary modulate color changes.
## Target the node by name (not path). "self" affects the node the generated script is on.
## If the generated script is attached to a parent Node2D, "self" can also find a CanvasItem child beneath it.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Object Flash"


func get_brick_info() -> Dictionary:
	return {
		"class": "ObjectFlash2DActuator",
		"name": "Object Flash",
		"type": "actuator",
		"category": "Game Feel",
		"description": "Flash a 2D object with a temporary color overlay.",
		"menu_order": 520,
		"domain": "2d",
	}


func _initialize_properties() -> void:
	properties = {
		"object_node_name": "self",
		"color": Color(1, 0, 0, 0.8),
		"effect": "single_flash",
		"speed": "0.08",
	}


func get_property_definitions() -> Array:
	return [
		{"name": "object_node_name", "type": TYPE_STRING, "default": "self"},
		{"name": "color", "type": TYPE_COLOR, "default": Color(1, 0, 0, 0.8)},
		{"name": "effect", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Single Flash,Strobe,Color Strobe", "default": "single_flash"},
		{"name": "speed", "type": TYPE_STRING, "default": "0.08"},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Flashes a 2D object with a temporary color tint. Type a node name, not a path.",
		"object_node_name": "Name of the 2D object to flash. Use \"self\" to flash this node or the first CanvasItem child beneath it.",
		"color": "Main flash color. Alpha controls how strongly it blends with the original color.",
		"effect": "Single Flash: one quick burst.\nStrobe: repeated on/off flashes using the chosen color.\nColor Strobe: repeated flashes with changing colors.",
		"speed": "Seconds per flash step. Lower = faster. Accepts a number or variable.",
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
	var target_var = "_flash_2d_target_%s" % helper_suffix
	var tween_var = "_flash_2d_tween_%s" % helper_suffix
	var base_color_var = "_flash_2d_base_color_%s" % helper_suffix
	var code_lines: Array[String] = []
	var methods: Array[String] = []

	methods.append(('''
func _find_canvas_item_child_{helper_suffix}(search_root: Node) -> CanvasItem:
	if not is_instance_valid(search_root):
		return null
	for _flash_child in search_root.get_children():
		if _flash_child is CanvasItem:
			return _flash_child as CanvasItem
		var _flash_found = _find_canvas_item_child_{helper_suffix}(_flash_child)
		if is_instance_valid(_flash_found):
			return _flash_found
	return null
''').format({"helper_suffix": helper_suffix}).strip_edges())

	methods.append(('''
func _resolve_flash_2d_target_{helper_suffix}(target_name: String) -> CanvasItem:
	if target_name == "self":
		var _self_node: Node = self
		if _self_node is CanvasItem:
			return _self_node as CanvasItem
		return _find_canvas_item_child_{helper_suffix}(self)
	var _flash_node = get_tree().root.find_child(target_name, true, false)
	if _flash_node is CanvasItem:
		return _flash_node as CanvasItem
	if is_instance_valid(_flash_node):
		return _find_canvas_item_child_{helper_suffix}(_flash_node)
	return null
''').format({"helper_suffix": helper_suffix}).strip_edges())

	methods.append(('''
func _flash_2d_blend_{helper_suffix}(base_color: Color, flash_color: Color) -> Color:
	return base_color.lerp(Color(flash_color.r, flash_color.g, flash_color.b, base_color.a), clampf(flash_color.a, 0.0, 1.0))
''').format({"helper_suffix": helper_suffix}).strip_edges())

	methods.append(('''
func _run_object_flash_2d_{helper_suffix}(target: CanvasItem, effect_mode: String, flash_color: Color, step_time: float) -> void:
	if not is_instance_valid(target):
		return
	var _target_key = str(target.get_instance_id())
	var _base_color: Color = target.modulate
	if {base_color_var}.has(_target_key):
		_base_color = {base_color_var}[_target_key]
	else:
		{base_color_var}[_target_key] = _base_color
	if is_instance_valid({tween_var}):
		{tween_var}.kill()
		target.modulate = _base_color
	{tween_var} = create_tween()
	var _step = max(step_time, 0.001)
	match effect_mode:
		"strobe":
			for _strobe_idx in range(4):
				var _visible = _flash_2d_blend_{helper_suffix}(_base_color, flash_color)
				{tween_var}.tween_property(target, "modulate", _visible, _step)
				{tween_var}.tween_property(target, "modulate", _base_color, _step)
		"color_strobe":
			for _color_strobe_idx in range(4):
				var _strobe_color = Color.from_hsv(randf(), max(flash_color.s, 0.75), max(flash_color.v, 0.85), flash_color.a)
				var _visible = _flash_2d_blend_{helper_suffix}(_base_color, _strobe_color)
				{tween_var}.tween_property(target, "modulate", _visible, _step)
				{tween_var}.tween_property(target, "modulate", _base_color, _step)
		_:
			var _visible = _flash_2d_blend_{helper_suffix}(_base_color, flash_color)
			{tween_var}.tween_property(target, "modulate", _visible, _step)
			{tween_var}.tween_property(target, "modulate", _base_color, _step)
	{tween_var}.finished.connect(func():
		if is_instance_valid(target):
			target.modulate = _base_color
		{base_color_var}.erase(_target_key)
	)
''').format({
		"helper_suffix": helper_suffix,
		"tween_var": tween_var,
		"base_color_var": base_color_var,
	}).strip_edges())

	code_lines.append("# Object Flash 2D Actuator")
	code_lines.append("var %s = _resolve_flash_2d_target_%s(\"%s\")" % [target_var, helper_suffix, object_node_name.c_escape()])
	code_lines.append("if is_instance_valid(%s):" % target_var)
	code_lines.append("\t_run_object_flash_2d_%s(%s, \"%s\", %s, float(%s))" % [helper_suffix, target_var, effect, color_str, speed_expr])
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Object Flash 2D Actuator: could not find a CanvasItem for node name '%s'\")" % object_node_name)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": [
			"var %s: CanvasItem = null" % target_var,
			"var %s: Tween = null" % tween_var,
			"var %s: Dictionary = {}" % base_color_var,
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
