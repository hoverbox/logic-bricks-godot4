@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Object Shake Actuator - briefly shakes a named child object, then returns it to its default value.
## Target is a node name, not a path. The generated script searches this node and its children.
## Add multiple Object Shake actuators if you want rotate + translate + scale on the same target.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Object Shake"


func _initialize_properties() -> void:
	properties = {
		"shake_type": "rotate",
		"object_node_name": "self",
		"preset": "medium",
		"x": "0.0",
		"y": "8.0",
		"z": "0.0",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "shake_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Rotate,Translate,Scale",
			"default": "rotate"
		},
		{
			"name": "object_node_name",
			"type": TYPE_STRING,
			"default": "self"
		},
		{
			"name": "preset",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Tiny,Light,Medium,Heavy,Side Hit,Vertical Hit,Scale Pop",
			"default": "medium"
		},
		{
			"name": "x",
			"type": TYPE_STRING,
			"default": "0.0"
		},
		{
			"name": "y",
			"type": TYPE_STRING,
			"default": "8.0"
		},
		{
			"name": "z",
			"type": TYPE_STRING,
			"default": "0.0"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Shakes a named object by rotation, translation, or scale, then returns it to its starting value.\nType a node name, not a path. Use multiple Object Shake actuators for multiple effects.",
		"shake_type": "Choose which transform value this actuator shakes.\nUse more than one Object Shake actuator if you want rotate + translate + scale together.",
		"object_node_name": "Node name to shake, not a path.\nUse \"self\" for this node. Otherwise, the script searches this node and its children by name.",
		"preset": "Populates X, Y, and Z below.\nThe preset does not do anything else, so you can edit the values after choosing it.",
		"x": "Shake amount on the X axis. Accepts a number or variable name.",
		"y": "Shake amount on the Y axis. Accepts a number or variable name.",
		"z": "Shake amount on the Z axis. Accepts a number or variable name.",
	}


## Preset values: {shake_type: {preset: [x, y, z]}}
## Rotate values are degrees. Translate values are local/world units. Scale values are additive scale amount.
## The same preset names intentionally map to different magnitudes so the UI feels natural for each transform type.
const PRESETS_BY_TYPE = {
	"rotate": {
		"tiny": ["0.0", "5.0", "0.0"],
		"light": ["0.0", "8.0", "0.0"],
		"medium": ["0.0", "14.0", "0.0"],
		"heavy": ["0.0", "25.0", "0.0"],
		"side_hit": ["18.0", "0.0", "0.0"],
		"vertical_hit": ["0.0", "18.0", "0.0"],
		"scale_pop": ["10.0", "10.0", "10.0"],
	},
	"translate": {
		"tiny": ["0.03", "0.0", "0.0"],
		"light": ["0.08", "0.0", "0.0"],
		"medium": ["0.15", "0.0", "0.0"],
		"heavy": ["0.35", "0.0", "0.0"],
		"side_hit": ["0.25", "0.0", "0.0"],
		"vertical_hit": ["0.0", "0.25", "0.0"],
		"scale_pop": ["0.12", "0.12", "0.12"],
	},
	"scale": {
		"tiny": ["0.01", "0.01", "0.01"],
		"light": ["0.025", "0.025", "0.025"],
		"medium": ["0.05", "0.05", "0.05"],
		"heavy": ["0.12", "0.12", "0.12"],
		"side_hit": ["0.08", "0.0", "0.0"],
		"vertical_hit": ["0.0", "0.08", "0.0"],
		"scale_pop": ["0.15", "0.15", "0.15"],
	},
}


func get_preset_values(preset_name: String) -> Array:
	var preset_key = preset_name.to_lower().replace(" ", "_")
	var type_key = str(properties.get("shake_type", "rotate")).to_lower().replace(" ", "_")
	if not PRESETS_BY_TYPE.has(type_key):
		type_key = "rotate"
	return PRESETS_BY_TYPE[type_key].get(preset_key, [])


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var shake_type = str(properties.get("shake_type", "rotate")).to_lower().replace(" ", "_")
	var object_node_name = str(properties.get("object_node_name", "self")).strip_edges()
	var x_expr = _to_expr(properties.get("x", "0.0"))
	var y_expr = _to_expr(properties.get("y", "8.0"))
	var z_expr = _to_expr(properties.get("z", "0.0"))

	if object_node_name.is_empty():
		object_node_name = "self"
	if not (shake_type in ["rotate", "translate", "scale"]):
		shake_type = "rotate"

	var stem = instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	stem = stem.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	stem = regex.sub(stem, "", true)
	if stem.is_empty():
		stem = chain_name

	var helper_suffix = "%s_%s" % [stem, chain_name]
	var tween_var = "_object_shake_tween_%s" % helper_suffix
	var base_var = "_object_shake_base_%s" % helper_suffix
	var target_var = "_object_shake_target_%s" % helper_suffix
	var code_lines: Array[String] = []

	var methods: Array[String] = []
	methods.append(('''
func _resolve_object_shake_target_{helper_suffix}(target_name: String) -> Node3D:
	if target_name == "self":
		return self as Node3D
	var _shake_root: Node = self
	var _shake_found = _shake_root.find_child(target_name, true, false)
	if _shake_found is Node3D:
		return _shake_found as Node3D
	return null
''').format({"helper_suffix": helper_suffix}).strip_edges())

	methods.append(('''
func _run_object_shake_{helper_suffix}(target: Node3D, shake_mode: String, amount: Vector3) -> void:
	if not is_instance_valid(target):
		return

	var _target_key = str(target.get_instance_id()) + ":" + shake_mode
	var _base_value: Vector3
	var _property_name = "rotation"
	match shake_mode:
		"translate":
			_property_name = "position"
		"scale":
			_property_name = "scale"
		_:
			_property_name = "rotation"

	if {base_var}.has(_target_key):
		_base_value = {base_var}[_target_key]
	else:
		_base_value = target.get(_property_name)
		{base_var}[_target_key] = _base_value

	if is_instance_valid({tween_var}):
		{tween_var}.kill()
		target.set(_property_name, _base_value)

	{tween_var} = create_tween()
	var _shake_step_time = 0.035
	var _shake_steps = 8
	match shake_mode:
		"translate":
			for _i in range(_shake_steps):
				var _dir = -1.0 if _i % 2 == 0 else 1.0
				var _falloff = 1.0 - float(_i) / float(_shake_steps)
				var _offset = Vector3(randf_range(-amount.x, amount.x), randf_range(-amount.y, amount.y), randf_range(-amount.z, amount.z)) * _falloff
				if _offset.length_squared() == 0.0:
					_offset = Vector3(amount.x, amount.y, amount.z) * _dir * _falloff
				{tween_var}.tween_property(target, "position", _base_value + _offset, _shake_step_time)
			{tween_var}.tween_property(target, "position", _base_value, _shake_step_time)
		"scale":
			for _i in range(_shake_steps):
				var _dir = -1.0 if _i % 2 == 0 else 1.0
				var _falloff = 1.0 - float(_i) / float(_shake_steps)
				var _scale_offset = Vector3(amount.x, amount.y, amount.z) * _dir * _falloff
				{tween_var}.tween_property(target, "scale", _base_value + _scale_offset, _shake_step_time)
			{tween_var}.tween_property(target, "scale", _base_value, _shake_step_time)
		_:
			# Rotation values in the UI are degrees, but Godot stores Node3D.rotation in radians.
			# Use tween_method instead of tween_property("rotation_degrees") because the generated
			# script needs to work reliably across all Node3D-derived targets.
			var _base_rotation = target.rotation
			for _i in range(_shake_steps):
				var _dir = -1.0 if _i % 2 == 0 else 1.0
				var _falloff = 1.0 - float(_i) / float(_shake_steps)
				var _rot_offset_degrees = Vector3(randf_range(-amount.x, amount.x), randf_range(-amount.y, amount.y), randf_range(-amount.z, amount.z)) * _falloff
				if _rot_offset_degrees.length_squared() == 0.0:
					_rot_offset_degrees = Vector3(amount.x, amount.y, amount.z) * _dir * _falloff
				var _target_rotation = _base_value + Vector3(deg_to_rad(_rot_offset_degrees.x), deg_to_rad(_rot_offset_degrees.y), deg_to_rad(_rot_offset_degrees.z))
				{tween_var}.tween_method(func(_r: Vector3):
					if is_instance_valid(target):
						target.rotation = _r
				, _base_rotation, _target_rotation, _shake_step_time)
				_base_rotation = _target_rotation
			{tween_var}.tween_method(func(_r: Vector3):
				if is_instance_valid(target):
					target.rotation = _r
			, _base_rotation, _base_value, _shake_step_time)

	{tween_var}.tween_callback(func():
		if is_instance_valid(target):
			target.set(_property_name, _base_value)
		{base_var}.erase(_target_key)
	)
''').format({
		"helper_suffix": helper_suffix,
		"tween_var": tween_var,
		"base_var": base_var,
	}).strip_edges())

	code_lines.append("# Object Shake Actuator")
	code_lines.append("var %s = _resolve_object_shake_target_%s(\"%s\")" % [target_var, helper_suffix, object_node_name.c_escape()])
	code_lines.append("if is_instance_valid(%s):" % target_var)
	code_lines.append("\t_run_object_shake_%s(%s, \"%s\", Vector3(float(%s), float(%s), float(%s)))" % [helper_suffix, target_var, shake_type, x_expr, y_expr, z_expr])
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Object Shake Actuator: could not find a Node3D named '%s' under this node\")" % object_node_name)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": [
			"var %s: Tween = null" % tween_var,
			"var %s: Dictionary = {}" % base_var,
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
