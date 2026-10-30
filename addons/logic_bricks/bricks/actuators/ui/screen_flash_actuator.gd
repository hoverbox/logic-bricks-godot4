@tool
extends "res://addons/logic_bricks/bricks/actuators/common/screen_flash_actuator.gd"

## UI-domain version of screen_flash_actuator.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UIScreenFlashActuator",
		"name": "Screen Flash",
		"type": "actuator",
		"category": "UI",
		"description": "Flashes a full-screen ColorRect overlay.",
		"menu_order": 150,
		"domain": "ui"
	}
