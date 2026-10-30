@tool
extends "res://addons/logic_bricks/bricks/sensors/common/input_map_sensor.gd"

## UI-domain version of input_map_sensor.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UIInputMapSensor",
		"name": "Input",
		"type": "sensor",
		"category": "UI",
		"description": "Detects Godot Input Map actions for UI logic.",
		"menu_order": 30,
		"domain": "ui"
	}
