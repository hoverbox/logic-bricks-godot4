@tool
extends "res://addons/logic_bricks/bricks/sensors/common/always_sensor.gd"

## UI-domain version of always_sensor.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UIAlwaysSensor",
		"name": "Always",
		"type": "sensor",
		"category": "UI",
		"description": "Always active while enabled.",
		"menu_order": 10,
		"domain": "ui"
	}


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Runs continuously while this logic chain is active. Useful for UI updates that need to happen every frame.",
	}
