@tool
extends "res://addons/logic_bricks/bricks/actuators/3d/scale_tween_actuator.gd"

## Legacy filename only. The old Scale implementation has been removed.
## This path now instantiates the dedicated Scale + Tween actuator.


## Shows every field: the parent brick's show/hide rules are for its own
## fields and were never applied to this brick.
func get_field_visibility_rules(_context_node: Node) -> Dictionary:
	return {}
