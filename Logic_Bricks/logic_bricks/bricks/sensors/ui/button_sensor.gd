@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Button Sensor - UI-only sensor for Button/BaseButton nodes.
## The generated code intentionally avoids typed BaseButton assignment so the
## Logic Bricks script can safely live on a Control container.

func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Button"

func get_brick_info() -> Dictionary:
	return {
		"class": "UIButtonSensor",
		"name": "Button",
		"type": "sensor",
		"category": "UI",
		"description": "Detects when a Button is pressed, toggled, hovered, or focused.",
		"menu_order": 5,
		"domain": "ui"
	}

func serialize() -> Dictionary:
	var data = super.serialize()
	var info = get_brick_info()
	if typeof(info) == TYPE_DICTIONARY and info.has("class"):
		data["type"] = str(info["class"])
	return data

func _initialize_properties() -> void:
	properties = {
		"target_node_name": "",
		"event": "just_pressed",
		"store_pressed": ""
	}

func get_property_definitions() -> Array:
	return [
		{"name": "target_node_name", "type": TYPE_STRING, "default": ""},
		{"name": "event", "type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": "Just Pressed,Pressed,Just Released,Hovering,Focused,Toggled On,Toggled Off", "default": "just_pressed"},
		{"name": "store_pressed", "type": TYPE_STRING, "default": ""},
	]

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Detects UI button state from a Button node. Leave Target Node Name blank to use self only when this Logic Bricks graph is on the Button itself.",
		"target_node_name": "Button node name to check. Leave blank to check the selected node itself.",
		"event": "Just Pressed/Released are one-frame events. Pressed checks current button state. Hovering and Focused check UI state. Toggled modes require a toggle button.",
		"store_pressed": "Optional variable name to store the button's current pressed/toggle state."
	}

func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "")).strip_edges()
	var event = str(properties.get("event", "just_pressed")).to_lower().replace(" ", "_")
	var store_pressed = str(properties.get("store_pressed", "")).strip_edges()
	var label = _unique_label(chain_name)
	var button_var = "_%s_button" % label
	var target_var = "_target_name_%s" % label
	var code_lines: Array[String] = []
	var member_vars: Array[String] = []

	member_vars.append("var %s = null" % button_var)
	_append_find_node_helpers(member_vars)

	code_lines.append("# Button Sensor")
	code_lines.append("var sensor_active = false")
	code_lines.append("var %s = \"%s\"" % [target_var, _gd_string(target_node_name)])
	code_lines.append("if %s.strip_edges().is_empty():" % target_var)
	code_lines.append("\t%s = self" % button_var)
	code_lines.append("elif %s == null or %s.name != %s:" % [button_var, button_var, target_var])
	code_lines.append("\t%s = _lb_find_node_in_current_scene(%s)" % [button_var, target_var])
	code_lines.append("if %s != null and %s is BaseButton:" % [button_var, button_var])
	match event:
		"just_pressed":
			code_lines.append("\tsensor_active = bool(%s.get(\"button_pressed\")) and not bool(%s.get_meta(\"_lb_was_pressed\", false))" % [button_var, button_var])
		"pressed":
			code_lines.append("\tsensor_active = bool(%s.get(\"button_pressed\"))" % button_var)
		"just_released":
			code_lines.append("\tsensor_active = (not bool(%s.get(\"button_pressed\"))) and bool(%s.get_meta(\"_lb_was_pressed\", false))" % [button_var, button_var])
		"hovering":
			code_lines.append("\tsensor_active = %s.is_hovered()" % button_var)
		"focused":
			code_lines.append("\tsensor_active = %s.has_focus()" % button_var)
		"toggled_on":
			code_lines.append("\tsensor_active = bool(%s.get(\"toggle_mode\")) and bool(%s.get(\"button_pressed\"))" % [button_var, button_var])
		"toggled_off":
			code_lines.append("\tsensor_active = bool(%s.get(\"toggle_mode\")) and not bool(%s.get(\"button_pressed\"))" % [button_var, button_var])
		_:
			code_lines.append("\tsensor_active = bool(%s.get(\"button_pressed\"))" % button_var)
	if not store_pressed.is_empty():
		code_lines.append("\t%s = bool(%s.get(\"button_pressed\"))" % [store_pressed, button_var])
	code_lines.append("\t%s.set_meta(\"_lb_was_pressed\", bool(%s.get(\"button_pressed\")))" % [button_var, button_var])
	return {"member_vars": member_vars, "sensor_code": "\n".join(code_lines)}

func _append_find_node_helpers(member_vars: Array[String]) -> void:
	var helper = "func _lb_find_node_in_current_scene(target_name: String) -> Node:\n\tvar scene_root = get_tree().current_scene\n\tif scene_root == null:\n\t\tscene_root = get_tree().root\n\treturn _lb_find_node_recursive(scene_root, target_name)\n\nfunc _lb_find_node_recursive(parent: Node, target_name: String) -> Node:\n\tif parent.name == target_name:\n\t\treturn parent\n\tfor child in parent.get_children():\n\t\tvar found = _lb_find_node_recursive(child, target_name)\n\t\tif found:\n\t\t\treturn found\n\treturn null"
	if not member_vars.has(helper):
		member_vars.append(helper)

func _unique_label(chain_name: String) -> String:
	var label = instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	label = label.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	if label.is_empty():
		label = "button_sensor"
	return label

func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n")
