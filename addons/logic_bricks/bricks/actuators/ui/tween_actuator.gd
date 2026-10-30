@tool
extends "res://addons/logic_bricks/bricks/actuators/common/tween_actuator.gd"

## UI-domain version of tween_actuator.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UITweenActuator",
		"name": "Tween",
		"type": "actuator",
		"category": "UI",
		"description": "Tweens a UI node property.",
		"menu_order": 140,
		"domain": "ui"
	}
