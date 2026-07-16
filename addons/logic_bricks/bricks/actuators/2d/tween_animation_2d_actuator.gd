@tool
extends "res://addons/logic_bricks/bricks/actuators/common/tween_actuator.gd"

## Tween Animation 2D Actuator - 2D menu wrapper around the shared Tween code.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Tween Animation"

func get_brick_info() -> Dictionary:
	return {
		"class": "TweenAnimation2DActuator",
		"name": "Tween Animation",
		"type": "actuator",
		"category": "Animation",
		"description": "Tween a 2D node property such as position, rotation, scale, or modulate.",
		"menu_order": 310,
		"domain": "2d",
	}
