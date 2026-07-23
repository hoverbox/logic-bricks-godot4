extends CanvasLayer
## Runtime-only Logic Bricks watch overlay.
## This script inspects watched node metadata and script properties. It does not
## require debug statements to be added to generated gameplay scripts.

const SCAN_INTERVAL := 0.5
const UPDATE_INTERVAL := 0.1
const TOGGLE_KEY := KEY_F8

var _panel: PanelContainer
var _label: Label
var _nodes: Array[Node] = []
var _scan_elapsed := 0.0
var _update_elapsed := 0.0
var _overlay_visible := true


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	layer = 1000
	_build_overlay()
	_scan_nodes()
	_refresh_text()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == TOGGLE_KEY:
		_overlay_visible = not _overlay_visible
		if is_instance_valid(_panel):
			_panel.visible = _overlay_visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_scan_elapsed += delta
	_update_elapsed += delta
	if _scan_elapsed >= SCAN_INTERVAL:
		_scan_elapsed = 0.0
		_scan_nodes()
	if _update_elapsed >= UPDATE_INTERVAL:
		_update_elapsed = 0.0
		_refresh_text()


func _build_overlay() -> void:
	_panel = PanelContainer.new()
	_panel.name = "LogicBricksDebugOverlay"
	_panel.position = Vector2(12, 12)
	_panel.custom_minimum_size = Vector2(300, 0)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)

	var title := Label.new()
	title.text = "🐞 Logic Bricks Debugger"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	_label = Label.new()
	_label.text = "No watched variables or states."
	_label.add_theme_font_size_override("font_size", 15)
	box.add_child(_label)


func _scan_nodes() -> void:
	_nodes.clear()
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	_collect_watched_nodes(tree.current_scene)


func _collect_watched_nodes(node: Node) -> void:
	if _node_has_watches(node):
		_nodes.append(node)
	for child in node.get_children():
		_collect_watched_nodes(child)


func _node_has_watches(node: Node) -> bool:
	if node.has_meta("logic_bricks_variables"):
		var vars = node.get_meta("logic_bricks_variables")
		if vars is Array:
			for data in vars:
				if data is Dictionary and _is_watch_enabled(data.get("debug_watch", false)):
					return true
	if _is_watch_enabled(node.get_meta("logic_bricks_debug_watch_state", false)):
		return true
	# Global watches are stored on the current scene root.
	if node == get_tree().current_scene and node.has_meta("logic_bricks_global_vars"):
		var globals = node.get_meta("logic_bricks_global_vars")
		if globals is Array:
			for data in globals:
				if data is Dictionary and _is_watch_enabled(data.get("debug_watch", false)):
					return true
	return false


func _refresh_text() -> void:
	if not is_instance_valid(_label):
		return
	var sections: Array[String] = []
	for node in _nodes:
		if not is_instance_valid(node):
			continue
		var lines: Array[String] = []
		_append_state_watch(node, lines)
		_append_variable_watches(node, lines)
		if node == get_tree().current_scene:
			_append_global_watches(node, lines)
		if not lines.is_empty():
			sections.append("[ %s ]\n%s" % [str(node.name), "\n".join(lines)])
	var has_watches := not sections.is_empty()
	_label.text = "No watched variables or states." if not has_watches else "\n\n".join(sections)
	if is_instance_valid(_panel):
		_panel.visible = _overlay_visible and has_watches


func _append_variable_watches(node: Node, lines: Array[String]) -> void:
	if not node.has_meta("logic_bricks_variables"):
		return
	var vars = node.get_meta("logic_bricks_variables")
	if not (vars is Array):
		return
	var property_names := _get_property_names(node)
	for data in vars:
		if not (data is Dictionary) or not _is_watch_enabled(data.get("debug_watch", false)):
			continue
		var variable_name := str(data.get("name", ""))
		if variable_name.is_empty():
			continue
		if property_names.has(variable_name):
			lines.append("%s: %s" % [variable_name, _format_value(node.get(variable_name))])
		else:
			lines.append("%s: <not found; apply code>" % variable_name)


func _append_global_watches(scene_root: Node, lines: Array[String]) -> void:
	if not scene_root.has_meta("logic_bricks_global_vars"):
		return
	var global_node := get_node_or_null("/root/GlobalVars")
	var globals = scene_root.get_meta("logic_bricks_global_vars")
	if not (globals is Array):
		return
	var property_names := _get_property_names(global_node) if global_node else {}
	for data in globals:
		if not (data is Dictionary) or not _is_watch_enabled(data.get("debug_watch", false)):
			continue
		var variable_name := str(data.get("name", ""))
		if variable_name.is_empty():
			continue
		if global_node and property_names.has(variable_name):
			lines.append("Global %s: %s" % [variable_name, _format_value(global_node.get(variable_name))])
		else:
			lines.append("Global %s: <not found>" % variable_name)


func _append_state_watch(node: Node, lines: Array[String]) -> void:
	if not node.has_meta("logic_bricks_states"):
		return
	var states = node.get_meta("logic_bricks_states")
	if not (states is Array):
		return
	if not _is_watch_enabled(node.get_meta("logic_bricks_debug_watch_state", false)):
		return
	var names_by_id := {}
	for data in states:
		if not (data is Dictionary):
			continue
		names_by_id[str(data.get("id", ""))] = str(data.get("name", data.get("id", "")))
	var state_id := ""
	if node.has_method("_logic_brick_get_state_signature"):
		state_id = str(node.call("_logic_brick_get_state_signature"))
	else:
		var property_names := _get_property_names(node)
		if not property_names.has("_logic_brick_state"):
			lines.append("State: <not found; apply code>")
			return
		state_id = str(node.get("_logic_brick_state"))
	lines.append("State: %s" % str(names_by_id.get(state_id, state_id if not state_id.is_empty() else "None")))


func _get_property_names(object: Object) -> Dictionary:
	var result := {}
	if object == null:
		return result
	for property_data in object.get_property_list():
		result[str(property_data.get("name", ""))] = true
	return result


func _is_watch_enabled(value: Variant) -> bool:
	# Be deliberately strict. Older metadata or text serialization may contain
	# the strings "true"/"false"; bool("false") evaluates to true in GDScript.
	# Only an actual true value (or an explicitly true string for migration)
	# should enable a runtime watch.
	if value is bool:
		return value
	if value is String:
		return value.strip_edges().to_lower() == "true"
	if value is int:
		return value == 1
	return false


func _format_value(value) -> String:
	if value is float:
		return "%.3f" % value
	return str(value)
