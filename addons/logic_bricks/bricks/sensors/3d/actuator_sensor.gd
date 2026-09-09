@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Action Active - Detects when a named action on this node is active.
## Fires TRUE the frame an action runs, FALSE when it doesn't.
## The action must be on the same node and have an instance name set.
## Useful for chaining actions: "do X when Y action is running".


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Action Active"


func _initialize_properties() -> void:
	properties = {
		"actuator_name": "",      # Instance name of the actuator to watch
		"trigger_on": "active",   # "active" or "inactive"
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "actuator_name", "required": true, "required_label": "an Action name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "trigger_on",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Active,Inactive",
			"default": "active"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Fires TRUE when the named action on this node matches the chosen state.\nThe action must have an instance name set.",
		"actuator_name": "The instance name of the action to watch.\nMust match the Name field on the action's graph node.",
		"trigger_on": "Active: fires TRUE while the actuator is running.\nInactive: fires TRUE while the actuator is NOT running.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var actuator_name = properties.get("actuator_name", "").strip_edges()
	var trigger_on = properties.get("trigger_on", "active")
	if typeof(trigger_on) == TYPE_STRING:
		trigger_on = trigger_on.to_lower()

	if actuator_name.is_empty():
		return {"sensor_code": "var sensor_active = false  # Actuator Sensor: no actuator name set"}

	var sensor_code: String
	if trigger_on == "inactive":
		sensor_code = "var sensor_active = not _actuator_active_flags.get(\"%s\", false)" % actuator_name
	else:
		sensor_code = "var sensor_active = _actuator_active_flags.get(\"%s\", false)" % actuator_name

	return {
		"sensor_code": sensor_code,
	}
