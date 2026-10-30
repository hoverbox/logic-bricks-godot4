@tool
extends "res://addons/logic_bricks/bricks/actuators/common/modulate_actuator.gd"

## UI-domain version of modulate_actuator.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UIModulateActuator",
		"name": "Color / Transparency",
		"type": "actuator",
		"category": "UI",
		"description": "Sets or transitions color/alpha on a Control or CanvasItem node.",
		"menu_order": 120,
		"domain": "ui"
	}
