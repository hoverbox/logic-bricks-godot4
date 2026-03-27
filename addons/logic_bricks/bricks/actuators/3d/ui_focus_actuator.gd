@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## UI Focus Actuator
## Sets, releases, or moves focus between Control nodes.
## Essential for gamepad/keyboard menu navigation — ensures the right button
## or slider is focused when a menu opens, closes, or transitions.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "UI Focus"


func _initialize_properties() -> void:
	properties = {
		"action":       "grab",     # grab, release, neighbor
		"direction":    "down",     # up, down, left, right (for neighbor mode)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Grab Focus,Release Focus,Focus Neighbor",
			"default": "grab"
		},
		{
			"name": "direction",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Up,Down,Left,Right",
			"default": "down"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Controls UI focus for keyboard and gamepad menu navigation.\nAssign the target Control node via the @export in the Inspector.\n\nGrab Focus: focus the assigned node immediately.\nRelease Focus: remove focus from the assigned node.\nFocus Neighbor: move focus to the next focusable node in a direction.",
		"action": "Grab Focus: call grab_focus() on the target node — use when opening a menu.\nRelease Focus: call release_focus() — use when closing a menu.\nFocus Neighbor: move focus in a direction from the target node — use for gamepad d-pad navigation.",
		"direction": "Which direction to move focus from the current node.\nOnly used when action is Focus Neighbor.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var action    = str(properties.get("action",    "grab")).to_lower().replace(" ", "_")
	var direction = str(properties.get("direction", "down")).to_lower()

	var control_var = "_ui_focus_node_%s" % chain_name
	var member_vars: Array[String] = []
	var code_lines:  Array[String] = []

	member_vars.append("@export var %s: Control" % control_var)

	code_lines.append("# UI Focus: %s" % action)
	code_lines.append("if %s:" % control_var)

	match action:
		"grab":
			code_lines.append("\t%s.grab_focus()" % control_var)

		"release":
			code_lines.append("\t%s.release_focus()" % control_var)

		"focus_neighbor":
			# Map direction to Godot's SIDE_* constant
			var side_map = {
				"up":    "SIDE_TOP",
				"down":  "SIDE_BOTTOM",
				"left":  "SIDE_LEFT",
				"right": "SIDE_RIGHT",
			}
			var side = side_map.get(direction, "SIDE_BOTTOM")
			# find_valid_focus_neighbor returns a NodePath; get_node on it gives the Control
			code_lines.append("\tvar _neighbor_path = %s.find_valid_focus_neighbor(%s)" % [control_var, side])
			code_lines.append("\tif not _neighbor_path.is_empty():")
			code_lines.append("\t\tvar _neighbor = %s.get_node_or_null(_neighbor_path)" % control_var)
			code_lines.append("\t\tif _neighbor and _neighbor is Control:")
			code_lines.append("\t\t\t_neighbor.grab_focus()")

		_:
			code_lines.append("\t%s.grab_focus()" % control_var)

	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"UI Focus Actuator: No Control assigned to '%s' — drag one into the inspector\")" % control_var)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars":   member_vars
	}
