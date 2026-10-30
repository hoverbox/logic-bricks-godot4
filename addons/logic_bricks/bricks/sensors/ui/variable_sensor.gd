@tool
extends "res://addons/logic_bricks/bricks/sensors/common/variable_sensor.gd"

## UI-domain version of variable_sensor.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UIVariableSensor",
		"name": "Variable",
		"type": "sensor",
		"category": "UI",
		"description": "Compares a variable value.",
		"menu_order": 50,
		"domain": "ui"
	}
