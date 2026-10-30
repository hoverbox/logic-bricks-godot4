@tool
extends "res://addons/logic_bricks/bricks/actuators/common/audio_2d_actuator.gd"

## UI-domain version of audio_2d_actuator.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UIAudio2DActuator",
		"name": "2D Audio",
		"type": "actuator",
		"category": "UI",
		"description": "Plays UI or 2D audio.",
		"menu_order": 160,
		"domain": "ui"
	}
