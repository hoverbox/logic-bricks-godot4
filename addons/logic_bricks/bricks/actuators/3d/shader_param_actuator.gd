@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Shader Parameter Actuator - Set a uniform on a node's material at runtime
## Works with MeshInstance3D, Sprite2D, ColorRect, or any node with a material
## Assign the target node via @export


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Shader Param"


func _initialize_properties() -> void:
	properties = {
		"param_name":  "",
		"value":       "1.0",
		"surface_idx": "0",
		"transition":  false,
		"transition_speed": "5.0",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "param_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "value",
			"type": TYPE_STRING,
			"default": "1.0"
		},
		{
			"name": "surface_idx",
			"type": TYPE_STRING,
			"default": "0"
		},
		{
			"name": "transition",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "transition_speed",
			"type": TYPE_STRING,
			"default": "5.0"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Sets a shader uniform on this node's material.\nThe material must be a ShaderMaterial.\nUseful for hit flash, dissolve, outline thickness, etc.",
		"param_name":       "The uniform name as declared in your shader.\nExample: 'flash_intensity', 'dissolve_amount'",
		"value":            "The value to set.\nAccepts float, int, bool, or variable name.\nFor colors: Color(r, g, b, a)  For vectors: Vector2/Vector3",
		"surface_idx":      "Surface index for MeshInstance3D. Usually 0.\nUse if your mesh has multiple surfaces with different materials.",
		"transition":       "Smoothly lerp a float value to the target each frame.",
		"transition_speed": "Lerp speed. Higher = faster.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var param_name  = str(properties.get("param_name", "")).strip_edges()
	var value       = _to_expr(properties.get("value", "1.0"))
	var surface_idx = _to_expr(properties.get("surface_idx", "0"))
	var transition  = properties.get("transition", false)
	var speed       = _to_expr(properties.get("transition_speed", "5.0"))

	if param_name.is_empty():
		return {"actuator_code": "push_warning(\"Shader Param: No parameter name set — open the brick and enter the shader uniform name\")"}

	var mat_var = "_shader_mat_%s" % chain_name
	var code_lines: Array[String] = []

	# Get the material — handle MeshInstance3D vs CanvasItem
	code_lines.append("# Shader Parameter Actuator")
	code_lines.append("var %s: ShaderMaterial = null" % mat_var)
	code_lines.append("if self is MeshInstance3D:")
	code_lines.append("\t%s = get_surface_override_material(%s)" % [mat_var, surface_idx])
	code_lines.append("\tif not %s:" % mat_var)
	code_lines.append("\t\t%s = mesh.surface_get_material(%s) as ShaderMaterial" % [mat_var, surface_idx])
	code_lines.append("elif self is CanvasItem:")
	code_lines.append("\t%s = material as ShaderMaterial" % mat_var)
	code_lines.append("if %s:" % mat_var)

	if transition:
		code_lines.append("\tvar _sp_cur_%s = %s.get_shader_parameter(\"%s\")" % [chain_name, mat_var, param_name])
		code_lines.append("\tif typeof(_sp_cur_%s) == TYPE_FLOAT:" % chain_name)
		code_lines.append("\t\t%s.set_shader_parameter(\"%s\", lerpf(_sp_cur_%s, %s, %s * _delta))" % [mat_var, param_name, chain_name, value, speed])
		code_lines.append("\telse:")
		code_lines.append("\t\t%s.set_shader_parameter(\"%s\", %s)" % [mat_var, param_name, value])
	else:
		code_lines.append("\t%s.set_shader_parameter(\"%s\", %s)" % [mat_var, param_name, value])

	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Shader Param Actuator: No ShaderMaterial found on this node\")")

	return {"actuator_code": "\n".join(code_lines)}


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0.0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
