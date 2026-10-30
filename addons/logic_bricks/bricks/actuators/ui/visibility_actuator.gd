@tool
extends "res://addons/logic_bricks/bricks/actuators/common/visibility_actuator.gd"

## UI-domain version of visibility_actuator.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UIVisibilityActuator",
		"name": "Visibility",
		"type": "actuator",
		"category": "UI",
		"description": "Shows, hides, or toggles a UI node.",
		"menu_order": 130,
		"domain": "ui"
	}
