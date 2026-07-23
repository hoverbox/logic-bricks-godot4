extends RefCounted

const VariableUtils = preload("res://addons/logic_bricks/core/logic_brick_variable_utils.gd")

var panel = null


func setup(target_panel) -> void:
	panel = target_panel


func add_local_variable() -> void:
	var var_data = VariableUtils.create_default_local_variable()
	panel.variables_data.append(var_data)
	refresh_local_variables_ui()
	panel._save_variables_to_metadata()


func add_global_variable() -> void:
	var var_data = VariableUtils.create_default_global_variable(panel._generate_global_var_id())
	panel.global_vars_data.append(var_data)
	refresh_global_variables_ui()
	panel._save_global_vars_to_metadata()


func refresh_local_variables_ui() -> void:
	for child in panel.variables_list.get_children():
		child.queue_free()
	for i in range(panel.variables_data.size()):
		create_local_variable_ui(i, panel.variables_data[i])


func refresh_global_variables_ui() -> void:
	if not panel.global_vars_list:
		return
	panel._ensure_global_var_ids()
	for child in panel.global_vars_list.get_children():
		child.queue_free()
	for i in range(panel.global_vars_data.size()):
		create_global_variable_ui(i, panel.global_vars_data[i])


func create_local_variable_ui(index: int, var_data: Dictionary) -> void:
	var item_panel = PanelContainer.new()
	panel.variables_list.add_child(item_panel)
	_build_variable_item_ui(item_panel, index, var_data, false)


func create_global_variable_ui(index: int, var_data: Dictionary) -> void:
	var item_panel = PanelContainer.new()
	panel.global_vars_list.add_child(item_panel)
	_build_variable_item_ui(item_panel, index, var_data, true)


func _build_variable_item_ui(item_panel: PanelContainer, index: int, var_data: Dictionary, is_global: bool) -> void:
	var vbox = VBoxContainer.new()
	item_panel.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var collapse_btn = Button.new()
	collapse_btn.text = "▼"
	collapse_btn.custom_minimum_size = Vector2(24, 0)
	if not is_global:
		collapse_btn.name = "CollapseBtn"
	header.add_child(collapse_btn)

	var name_display = Label.new()
	name_display.text = "%s: %s" % [var_data.get("name", ""), var_data.get("type", "int")]
	name_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not is_global:
		name_display.name = "NameDisplay"
	header.add_child(name_display)

	var debug_btn = Button.new()
	debug_btn.text = "🐞"
	debug_btn.toggle_mode = true
	debug_btn.button_pressed = _is_debug_watch_enabled(var_data.get("debug_watch", false))
	debug_btn.custom_minimum_size = Vector2(30, 0)
	debug_btn.tooltip_text = "Show in Runtime Debug Overlay"
	if panel and panel.has_method("_style_debug_watch_button"):
		panel._style_debug_watch_button(debug_btn, debug_btn.button_pressed)
	debug_btn.toggled.connect(_on_variable_debug_watch_toggled.bind(index, is_global))
	header.add_child(debug_btn)

	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.custom_minimum_size = Vector2(24, 0)
	delete_btn.pressed.connect(_on_delete_variable_pressed.bind(index, is_global))
	header.add_child(delete_btn)

	var details = VBoxContainer.new()
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
	name_edit.text = var_data.get("name", "")
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
	for i in range(type_names.size()):
		type_option.add_item(type_names[i], i)
	type_option.selected = _get_type_index(var_data.get("type", "int"))
	type_option.item_selected.connect(_on_variable_type_changed.bind(index, name_display, is_global))
	row2.add_child(type_option)

	_create_value_editor(details, index, var_data, is_global)

	if is_global:
		var row_use = HBoxContainer.new()
		details.add_child(row_use)
		var use_check = CheckBox.new()
		use_check.text = "Use in this script"
		use_check.button_pressed = panel._is_global_used_in_current_script(var_data)
		use_check.toggled.connect(_on_global_variable_use_in_script_toggled.bind(index))
		row_use.add_child(use_check)
	else:
		var row4 = HBoxContainer.new()
		details.add_child(row4)
		var export_check = CheckBox.new()
		export_check.text = "Export (visible in Inspector)"
		export_check.button_pressed = var_data.get("exported", false)
		export_check.toggled.connect(_on_variable_exported_changed.bind(index))
		row4.add_child(export_check)

	var is_numeric = VariableUtils.is_numeric_type(var_data.get("type", "int"))

	var row_min = HBoxContainer.new()
	if not is_global:
		row_min.name = "RowMin"
	row_min.visible = is_numeric
	details.add_child(row_min)
	var min_check = CheckBox.new()
	min_check.text = "Min"
	min_check.button_pressed = var_data.get("use_min", false)
	row_min.add_child(min_check)
	var min_edit = LineEdit.new()
	min_edit.text = var_data.get("min_val", "0")
	min_edit.custom_minimum_size = Vector2(60, 0)
	_set_limit_edit_enabled(min_edit, var_data.get("use_min", false))
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
	max_check.button_pressed = var_data.get("use_max", false)
	row_max.add_child(max_check)
	var max_edit = LineEdit.new()
	max_edit.text = var_data.get("max_val", "100")
	max_edit.custom_minimum_size = Vector2(60, 0)
	_set_limit_edit_enabled(max_edit, var_data.get("use_max", false))
	max_edit.text_changed.connect(_on_variable_max_val_changed.bind(index, is_global))
	row_max.add_child(max_edit)
	max_check.toggled.connect(_on_variable_max_toggled.bind(index, max_edit, is_global))

	var is_collapsed = var_data.get("collapsed", false)
	details.visible = not is_collapsed
	collapse_btn.text = "▶" if is_collapsed else "▼"
	collapse_btn.pressed.connect(_on_variable_collapse_toggled.bind(index, is_global, collapse_btn, details))


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
	if var_type != "Vector2" and var_type != "Vector3":
		var row = HBoxContainer.new()
		parent.add_child(row)
		var label = Label.new()
		label.text = "Value:"
		row.add_child(label)
		var edit = LineEdit.new()
		edit.text = str(var_data.get("value", VariableUtils.get_default_value_for_variable_type(var_type)))
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.text_changed.connect(_on_variable_value_changed.bind(index, is_global))
		row.add_child(edit)
		return
	var dimensions := 2 if var_type == "Vector2" else 3
	var components := _vector_components_from_value(var_data.get("value", VariableUtils.get_default_value_for_variable_type(var_type)), dimensions)
	var label = Label.new()
	label.text = "Value:"
	parent.add_child(label)
	var edits: Array[LineEdit] = []
	for axis_index in range(dimensions):
		var axis_row = HBoxContainer.new()
		parent.add_child(axis_row)
		var axis_label = Label.new()
		axis_label.text = ["X:", "Y:", "Z:"][axis_index]
		axis_label.custom_minimum_size = Vector2(24, 0)
		axis_row.add_child(axis_label)
		var edit = LineEdit.new()
		edit.text = components[axis_index]
		edit.placeholder_text = "0"
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edits.append(edit)
		axis_row.add_child(edit)
	for edit in edits:
		edit.text_changed.connect(_on_vector_axis_value_changed.bind(index, var_type, edits, is_global))


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
		panel._save_global_vars_to_metadata()
	else:
		panel._save_variables_to_metadata()


func _get_type_index(type_name: String) -> int:
	return VariableUtils.get_type_index(type_name)


func _set_limit_edit_enabled(line_edit: LineEdit, enabled: bool) -> void:
	line_edit.editable = enabled
	line_edit.modulate.a = 1.0 if enabled else 0.4


func _on_variable_name_changed(new_name: String, index: int, name_display: Label, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index >= data.size():
		return
	data[index]["name"] = new_name
	name_display.text = "%s: %s" % [new_name, data[index].get("type", "int")]
	if is_global:
		panel._save_global_vars_to_metadata()
	else:
		panel._save_variables_to_metadata()


func _on_variable_type_changed(type_index: int, index: int, name_display: Label, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	var type_names = VariableUtils.get_supported_types()
	if index >= data.size() or type_index < 0 or type_index >= type_names.size():
		return
	var new_type = type_names[type_index]
	data[index]["type"] = new_type
	data[index]["value"] = VariableUtils.coerce_variable_value_for_type(data[index].get("value", VariableUtils.get_default_value_for_variable_type(new_type)), new_type)
	name_display.text = "%s: %s" % [data[index].get("name", ""), new_type]
	if is_global:
		panel._save_global_vars_to_metadata()
		refresh_global_variables_ui()
	else:
		panel._save_variables_to_metadata()
		refresh_local_variables_ui()


func _on_variable_value_changed(new_value: String, index: int, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index >= data.size():
		return
	data[index]["value"] = new_value
	if is_global:
		panel._save_global_vars_to_metadata()
	else:
		panel._save_variables_to_metadata()


func _on_variable_exported_changed(exported: bool, index: int) -> void:
	if index >= panel.variables_data.size():
		return
	panel.variables_data[index]["exported"] = exported
	panel._save_variables_to_metadata()


func _on_global_variable_use_in_script_toggled(enabled: bool, index: int) -> void:
	panel._set_global_used_in_current_script(index, enabled)


func _on_variable_min_toggled(enabled: bool, index: int, min_edit: LineEdit, is_global: bool) -> void:
	_set_limit_edit_enabled(min_edit, enabled)
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index >= data.size():
		return
	data[index]["use_min"] = enabled
	if is_global:
		panel._save_global_vars_to_metadata()
	else:
		panel._save_variables_to_metadata()


func _on_variable_min_val_changed(new_val: String, index: int, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index >= data.size():
		return
	data[index]["min_val"] = new_val
	if is_global:
		panel._save_global_vars_to_metadata()
	else:
		panel._save_variables_to_metadata()


func _on_variable_max_toggled(enabled: bool, index: int, max_edit: LineEdit, is_global: bool) -> void:
	_set_limit_edit_enabled(max_edit, enabled)
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index >= data.size():
		return
	data[index]["use_max"] = enabled
	if is_global:
		panel._save_global_vars_to_metadata()
	else:
		panel._save_variables_to_metadata()


func _on_variable_max_val_changed(new_val: String, index: int, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index >= data.size():
		return
	data[index]["max_val"] = new_val
	if is_global:
		panel._save_global_vars_to_metadata()
	else:
		panel._save_variables_to_metadata()


func _on_variable_collapse_toggled(index: int, is_global: bool, collapse_btn: Button, details: VBoxContainer) -> void:
	details.visible = not details.visible
	collapse_btn.text = "▼" if details.visible else "▶"
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index >= data.size():
		return
	data[index]["collapsed"] = not details.visible
	if is_global:
		panel._save_global_vars_to_metadata()
	else:
		panel._save_variables_to_metadata()


func _on_delete_variable_pressed(index: int, is_global: bool) -> void:
	if is_global:
		if index >= panel.global_vars_data.size():
			return
		var removed_id = str(panel.global_vars_data[index].get("id", ""))
		panel.global_vars_data.remove_at(index)
		if panel.current_node and not removed_id.is_empty():
			var usage = panel._get_global_usage_map()
			if usage.has(removed_id):
				usage.erase(removed_id)
				panel.current_node.set_meta("logic_bricks_global_usage", usage)
		refresh_global_variables_ui()
		panel._save_global_vars_to_metadata()
		return

	if index >= panel.variables_data.size():
		return
	panel.variables_data.remove_at(index)
	refresh_local_variables_ui()
	panel._save_variables_to_metadata()


func _is_debug_watch_enabled(value: Variant) -> bool:
	if value is bool:
		return value
	if value is String:
		return value.strip_edges().to_lower() == "true"
	if value is int:
		return value == 1
	return false


func _on_variable_debug_watch_toggled(enabled: bool, index: int, is_global: bool) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	data[index]["debug_watch"] = enabled
	if is_global:
		panel._save_global_vars_to_metadata()
	else:
		panel._save_variables_to_metadata()
