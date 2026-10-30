@tool
extends RefCounted

# Editor-only assistance. Never change stored text until a student chooses a name.
var panel = null
var properties_ui = null
const VariableUtils = preload("res://addons/logic_bricks/core/logic_brick_variable_utils.gd")

# Only fields whose generators accept expressions; literal indices/text stay literal.
const NUMERIC_FIELDS = {
	"motion_actuator": ["x", "y", "z"], "motion_2d_actuator": ["x", "y"],
	"position_actuator": ["x", "y", "z"], "position_2d_actuator": ["x", "y"],
	"rotation_xyz_actuator": ["x", "y", "z"], "rotation_2d_actuator": ["degrees"],
	"scale_tween_actuator": ["x", "y", "z"], "scale_2d_actuator": ["x", "y"],
	"gravity_actuator": ["gravity_strength", "direction_x", "direction_y", "direction_z"],
	"gravity_2d_actuator": ["strength", "direction_x", "direction_y"],
	"linear_velocity_actuator": ["velocity_x", "velocity_y", "velocity_z", "max_speed"], "linear_velocity_2d_actuator": ["x", "y"],
	"impulse_actuator": ["x", "y", "z", "pos_x", "pos_y", "pos_z"], "impulse_2d_actuator": ["x", "y"],
	"force_actuator": ["x", "y", "z", "max_force"], "force_2d_actuator": ["x", "y", "point_x", "point_y"],
	"torque_actuator": ["x", "y", "z", "max_torque"],
	"camera_zoom_actuator": ["fov", "zoom", "transition_speed"], "camera_zoom_2d_actuator": ["zoom", "transition_speed"],
	"waypoint_path_actuator": ["speed", "arrival_distance"], "waypoint_path_2d_actuator": ["speed", "arrival_distance"],
	"move_towards_actuator": ["arrival_distance", "slowing_distance", "desired_distance", "distance_tolerance", "orbit_distance", "wander_amount", "wander_frequency", "velocity", "acceleration", "turn_speed"],
	"move_towards_2d_actuator": ["coordinate_x", "coordinate_y", "speed", "arrival_distance", "slowing_distance", "desired_distance", "distance_tolerance", "orbit_distance", "wander_amount", "wander_frequency"],
	"jump_actuator": ["jump_height", "gravity_strength", "max_jumps"], "jump_2d_actuator": ["jump_height", "gravity_strength", "max_jumps"],
	"progress_bar_actuator": ["value", "min_value", "max_value", "transition_speed"], "progress_bar_2d_actuator": ["value", "min_value", "max_value", "transition_speed"],
	"object_flash_actuator": ["speed"], "object_flash_2d_actuator": ["speed"],
	"object_shake_actuator": ["x", "y", "z"], "object_shake_2d_actuator": ["x", "y", "rotation_degrees"],
	"character_actuator": ["gravity_strength", "max_fall_speed", "floor_snap_length", "slope_limit", "acceleration", "friction", "bounce"],
	"character_2d_actuator": ["gravity_strength", "max_fall_speed", "floor_snap_length", "slope_limit", "acceleration", "friction", "bounce"],
	"mouse_actuator": ["mouse_velocity", "mouse_acceleration", "mouse_turn_speed", "mouse_arrival_distance"],
	"mouse_2d_actuator": ["mouse_velocity", "mouse_acceleration", "mouse_turn_speed", "mouse_arrival_distance"],
	"screen_shake_actuator": ["trauma", "max_offset", "decay", "noise_speed"], "screen_shake_2d_actuator": ["intensity", "duration", "rotation_intensity"],
	"soft_body_point_force_actuator": ["point_index", "x", "y", "z", "max_force"], "soft_body_point_impulse_actuator": ["point_index", "x", "y", "z"],
	"tween_actuator": ["duration"], "screen_flash_actuator": ["duration", "fade_in"], "hit_stop_actuator": ["duration", "time_scale"],
	"modulate_actuator": ["transition_speed"], "slider_actuator": ["value"], "scroll_actuator": ["x", "y"], "tab_actuator": ["tab_index"],
	"sprite_frames_actuator": ["speed_scale"], "sprite_animation_2d_actuator": ["speed_scale"],
	"rotate_towards_2d_actuator": ["speed", "angle_offset"], "animation_actuator": ["speed"],
	"delay_sensor": ["delay", "duration"], "object_pool_actuator": ["spawn_amount"], "music_actuator": ["set_track", "to_track"],
	"edit_object_actuator": ["velocity_x", "velocity_y", "velocity_z"], "variable_actuator": ["index"],
	"tween_animation_2d_actuator": ["duration"], "split_screen_actuator": ["player_count"]
}

func setup(owner_panel, property_helper) -> void:
	panel = owner_panel
	properties_ui = property_helper


func decorate(control: Control, graph: GraphNode, brick, definition: Dictionary) -> Control:
	if int(definition.get("type", TYPE_NIL)) not in [TYPE_STRING, TYPE_INT, TYPE_FLOAT] or int(definition.get("hint", PROPERTY_HINT_NONE)) in [PROPERTY_HINT_ENUM, PROPERTY_HINT_FILE]:
		return control
	var edit := control.find_child("PropertyControl_" + str(definition["name"]), true, false) as LineEdit
	if edit == null or not edit.editable:
		return control
	# Literal text has no assistance UI; modes that can switch context are retained.
	var file := str(brick.get_script().resource_path.get_file().get_basename())
	if context(brick, definition).is_empty() and not (file == "variable_actuator" and str(definition.get("name", "")) == "value"):
		return control
	var wrapper := VBoxContainer.new()
	if control.has_meta("group_picker_if"): wrapper.set_meta("group_picker_if", control.get_meta("group_picker_if"))
	wrapper.add_child(control)
	attach(wrapper, edit, graph, brick, definition)
	return wrapper


func attach(wrapper: VBoxContainer, edit: LineEdit, graph: GraphNode, brick, definition: Dictionary, commit: Callable = Callable()) -> Dictionary:
	var warning := RichTextLabel.new()
	warning.bbcode_enabled = false
	warning.fit_content = true
	warning.scroll_active = false
	warning.custom_minimum_size.x = 240
	warning.add_theme_color_override("default_color", Color(1.0, 0.75, 0.25))
	warning.hide()
	wrapper.add_child(warning)
	var choices := VBoxContainer.new()
	choices.hide()
	wrapper.add_child(choices)
	var data := {"wrapper": wrapper, "edit": edit, "graph": graph, "brick": brick, "definition": definition, "warning": warning, "choices": choices, "message": "", "suggestion": "", "original": "", "dismissed": false, "commit": commit}
	wrapper.set_meta("typing_assistance", data)
	edit.set_meta("typing_assistance", data)
	edit.text_changed.connect(func(_text):
		data.dismissed = false
		refresh(data)
	)
	edit.focus_entered.connect(func():
		data.dismissed = false
		refresh(data)
	)
	edit.focus_exited.connect(func():
		choices.call_deferred("hide")
		call_deferred("refresh", data)
	)
	edit.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			data.dismissed = true
			choices.hide()
			edit.accept_event()
	)
	warning.meta_clicked.connect(func(_meta):
		if not str(data.suggestion).is_empty():
			choose(data, str(data.suggestion), str(data.original))
	)
	refresh(data)
	return data


func context(brick, definition: Dictionary) -> Dictionary:
	var name := str(definition.get("name", ""))
	var file := str(brick.get_script().resource_path.get_file().get_basename())
	var props: Dictionary = brick.get_properties()
	if name in ["target_node_name", "camera_node_name"] and normalize(props.get("node_name_source", "literal")) == "string_variable":
		return {"kind": "variable", "types": ["String"]}
	if bool(definition.get("group_picker", false)) and properties_ui._group_picker_condition_matches(brick, definition.get("group_picker_if", {})):
		return {"kind": "group", "multi": bool(definition.get("group_picker_multi", false)), "new": file == "group_actuator" and normalize(props.get("mode", "add")) in ["add", "change"]}
	if properties_ui._is_node_reference_property(definition, name):
		return {"kind": "node"}
	if bool(definition.get("input_action_picker", false)):
		return {"kind": "input action"}
	if name == "signal_name" and file in ["message_sensor", "message_actuator"]:
		return {"kind": "signal", "new": true}
	if bool(definition.get("variable_picker", false)) or name in ["variable_name", "source_variable", "target_variable", "store_in", "store_as", "store_pressed"]:
		var types: Array = []
		if name == "target_variable":
			types = ["Vector2"] if file.contains("2d") else ["Vector3"]
		elif name == "source_variable":
			var target_type: String = properties_ui._logic_variable_type(str(props.get("variable_name", "")))
			if not target_type.is_empty(): types = [target_type]
		elif name == "store_pressed": types = ["bool"]
		elif name == "store_in" and file == "input_map_sensor": types = ["int", "float"]
		return {"kind": "variable", "types": types, "new": name == "store_as", "logic_only": file in ["text_actuator", "text_2d_actuator"] and name == "variable_name"}
	if name == "audio_bus": return {"kind": "audio bus"}
	if name == "animation_name": return {"kind": "animation"}
	if name == "actuator_name": return {"kind": "action brick"}
	if name == "move_actions": return {"kind": "input action", "multi": true}
	if name in ["parameter_path", "state_machine_path"] and file in ["animation_tree_actuator", "animation_tree_sensor"]:
		return {"kind": "animation parameter", "playback": name == "state_machine_path"}
	if name == "condition_name" and file == "animation_tree_sensor": return {"kind": "animation condition"}
	if name == "state_name" and file in ["animation_tree_actuator", "animation_tree_sensor"]: return {"kind": "animation state"}
	if file in ["tween_actuator", "tween_animation_2d_actuator"] and name == "property": return {"kind": "node property"}
	if file == "property_actuator" and name == "value":
		var target = properties_ui._resolve_property_actuator_target(brick)
		var type_id: int = brick._property_type(target, str(props.get("property_name", "")))
		var type_name: String = VariableUtils.gdscript_type_name_from_variant_type(type_id)
		return {"kind": "expression", "types": [type_name] if not type_name.is_empty() else [], "literal": type_id in [TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH], "locals_only": true}
	if file in ["variable_actuator", "variable_sensor"] and name in ["value", "min_value", "max_value"]:
		var target_type: String = properties_ui._logic_variable_type(str(props.get("variable_name", "")))
		var mode := normalize(props.get("mode", "assign"))
		if file == "variable_actuator" and mode in ["replace", "prepend", "append", "add_item", "remove_item", "set_item_at_index"]:
			return {} # These operations generate literals, even when text resembles a variable.
		if file == "variable_sensor" and target_type == "Array" and normalize(props.get("evaluation_type", "")) in ["contains", "does_not_contain"]:
			return {}
		return {"kind": "expression", "types": [target_type] if not target_type.is_empty() else [], "literal": target_type == "String"}
	if definition.has("typing_expression_types"):
		return {"kind": "expression", "types": definition["typing_expression_types"]}
	if int(definition.get("type", TYPE_NIL)) in [TYPE_INT, TYPE_FLOAT] and int(definition.get("hint", PROPERTY_HINT_NONE)) != PROPERTY_HINT_ENUM:
		return {"kind": "expression", "types": ["int", "float"]}
	if NUMERIC_FIELDS.get(file, []).has(name) or (file == "environment_actuator" and str(definition.get("default", "")).is_valid_float()):
		return {"kind": "expression", "types": ["int", "float"]}
	if file in ["tween_actuator", "tween_animation_2d_actuator"] and name == "target_value":
		return {"kind": "expression", "types": []}
	return {}


static func normalize(value) -> String:
	return str(value).to_lower().replace(" ", "_")


func candidates(brick, definition: Dictionary, info: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var name := str(definition.get("name", ""))
	var kind := str(info.get("kind", ""))
	if kind in ["variable", "expression"]:
		var local: Array = panel.variables_data
		var global: Array = [] if info.get("locals_only", false) else panel.global_vars_data
		var source: Node = panel.current_node
		if brick.get_script().resource_path.ends_with("get_variable_actuator.gd") and name == "variable_name":
			match normalize(brick.get_property("source", "node_name")):
				"globalvars": local = []; source = null
				"self": global = []
				"node_name":
					source = resolve_node(str(brick.get_property("source_node_name", "")))
					local = source.get_meta("logic_bricks_variables", []) if source else []
					global = []
		for entry in local:
			add_variable(result, entry, "Local", info.get("types", []))
		for entry in global:
			add_variable(result, entry, "Global", info.get("types", []))
		if not info.get("locals_only", false) and not info.get("logic_only", false) and source:
			var script = source.get_script()
			if script:
				for entry in script.get_script_property_list():
					var type_name: String = VariableUtils.gdscript_type_name_from_variant_type(int(entry.get("type", TYPE_NIL)))
					if not type_name.is_empty(): add_variable(result, {"name": entry.name, "type": type_name}, "Script", info.get("types", []))
			if brick.get_script().resource_path.ends_with("get_variable_actuator.gd") and name == "variable_name":
				for entry in source.get_property_list():
					var type_name: String = VariableUtils.gdscript_type_name_from_variant_type(int(entry.get("type", TYPE_NIL)))
					if not type_name.is_empty(): add_variable(result, {"name": entry.name, "type": type_name}, "Property", info.get("types", []))
		if source == panel.current_node and not info.get("locals_only", false) and not info.get("logic_only", false):
			for graph in panel.graph_edit.get_children():
				if graph.has_meta("brick_data"):
					var other = graph.get_meta("brick_data").get("brick_instance")
					if other and other.get_script().resource_path.ends_with("get_variable_actuator.gd"):
						add_variable(result, {"name": other.get_property("store_as", ""), "type": ""}, "Get Variable", info.get("types", []))
	elif kind == "node":
		var accepted: Array = accepted_node_types(brick, definition)
		var root: Node = panel.current_node
		if name != "area_node_name" and str(definition.get("node_picker_scope", "scene")) == "scene": root = scene_root()
		var nodes: Array[Node] = properties_ui._compatible_direct_child_nodes(root, accepted) if name == "area_node_name" else properties_ui._compatible_child_nodes(root, accepted)
		if name != "area_node_name" and root != panel.current_node and properties_ui._node_matches_types(root, accepted): nodes.push_front(root)
		for child in nodes:
			var value := str(child.name)
			if str(definition.get("node_reference_store", "name")) == "path": value = str(panel.current_node.get_path_to(child))
			result.append({"value": value, "label": "%s (%s)" % [str(panel.current_node.get_path_to(child)), child.get_class()], "aliases": [str(panel.current_node.get_path_to(child))]})
	elif kind == "input action":
		var custom: Array[String] = properties_ui._get_project_input_actions()
		for value in custom + properties_ui._get_builtin_input_actions(custom): add_name(result, value)
	elif kind == "group":
		for value in properties_ui._collect_project_group_names(): add_name(result, value)
	elif kind == "signal":
		collect_signals(scene_root(), brick, result)
	elif kind == "audio bus":
		for index in AudioServer.bus_count: add_name(result, AudioServer.get_bus_name(index))
	elif kind == "animation":
		var target := resolve_node(str(brick.get_property("target_node", "")))
		if target is AnimatedSprite2D or target is AnimatedSprite3D:
			if target.sprite_frames:
				for value in target.sprite_frames.get_animation_names(): add_name(result, value)
	elif kind == "action brick":
		for graph in panel.graph_edit.get_children():
			if graph.has_meta("brick_data"):
				var data: Dictionary = graph.get_meta("brick_data")
				if str(data.get("brick_type", "")) == "actuator": add_name(result, data.brick_instance.get_instance_name())
	elif kind == "animation parameter":
		var target := resolve_node(str(brick.get_property("animation_tree_name", brick.get_property("animation_tree_node_name", ""))))
		if target is AnimationTree:
			for entry in target.get_property_list():
				var value := str(entry.name)
				if value.begins_with("parameters/") and (not info.get("playback", false) or value.ends_with("/playback")): add_name(result, value)
	elif kind in ["animation condition", "animation state"]:
		var target := resolve_node(str(brick.get_property("animation_tree_name", brick.get_property("animation_tree_node_name", ""))))
		if target is AnimationTree:
			if kind == "animation condition":
				for entry in target.get_property_list():
					var value := str(entry.name)
					if value.begins_with("parameters/conditions/"): add_name(result, value.trim_prefix("parameters/conditions/"))
			else:
				var playback := str(brick.get_property("state_machine_path", ""))
				if playback.is_empty():
					for entry in target.get_property_list():
						if str(entry.name).ends_with("/playback"):
							playback = str(entry.name)
							break
				var machine: Resource = target.tree_root
				var resource_path := playback.trim_prefix("parameters/").trim_suffix("/playback")
				if resource_path != "playback":
					for part in resource_path.split("/", false):
						machine = machine.call("get_node", StringName(part)) if machine and machine.has_method("get_node") else null
				if machine is AnimationNodeStateMachine:
					if machine.has_method("get_node_list"):
						for value in machine.call("get_node_list"): add_name(result, str(value))
					else:
						# Godot 4.3 exposes state resources through stored properties.
						for entry in machine.get_property_list():
							var value := str(entry.name)
							if value.begins_with("states/") and value.ends_with("/node"): add_name(result, value.get_slice("/", 1))
	elif kind == "node property":
		var target: Node = resolve_node(str(brick.get_property("target_node_name", ""))) if normalize(brick.get_property("target_mode", "self")) == "node" else panel.current_node
		if target:
			for entry in target.get_property_list():
				if int(entry.get("usage", 0)) & PROPERTY_USAGE_EDITOR: add_name(result, str(entry.name))
	if kind in ["variable", "expression"]:
		var compatible: Array[Dictionary] = []
		for entry in result:
			if bool(entry.get("compatible", true)): compatible.append(entry)
		return compatible
	return result


func accepted_node_types(brick, definition: Dictionary) -> Array:
	var accepted: Array = properties_ui._accepted_node_types(definition, str(definition.name))
	if not accepted.is_empty(): return accepted
	var file := str(brick.get_script().resource_path.get_file().get_basename())
	if str(definition.name) == "target_node_name":
		if file in ["text_actuator", "text_2d_actuator"]: return ["Label", "Label3D", "RichTextLabel", "LineEdit", "TextEdit", "Button"]
		if file in ["progress_bar_actuator", "progress_bar_2d_actuator", "slider_actuator"]: return ["Range"]
		if file == "light_actuator": return ["Light3D"]
		if file == "focus_actuator": return ["Control"]
		if file in ["button_actuator", "button_sensor"]: return ["BaseButton"]
		if file == "tab_actuator": return ["TabContainer"]
		if file == "scroll_actuator": return ["ScrollContainer"]
		if file in ["popup_actuator", "window_actuator"]: return ["Window", "Control"]
		if file == "visibility_actuator": return ["Node3D", "CanvasItem"]
		if file.contains("2d") and not file.begins_with("text"): return ["Node2D"]
		if file in ["motion_actuator", "position_actuator", "rotation_xyz_actuator", "scale_tween_actuator", "look_at_input_actuator", "look_at_movement_actuator"]: return ["Node3D"]
	return accepted


func scene_root() -> Node:
	return panel.editor_interface.get_edited_scene_root() if panel.editor_interface else panel.current_node


func resolve_node(value: String) -> Node:
	if not panel.current_node: return null
	if value.is_empty() or normalize(value) in ["self", "."]: return panel.current_node
	var found: Node = panel.current_node.get_node_or_null(NodePath(value))
	if found: return found
	var root := scene_root()
	if root:
		if str(root.name) == value: return root
		return root.find_child(value, true, false)
	return null


func collect_signals(node: Node, current_brick, result: Array[Dictionary]) -> void:
	if not node: return
	var receiving: bool = current_brick.brick_type == 0
	var wanted := "MessageActuator" if receiving else "MessageSensor"
	var entries: Array = node.get_meta("logic_bricks_graph", {}).get("nodes", [])
	if node == panel.current_node:
		entries = []
		for graph in panel.graph_edit.get_children():
			if graph.has_meta("brick_data"):
				var data: Dictionary = graph.get_meta("brick_data")
				if data.get("brick_instance") == current_brick: continue
				entries.append({"brick_class": data.get("brick_class", ""), "properties": data.brick_instance.get_properties()})
	for entry in entries:
		if str(entry.get("brick_class", "")) == wanted:
			var _props: Dictionary = entry.get("properties", {})
			add_name(result, str(_props.get("signal_name", _props.get("subject", ""))))
	for child in node.get_children(): collect_signals(child, current_brick, result)


static func add_name(result: Array[Dictionary], value: String) -> void:
	if value.is_empty(): return
	for entry in result:
		if str(entry.value) == value: return
	result.append({"value": value, "label": value})


static func add_variable(result: Array[Dictionary], entry: Dictionary, scope: String, types: Array) -> void:
	var name := str(entry.get("name", ""))
	var type_name := str(entry.get("type", ""))
	if name.is_empty(): return
	for existing in result:
		if str(existing.value) == name: return
	var compatible := types.is_empty() or types.has(type_name) or (type_name in ["int", "float"] and (types.has("int") or types.has("float")))
	result.append({"value": name, "compatible": compatible, "label": "%s (%s%s)" % [name, scope, ", " + type_name if not type_name.is_empty() else ""]})


# Small, bounded Damerau-Levenshtein comparison catches adjacent transpositions.
static func distance(a: String, b: String) -> int:
	if a.length() > 80 or b.length() > 80: return 99
	var rows: Array = []
	for i in range(a.length() + 1):
		var row: Array[int] = []
		for j in range(b.length() + 1): row.append(j if i == 0 else (i if j == 0 else 0))
		rows.append(row)
	for i in range(1, a.length() + 1):
		for j in range(1, b.length() + 1):
			rows[i][j] = mini(mini(rows[i - 1][j] + 1, rows[i][j - 1] + 1), rows[i - 1][j - 1] + (0 if a[i - 1] == b[j - 1] else 1))
			if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]: rows[i][j] = mini(rows[i][j], rows[i - 2][j - 2] + 1)
	return rows[a.length()][b.length()]


static func closest(value: String, options: Array[Dictionary]) -> Dictionary:
	for option in options:
		if value == str(option.value) or option.get("aliases", []).has(value): return {}
	for option in options:
		if value.to_lower() == str(option.value).to_lower(): return {"value": option.value, "case": true}
		for alias in option.get("aliases", []):
			if value.to_lower() == str(alias).to_lower(): return {"value": option.value, "case": true}
	if value.length() < 3: return {}
	var best := 99
	var winner := ""
	var ambiguous := false
	for option in options:
		var candidate := str(option.value)
		if absi(value.length() - candidate.length()) > 2: continue
		var score := distance(value.to_lower(), candidate.to_lower())
		if score < best: best = score; winner = candidate; ambiguous = false
		elif score == best and winner != candidate: ambiguous = true
	var limit := 1 if value.length() < 7 else 2
	return {"value": winner, "case": false} if best <= limit and not ambiguous else {}


static func identifier_at_caret(text: String, caret: int) -> Dictionary:
	var start := clampi(caret, 0, text.length())
	var end := start
	while start > 0 and identifier_character(text[start - 1]): start -= 1
	while end < text.length() and identifier_character(text[end]): end += 1
	return {"start": start, "end": end, "value": text.substr(start, end - start)}


static func identifier_character(ch: String) -> bool:
	return ch == "_" or (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9")


static func expression_tokens(text: String) -> Array[String]:
	var result: Array[String] = []
	for span in expression_spans(text):
		if not result.has(str(span.value)): result.append(str(span.value))
	return result


static func expression_spans(text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var regex := RegEx.new()
	regex.compile("\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|[A-Za-z_][A-Za-z_0-9]*")
	for found in regex.search_all(text):
		var token: String = found.get_string()
		if token.begins_with("\"") or token.begins_with("'"): continue
		var start: int = found.get_start()
		var end: int = found.get_end()
		if start > 0 and (text[start - 1] == "." or identifier_character(text[start - 1])): continue
		if end < text.length() and text[end] == "(": continue
		if token in ["true", "false", "null", "self", "PI", "TAU", "INF", "NAN", "Vector2", "Vector3", "Color", "GlobalVars", "and", "or", "not"]: continue
		result.append({"value": token, "start": start, "end": end})
	return result


func refresh(data: Dictionary) -> void:
	var edit: LineEdit = data.edit
	if not is_instance_valid(edit) or not is_instance_valid(data.graph): return
	var info := context(data.brick, data.definition)
	var options := candidates(data.brick, data.definition, info)
	var kind := str(info.get("kind", ""))
	var text := edit.text.strip_edges()
	var tokens: Array[String] = []
	if kind == "expression":
		tokens.append_array(expression_tokens(text))
	else:
		tokens.append(text)
	if info.get("multi", false):
		tokens.clear()
		for part in text.split(",", false): tokens.append(part.strip_edges())
	data.message = ""; data.suggestion = ""; data.original = ""
	for token in tokens:
		if token.is_empty() or kind.is_empty(): continue
		if info.get("literal", false): continue
		if kind == "node" and normalize(token) in ["self", "."]: continue
		if kind == "node" and str(data.definition.name) != "area_node_name" and resolve_node(token): continue
		if kind == "signal" and normalize(data.brick.get_property("match_mode", "exact")) != "exact":
			var matched := false
			for option in options:
				if (normalize(data.brick.get_property("match_mode")) == "contains" and str(option.value).contains(token)) or str(option.value).begins_with(token): matched = true
			if matched: continue
		var match_info := closest(token, options)
		if not match_info.is_empty():
			data.original = token; data.suggestion = str(match_info.value)
			data.message = "You typed '%s', but the %s is named '%s'. Capitalization must match." % [token, kind, data.suggestion] if match_info["case"] else "Possible typo: '%s'. Did you mean '%s'?" % [token, data.suggestion]
			break
		if kind in ["node", "variable", "input action", "animation", "audio bus", "animation parameter", "animation condition", "animation state"] and not info.get("new", false):
			var exact := false
			for option in options:
				if token == str(option.value) or option.get("aliases", []).has(token): exact = true
				if edit.has_focus() and str(option.value).to_lower().begins_with(token.to_lower()): exact = true
			if not exact:
				data.message = "'%s' wasn't found among the available %s names." % [token, kind]
				break
	var warning: RichTextLabel = data.warning
	warning.clear()
	if not str(data.message).is_empty():
		warning.add_text("⚠ " + str(data.message))
		if not str(data.suggestion).is_empty():
			warning.add_text(" ")
			warning.push_meta("correct")
			warning.add_text("Use " + str(data.suggestion))
			warning.pop()
	warning.visible = not str(data.message).is_empty()
	var choices: VBoxContainer = data.choices
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	var query := identifier_at_caret(edit.text, edit.caret_column) if kind == "expression" else {"value": text}
	if info.get("multi", false): query = {"value": text.get_slice(",", text.get_slice_count(",") - 1).strip_edges()}
	var needle := str(query.value)
	var ranked: Array[Dictionary] = []
	if not needle.is_empty():
		for option in options:
			var value := str(option.value)
			if value == needle: continue
			var rank := 99
			if value.to_lower().begins_with(needle.to_lower()): rank = 0
			elif str(option.label).to_lower().contains(needle.to_lower()): rank = 1
			elif needle.length() >= 3 and distance(needle.to_lower(), value.to_lower()) <= (1 if needle.length() < 7 else 2): rank = 2
			if rank < 99: ranked.append({"option": option, "rank": rank})
	ranked.sort_custom(func(a, b): return a.rank < b.rank if a.rank != b.rank else str(a.option.label).naturalnocasecmp_to(str(b.option.label)) < 0)
	for index in mini(8, ranked.size()):
		var option: Dictionary = ranked[index].option
		var button := Button.new()
		button.text = str(option.label)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = str(option.label) + "\nInsert exact spelling and capitalization"
		button.pressed.connect(choose.bind(data, str(option.value), needle))
		choices.add_child(button)
	choices.visible = choices.get_child_count() > 0 and edit.has_focus() and not data.dismissed
	data.graph.reset_size()


func choose(data: Dictionary, value: String, original: String) -> void:
	var edit: LineEdit = data.edit
	if not is_instance_valid(edit) or not is_instance_valid(data.graph): return
	var info := context(data.brick, data.definition)
	var new_text := value
	if str(info.get("kind", "")) == "expression":
		# Fix only the matching identifier; preserve arithmetic and quoted text.
		var selected: Dictionary = {}
		for span in expression_spans(edit.text):
			if str(span.value) == original:
				if selected.is_empty(): selected = span
				if edit.caret_column >= int(span.start) and edit.caret_column <= int(span.end):
					selected = span
					break
		if not selected.is_empty(): new_text = edit.text.substr(0, int(selected.start)) + value + edit.text.substr(int(selected.end))
	elif info.get("multi", false):
		var parts := edit.text.split(",", false)
		for index in parts.size():
			if parts[index].strip_edges() == original: parts[index] = value
		new_text = ", ".join(parts)
	edit.text = new_text
	edit.caret_column = new_text.length()
	if data.commit.is_valid(): data.commit.call(new_text)
	else: properties_ui._on_property_changed(new_text, data.graph, str(data.definition.name))
	data.dismissed = true
	refresh(data)
	# Selection must not trigger select-all/expanded-editor focus callbacks again.
	# Buttons do not take focus, so typing can continue without a focus jump.


func refresh_graph(graph: GraphNode) -> void:
	if not is_instance_valid(graph): return
	for data in fields_in(graph): refresh(data)


func fields_in(node: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if node is VBoxContainer and node.has_meta("typing_assistance"): result.append(node.get_meta("typing_assistance"))
	for child in node.get_children(): result.append_array(fields_in(child))
	return result


func warnings_for(graph: GraphNode) -> Array[String]:
	var messages: Array[String] = []
	refresh_graph(graph)
	for data in fields_in(graph):
		if field_active(data) and not str(data.message).is_empty(): messages.append(properties_ui._format_property_name(str(data.definition.name)) + ": " + str(data.message))
	return messages


func field_active(data: Dictionary) -> bool:
	var node: Node = data.wrapper
	while node != null and node != data.graph:
		if node is Control and not node.visible and str(node.name) != "GroupBody": return false
		node = node.get_parent()
	return true
