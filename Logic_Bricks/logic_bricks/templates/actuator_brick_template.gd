@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Actuator Brick Template
## =======================
## Copy this file into:  res://addons/logic_bricks/bricks/actuators/3d/
## Rename it to snake_case, e.g.  grid_map_actuator.gd
##
## The registry auto-discovers any .gd file dropped under that folder.
## Minimum requirements: _init() sets brick_type and brick_name.
## Everything else is optional but recommended.
##
## HOW ACTUATORS WORK
## ------------------
## generate_code() must return a Dictionary containing "actuator_code".
## That code is injected inside the chain's `if sensor_active:` block, so
## it only runs when the connected sensor and controller both pass.
##
##   return { "actuator_code": "position.y += 1.0" }
##
## Your code runs in the scope of the owning node at runtime, so `self`,
## `position`, `get_tree()`, etc. are all available.
##
## OPTIONAL RETURN KEYS
## --------------------
## "member_vars"  – Array[String] of lines added as member variables on
##                  the node class (outside _process). Use for state that
##                  must persist across frames, e.g. a tween reference.
##
## "ready_lines"  – Array[String] of lines added inside _ready(). Use for
##                  one-time setup, e.g. caching a node reference.
##
## Example (actuator with persistent state):
##   return {
##       "member_vars": ["var _tween_%s: Tween" % chain_name],
##       "ready_lines": [],
##       "actuator_code": (
##           "if _tween_%s: _tween_%s.kill()\n" % [chain_name, chain_name] +
##           "_tween_%s = create_tween()\n" % chain_name +
##           "_tween_%s.tween_property(self, \"position:y\", 5.0, 0.5)" % chain_name
##       ),
##   }
##
## USE chain_name TO AVOID COLLISIONS
## ------------------------------------
## Multiple actuator instances on the same node each get a unique chain_name
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
## Enum values come back as lowercase with spaces replaced by underscores.
## Normalise before comparing:
##   var mode = str(properties.get("mode", "once")).to_lower().replace(" ", "_")
##
## NODE TYPE GUARDS
## ----------------
## If your actuator only works with specific node classes, check at codegen
## time and emit a warning comment rather than broken code:
##   if not (node is RigidBody3D):
##       var lines = [
##           "# WARNING: %s requires RigidBody3D, got %s" % [brick_name, node.get_class()],
##           "push_warning(\"%s requires RigidBody3D\")" % brick_name,
##       ]
##       return { "actuator_code": "\n".join(lines) }
##
## FINDING CHILD NODES AT RUNTIME
## --------------------------------
## Use find_child() rather than get_node() so users only need to type a
## node name, not a full path:
##   "var _target = find_child(\"%s\", true, false)" % target_node_name
##   "if _target == null: push_warning(\"...\"); return"
##
## REGISTRATION (automatic)
## -------------------------
## The registry infers everything it needs from the file path and brick_name.
## get_brick_info() is optional — only needed when you want to override the
## display name, set a category, control menu_order, or declare aliases.
##
## Category controls the submenu grouping in the Add Brick menu.
## Actuators with no category land in "General".
## menu_order controls sort position within a category (lower = higher up).


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Example Actuator"


## Optional — override display name, category, menu order, or aliases.
## Remove this function entirely if the defaults are fine.
func get_brick_info() -> Dictionary:
	return {
		"class": "ExampleActuator",     # PascalCase, must be unique across all bricks
		"name": "Example Actuator",     # Label shown in the UI
		"type": "actuator",
		"category": "General",          # Submenu group, e.g. "Motion", "Audio", "UI"
		"description": "Describe the action this actuator performs.",
		"menu_order": 9999,             # Lower numbers appear higher in the menu
		"aliases": []                   # Legacy class names that deserialize to this brick
	}


func _initialize_properties() -> void:
	properties = {
		"target_node": "self",
		"enabled": true
		# Add your own properties here.
		# Use plain GDScript values (bool, int, float, String).
		# String fields can also hold variable names or expressions,
		# letting users wire logic-brick variables into the actuator at runtime.
	}


func get_property_definitions() -> Array:
	## Describes each property for the UI panel.
	## Required keys:  "name", "type", "default"
	## Optional keys:  "hint" (PROPERTY_HINT_*), "hint_string"
	return [
		{
			"name": "target_node",
			"type": TYPE_STRING,
			"default": "self"
		},
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
		#     "hint_string": "Add,Set,Subtract",
		#     "default": "set"
		# },
	]


func get_tooltip_definitions() -> Dictionary:
	## Tooltip text shown when hovering over the brick or its property fields.
	## "_description" is the overall brick tooltip (also used as the registry
	## description if get_brick_info() doesn't supply one).
	## All other keys match property names defined in get_property_definitions().
	return {
		"_description": "Short explanation of what this actuator does.",
		"target_node": "Use 'self' to target the owning node, or type a child node name. Uses find_child() so only the name is needed, not the full path.",
		"enabled": "Turns this actuator on or off.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	## node        – the scene node this brick is attached to (available at
	##               editor/codegen time for type checks; not the runtime self)
	## chain_name  – unique string for this chain, e.g. "chain_0"
	##               Suffix all emitted variable/function names with it.

	var target_node: String = str(properties.get("target_node", "self"))
	var enabled: bool = bool(properties.get("enabled", true))

	if not enabled:
		return { "actuator_code": "# %s (disabled)" % brick_name }

	var code_lines: Array[String] = []

	# Resolve target node reference
	if target_node == "self":
		code_lines.append("var _target_%s = self" % chain_name)
	else:
		code_lines.append("var _target_%s = find_child(\"%s\", true, false)" % [chain_name, target_node])
		code_lines.append("if _target_%s == null:" % chain_name)
		code_lines.append("\tpush_warning(\"%s: could not find node '%s'\")" % [brick_name, target_node])
		code_lines.append("\treturn")

	# Replace the lines below with your actual actuator action.
	code_lines.append("# TODO: replace with actuator action")
	code_lines.append("pass")

	return { "actuator_code": "\n".join(code_lines) }
