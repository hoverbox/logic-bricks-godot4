@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Animation Tree Actuator - Controls an AnimationTree node
## Supports state machine travel, parameter setting, and condition toggling
## The AnimationTree is assigned via @export (drag and drop in inspector)
##
## Modes:
##   Travel: Transition to a named state in a StateMachine
##   Set Parameter: Set any AnimationTree parameter (blend amounts, time scales)
##   Set Condition: Set a boolean condition for transitions


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Animation Tree"


func _initialize_properties() -> void:
	properties = {
		"mode": "travel",              # travel, set_parameter, set_condition
		# Travel mode
		"state_name": "",              # Target state to travel to
		"state_machine_path": "parameters/playback",  # Path to StateMachinePlayback
		# Set Parameter mode
		"parameter_path": "",          # e.g., "parameters/blend_position" or "parameters/TimeScale/scale"
		"param_type": "float",         # float, int, bool, vector2
		"param_float": 0.0,
		"param_int": 0,
		"param_bool": true,
		"param_x": 0.0,               # Vector2 x (for 2D blend spaces)
		"param_y": 0.0,               # Vector2 y
		# Set Condition mode
		"condition_name": "",          # Condition name (without parameters/conditions/ prefix)
		"condition_value": true,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Travel,Set Parameter,Set Condition",
			"default": "travel"
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
			"name": "parameter_path",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "param_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Float,Int,Bool,Vector2",
			"default": "float"
		},
		{
			"name": "param_float",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "param_int",
			"type": TYPE_INT,
			"default": 0
		},
		{
			"name": "param_bool",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "param_x",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "param_y",
			"type": TYPE_FLOAT,
			"default": 0.0
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
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Controls an AnimationTree node.\nSupports state machine travel, parameter setting, and condition toggling.\n\n⚠ Adds an @export in the Inspector — assign your AnimationTree there.",
		"mode": "Travel: transition to a state in the state machine\nSet Parameter: set an AnimationTree parameter\nSet Condition: toggle a condition boolean",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "travel")
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")

	var anim_tree_var = "_anim_tree_%s" % chain_name
	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	member_vars.append("@export var %s: AnimationTree" % anim_tree_var)

	code_lines.append("# Animation Tree actuator")
	code_lines.append("if not %s:" % anim_tree_var)
	code_lines.append("\tpush_warning(\"Animation Tree Actuator: No AnimationTree assigned to '%s'\")" % anim_tree_var)
	code_lines.append("else:")

	match mode:
		"travel":
			var state_name = properties.get("state_name", "")
			var sm_path = properties.get("state_machine_path", "parameters/playback")

			if state_name.strip_edges().is_empty():
				code_lines.append("\tpush_warning(\"Animation Tree Actuator: No state name set\")")
			else:
				code_lines.append("\t# Travel to state '%s'" % state_name.strip_edges())
				code_lines.append("\tvar _playback = %s.get(\"%s\")" % [anim_tree_var, sm_path.strip_edges()])
				code_lines.append("\tif _playback:")
				code_lines.append("\t\t_playback.travel(\"%s\")" % state_name.strip_edges())
				code_lines.append("\telse:")
				code_lines.append("\t\tpush_warning(\"Animation Tree Actuator: No playback found at '%s'\")" % sm_path.strip_edges())

		"set_parameter":
			var param_path = properties.get("parameter_path", "")
			var param_type = properties.get("param_type", "float")
			if typeof(param_type) == TYPE_STRING:
				param_type = param_type.to_lower()

			if param_path.strip_edges().is_empty():
				code_lines.append("\tpush_warning(\"Animation Tree Actuator: No parameter path set\")")
			else:
				var value_expr = ""
				match param_type:
					"float":
						value_expr = "%.3f" % properties.get("param_float", 0.0)
					"int":
						value_expr = "%d" % properties.get("param_int", 0)
					"bool":
						value_expr = "true" if properties.get("param_bool", true) else "false"
					"vector2":
						var px = properties.get("param_x", 0.0)
						var py = properties.get("param_y", 0.0)
						value_expr = "Vector2(%.3f, %.3f)" % [px, py]

				code_lines.append("\t# Set parameter '%s'" % param_path.strip_edges())
				code_lines.append("\t%s.set(\"%s\", %s)" % [anim_tree_var, param_path.strip_edges(), value_expr])

		"set_condition":
			var condition_name = properties.get("condition_name", "")
			var condition_value = properties.get("condition_value", true)

			if condition_name.strip_edges().is_empty():
				code_lines.append("\tpush_warning(\"Animation Tree Actuator: No condition name set\")")
			else:
				var val_str = "true" if condition_value else "false"
				code_lines.append("\t# Set condition '%s' = %s" % [condition_name.strip_edges(), val_str])
				code_lines.append("\t%s.set(\"parameters/conditions/%s\", %s)" % [anim_tree_var, condition_name.strip_edges(), val_str])

		_:
			code_lines.append("\tpass  # Unknown mode")

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
