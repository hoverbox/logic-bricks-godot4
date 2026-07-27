@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Animation Tree Actuator - beginner-friendly control for AnimationTree nodes
##
## Design goals:
## - User types only the AnimationTree node name, usually "AnimationTree".
## - The generated script searches all children recursively, like the Collision actuator.
## - Travel mode auto-finds the StateMachine playback object; users do not need
##   to know parameters/playback or nested state machine paths.
## - Condition mode auto-builds parameters/conditions/<condition_name>.
## - Parameter mode keeps a parameter field because arbitrary blend/tree params
##   cannot always be guessed, but it accepts either a full path or a short name.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Animation State"


func _initialize_properties() -> void:
	properties = {
		"mode": "go_to_state",             # go_to_state, set_parameter, set_condition
		"animation_tree_name": "AnimationTree", # Searches all children recursively. Empty = first AnimationTree found.
		# Travel mode
		"state_name": "",                  # Target state to travel to
		"state_machine_path": "",          # Advanced override. Empty = auto-detect playback.
		# Set Parameter mode
		"parameter_name": "",              # Simple name, e.g. blend_position, or full path.
		"parameter_path": "",              # Legacy/advanced full path.
		"param_type": "float",             # float, int, bool, vector2
		"param_float": 0.0,
		"param_int": 0,
		"param_bool": true,
		"param_x": 0.0,
		"param_y": 0.0,
		# Set Condition mode
		"condition_name": "",              # without parameters/conditions/ prefix
		"condition_value": "true",         # true/false, or expression for advanced use
		# Beginner condition-pair mode: set one condition true and another false in the same brick.
		"true_condition_name": "",         # condition to set true while this brick is active
		"false_condition_name": "",        # condition to set false while this brick is active
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Go To State:go_to_state,Set Blend Parameter:set_parameter,Advanced - Set Condition:set_condition_value",
			"default": "go_to_state"
		},
		{
			"name": "animation_tree_name",
			"type": TYPE_STRING,
			"default": "AnimationTree"
		},
		{
			"name": "state_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "true_condition_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "__ANIM_TREE_CONDITION_LIST__",
			"default": ""
		},
		{
			"name": "false_condition_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "__ANIM_TREE_CONDITION_LIST__",
			"default": ""
		},
		{
			"name": "condition_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "__ANIM_TREE_CONDITION_LIST__",
			"default": ""
		},
		{
			"name": "condition_value",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "true,false",
			"default": "true"
		},
		{
			"name": "parameter_name",
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
			"name": "state_machine_path",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "parameter_path",
			"type": TYPE_STRING,
			"default": ""
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Beginner-friendly AnimationTree control. Use Go To State for normal character animations. Blending comes from the transition Xfade Time inside the AnimationTree.",
		"mode": "Go To State: easiest choice. Travels to a state like Idle, Run, Jump, or Attack. Blending uses the AnimationTree transition Xfade Time.\nSet Blend Parameter: for BlendSpace values like blend_position.\nAdvanced - Set Condition: only for users who understand AnimationTree transition conditions.",
		"animation_tree_name": "Usually AnimationTree. Searches all children recursively, so paths are not required. Leave blank to use the first AnimationTree found under this node.",
		"state_name": "The AnimationTree state to play, for example Idle, Run, Jump, or Attack. This must match the state name inside the AnimationTree exactly.",
		"state_machine_path": "Advanced override only. Leave blank for Auto. Examples: parameters/playback or parameters/Locomotion/playback.",
		"parameter_name": "For Set Parameter mode. Use a short name like blend_position, or a full path like parameters/Locomotion/blend_position.",
		"parameter_path": "Legacy advanced full path. Prefer Parameter Name.",
		"true_condition_name": "Beginner pair mode: this condition is set to true while the brick is active. Example: is_moving.",
		"false_condition_name": "Beginner pair mode: this condition is set to false while the brick is active. Example: is_idle.",
		"condition_name": "Advanced single-value mode: condition name only. The brick generates parameters/conditions/<name> automatically.",
		"condition_value": "Advanced single-value mode: use true/false or a boolean variable/expression. Conditions must evaluate to bool.",
	}


func _gd_string(value: String) -> String:
	return value.c_escape()


func _parse_value(value_str: String) -> String:
	value_str = value_str.strip_edges()

	if value_str.to_lower() == "true":
		return "true"
	if value_str.to_lower() == "false":
		return "false"

	if value_str.is_valid_float():
		return value_str

	if value_str.begins_with("Vector2(") or value_str.begins_with("Vector3("):
		return value_str

	if value_str.begins_with("Color(") and value_str.ends_with(")"):
		return value_str

	# Could be a variable name. This intentionally matches the Modify Variable actuator.
	if value_str.is_valid_identifier():
		return value_str

	# Default: string literal. For AnimationTree conditions, the generated code
	# will report a type error if the final value is not a bool.
	return "\"%s\"" % value_str.replace("\"", "\\\"")


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "go_to_state")
	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")

	var anim_tree_name = str(properties.get("animation_tree_name", "AnimationTree")).strip_edges()
	var anim_tree_var = "_anim_tree_%s" % chain_name
	var code_lines: Array[String] = []
	var member_vars: Array[String] = []

	# Shared helpers. These are intentionally general and safe to include once or
	# more; the rebuild helper de-duplicates member vars elsewhere in the addon.
	member_vars.append("")
	member_vars.append("func _lb_find_first_animation_tree(node: Node) -> AnimationTree:")
	member_vars.append("\tfor child in node.get_children():")
	member_vars.append("\t\tif child is AnimationTree:")
	member_vars.append("\t\t\treturn child")
	member_vars.append("\t\tvar found = _lb_find_first_animation_tree(child)")
	member_vars.append("\t\tif found: return found")
	member_vars.append("\treturn null")
	member_vars.append("")
	member_vars.append("func _lb_find_animation_tree_playback(anim_tree: AnimationTree, preferred_path: String = \"\"):")
	member_vars.append("\tif anim_tree == null:")
	member_vars.append("\t\treturn null")
	member_vars.append("\tif not preferred_path.is_empty():")
	member_vars.append("\t\tvar preferred = anim_tree.get(preferred_path)")
	member_vars.append("\t\tif preferred is AnimationNodeStateMachinePlayback:")
	member_vars.append("\t\t\treturn preferred")
	member_vars.append("\tvar root_playback = anim_tree.get(\"parameters/playback\")")
	member_vars.append("\tif root_playback is AnimationNodeStateMachinePlayback:")
	member_vars.append("\t\treturn root_playback")
	member_vars.append("\tfor prop in anim_tree.get_property_list():")
	member_vars.append("\t\tvar prop_name = str(prop.get(\"name\", \"\"))")
	member_vars.append("\t\tif prop_name.ends_with(\"/playback\"):")
	member_vars.append("\t\t\tvar candidate = anim_tree.get(prop_name)")
	member_vars.append("\t\t\tif candidate is AnimationNodeStateMachinePlayback:")
	member_vars.append("\t\t\t\treturn candidate")
	member_vars.append("\treturn null")

	code_lines.append("# Animation Tree Actuator: find AnimationTree")
	if anim_tree_name.is_empty():
		code_lines.append("var %s = _lb_find_first_animation_tree(self)" % anim_tree_var)
	else:
		code_lines.append("var %s = find_child(\"%s\", true, false) as AnimationTree" % [anim_tree_var, _gd_string(anim_tree_name)])
	code_lines.append("if %s:" % anim_tree_var)

	match mode:
		"travel", "go_to_state":
			var state_name = str(properties.get("state_name", "")).strip_edges()
			var sm_path = str(properties.get("state_machine_path", "")).strip_edges()

			if state_name.is_empty():
				code_lines.append("\tpush_warning(\"Animation Tree Actuator: No state name set\")")
			else:
				code_lines.append("\t# Go to AnimationTree state '%s'. Blending is controlled by the AnimationTree transition Xfade Time." % _gd_string(state_name))
				code_lines.append("\t%s.active = true" % anim_tree_var)
				code_lines.append("\tvar _playback_%s = _lb_find_animation_tree_playback(%s, \"%s\")" % [chain_name, anim_tree_var, _gd_string(sm_path)])
				code_lines.append("\tif _playback_%s:" % chain_name)
				code_lines.append("\t\t_playback_%s.travel(\"%s\")" % [chain_name, _gd_string(state_name)])
				code_lines.append("\telse:")
				code_lines.append("\t\tpush_warning(\"Animation Tree Actuator: Could not find a StateMachine playback object. Make sure the AnimationTree Tree Root is an AnimationNodeStateMachine.\")")

		"set_parameter":
			var param_path = str(properties.get("parameter_path", "")).strip_edges()
			var param_name = str(properties.get("parameter_name", "")).strip_edges()
			if param_path.is_empty():
				param_path = param_name
			if not param_path.is_empty() and not param_path.begins_with("parameters/"):
				param_path = "parameters/%s" % param_path

			var param_type = properties.get("param_type", "float")
			if typeof(param_type) == TYPE_STRING:
				param_type = param_type.to_lower()

			# Guard: setting parameters/playback to a bool is always wrong.
			# parameters/playback holds an AnimationNodeStateMachinePlayback object,
			# not a boolean. This is a common misconfiguration when users want to
			# drive AnimationTree conditions. Use "Set Condition" mode instead and
			# set the condition name (e.g. "is_idle") with a true/false value, which
			# writes to parameters/conditions/<name> — what the state machine reads.
			if (param_path == "parameters/playback" or param_path.ends_with("/playback")) and param_type == "bool":
				code_lines.append("\t# ERROR: 'parameters/playback' is an AnimationNodeStateMachinePlayback object,")
				code_lines.append("\t# not a bool. Setting it to true/false does nothing.")
				code_lines.append("\t# To drive AnimationTree state-machine transitions, use the")
				code_lines.append("\t# Animation Tree Actuator in 'Set Condition' mode instead,")
				code_lines.append("\t# and set the condition name to match your transition condition (e.g. 'is_idle').")
				code_lines.append("\tpush_error(\"Animation Tree Actuator: 'parameters/playback' is not a bool. Switch this brick to 'Set Condition' mode and enter your condition name (e.g. is_idle).\")")
			elif param_path.is_empty():
				code_lines.append("\tpush_warning(\"Animation Tree Actuator: No parameter name set\")")
			else:
				var value_expr = "null"
				match param_type:
					"float":
						value_expr = "%.3f" % float(str(properties.get("param_float", 0.0)).to_float())
					"int":
						value_expr = "%d" % int(str(properties.get("param_int", 0)).to_int())
					"bool":
						var _raw_bool = properties.get("param_bool", true)
						value_expr = "true" if (str(_raw_bool).to_lower() not in ["false", "0", ""]) else "false"
					"vector2":
						var px = float(str(properties.get("param_x", 0.0)).to_float())
						var py = float(str(properties.get("param_y", 0.0)).to_float())
						value_expr = "Vector2(%.3f, %.3f)" % [px, py]
					_:
						value_expr = "%.3f" % float(str(properties.get("param_float", 0.0)).to_float())

				code_lines.append("\t# Set parameter '%s'" % _gd_string(param_path))
				code_lines.append("\t%s.set(\"%s\", %s)" % [anim_tree_var, _gd_string(param_path), value_expr])

		"set_condition_pair":
			var true_condition = str(properties.get("true_condition_name", "")).strip_edges()
			var false_condition = str(properties.get("false_condition_name", "")).strip_edges()

			if true_condition.is_empty() and false_condition.is_empty():
				code_lines.append("\tpush_warning(\"Animation Tree Actuator: No conditions selected for Condition Pair\")")
			else:
				code_lines.append("\t# Set AnimationTree condition pair every active frame")
				code_lines.append("\t%s.active = true" % anim_tree_var)
				if not true_condition.is_empty():
					code_lines.append("\t# TRUE condition: '%s'" % _gd_string(true_condition))
					code_lines.append("\t%s.set(\"parameters/conditions/%s\", true)" % [anim_tree_var, _gd_string(true_condition)])
				if not false_condition.is_empty():
					code_lines.append("\t# FALSE condition: '%s'" % _gd_string(false_condition))
					code_lines.append("\t%s.set(\"parameters/conditions/%s\", false)" % [anim_tree_var, _gd_string(false_condition)])

		"set_condition", "set_condition_value":
			var condition_name = str(properties.get("condition_name", "")).strip_edges()
			var condition_value_raw = str(properties.get("condition_value", "true")).strip_edges()

			if condition_name.is_empty():
				code_lines.append("\tpush_warning(\"Animation Tree Actuator: No condition name set\")")
			elif condition_value_raw.is_empty():
				code_lines.append("\tpush_warning(\"Animation Tree Actuator: No value set for condition '%s'\")" % _gd_string(condition_name))
			else:
				var value_expr = _parse_value(condition_value_raw)
				var value_var = "_condition_value_%s" % chain_name
				code_lines.append("\t# Set condition '%s' = %s every active frame" % [_gd_string(condition_name), condition_value_raw])
				code_lines.append("\t%s.active = true" % anim_tree_var)
				code_lines.append("\tvar %s = %s" % [value_var, value_expr])
				code_lines.append("\tif typeof(%s) == TYPE_BOOL:" % value_var)
				code_lines.append("\t\t%s.set(\"parameters/conditions/%s\", %s)" % [anim_tree_var, _gd_string(condition_name), value_var])
				code_lines.append("\telse:")
				code_lines.append("\t\tpush_error(\"Animation Tree Actuator: Condition '%s' expects a bool value, but got \" + type_string(typeof(%s)) + \". Use true/false or a bool variable/expression.\")" % [_gd_string(condition_name), value_var])

		_:
			code_lines.append("\tpass # Unknown mode")

	code_lines.append("else:")
	if anim_tree_name.is_empty():
		code_lines.append("\tpush_warning(\"Animation Tree Actuator: No AnimationTree found under this node\")")
	else:
		code_lines.append("\tpush_warning(\"Animation Tree Actuator: No AnimationTree named '%s' found under this node\")" % _gd_string(anim_tree_name))

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
