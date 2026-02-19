@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Animation Tree Sensor - Monitors an AnimationTree's state and parameters
## The AnimationTree is assigned via @export (drag and drop in inspector)
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
	var mode = properties.get("mode", "current_state")
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")

	var anim_tree_var = "_anim_tree_sensor_%s" % chain_name
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("@export var %s: AnimationTree" % anim_tree_var)

	code_lines.append("# Animation Tree sensor")
	code_lines.append("var sensor_active = false")
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
