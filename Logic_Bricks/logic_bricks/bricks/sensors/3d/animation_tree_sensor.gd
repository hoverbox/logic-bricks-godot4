@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Animation Tree Sensor - Monitors an AnimationTree's state and parameters
## The AnimationTree is found by typed node name
##
## Modes:
##   Current State: True when the state machine is in a specific state
##   Condition: True when a boolean condition matches
##   Parameter Compare: True when a parameter meets a comparison condition


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Animation Tree"


func _initialize_properties() -> void:
	properties = {
		"animation_tree_node_name": "AnimationTree",
		"mode": "current_state",       # current_state, condition, parameter_compare
		# Current State mode
		"state_name": "",              # State to check for
		"state_machine_path": "parameters/playback",
		# Condition mode
		"condition_name": "",          # Condition to check
		"condition_expected": true,    # Expected value
		# Parameter Compare mode
		"parameter_path": "",          # Parameter to check
		"compare_op": "equal",         # equal, not_equal, greater, less, greater_equal, less_equal
		"compare_value": 0.0,          # Value to compare against
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "animation_tree_node_name",
			"type": TYPE_STRING,
			"default": "AnimationTree",
			"placeholder": "AnimationTree node name"
		},
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Current State,Condition,Parameter Compare",
			"default": "current_state"
		},
		{
			"name": "state_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "state_machine_path",
			"type": TYPE_STRING,
			"default": "parameters/playback"
		},
		{
			"name": "condition_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "condition_expected",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "parameter_path",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "compare_op",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Equal,Not Equal,Greater,Less,Greater Equal,Less Equal",
			"default": "equal"
		},
		{
			"name": "compare_value",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var animation_tree_node_name = str(properties.get("animation_tree_node_name", "AnimationTree")).strip_edges()
	var mode = properties.get("mode", "current_state")
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")

	var anim_tree_var = "_anim_tree_sensor_%s" % chain_name
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("var %s: AnimationTree = null" % anim_tree_var)
	_append_find_node_helpers(member_vars)

	code_lines.append("# Animation Tree sensor")
	code_lines.append("var sensor_active = false")
	code_lines.append("var _node_name_%s = \"%s\"" % [chain_name, _gd_string(animation_tree_node_name)])
	code_lines.append("if _node_name_%s.is_empty():" % chain_name)
	code_lines.append("\tpush_warning(\"Animation Tree Sensor: No node name set\")")
	code_lines.append("\t" + anim_tree_var + " = null")
	code_lines.append("elif " + anim_tree_var + " == null or " + anim_tree_var + ".name != _node_name_%s:" % chain_name)
	code_lines.append("\tvar _found_node_%s = _lb_find_node_in_current_scene(_node_name_%s)" % [chain_name, chain_name])
	code_lines.append("\tif _found_node_%s is AnimationTree:" % chain_name)
	code_lines.append("\t\t" + anim_tree_var + " = _found_node_%s" % chain_name)
	code_lines.append("\telif _found_node_%s:" % chain_name)
	code_lines.append("\t\tpush_warning(\"Animation Tree Sensor: node '\" + str(_node_name_%s) + \"' is not a AnimationTree\")" % chain_name)
	code_lines.append("if %s:" % anim_tree_var)

	match mode:
		"current_state":
			var state_name = properties.get("state_name", "")
			var sm_path = properties.get("state_machine_path", "parameters/playback")

			if state_name.strip_edges().is_empty():
				code_lines.append("\tpass  # No state name set")
			else:
				code_lines.append("\tvar _playback = %s.get(\"%s\")" % [anim_tree_var, sm_path.strip_edges()])
				code_lines.append("\tif _playback:")
				code_lines.append("\t\tsensor_active = _playback.get_current_node() == \"%s\"" % state_name.strip_edges())

		"condition":
			var condition_name = properties.get("condition_name", "")
			var condition_expected = properties.get("condition_expected", true)

			if condition_name.strip_edges().is_empty():
				code_lines.append("\tpass  # No condition name set")
			else:
				var expected_str = "true" if condition_expected else "false"
				code_lines.append("\tvar _cond_val = %s.get(\"parameters/conditions/%s\")" % [anim_tree_var, condition_name.strip_edges()])
				code_lines.append("\tsensor_active = _cond_val == %s" % expected_str)

		"parameter_compare":
			var param_path = properties.get("parameter_path", "")
			var compare_op = properties.get("compare_op", "equal")
			var compare_value = properties.get("compare_value", 0.0)

			if typeof(compare_op) == TYPE_STRING:
				compare_op = compare_op.to_lower().replace(" ", "_")

			if param_path.strip_edges().is_empty():
				code_lines.append("\tpass  # No parameter path set")
			else:
				code_lines.append("\tvar _param_val = %s.get(\"%s\")" % [anim_tree_var, param_path.strip_edges()])
				code_lines.append("\tif _param_val != null:")

				var op_str = "=="
				match compare_op:
					"equal":
						op_str = "=="
					"not_equal":
						op_str = "!="
					"greater":
						op_str = ">"
					"less":
						op_str = "<"
					"greater_equal":
						op_str = ">="
					"less_equal":
						op_str = "<="

				code_lines.append("\t\tsensor_active = _param_val %s %.3f" % [op_str, compare_value])

		_:
			code_lines.append("\tpass  # Unknown mode")

	return {
		"sensor_code": "\n".join(code_lines),
		"member_vars": member_vars
	}


func _append_find_node_helpers(member_vars: Array[String]) -> void:
	member_vars.append("")
	member_vars.append("func _lb_find_node_by_name_recursive(node: Node, target_name: String) -> Node:")
	member_vars.append("\tif node == null or target_name.is_empty():")
	member_vars.append("\t\treturn null")
	member_vars.append("\tif node.name == target_name:")
	member_vars.append("\t\treturn node")
	member_vars.append("\tfor child in node.get_children():")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(child, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn null")
	member_vars.append("")
	member_vars.append("func _lb_find_node_in_current_scene(target_name: String) -> Node:")
	member_vars.append("\tvar scene_root = get_tree().current_scene")
	member_vars.append("\tif scene_root:")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(scene_root, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn _lb_find_node_by_name_recursive(get_tree().root, target_name)")

func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")
