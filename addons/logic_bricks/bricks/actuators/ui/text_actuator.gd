@tool
extends "res://addons/logic_bricks/bricks/actuators/2d/text_2d_actuator.gd"

## UI-domain version of text_2d_actuator.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UITextActuator",
		"name": "Text",
		"type": "actuator",
		"category": "UI",
		"description": "Updates a Label, RichTextLabel, or other text UI node.",
		"menu_order": 100,
		"domain": "ui"
	}
