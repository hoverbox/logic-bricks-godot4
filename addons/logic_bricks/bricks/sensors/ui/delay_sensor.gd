@tool
extends "res://addons/logic_bricks/bricks/sensors/common/delay_sensor.gd"

## UI-domain version of delay_sensor.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UIDelaySensor",
		"name": "Delay",
		"type": "sensor",
		"category": "UI",
		"description": "Triggers after a delay or at an interval.",
		"menu_order": 20,
		"domain": "ui"
	}
