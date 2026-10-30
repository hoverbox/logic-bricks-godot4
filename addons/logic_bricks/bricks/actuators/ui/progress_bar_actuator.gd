@tool
extends "res://addons/logic_bricks/bricks/actuators/2d/progress_bar_2d_actuator.gd"

## UI-domain version of progress_bar_2d_actuator.gd: same code generation, its own
## registry entry (class, menu, domain). Fix behavior in the base file.

func get_brick_info() -> Dictionary:
	return {
		"class": "UIProgressBarActuator",
		"name": "Progress Bar",
		"type": "actuator",
		"category": "UI",
		"description": "Sets the value, min, or max of a ProgressBar, Slider, or Range UI node.",
		"menu_order": 110,
		"domain": "ui"
	}


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var set_value = properties.get("set_value", true)
	var set_min = properties.get("set_min", false)
	var set_max = properties.get("set_max", false)
	var transition = properties.get("transition", false)
	for child in _get_field_names():
		if true:
			var prop_name = child
			match prop_name:
				"value":
					shown[child] = set_value
				"min_value":
					shown[child] = set_min
				"max_value":
					shown[child] = set_max
				"transition_speed":
					shown[child] = transition and set_value
	return shown
