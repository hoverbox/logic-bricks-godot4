@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Save Game Actuator - Saves or loads game state to/from a file
## Saves logic brick variables, position, and rotation for this node
## Data is stored as JSON in user:// so it persists across sessions
## Pair with an InputMap Sensor or Collision Sensor to trigger


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Save Game"


func _initialize_properties() -> void:
	properties = {
		"mode": "save",             # save, load
		"slot": "slot1",            # Save slot name
		"save_position": true,
		"save_rotation": true,
		"save_variables": true,     # Save all script variables (non-private)
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Save,Load",
			"default": "save"
		},
		{
			"name": "slot",
			"type": TYPE_STRING,
			"default": "slot1"
		},
		{
			"name": "save_position",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "save_rotation",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "save_variables",
			"type": TYPE_BOOL,
			"default": true
		},
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var mode = properties.get("mode", "save")
	var slot = properties.get("slot", "slot1")
	var save_position = properties.get("save_position", true)
	var save_rotation = properties.get("save_rotation", true)
	var save_variables = properties.get("save_variables", true)

	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower()
	if typeof(slot) == TYPE_STRING:
		slot = slot.strip_edges()
	if slot.is_empty():
		slot = "slot1"

	var code_lines: Array[String] = []
	var save_path = "user://save_%s.json" % slot

	match mode:
		"save":
			code_lines.append("# Save game state")
			code_lines.append("var _save_data: Dictionary = {}")

			if save_position:
				code_lines.append("_save_data[\"position\"] = {\"x\": global_position.x, \"y\": global_position.y, \"z\": global_position.z}")

			if save_rotation:
				code_lines.append("_save_data[\"rotation\"] = {\"x\": global_rotation.x, \"y\": global_rotation.y, \"z\": global_rotation.z}")

			if save_variables:
				code_lines.append("")
				code_lines.append("# Save all non-private script variables")
				code_lines.append("var _vars: Dictionary = {}")
				code_lines.append("for _prop in get_script().get_script_property_list():")
				code_lines.append("\tvar _name = _prop[\"name\"]")
				code_lines.append("\tif _name.begins_with(\"_\") or _name.begins_with(\"@\"):")
				code_lines.append("\t\tcontinue")
				code_lines.append("\tvar _val = get(_name)")
				code_lines.append("\tif _val is int or _val is float or _val is bool or _val is String:")
				code_lines.append("\t\t_vars[_name] = _val")
				code_lines.append("_save_data[\"variables\"] = _vars")

			code_lines.append("")
			code_lines.append("var _file = FileAccess.open(\"%s\", FileAccess.WRITE)" % save_path)
			code_lines.append("if _file:")
			code_lines.append("\t_file.store_string(JSON.stringify(_save_data))")
			code_lines.append("\t_file.close()")

		"load":
			code_lines.append("# Load game state")
			code_lines.append("if FileAccess.file_exists(\"%s\"):" % save_path)
			code_lines.append("\tvar _file = FileAccess.open(\"%s\", FileAccess.READ)" % save_path)
			code_lines.append("\tif _file:")
			code_lines.append("\t\tvar _json = JSON.new()")
			code_lines.append("\t\tvar _err = _json.parse(_file.get_as_text())")
			code_lines.append("\t\t_file.close()")
			code_lines.append("\t\tif _err == OK:")
			code_lines.append("\t\t\tvar _save_data = _json.data")

			if save_position:
				code_lines.append("\t\t\tif _save_data.has(\"position\"):")
				code_lines.append("\t\t\t\tvar _pos = _save_data[\"position\"]")
				code_lines.append("\t\t\t\tglobal_position = Vector3(_pos[\"x\"], _pos[\"y\"], _pos[\"z\"])")

			if save_rotation:
				code_lines.append("\t\t\tif _save_data.has(\"rotation\"):")
				code_lines.append("\t\t\t\tvar _rot = _save_data[\"rotation\"]")
				code_lines.append("\t\t\t\tglobal_rotation = Vector3(_rot[\"x\"], _rot[\"y\"], _rot[\"z\"])")

			if save_variables:
				code_lines.append("\t\t\tif _save_data.has(\"variables\"):")
				code_lines.append("\t\t\t\tfor _name in _save_data[\"variables\"]:")
				code_lines.append("\t\t\t\t\tset(_name, _save_data[\"variables\"][_name])")

	return {
		"actuator_code": "\n".join(code_lines)
	}
