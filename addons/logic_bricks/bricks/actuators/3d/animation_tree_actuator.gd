@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Animation Tree Actuator - Controls an AnimationTree node
## 
## Simplified interface:
##   Travel: Type a state name to transition to (e.g. "run", "idle")
##   Set Condition: Toggle a boolean condition for transitions
##   Set Parameter: Set any AnimationTree parameter by path and value
##
## The "Node Path" field should point to the child node that has the
## AnimationTree (e.g. your imported GLB model).


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Animation Tree"


func _initialize_properties() -> void:
	properties = {
		"animation_node_path": "",     # Path to child node containing AnimationTree
		"mode": "travel",              # travel, set_condition, set_parameter
		"state_name": "",              # Travel: target state name (e.g. "run")
		"condition_name": "",          # Set Condition: condition name
		"condition_value": true,       # Set Condition: true/false
		"parameter_path": "",          # Set Parameter: full path (e.g. "parameters/blend_position")
		"value": "0.0",                # Set Parameter: value as string (auto-detects type)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "animation_node_path",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Travel,Set Condition,Set Parameter",
			"default": "travel"
		},
		{
			"name": "state_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "condition_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "condition_value",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "parameter_path",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "value",
			"type": TYPE_STRING,
			"default": "0.0"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Controls an AnimationTree node.\nTravel between states, set conditions, or set parameters.",
		"animation_node_path": "Path to the child node that has the AnimationTree\n(e.g. your imported GLB model name).",
		"mode": "Travel: go to a state (e.g. 'run', 'idle')\nSet Condition: toggle a transition condition\nSet Parameter: set any tree parameter by path",
		"state_name": "Name of the state to travel to (e.g. 'run', 'idle', 'jump').",
		"condition_name": "Name of the condition (just the name, not the full path).\nThe 'parameters/conditions/' prefix is added automatically.",
		"condition_value": "Set the condition to true or false.",
		"parameter_path": "Full parameter path in the AnimationTree\n(e.g. 'parameters/blend_position' or 'parameters/TimeScale/scale').",
		"value": "Value to set. Auto-detects type:\n• Number: 1.5\n• Bool: true / false\n• Vector2: 0.5, 0.8",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var anim_node_path = properties.get("animation_node_path", "")
	var mode = properties.get("mode", "travel")
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")

	var node_path_str = str(anim_node_path).strip_edges()
	var code_lines: Array[String] = []

	if node_path_str.is_empty():
		code_lines.append("pass  # Animation Tree: No node path specified")
		return {"actuator_code": "\n".join(code_lines)}

	# Find AnimationTree on the child node
	code_lines.append("var _at_node = get_node_or_null(\"%s\")" % node_path_str)
	code_lines.append("if _at_node:")
	code_lines.append("\tvar _anim_tree: AnimationTree = null")
	code_lines.append("\tif _at_node is AnimationTree:")
	code_lines.append("\t\t_anim_tree = _at_node")
	code_lines.append("\telse:")
	code_lines.append("\t\tfor child in _at_node.get_children():")
	code_lines.append("\t\t\tif child is AnimationTree:")
	code_lines.append("\t\t\t\t_anim_tree = child")
	code_lines.append("\t\t\t\tbreak")
	code_lines.append("\tif _anim_tree:")

	match mode:
		"travel":
			var state_name = str(properties.get("state_name", "")).strip_edges()
			if state_name.is_empty():
				code_lines.append("\t\tpass  # No state name specified")
			else:
				code_lines.append("\t\tvar _pb = _anim_tree.get(\"parameters/playback\")")
				code_lines.append("\t\tif _pb:")
				code_lines.append("\t\t\t_pb.travel(\"%s\")" % state_name)

		"set_condition":
			var cond_name = str(properties.get("condition_name", "")).strip_edges()
			var cond_val = properties.get("condition_value", true)
			if cond_name.is_empty():
				code_lines.append("\t\tpass  # No condition name specified")
			else:
				var val_str = "true" if cond_val else "false"
				code_lines.append("\t\t_anim_tree.set(\"parameters/conditions/%s\", %s)" % [cond_name, val_str])

		"set_parameter":
			var param_path = str(properties.get("parameter_path", "")).strip_edges()
			var raw_value = str(properties.get("value", "0.0")).strip_edges()
			if param_path.is_empty():
				code_lines.append("\t\tpass  # No parameter path specified")
			else:
				var value_expr = _parse_value(raw_value)
				code_lines.append("\t\t_anim_tree.set(\"%s\", %s)" % [param_path, value_expr])

		_:
			code_lines.append("\t\tpass")

	return {"actuator_code": "\n".join(code_lines)}


## Parse a user-entered value string into a GDScript expression
## Supports: float, int, bool, Vector2 (comma-separated)
func _parse_value(raw: String) -> String:
	# Bool
	if raw.to_lower() == "true":
		return "true"
	if raw.to_lower() == "false":
		return "false"
	
	# Vector2 (two comma-separated numbers)
	if "," in raw:
		var parts = raw.split(",")
		if parts.size() == 2:
			var x = parts[0].strip_edges()
			var y = parts[1].strip_edges()
			if x.is_valid_float() and y.is_valid_float():
				return "Vector2(%s, %s)" % [x, y]
	
	# Int (no decimal point)
	if raw.is_valid_int():
		return raw
	
	# Float
	if raw.is_valid_float():
		return raw
	
	# Variable name fallback
	return raw
