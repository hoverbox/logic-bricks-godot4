extends RefCounted

const VariableUtils = preload("res://addons/logic_bricks/core/logic_brick_variable_utils.gd")
const VariableReorderItem = preload("res://addons/logic_bricks/ui/variable_reorder_item.gd")

var panel = null


func setup(target_panel) -> void:
	panel = target_panel


func add_local_variable() -> void:
	var var_data := VariableUtils.create_default_local_variable()
	var_data["collapsed"] = false
	panel.variables_data.append(var_data)
	refresh_local_variables_ui()
	save_variables_to_metadata()


func add_global_variable() -> void:
	var var_data := VariableUtils.create_default_global_variable(generate_global_var_id())
	var_data["collapsed"] = false
	panel.global_vars_data.append(var_data)
	refresh_global_variables_ui()
	save_global_vars_to_metadata()


func refresh_local_variables_ui() -> void:
	if not panel.variables_list:
		return
	for child in panel.variables_list.get_children():
		child.queue_free()
	for i in range(panel.variables_data.size()):
		create_variable_ui(i, panel.variables_data[i], false)


func refresh_global_variables_ui() -> void:
	if not panel.global_vars_list:
		return
	ensure_global_var_ids()
	for child in panel.global_vars_list.get_children():
		child.queue_free()
	for i in range(panel.global_vars_data.size()):
		create_variable_ui(i, panel.global_vars_data[i], true)


func clear_drop_indicators() -> void:
	for list in [panel.variables_list, panel.global_vars_list]:
		if list == null:
			continue
		for child in list.get_children():
			if child.has_method("clear_drop_indicator"):
				child.clear_drop_indicator()


func reorder_variable(from_index: int, target_index: int, is_global: bool) -> void:
	var data: Array = panel.global_vars_data if is_global else panel.variables_data
	if from_index < 0 or from_index >= data.size():
		return
	var moved = data.pop_at(from_index)
	if target_index > from_index:
		target_index -= 1
	target_index = clampi(target_index, 0, data.size())
	data.insert(target_index, moved)
	if is_global:
		refresh_global_variables_ui()
		save_global_vars_to_metadata()
	else:
		refresh_local_variables_ui()
		save_variables_to_metadata()


func create_variable_ui(index: int, var_data: Dictionary, is_global: bool) -> void:
	var item_panel = VariableReorderItem.new()
	item_panel.setup(panel, index, is_global, str(var_data.get("name", "Global Variable" if is_global else "Variable")))
	item_panel.tooltip_text = "Drag the header to reorder this global variable" if is_global else "Drag the header to reorder this variable"
	var list = panel.global_vars_list if is_global else panel.variables_list
	list.add_child(item_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	item_panel.add_child(vbox)

	var header = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	var collapse_btn = Button.new()
	collapse_btn.text = "▼"
	_style_variable_collapse_button(collapse_btn)
	if not is_global:
		collapse_btn.name = "CollapseBtn"
	header.add_child(collapse_btn)

	var name_display = Label.new()
	name_display.text = "%s: %s" % [var_data.get("name", ""), var_data.get("type", "int")]
	name_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_global:
		name_display.name = "NameDisplay"
	header.add_child(name_display)

	var debug_btn = Button.new()
	debug_btn.button_pressed = _is_debug_watch_enabled(var_data.get("debug_watch", false))
	panel._style_debug_watch_button(debug_btn, debug_btn.button_pressed)
	debug_btn.toggled.connect(_on_variable_debug_watch_toggled.bind(index, is_global, debug_btn))
	header.add_child(debug_btn)

	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.custom_minimum_size = Vector2(24, 0)
	delete_btn.pressed.connect(_on_delete_variable_pressed.bind(index, is_global))
	header.add_child(delete_btn)

	var details = VBoxContainer.new()
	details.add_theme_constant_override("separation", 8)
	details.name = "Details"
	vbox.add_child(details)

	var row1 = HBoxContainer.new()
	details.add_child(row1)
	var name_label = Label.new()
	name_label.text = "Name:"
	row1.add_child(name_label)
	var name_edit = LineEdit.new()
	if not is_global:
		name_edit.name = "NameEdit"
	name_edit.text = str(var_data.get("name", ""))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_variable_name_changed.bind(index, name_display, is_global))
	row1.add_child(name_edit)

	var row2 = HBoxContainer.new()
	details.add_child(row2)
	var type_label = Label.new()
	type_label.text = "Type:"
	row2.add_child(type_label)
	var type_option = OptionButton.new()
	if not is_global:
		type_option.name = "TypeOption"
	var type_names = VariableUtils.get_supported_types()
	for type_i in range(type_names.size()):
		type_option.add_item(type_names[type_i], type_i)
	type_option.selected = VariableUtils.get_type_index(str(var_data.get("type", "int")))
	type_option.item_selected.connect(_on_variable_type_changed.bind(index, name_display, is_global))
	row2.add_child(type_option)

	_create_value_editor(details, index, var_data, is_global)

	if is_global:
		var row_use = HBoxContainer.new()
		details.add_child(row_use)
		var use_check = CheckBox.new()
		use_check.text = "Use in this script"
		use_check.button_pressed = is_global_used_in_current_script(var_data)
		use_check.toggled.connect(_on_global_variable_use_in_script_toggled.bind(index))
		row_use.add_child(use_check)
	else:
		var row_export = HBoxContainer.new()
		details.add_child(row_export)
		var export_check = CheckBox.new()
		export_check.text = "Export (visible in Inspector)"
		export_check.button_pressed = bool(var_data.get("exported", false))
		export_check.toggled.connect(_on_variable_exported_changed.bind(index))
		row_export.add_child(export_check)

	var is_numeric = str(var_data.get("type", "int")) in ["int", "float"]
	var row_min = HBoxContainer.new()
	if not is_global:
		row_min.name = "RowMin"
	row_min.visible = is_numeric
	details.add_child(row_min)
	var min_check = CheckBox.new()
	min_check.text = "Min"
	min_check.button_pressed = bool(var_data.get("use_min", false))
	row_min.add_child(min_check)
	var min_edit = LineEdit.new()
	min_edit.text = str(var_data.get("min_val", "0"))
	min_edit.custom_minimum_size = Vector2(60, 0)
	_set_limit_edit_enabled(min_edit, bool(var_data.get("use_min", false)))
	min_edit.text_changed.connect(_on_variable_min_val_changed.bind(index, is_global))
	row_min.add_child(min_edit)
	min_check.toggled.connect(_on_variable_min_toggled.bind(index, min_edit, is_global))

	var row_max = HBoxContainer.new()
	if not is_global:
		row_max.name = "RowMax"
	row_max.visible = is_numeric
	details.add_child(row_max)
	var max_check = CheckBox.new()
	max_check.text = "Max"
	max_check.button_pressed = bool(var_data.get("use_max", false))
	row_max.add_child(max_check)
	var max_edit = LineEdit.new()
	max_edit.text = str(var_data.get("max_val", "100"))
	max_edit.custom_minimum_size = Vector2(60, 0)
	_set_limit_edit_enabled(max_edit, bool(var_data.get("use_max", false)))
	max_edit.text_changed.connect(_on_variable_max_val_changed.bind(index, is_global))
	row_max.add_child(max_edit)
	max_check.toggled.connect(_on_variable_max_toggled.bind(index, max_edit, is_global))

	_apply_collapsed_state(collapse_btn, details, bool(var_data.get("collapsed", false)))
	collapse_btn.pressed.connect(_on_variable_collapse_toggled.bind(index, is_global, collapse_btn, details))


func _style_variable_collapse_button(button: Button) -> void:
	button.flat = true
	button.custom_minimum_size = Vector2(18, 0)
	button.add_theme_font_size_override("font_size", 12)
	button.tooltip_text = "Expand/collapse variable"


func _apply_collapsed_state(collapse_btn: Button, details: VBoxContainer, collapsed: bool) -> void:
	details.visible = not collapsed
	collapse_btn.text = "▶" if collapsed else "▼"


func _vector_components_from_value(value, dimensions: int) -> Array[String]:
	var result: Array[String] = []
	var text := str(value).strip_edges()
	if text == "Vector2.ZERO" or text == "Vector3.ZERO" or text.is_empty():
		text = "0, 0" if dimensions == 2 else "0, 0, 0"
	elif text.begins_with("Vector2(") or text.begins_with("Vector3("):
		text = text.substr(text.find("(") + 1)
		if text.ends_with(")"):
			text = text.left(-1)
	var parts := text.split(",", false)
	for i in range(dimensions):
		var component := "0"
		if i < parts.size():
			component = str(parts[i]).strip_edges()
			if not component.is_valid_float():
				component = "0"
		result.append(component)
	return result


func _create_value_editor(parent: VBoxContainer, index: int, var_data: Dictionary, is_global: bool) -> void:
	var var_type := str(var_data.get("type", "int"))
	if var_type == "Array":
		_create_array_value_editor(parent, index, var_data, is_global)
		return
	if var_type != "Vector2" and var_type != "Vector3":
		var row = HBoxContainer.new()
		parent.add_child(row)
		var label = Label.new()
		label.text = "Value:"
		row.add_child(label)
		var edit = LineEdit.new()
		edit.text = value_to_line_edit_text(var_data.get("value", VariableUtils.get_default_value_for_variable_type(var_type)))
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(_on_variable_value_changed.bind(index, is_global))
		row.add_child(edit)
		return

	var dimensions := 2 if var_type == "Vector2" else 3
	var components := _vector_components_from_value(var_data.get("value", VariableUtils.get_default_value_for_variable_type(var_type)), dimensions)
	var value_label = Label.new()
	value_label.text = "Value:"
	parent.add_child(value_label)
	var edits: Array[LineEdit] = []
	for axis_index in range(dimensions):
		var axis_row = HBoxContainer.new()
		parent.add_child(axis_row)
		var axis_label = Label.new()
		axis_label.text = ["X:", "Y:", "Z:"][axis_index]
		axis_label.custom_minimum_size = Vector2(24, 0)
		axis_row.add_child(axis_label)
		var axis_edit = LineEdit.new()
		axis_edit.text = components[axis_index]
		axis_edit.placeholder_text = "0"
		axis_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edits.append(axis_edit)
		axis_row.add_child(axis_edit)
	for axis_edit in edits:
		axis_edit.text_changed.connect(_on_vector_axis_value_changed.bind(index, var_type, edits, is_global))


func _create_array_value_editor(parent: VBoxContainer, index: int, var_data: Dictionary, is_global: bool) -> void:
	var header := HBoxContainer.new()
	parent.add_child(header)
	var label := Label.new()
	label.text = "Items:"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var add_btn := Button.new()
	add_btn.text = "+ Add Item"
	add_btn.pressed.connect(_on_array_item_added.bind(index, is_global))
	header.add_child(add_btn)

	var items = var_data.get("value", [])
	if not (items is Array):
		items = []
	for item_index in range(items.size()):
		var item = items[item_index]
		if not (item is Dictionary):
			item = {"type":"String", "value":str(item)}
		var row := HBoxContainer.new()
		parent.add_child(row)
		var idx := Label.new()
		idx.text = "[%d]" % item_index
		idx.custom_minimum_size = Vector2(36, 0)
		row.add_child(idx)
		var type_option := OptionButton.new()
		var item_types = ["bool", "int", "float", "String", "Vector2", "Vector3"]
		for type_name in item_types:
			type_option.add_item(type_name)
		var selected := item_types.find(str(item.get("type", "String")))
		type_option.selected = selected if selected >= 0 else item_types.find("String")
		type_option.item_selected.connect(_on_array_item_type_changed.bind(index, item_index, item_types, is_global))
		row.add_child(type_option)
		var edit := LineEdit.new()
		edit.text = str(item.get("value", ""))
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(_on_array_item_value_changed.bind(index, item_index, is_global))
		row.add_child(edit)
		var remove_btn := Button.new()
		remove_btn.text = "×"
		remove_btn.tooltip_text = "Remove item at index %d" % item_index
		remove_btn.pressed.connect(_on_array_item_removed.bind(index, item_index, is_global))
		row.add_child(remove_btn)


func _on_array_item_added(index: int, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	var items = data[index].get("value", [])
	if not (items is Array):
		items = []
	items.append({"type":"String", "value":""})
	data[index]["value"] = items
	_save_array_change(is_global)
	_refresh_for_scope(is_global)


func _on_array_item_removed(index: int, item_index: int, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	var items = data[index].get("value", [])
	if not (items is Array) or item_index < 0 or item_index >= items.size():
		return
	items.remove_at(item_index)
	data[index]["value"] = items
	_save_array_change(is_global)
	_refresh_for_scope(is_global)


func _on_array_item_type_changed(type_index: int, index: int, item_index: int, item_types: Array, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size() or type_index < 0 or type_index >= item_types.size():
		return
	var items = data[index].get("value", [])
	if not (items is Array) or item_index < 0 or item_index >= items.size():
		return
	var old = items[item_index] if items[item_index] is Dictionary else {"type":"String", "value":str(items[item_index])}
	var new_type := str(item_types[type_index])
	items[item_index] = {"type":new_type, "value":VariableUtils.coerce_variable_value_for_type(old.get("value", ""), new_type)}
	data[index]["value"] = items
	_save_array_change(is_global)
	_refresh_for_scope(is_global)


func _on_array_item_value_changed(new_value: String, index: int, item_index: int, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	var items = data[index].get("value", [])
	if not (items is Array) or item_index < 0 or item_index >= items.size():
		return
	if not (items[item_index] is Dictionary):
		items[item_index] = {"type":"String", "value":""}
	items[item_index]["value"] = new_value
	data[index]["value"] = items
	_save_array_change(is_global)


func _save_array_change(is_global: bool) -> void:
	if is_global:
		save_global_vars_to_metadata()
	else:
		save_variables_to_metadata()


func _refresh_for_scope(is_global: bool) -> void:
	if is_global:
		refresh_global_variables_ui()
	else:
		refresh_local_variables_ui()


func _on_vector_axis_value_changed(_new_text: String, index: int, var_type: String, edits: Array[LineEdit], is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	var values: Array[String] = []
	for edit in edits:
		var component := edit.text.strip_edges()
		if component.is_empty() or not component.is_valid_float():
			component = "0"
		values.append(component)
	data[index]["value"] = "%s(%s)" % [var_type, ", ".join(values)]
	if is_global:
		save_global_vars_to_metadata()
	else:
		save_variables_to_metadata()


func _set_limit_edit_enabled(line_edit: LineEdit, enabled: bool) -> void:
	line_edit.editable = enabled
	line_edit.modulate.a = 1.0 if enabled else 0.4


func _on_variable_name_changed(new_name: String, index: int, name_display: Label, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	data[index]["name"] = new_name
	name_display.text = "%s: %s" % [new_name, data[index].get("type", "int")]
	if is_global:
		save_global_vars_to_metadata()
	else:
		save_variables_to_metadata()


func _on_variable_type_changed(type_index: int, index: int, name_display: Label, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	var type_names = VariableUtils.get_supported_types()
	if index < 0 or index >= data.size() or type_index < 0 or type_index >= type_names.size():
		return
	var new_type = type_names[type_index]
	data[index]["type"] = new_type
	data[index]["value"] = VariableUtils.coerce_variable_value_for_type(data[index].get("value", VariableUtils.get_default_value_for_variable_type(new_type)), new_type)
	name_display.text = "%s: %s" % [data[index].get("name", ""), new_type]
	if is_global:
		save_global_vars_to_metadata()
		refresh_global_variables_ui()
	else:
		save_variables_to_metadata()
		refresh_local_variables_ui()


func _on_variable_value_changed(new_value: String, index: int, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	data[index]["value"] = new_value
	if is_global:
		save_global_vars_to_metadata()
	else:
		save_variables_to_metadata()


func _on_variable_exported_changed(exported: bool, index: int) -> void:
	if index < 0 or index >= panel.variables_data.size():
		return
	panel.variables_data[index]["exported"] = exported
	save_variables_to_metadata()


func _on_global_variable_use_in_script_toggled(enabled: bool, index: int) -> void:
	set_global_used_in_current_script(index, enabled)


func _on_variable_min_toggled(enabled: bool, index: int, min_edit: LineEdit, is_global: bool) -> void:
	_set_limit_edit_enabled(min_edit, enabled)
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	data[index]["use_min"] = enabled
	if is_global:
		save_global_vars_to_metadata()
	else:
		save_variables_to_metadata()


func _on_variable_min_val_changed(new_val: String, index: int, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	data[index]["min_val"] = new_val
	if is_global:
		save_global_vars_to_metadata()
	else:
		save_variables_to_metadata()


func _on_variable_max_toggled(enabled: bool, index: int, max_edit: LineEdit, is_global: bool) -> void:
	_set_limit_edit_enabled(max_edit, enabled)
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	data[index]["use_max"] = enabled
	if is_global:
		save_global_vars_to_metadata()
	else:
		save_variables_to_metadata()


func _on_variable_max_val_changed(new_val: String, index: int, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	data[index]["max_val"] = new_val
	if is_global:
		save_global_vars_to_metadata()
	else:
		save_variables_to_metadata()


func _on_variable_collapse_toggled(index: int, is_global: bool, collapse_btn: Button, details: VBoxContainer) -> void:
	var collapsed := details.visible
	_apply_collapsed_state(collapse_btn, details, collapsed)
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	data[index]["collapsed"] = collapsed
	if is_global:
		save_global_vars_to_metadata()
	else:
		save_variables_to_metadata()


func _on_delete_variable_pressed(index: int, is_global: bool) -> void:
	if is_global:
		if index < 0 or index >= panel.global_vars_data.size():
			return
		var removed_id = str(panel.global_vars_data[index].get("id", ""))
		panel.global_vars_data.remove_at(index)
		if panel.current_node and not removed_id.is_empty():
			var usage = get_global_usage_map()
			if usage.has(removed_id):
				usage.erase(removed_id)
				panel.current_node.set_meta("logic_bricks_global_usage", usage)
		refresh_global_variables_ui()
		save_global_vars_to_metadata()
		return
	if index < 0 or index >= panel.variables_data.size():
		return
	panel.variables_data.remove_at(index)
	refresh_local_variables_ui()
	save_variables_to_metadata()


func _is_debug_watch_enabled(value: Variant) -> bool:
	if value is bool:
		return value
	if value is String:
		return value.strip_edges().to_lower() == "true"
	if value is int:
		return value == 1
	return false


func _on_variable_debug_watch_toggled(enabled: bool, index: int, is_global: bool, button: Button) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	data[index]["debug_watch"] = enabled
	panel._style_debug_watch_button(button, enabled)
	if is_global:
		save_global_vars_to_metadata()
	else:
		save_variables_to_metadata()

# --- Variables/Globals persistence and code generation ---

func generate_global_var_id() -> String:
	return "lb_global_%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]


func ensure_global_var_ids() -> void:
	var used_ids: Dictionary = {}
	for i in range(panel.global_vars_data.size()):
		var var_data = panel.global_vars_data[i]
		var gid = str(var_data.get("id", ""))
		if gid.is_empty() or used_ids.has(gid):
			gid = generate_global_var_id() + "_%d" % i
			panel.global_vars_data[i]["id"] = gid
		used_ids[gid] = true


func get_global_usage_map() -> Dictionary:
	if not panel.current_node or not panel.current_node.has_meta("logic_bricks_global_usage"):
		return {}
	var usage = panel.current_node.get_meta("logic_bricks_global_usage")
	return usage.duplicate(true) if usage is Dictionary else {}


func is_global_used_in_current_script(var_data: Dictionary) -> bool:
	var gid = str(var_data.get("id", ""))
	if gid.is_empty():
		return false
	return bool(get_global_usage_map().get(gid, false))


func set_global_used_in_current_script(index: int, enabled: bool) -> void:
	if not panel.current_node or index < 0 or index >= panel.global_vars_data.size():
		return
	ensure_global_var_ids()
	var gid = str(panel.global_vars_data[index].get("id", ""))
	if gid.is_empty():
		return
	var usage = get_global_usage_map()
	usage[gid] = enabled
	panel.current_node.set_meta("logic_bricks_global_usage", usage)
	panel._mark_scene_modified()


func save_variables_to_metadata(record_change: bool = true, action_name: String = "Edit Logic Brick Variable") -> void:
	if not panel.current_node:
		return
	if panel._is_part_of_instance(panel.current_node) and not panel._instance_override:
		return
	var target_node = panel.current_node
	var before_snapshot = panel._take_graph_snapshot()
	target_node.set_meta("logic_bricks_variables", panel.variables_data.duplicate(true))
	panel._mark_scene_modified()
	update_global_vars_script()
	if record_change:
		panel._record_undo(action_name, before_snapshot, panel._take_graph_snapshot(), target_node, true)


func save_global_vars_to_metadata(record_change: bool = true, action_name: String = "Edit Global Logic Brick Variable") -> void:
	if not panel.editor_interface:
		return
	ensure_global_var_ids()
	var scene_root = panel.editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	var target_node = panel.current_node
	var before_snapshot = panel._take_graph_snapshot() if target_node else {}
	scene_root.set_meta("logic_bricks_global_vars", panel.global_vars_data.duplicate(true))
	panel._mark_scene_modified()
	update_global_vars_script()
	if record_change and target_node:
		panel._record_undo(action_name, before_snapshot, panel._take_graph_snapshot(), target_node, true)


func update_global_vars_script() -> void:
	var script_path = "res://addons/logic_bricks/global_vars.gd"
	var merged: Array[Dictionary] = []
	var merged_names: Array[String] = []
	for var_data in panel.global_vars_data:
		var vname = var_data.get("name", "")
		if not vname.is_empty() and vname not in merged_names:
			merged.append(var_data.duplicate())
			merged_names.append(vname)
	for disk_var in read_global_vars_from_script():
		var vname = disk_var.get("name", "")
		if not vname.is_empty() and vname not in merged_names:
			merged.append(disk_var)
			merged_names.append(vname)

	var lines: Array[String] = [
		"extends Node", "", "## Auto-generated by Logic Bricks plugin",
		"## Global variables shared across all scenes", "## Do not edit between the markers", "",
		"# === LOGIC BRICKS GLOBALS START ==="
	]
	if merged.is_empty():
		lines.append("# (no global variables)")
	else:
		for var_data in merged:
			var var_name = var_data.get("name", "")
			var var_type = VariableUtils.normalize_type(str(var_data.get("type", "int")))
			var var_value = VariableUtils.to_gdscript_value_literal(var_data.get("value", VariableUtils.get_default_value_for_variable_type(var_type)), var_type)
			if not var_name.is_empty():
				lines.append("var %s: %s = %s" % [var_name, var_type, var_value])
	lines.append("# === LOGIC BRICKS GLOBALS END ===")
	lines.append("")

	if not panel.manager or not panel.manager.safe_write_gdscript(script_path, "\n".join(lines), "GlobalVars update"):
		return
	if panel.editor_interface:
		panel.editor_interface.get_resource_filesystem().scan()
	ensure_global_vars_autoload(script_path)


func read_global_vars_from_script() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var file = FileAccess.open("res://addons/logic_bricks/global_vars.gd", FileAccess.READ)
	if not file:
		return result
	var text = file.get_as_text()
	file.close()
	var in_block = false
	for raw_line in text.split("\n"):
		var line = raw_line.strip_edges()
		if line == "# === LOGIC BRICKS GLOBALS START ===":
			in_block = true
			continue
		if line == "# === LOGIC BRICKS GLOBALS END ===":
			break
		if not in_block or not line.begins_with("var "):
			continue
		var after_var = line.substr(4)
		var colon = after_var.find(":")
		var eq = after_var.find("=")
		if colon == -1 or eq == -1:
			continue
		var vname = after_var.substr(0, colon).strip_edges()
		var vtype = after_var.substr(colon + 1, eq - colon - 1).strip_edges()
		var vval = after_var.substr(eq + 1).strip_edges()
		if vname.is_empty():
			continue
		var normalized_type = VariableUtils.normalize_type(vtype)
		var parsed_value = VariableUtils.parse_gdscript_value_literal(vval, normalized_type)
		result.append({"name": vname, "type": normalized_type, "value": parsed_value})
	return result


func ensure_global_vars_autoload(script_path: String) -> void:
	if ProjectSettings.has_setting("autoload/GlobalVars"):
		return
	if panel.plugin:
		panel.plugin.ensure_global_vars_autoload(script_path)
	else:
		ProjectSettings.set_setting("autoload/GlobalVars", "*" + script_path)
		ProjectSettings.save()
		print("Logic Bricks: Registered GlobalVars autoload (restart editor to activate)")


func load_variables_from_metadata() -> void:
	panel.variables_data.clear()
	panel.global_vars_data.clear()
	if not panel.current_node:
		return
	if panel.current_node.has_meta("logic_bricks_variables"):
		var saved_vars = panel.current_node.get_meta("logic_bricks_variables")
		if saved_vars is Array:
			for var_data in saved_vars:
				if not var_data.get("global", false):
					panel.variables_data.append(var_data.duplicate())
	if panel.editor_interface:
		var scene_root = panel.editor_interface.get_edited_scene_root()
		if scene_root and scene_root.has_meta("logic_bricks_global_vars"):
			var saved_globals = scene_root.get_meta("logic_bricks_global_vars")
			if saved_globals is Array:
				for var_data in saved_globals:
					panel.global_vars_data.append(var_data.duplicate())
		else:
			for var_data in read_global_vars_from_script():
				panel.global_vars_data.append(var_data)
			if not panel.global_vars_data.is_empty() and scene_root:
				scene_root.set_meta("logic_bricks_global_vars", panel.global_vars_data.duplicate())
	ensure_global_var_ids()
	if panel.current_node.has_meta("logic_bricks_variables"):
		var legacy_vars = panel.current_node.get_meta("logic_bricks_variables")
		if legacy_vars is Array:
			var usage_map = get_global_usage_map()
			var usage_changed = false
			for legacy_var in legacy_vars:
				if not legacy_var.get("global", false):
					continue
				var legacy_name = str(legacy_var.get("name", ""))
				if legacy_name.is_empty():
					continue
				for global_var in panel.global_vars_data:
					if str(global_var.get("name", "")) == legacy_name:
						var gid = str(global_var.get("id", ""))
						if not gid.is_empty() and not usage_map.has(gid):
							usage_map[gid] = true
							usage_changed = true
						break
			if usage_changed:
				panel.current_node.set_meta("logic_bricks_global_usage", usage_map)
	refresh_local_variables_ui()
	refresh_global_variables_ui()


func build_export_range_str(var_type: String, use_min: bool, min_val: String, use_max: bool, max_val: String) -> String:
	var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
	var hi = max_val if use_max else ("9999999" if var_type == "int" else "9999999.0")
	return "%s, %s" % [lo, hi]


func build_clamp_expr(val_var: String, var_type: String, use_min: bool, min_val: String, use_max: bool, max_val: String) -> String:
	var fn = "clampi" if var_type == "int" else "clampf"
	var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
	var hi = max_val if use_max else ("9999999" if var_type == "int" else "9999999.0")
	return "%s(%s, %s, %s)" % [fn, val_var, lo, hi]


func value_to_line_edit_text(value) -> String:
	return VariableUtils.value_to_line_edit_text(value)


func get_variables_code() -> String:
	var lines: Array[String] = []
	var used_globals: Array[Dictionary] = []
	for var_data in panel.global_vars_data:
		if is_global_used_in_current_script(var_data):
			used_globals.append(var_data)
	if not panel.variables_data.is_empty() or not used_globals.is_empty():
		lines.append("# Variables")
	for var_data in panel.variables_data:
		var var_name = var_data.get("name", "")
		var var_type = var_data.get("type", "int")
		var var_value = VariableUtils.to_gdscript_value_literal(var_data.get("value", VariableUtils.get_default_value_for_variable_type(var_type)), var_type)
		var exported = var_data.get("exported", false)
		var use_min = var_data.get("use_min", false)
		var min_val = var_data.get("min_val", "0")
		var use_max = var_data.get("use_max", false)
		var max_val = var_data.get("max_val", "100")
		var has_range = (var_type in ["int", "float"]) and (use_min or use_max)
		if has_range and exported:
			lines.append("@export_range(%s) var %s: %s = %s" % [build_export_range_str(var_type, use_min, min_val, use_max, max_val), var_name, var_type, var_value])
		elif has_range:
			lines.append("var _%s_raw: %s = %s" % [var_name, var_type, var_value])
			lines.append("var %s: %s:" % [var_name, var_type])
			lines.append("\tget: return _%s_raw" % var_name)
			lines.append("\tset(val): _%s_raw = %s" % [var_name, build_clamp_expr("val", var_type, use_min, min_val, use_max, max_val)])
		else:
			lines.append(("@export " if exported else "") + "var %s: %s = %s" % [var_name, var_type, var_value])
	for var_data in used_globals:
		var var_name = var_data.get("name", "")
		var var_type = var_data.get("type", "int")
		var use_min = var_data.get("use_min", false)
		var min_val = var_data.get("min_val", "0")
		var use_max = var_data.get("use_max", false)
		var max_val = var_data.get("max_val", "100")
		if var_name.is_empty():
			continue
		lines.append("var %s: %s:" % [var_name, var_type])
		lines.append("\tget:")
		lines.append("\t\tvar _gv = get_node_or_null(\"/root/GlobalVars\")")
		lines.append("\t\treturn _gv.%s if _gv else null" % var_name)
		lines.append("\tset(val):")
		lines.append("\t\tvar _gv = get_node_or_null(\"/root/GlobalVars\")")
		if var_type in ["int", "float"] and (use_min or use_max):
			lines.append("\t\tif _gv: _gv.%s = %s" % [var_name, build_clamp_expr("val", var_type, use_min, min_val, use_max, max_val)])
		else:
			lines.append("\t\tif _gv: _gv.%s = val" % var_name)
	if lines.is_empty():
		return ""
	lines.append("")
	return "\n".join(lines)

