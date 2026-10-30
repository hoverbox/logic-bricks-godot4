@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Particles Actuator - Starts, stops, or restarts Godot particle emitters.
## Supports GPUParticles2D/3D and CPUParticles2D/3D.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Particles"


func get_brick_info() -> Dictionary:
	return {
		"class": "ParticlesActuator",
		"name": "Particles",
		"type": "actuator",
		"category": "Game Feel",
		"description": "Starts, stops, or restarts a 2D or 3D particle system.",
		"menu_order": 70,
		"domain": "common"
	}


func _initialize_properties() -> void:
	properties = {
		"target_node_name": "",
		"action": "start",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_node_name",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Particle node name (blank = self)",
			"node_reference": true,
			"accepted_node_types": ["GPUParticles3D", "CPUParticles3D", "GPUParticles2D", "CPUParticles2D"]
		},
		{
			"name": "action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Start,Stop,Restart",
			"default": "start"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Controls a GPUParticles or CPUParticles node in 2D or 3D.",
		"target_node_name": "Choose the particle system to control. Leave blank to control this node if it is itself a particle system.",
		"action": "Start: begin emitting.\nStop: stop emitting new particles.\nRestart: clear/restart the effect and begin emitting again."
	}


func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings: Array[String] = []
	if str(properties.get("target_node_name", "")).strip_edges().is_empty() and node != null:
		if not _is_particle_node(node):
			warnings.append("Choose a particle node")
	return warnings


func _is_particle_node(node: Node) -> bool:
	return node is GPUParticles3D or node is CPUParticles3D or node is GPUParticles2D or node is CPUParticles2D


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_name := str(properties.get("target_node_name", "")).strip_edges()
	var action := str(properties.get("action", "start")).to_lower()
	var label := _unique_label(chain_name)
	var target_var := "_lb_particles_%s" % label
	var code_lines: Array[String] = []

	code_lines.append("# Particles Actuator")
	code_lines.append("var %s: Node = self" % target_var)
	if not target_name.is_empty() and target_name.to_lower() != "self":
		code_lines.append("%s = self.find_child(\"%s\", true, false)" % [target_var, _gd_string(target_name)])
		code_lines.append("if %s == null and get_tree().current_scene != null:" % target_var)
		code_lines.append("\t%s = get_tree().current_scene.find_child(\"%s\", true, false)" % [target_var, _gd_string(target_name)])

	code_lines.append("if %s is GPUParticles3D or %s is CPUParticles3D or %s is GPUParticles2D or %s is CPUParticles2D:" % [target_var, target_var, target_var, target_var])
	match action:
		"start":
			code_lines.append("\t%s.set(\"emitting\", true)" % target_var)
		"stop":
			code_lines.append("\t%s.set(\"emitting\", false)" % target_var)
		"restart":
			code_lines.append("\tif %s.has_method(\"restart\"):" % target_var)
			code_lines.append("\t\t%s.call(\"restart\")" % target_var)
			code_lines.append("\t%s.set(\"emitting\", true)" % target_var)
		_:
			code_lines.append("\tpush_warning(\"Particles Actuator: unknown action\")")
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Particles Actuator: target is not a particle system\")")

	return {"actuator_code": "\n".join(code_lines)}


func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")


func _unique_label(chain_name: String) -> String:
	return str(abs((chain_name + str(properties)).hash()))
