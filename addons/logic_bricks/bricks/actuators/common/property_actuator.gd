@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Node Properties - set one Inspector property on the selected target node.
## The editor populates the Property dropdown from the actual target node, so
## this works with built-in nodes and custom script properties without a
## hand-maintained node-type list.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Node Properties"


func _initialize_properties() -> void:
	properties = {
		"target_node": "self",
		"property_name": "",
		"value": "",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_node",
			"type": TYPE_STRING,
			"default": "self",
			"node_reference": true,
			"placeholder": "self or node name",
		},
		{
			"name": "property_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "__TARGET_NODE_PROPERTY_LIST__",
			"default": "",
		},
		{
			"name": "value",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Value, variable, or expression",
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Sets an Inspector property on Self or another node. The Property list updates to match the selected Target Node.",
		"target_node": "Self uses the node that owns these Logic Bricks. Type a node name or Ctrl-drag a node from the Scene dock.",
		"property_name": "Properties are read directly from the selected target node's Inspector property list.",
		"value": "Value to assign. Numbers, booleans, vectors, colors, variables, and expressions can be entered directly. Plain text is automatically quoted for String properties.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_name := str(properties.get("target_node", "self")).strip_edges()
	var property_name := str(properties.get("property_name", "")).strip_edges()
	var raw_value := str(properties.get("value", "")).strip_edges()
	if target_name.is_empty():
		target_name = "self"
	if property_name.is_empty():
		return {"actuator_code": "push_warning(\"Node Properties: No property selected\")"}
	if raw_value.is_empty():
		return {"actuator_code": "push_warning(\"Node Properties: No value set for property '%s'\")" % _gd_string(property_name)}

	var target := _resolve_editor_target(node, target_name)
	var property_type := _property_type(target, property_name)
	var value_expr := _value_expression(node, raw_value, property_type)
	var safe_property := _gd_string(property_name)
	var code_lines: Array[String] = []

	if target_name.to_lower() == "self":
		code_lines.append("set_indexed(\"%s\", %s)" % [safe_property, value_expr])
		return {"actuator_code": "\n".join(code_lines)}

	var target_var := "_property_target_%s" % chain_name
	code_lines.append("var %s = get_tree().root.find_child(\"%s\", true, false)" % [target_var, _gd_string(target_name)])
	code_lines.append("if %s:" % target_var)
	code_lines.append("\t%s.set_indexed(\"%s\", %s)" % [target_var, safe_property, value_expr])
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Node Properties: Node named '%s' not found\")" % _gd_string(target_name))
	return {"actuator_code": "\n".join(code_lines)}


func _resolve_editor_target(owner_node: Node, target_name: String) -> Node:
	if owner_node == null:
		return null
	if target_name.is_empty() or target_name.to_lower() == "self":
		return owner_node
	var tree := owner_node.get_tree()
	if tree != null and tree.root != null:
		return tree.root.find_child(target_name, true, false)
	return owner_node.find_child(target_name, true, false)


func _property_type(target: Node, property_name: String) -> int:
	if target == null:
		return TYPE_NIL
	for info in target.get_property_list():
		if str(info.get("name", "")) == property_name:
			return int(info.get("type", TYPE_NIL))
	return TYPE_NIL


func _value_expression(owner_node: Node, raw_value: String, property_type: int) -> String:
	# Exact Logic Bricks variable names stay as variable references, including
	# String variables. Everything else follows the target property's type.
	if _is_logic_brick_variable(owner_node, raw_value):
		return raw_value
	match property_type:
		TYPE_STRING:
			return "\"%s\"" % _gd_string(raw_value)
		TYPE_STRING_NAME:
			return "StringName(\"%s\")" % _gd_string(raw_value)
		TYPE_NODE_PATH:
			return "NodePath(\"%s\")" % _gd_string(raw_value)
		_:
			return raw_value


func _is_logic_brick_variable(owner_node: Node, candidate: String) -> bool:
	if owner_node == null or candidate.is_empty():
		return false
	var variables = owner_node.get_meta("logic_bricks_variables", [])
	if not variables is Array:
		return false
	for variable in variables:
		if variable is Dictionary and str(variable.get("name", "")) == candidate:
			return true
	return false
