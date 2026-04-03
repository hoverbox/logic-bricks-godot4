@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Save / Load Actuator - Saves or loads game state to/from a file
## Three scopes:
##   This Node   — saves position, rotation, and variables for the node this brick is on
##   Target Node — saves position, rotation, and variables for a specific named node
##   Group       — saves position, rotation, and variables for every node in a named group
## No custom save()/load() methods required on any node.
## Pair with an InputMap Sensor or Collision Sensor to trigger


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Save / Load"


func _initialize_properties() -> void:
	properties = {
		"mode": "save",         # save, load
		"scope": "this_node",   # this_node, target_node, group
		"target": "",           # Node name (target_node) or group name (group)
		"slot": "slot1",        # Save slot name → user://saves/slot1.json
		"save_path": "",        # Custom path, overrides slot if set
		"save_position": true,
		"save_rotation": true,
		"save_variables": true,
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
			"name": "scope",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "This Node,Target Node,Group",
			"default": "this_node"
		},
		{
			"name": "target",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Node name or group name"
		},
		{
			"name": "slot",
			"type": TYPE_STRING,
			"default": "slot1"
		},
		{
			"name": "save_path",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "e.g. user://saves/mysave.json"
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
	var scope = properties.get("scope", "this_node")
	var target = properties.get("target", "")
	var slot = properties.get("slot", "slot1")
	var save_path = properties.get("save_path", "")
	var save_position = properties.get("save_position", true)
	var save_rotation = properties.get("save_rotation", true)
	var save_variables = properties.get("save_variables", true)

	if typeof(mode) == TYPE_STRING:
		mode = mode.to_lower().replace(" ", "_")
	if typeof(scope) == TYPE_STRING:
		scope = scope.to_lower().replace(" ", "_")
	if typeof(slot) == TYPE_STRING:
		slot = slot.strip_edges()
	if slot.is_empty():
		slot = "slot1"
	if typeof(save_path) == TYPE_STRING:
		save_path = save_path.strip_edges()
	if typeof(target) == TYPE_STRING:
		target = target.strip_edges()

	# Resolve the final file path
	var resolved_path: String
	if not save_path.is_empty():
		resolved_path = save_path
	else:
		resolved_path = "user://saves/%s.json" % slot

	var code_lines: Array[String] = []

	# Ensure the saves directory exists before any file operation
	code_lines.append("DirAccess.make_dir_recursive_absolute(\"user://saves\")")

	# Build a helper that serializes a single node's state into a sub-dictionary
	# We inline this logic per-scope rather than emitting a helper function,
	# so the generated code stays self-contained.

	match scope:

		# ── This Node ──────────────────────────────────────────────────────────
		"this_node":
			match mode:
				"save":
					code_lines.append("# Save game state (this node)")
					code_lines.append("var _save_data: Dictionary = {}")
					_append_node_save_lines(code_lines, "self", save_position, save_rotation, save_variables, "")
					code_lines.append("var _file = FileAccess.open(\"%s\", FileAccess.WRITE)" % resolved_path)
					code_lines.append("if _file:")
					code_lines.append("\t_file.store_string(JSON.stringify(_save_data))")
					code_lines.append("\t_file.close()")
					code_lines.append("else:")
					code_lines.append("\tpush_error(\"Save/Load Actuator: Failed to open save file: %s\")" % resolved_path)

				"load":
					code_lines.append("# Load game state (this node)")
					code_lines.append("if FileAccess.file_exists(\"%s\"):" % resolved_path)
					code_lines.append("\tvar _file = FileAccess.open(\"%s\", FileAccess.READ)" % resolved_path)
					code_lines.append("\tif _file:")
					code_lines.append("\t\tvar _json = JSON.new()")
					code_lines.append("\t\tvar _err = _json.parse(_file.get_as_text())")
					code_lines.append("\t\t_file.close()")
					code_lines.append("\t\tif _err == OK and _json.data is Dictionary:")
					_append_node_load_lines(code_lines, "self", save_position, save_rotation, save_variables, "\t\t\t")
					code_lines.append("\t\telse:")
					code_lines.append("\t\t\tpush_error(\"Save/Load Actuator: Invalid or missing save file: %s\")" % resolved_path)
					code_lines.append("\telse:")
					code_lines.append("\t\tpush_error(\"Save/Load Actuator: Failed to open save file: %s\")" % resolved_path)
					code_lines.append("else:")
					code_lines.append("\tpush_warning(\"Save/Load Actuator: Save file not found: %s\")" % resolved_path)

		# ── Target Node ────────────────────────────────────────────────────────
		"target_node":
			if target.is_empty():
				code_lines.append("push_warning(\"Save/Load Actuator: Target Node scope requires a node name in the Target field.\")")
			else:
				match mode:
					"save":
						code_lines.append("# Save game state (target node: %s)" % target)
						code_lines.append("var _target_node = get_tree().root.find_child(\"%s\", true, false)" % target)
						code_lines.append("if _target_node:")
						code_lines.append("\tvar _save_data: Dictionary = {}")
						_append_node_save_lines(code_lines, "_target_node", save_position, save_rotation, save_variables, "\t")
						code_lines.append("\tvar _file = FileAccess.open(\"%s\", FileAccess.WRITE)" % resolved_path)
						code_lines.append("\tif _file:")
						code_lines.append("\t\t_file.store_string(JSON.stringify(_save_data))")
						code_lines.append("\t\t_file.close()")
						code_lines.append("\telse:")
						code_lines.append("\t\tpush_error(\"Save/Load Actuator: Failed to open save file: %s\")" % resolved_path)
						code_lines.append("else:")
						code_lines.append("\tpush_warning(\"Save/Load Actuator: Could not find node named '%s'.\")" % target)

					"load":
						code_lines.append("# Load game state (target node: %s)" % target)
						code_lines.append("var _target_node = get_tree().root.find_child(\"%s\", true, false)" % target)
						code_lines.append("if _target_node:")
						code_lines.append("\tif FileAccess.file_exists(\"%s\"):" % resolved_path)
						code_lines.append("\t\tvar _file = FileAccess.open(\"%s\", FileAccess.READ)" % resolved_path)
						code_lines.append("\t\tif _file:")
						code_lines.append("\t\t\tvar _json = JSON.new()")
						code_lines.append("\t\t\tvar _err = _json.parse(_file.get_as_text())")
						code_lines.append("\t\t\t_file.close()")
						code_lines.append("\t\t\tif _err == OK and _json.data is Dictionary:")
						_append_node_load_lines(code_lines, "_target_node", save_position, save_rotation, save_variables, "\t\t\t\t")
						code_lines.append("\t\t\telse:")
						code_lines.append("\t\t\t\tpush_error(\"Save/Load Actuator: Invalid save data: %s\")" % resolved_path)
						code_lines.append("\t\telse:")
						code_lines.append("\t\t\tpush_error(\"Save/Load Actuator: Failed to open save file: %s\")" % resolved_path)
						code_lines.append("\telse:")
						code_lines.append("\t\tpush_warning(\"Save/Load Actuator: Save file not found: %s\")" % resolved_path)
						code_lines.append("else:")
						code_lines.append("\tpush_warning(\"Save/Load Actuator: Could not find node named '%s'.\")" % target)

		# ── Group ──────────────────────────────────────────────────────────────
		"group":
			var group_name = target if not target.is_empty() else "save"
			match mode:
				"save":
					code_lines.append("# Save game state (group: %s)" % group_name)
					code_lines.append("var _save_data: Dictionary = {}")
					code_lines.append("for _gnode in get_tree().get_nodes_in_group(\"%s\"):" % group_name)
					code_lines.append("\tvar _ndata: Dictionary = {}")
					if save_position:
						code_lines.append("\tif _gnode.get(\"global_position\") != null:")
						code_lines.append("\t\t_ndata[\"position\"] = {\"x\": _gnode.global_position.x, \"y\": _gnode.global_position.y, \"z\": _gnode.global_position.z}")
					if save_rotation:
						code_lines.append("\tif _gnode.get(\"global_rotation\") != null:")
						code_lines.append("\t\t_ndata[\"rotation\"] = {\"x\": _gnode.global_rotation.x, \"y\": _gnode.global_rotation.y, \"z\": _gnode.global_rotation.z}")
					if save_variables:
						code_lines.append("\tif _gnode.get_script():")
						code_lines.append("\t\tvar _vars: Dictionary = {}")
						code_lines.append("\t\tfor _prop in _gnode.get_script().get_script_property_list():")
						code_lines.append("\t\t\tvar _pname = _prop[\"name\"]")
						code_lines.append("\t\t\tif _pname.begins_with(\"_\") or _pname.begins_with(\"@\"):")
						code_lines.append("\t\t\t\tcontinue")
						code_lines.append("\t\t\tvar _val = _gnode.get(_pname)")
						code_lines.append("\t\t\tif _val is int or _val is float or _val is bool or _val is String:")
						code_lines.append("\t\t\t\t_vars[_pname] = _val")
						code_lines.append("\t\t_ndata[\"variables\"] = _vars")
					code_lines.append("\t_save_data[str(_gnode.get_path())] = _ndata")
					code_lines.append("var _file = FileAccess.open(\"%s\", FileAccess.WRITE)" % resolved_path)
					code_lines.append("if _file:")
					code_lines.append("\t_file.store_string(JSON.stringify(_save_data))")
					code_lines.append("\t_file.close()")
					code_lines.append("\tprint(\"Game saved to: %s\")" % resolved_path)
					code_lines.append("else:")
					code_lines.append("\tpush_error(\"Save/Load Actuator: Failed to open save file: %s\")" % resolved_path)

				"load":
					code_lines.append("# Load game state (group: %s)" % group_name)
					code_lines.append("if FileAccess.file_exists(\"%s\"):" % resolved_path)
					code_lines.append("\tvar _file = FileAccess.open(\"%s\", FileAccess.READ)" % resolved_path)
					code_lines.append("\tif _file:")
					code_lines.append("\t\tvar _json = JSON.new()")
					code_lines.append("\t\tvar _err = _json.parse(_file.get_as_text())")
					code_lines.append("\t\t_file.close()")
					code_lines.append("\t\tif _err == OK and _json.data is Dictionary:")
					code_lines.append("\t\t\tfor _node_path in _json.data.keys():")
					code_lines.append("\t\t\t\tvar _gnode = get_node_or_null(_node_path)")
					code_lines.append("\t\t\t\tif not _gnode:")
					code_lines.append("\t\t\t\t\tpush_warning(\"Save/Load Actuator: Could not find node at path '%s'.\" % _node_path)")
					code_lines.append("\t\t\t\t\tcontinue")
					code_lines.append("\t\t\t\tvar _ndata = _json.data[_node_path]")
					if save_position:
						code_lines.append("\t\t\t\tif _ndata.has(\"position\") and _gnode.get(\"global_position\") != null:")
						code_lines.append("\t\t\t\t\tvar _pos = _ndata[\"position\"]")
						code_lines.append("\t\t\t\t\t_gnode.global_position = Vector3(_pos[\"x\"], _pos[\"y\"], _pos[\"z\"])")
					if save_rotation:
						code_lines.append("\t\t\t\tif _ndata.has(\"rotation\") and _gnode.get(\"global_rotation\") != null:")
						code_lines.append("\t\t\t\t\tvar _rot = _ndata[\"rotation\"]")
						code_lines.append("\t\t\t\t\t_gnode.global_rotation = Vector3(_rot[\"x\"], _rot[\"y\"], _rot[\"z\"])")
					if save_variables:
						code_lines.append("\t\t\t\tif _ndata.has(\"variables\"):")
						code_lines.append("\t\t\t\t\tfor _vname in _ndata[\"variables\"]:")
						code_lines.append("\t\t\t\t\t\t_gnode.set(_vname, _ndata[\"variables\"][_vname])")
					code_lines.append("\t\t\tprint(\"Game loaded from: %s\")" % resolved_path)
					code_lines.append("\t\telse:")
					code_lines.append("\t\t\tpush_error(\"Save/Load Actuator: Invalid save data: %s\")" % resolved_path)
					code_lines.append("\telse:")
					code_lines.append("\t\tpush_error(\"Save/Load Actuator: Failed to open save file: %s\")" % resolved_path)
					code_lines.append("else:")
					code_lines.append("\tpush_warning(\"Save/Load Actuator: Save file not found: %s\")" % resolved_path)

	return {
		"actuator_code": "\n".join(code_lines)
	}


## Appends save lines for a single node reference (inline helper)
func _append_node_save_lines(lines: Array, node_ref: String, pos: bool, rot: bool, vars: bool, indent: String) -> void:
	if pos:
		lines.append("%s_save_data[\"position\"] = {\"x\": %s.global_position.x, \"y\": %s.global_position.y, \"z\": %s.global_position.z}" % [indent, node_ref, node_ref, node_ref])
	if rot:
		lines.append("%s_save_data[\"rotation\"] = {\"x\": %s.global_rotation.x, \"y\": %s.global_rotation.y, \"z\": %s.global_rotation.z}" % [indent, node_ref, node_ref, node_ref])
	if vars:
		lines.append("%sif %s.get_script():" % [indent, node_ref])
		lines.append("%s\tvar _vars: Dictionary = {}" % indent)
		lines.append("%s\tfor _prop in %s.get_script().get_script_property_list():" % [indent, node_ref])
		lines.append("%s\t\tvar _name = _prop[\"name\"]" % indent)
		lines.append("%s\t\tif _name.begins_with(\"_\") or _name.begins_with(\"@\"):" % indent)
		lines.append("%s\t\t\tcontinue" % indent)
		lines.append("%s\t\tvar _val = %s.get(_name)" % [indent, node_ref])
		lines.append("%s\t\tif _val is int or _val is float or _val is bool or _val is String:" % indent)
		lines.append("%s\t\t\t_vars[_name] = _val" % indent)
		lines.append("%s\t_save_data[\"variables\"] = _vars" % indent)


## Appends load lines for a single node reference (inline helper)
func _append_node_load_lines(lines: Array, node_ref: String, pos: bool, rot: bool, vars: bool, indent: String) -> void:
	if pos:
		lines.append("%sif _json.data.has(\"position\"):" % indent)
		lines.append("%s\tvar _pos = _json.data[\"position\"]" % indent)
		lines.append("%s\t%s.global_position = Vector3(_pos[\"x\"], _pos[\"y\"], _pos[\"z\"])" % [indent, node_ref])
	if rot:
		lines.append("%sif _json.data.has(\"rotation\"):" % indent)
		lines.append("%s\tvar _rot = _json.data[\"rotation\"]" % indent)
		lines.append("%s\t%s.global_rotation = Vector3(_rot[\"x\"], _rot[\"y\"], _rot[\"z\"])" % [indent, node_ref])
	if vars:
		lines.append("%sif _json.data.has(\"variables\"):" % indent)
		lines.append("%s\tfor _vname in _json.data[\"variables\"]:" % indent)
		lines.append("%s\t\t%s.set(_vname, _json.data[\"variables\"][_vname])" % [indent, node_ref])
