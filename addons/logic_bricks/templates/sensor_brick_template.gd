@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Sensor Brick Template
## =====================
## Copy this file into:  res://addons/logic_bricks/bricks/sensors/3d/
## Rename it to snake_case, e.g.  enemy_near_sensor.gd
##
## The registry auto-discovers any .gd file dropped under that folder.
## Minimum requirements: _init() sets brick_type and brick_name.
## Everything else is optional but recommended.
##
## HOW SENSORS WORK
## ----------------
## generate_code() must return a Dictionary containing "sensor_code".
## That code will be injected into the node's _process() method.
## It MUST assign a boolean to a local variable named `sensor_active`.
## The chain evaluates `sensor_active` to decide whether to fire the
## connected controller and actuators.
##
##   return { "sensor_code": "var sensor_active = true" }
##
## Your code runs in the scope of the owning node, so `self`, `name`,
## `get_tree()`, etc. are all available at runtime.
##
## OPTIONAL RETURN KEYS
## --------------------
## "member_vars"  – Array[String] of lines added as member variables on
##                  the node class (outside _process). Use for state that
##                  must persist across frames, e.g. signal-connected flags.
##
## "ready_lines"  – Array[String] of lines added inside _ready(). Use for
##                  one-time setup such as connecting signals or caching
##                  node references.
##
## Example (signal-based sensor):
##   return {
##       "member_vars": ["var _hit_flag_%s := false" % chain_name],
##       "ready_lines": [
##           "var _area = find_child(\"HitArea\", true, false)",
##           "_area.body_entered.connect(func(_b): _hit_flag_%s = true)" % chain_name,
##       ],
##       "sensor_code": "var sensor_active = _hit_flag_%s\n_hit_flag_%s = false" % [chain_name, chain_name],
##   }
##
## USE chain_name TO AVOID COLLISIONS
## ------------------------------------
## Multiple sensor instances on the same node each get a unique chain_name
## string (e.g. "chain_0", "chain_1"). Always suffix any member vars and
## helper functions you emit with chain_name so they don't collide.
##
## PROPERTY TYPES QUICK REFERENCE
## --------------------------------
## TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR3
## Add hint/hint_string for dropdowns:
##   "hint": PROPERTY_HINT_ENUM, "hint_string": "Option A,Option B,Option C"
## Properties stored as TYPE_STRING can also hold variable/expression names
## so users can wire logic-brick variables into fields at runtime.
##
## NODE TYPE GUARDS
## ----------------
## If your sensor only works with a specific node class, check at codegen
## time and emit a warning comment rather than broken code:
##   if not (node is Area3D):
##       return { "sensor_code": "var sensor_active = false  # Needs Area3D" }
##
## REGISTRATION (automatic)
## -------------------------
## The registry infers everything it needs from the file path and brick_name.
## get_brick_info() is optional — only needed when you want to override the
## display name, set a category, control menu_order, or declare aliases.
##
## Category controls the submenu grouping in the Add Brick menu.
## Sensors with no category appear at the top level.
## menu_order controls sort position within a category (lower = higher up).


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Example Sensor"


## Optional — override display name, category, menu order, or aliases.
## Remove this function entirely if the defaults are fine.
func get_brick_info() -> Dictionary:
	return {
		"class": "ExampleSensor",       # PascalCase, must be unique across all bricks
		"name": "Example Sensor",       # Label shown in the UI
		"type": "sensor",
		"category": "",                 # Submenu group, e.g. "Detection". Empty = top level.
		"description": "Describe when this sensor fires.",
		"menu_order": 9999,             # Lower numbers appear higher in the menu
		"aliases": []                   # Legacy class names that deserialize to this brick
	}


func _initialize_properties() -> void:
	properties = {
		"enabled": true
		# Add your own properties here.
		# Use plain GDScript values (bool, int, float, String).
		# String fields can also hold variable names or expressions,
		# letting users wire logic-brick variables into the sensor at runtime.
	}


func get_property_definitions() -> Array:
	## Describes each property for the UI panel.
	## Required keys:  "name", "type", "default"
	## Optional keys:  "hint" (PROPERTY_HINT_*), "hint_string"
	return [
		{
			"name": "enabled",
			"type": TYPE_BOOL,
			"default": true
		},
		# Enum example — shows a dropdown in the panel:
		# {
		#     "name": "mode",
		#     "type": TYPE_STRING,
		#     "hint": PROPERTY_HINT_ENUM,
		#     "hint_string": "Once,Repeat,Toggle",
		#     "default": "once"
		# },
	]


func get_tooltip_definitions() -> Dictionary:
	## Tooltip text shown when hovering over the brick or its property fields.
	## "_description" is the overall brick tooltip (also used as the registry
	## description if get_brick_info() doesn't supply one).
	## All other keys match property names defined in get_property_definitions().
	return {
		"_description": "Short explanation of when this sensor is active.",
		"enabled": "Turns this sensor on or off.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	## node        – the scene node this brick is attached to (available at
	##               editor/codegen time for type checks; not the runtime self)
	## chain_name  – unique string for this chain, e.g. "chain_0"
	##               Suffix all emitted variable/function names with it.

	var enabled: bool = bool(properties.get("enabled", true))

	if not enabled:
		return { "sensor_code": "var sensor_active = false" }

	# Replace the line below with your actual sensor condition.
	# `sensor_active` MUST be assigned a bool before this block ends.
	var code := "var sensor_active = true"

	return { "sensor_code": code }
