@tool
extends "res://addons/logic_bricks/bricks/actuators/common/transforms_actuator.gd"

## Compatibility shim for scenes and editor caches that still reference the former
## Scale Actuator script path. New graphs should use TransformsActuator.

func _init() -> void:
	super._init()

func get_brick_info() -> Dictionary:
	return {
		"class": "TransformsActuator",
		"name": "Set Transforms",
		"type": "actuator",
		"category": "Object",
		"description": "Sets position, rotation, and scale from entered values or variables, instantly or over time.",
		"menu_order": 240,
		"domain": "common"
	}
