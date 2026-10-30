@tool
extends "res://addons/logic_bricks/bricks/actuators/common/tween_actuator.gd"

## Tween 2D Actuator - 2D menu wrapper around the shared Tween code.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Tween"

func get_brick_info() -> Dictionary:
	return {
		"class": "Tween2DActuator",
		"name": "Tween",
		"type": "actuator",
		# Not "UI": the 2D/3D menus hide that category, which left 2D with no
		# tween brick at all (the common Tween is replaced by this one in 2D).
		"category": "Animation",
		"description": "Tween a 2D node property such as position, rotation, scale, or modulate.",
		"menu_order": 310,
		"domain": "2d",
	}

func get_tooltip_definitions() -> Dictionary:
	return super.get_tooltip_definitions()

