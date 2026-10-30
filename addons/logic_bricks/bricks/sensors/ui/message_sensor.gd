@tool
extends "res://addons/logic_bricks/bricks/sensors/common/message_sensor.gd"

## UI-domain version of message_sensor.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UIMessageSensor",
		"name": "Signal Receive",
		"type": "sensor",
		"category": "UI",
		"description": "Receives a Logic Bricks message.",
		"menu_order": 40,
		"domain": "ui"
	}
