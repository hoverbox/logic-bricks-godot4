@tool
extends "res://addons/logic_bricks/bricks/sensors/common/random_sensor.gd"

## UI-domain version of random_sensor.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UIRandomSensor",
		"name": "Random Chance",
		"type": "sensor",
		"category": "UI",
		"description": "Randomly activates based on chance.",
		"menu_order": 60,
		"domain": "ui"
	}
