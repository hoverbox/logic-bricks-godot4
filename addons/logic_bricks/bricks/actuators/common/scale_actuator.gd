@tool
extends "res://addons/logic_bricks/bricks/actuators/3d/scale_tween_actuator.gd"

## Legacy compatibility path only. This no longer extends Set Transforms.
## It now resolves to the dedicated 3D Scale + Tween actuator.


## Shows every field: the parent brick's show/hide rules are for its own
## fields and were never applied to this brick.
func get_field_visibility_rules(_context_node: Node) -> Dictionary:
	return {}
