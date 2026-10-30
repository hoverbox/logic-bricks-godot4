extends RefCounted

const VariableUtils = preload("res://addons/logic_bricks/core/logic_brick_variable_utils.gd")
const VariableReorderItem = preload("res://addons/logic_bricks/ui/variable_reorder_item.gd")

const GLOBAL_VARS_PATH := "res://logic_bricks_global_vars.gd"
const LEGACY_GLOBAL_VARS_PATH := "res://addons/logic_bricks/global_vars.gd"
const GLOBAL_VARS_SETTING := "logic_bricks/global_vars"

var panel = null
var _typing_save_timer: Timer = null
var _pending_local_save := false
var _pending_global_save := false


func setup(target_panel) -> void:
	panel = target_panel


func _queue_typing_save(is_global: bool) -> void:
	if not (panel is Node) or not panel.is_inside_tree():
		if is_global:
			save_global_vars_to_metadata()
		else:
			save_variables_to_metadata()
		return
	if is_global:
		_pending_global_save = true
	else:
		_pending_local_save = true
	if not is_instance_valid(_typing_save_timer):
		_typing_save_timer = Timer.new()
		_typing_save_timer.one_shot = true
		_typing_save_timer.wait_time = 0.4
		_typing_save_timer.timeout.connect(flush_pending_typing)
		panel.add_child(_typing_save_timer)
	_typing_save_timer.start()


func flush_pending_typing() -> void:
	if is_instance_valid(_typing_save_timer):
		_typing_save_timer.stop()
	var save_local := _pending_local_save
	var save_global := _pending_global_save
	_pending_local_save = false
	_pending_global_save = false
	if save_local:
		save_variables_to_metadata()
	if save_global:
		save_global_vars_to_metadata()


func _connect_typing_commit(edit: LineEdit) -> void:
	edit.focus_exited.connect(flush_pending_typing)
	edit.text_submitted.connect(func(_text: String): flush_pending_typing())


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
	var_data["name"] = VariableUtils.normalize_name_spaces(str(var_data.get("name", "")))
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
	name_edit.text = VariableUtils.normalize_name_spaces(str(var_data.get("name", "")))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_variable_name_changed.bind(index, name_display, is_global, name_edit))
	_connect_typing_commit(name_edit)
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
	_connect_typing_commit(min_edit)
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
	_connect_typing_commit(max_edit)
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
		_connect_typing_commit(edit)
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
		_connect_typing_commit(axis_edit)


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
		_connect_typing_commit(edit)
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
	_queue_typing_save(is_global)


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
	_queue_typing_save(is_global)


func _set_limit_edit_enabled(line_edit: LineEdit, enabled: bool) -> void:
	line_edit.editable = enabled
	line_edit.modulate.a = 1.0 if enabled else 0.4


func _on_variable_name_changed(new_name: String, index: int, name_display: Label, is_global: bool, name_edit: LineEdit = null) -> void:
	var data = panel.global_vars_data if is_global else panel.variables_data
	if index < 0 or index >= data.size():
		return
	new_name = VariableUtils.normalize_name_edit(new_name, name_edit)
	data[index]["name"] = new_name
	name_display.text = "%s: %s" % [new_name, data[index].get("type", "int")]
	_queue_typing_save(is_global)


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
	_queue_typing_save(is_global)


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
	_queue_typing_save(is_global)


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
	_queue_typing_save(is_global)


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
		# A global belongs to the project, not one selected node. Remove its usage
		# flag from every node in the edited scene so stale metadata cannot bring
		# the deleted proxy back on a later Apply Code.
		if panel.editor_interface and not removed_id.is_empty():
			var scene_root = panel.editor_interface.get_edited_scene_root()
			_clear_global_usage_recursive(scene_root, removed_id)
		refresh_global_variables_ui()
		save_global_vars_to_metadata(true, "Delete Global Logic Brick Variable")
		return
	if index < 0 or index >= panel.variables_data.size():
		return
	panel.variables_data.remove_at(index)
	refresh_local_variables_ui()
	save_variables_to_metadata()


func _clear_global_usage_recursive(node: Node, global_id: String) -> void:
	if node == null or global_id.is_empty():
		return
	if node.has_meta("logic_bricks_global_usage"):
		var usage = node.get_meta("logic_bricks_global_usage")
		if usage is Dictionary and usage.has(global_id):
			var updated = usage.duplicate(true)
			updated.erase(global_id)
			node.set_meta("logic_bricks_global_usage", updated)
	for child in node.get_children():
		_clear_global_usage_recursive(child, global_id)


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
	_pending_local_save = false
	if not panel.current_node:
		return
	if panel._is_part_of_instance(panel.current_node) and not panel._instance_override:
		return
	var target_node = panel.current_node
	var before_snapshot = panel._take_graph_snapshot()
	target_node.set_meta("logic_bricks_variables", panel.variables_data.duplicate(true))
	panel._refresh_variable_brick_context_ui()
	panel._mark_scene_modified()
	update_global_vars_script()
	if record_change:
		panel._record_undo(action_name, before_snapshot, panel._take_graph_snapshot(), target_node, true)


func save_global_vars_to_metadata(record_change: bool = true, action_name: String = "Edit Global Logic Brick Variable") -> void:
	_pending_global_save = false
	if not panel.editor_interface:
		return
	ensure_global_var_ids()
	var scene_root = panel.editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	var target_node = panel.current_node
	var before_snapshot = panel._take_graph_snapshot() if target_node else {}
	var project_globals = panel.global_vars_data.duplicate(true)
	# Store the canonical definitions in project.godot. This survives addon
	# replacement and is shared by every scene. Keep scene metadata as a
	# compatibility mirror for older versions of Logic Bricks.
	ProjectSettings.set_setting(GLOBAL_VARS_SETTING, project_globals)
	ProjectSettings.save()
	scene_root.set_meta("logic_bricks_global_vars", project_globals)
	panel._refresh_variable_brick_context_ui()
	panel._mark_scene_modified()
	update_global_vars_script()
	if record_change and target_node:
		panel._record_undo(action_name, before_snapshot, panel._take_graph_snapshot(), target_node, true)


func update_global_vars_script() -> void:
	var script_path = GLOBAL_VARS_PATH
	# The in-memory project list is authoritative. Do not merge old declarations
	# back in from disk: that made a deleted global impossible to delete.
	var merged: Array[Dictionary] = []
	var merged_names: Array[String] = []
	for var_data in panel.global_vars_data:
		var vname = VariableUtils.normalize_name_spaces(str(var_data.get("name", "")))
		if not vname.is_empty() and vname not in merged_names:
			var definition: Dictionary = var_data.duplicate(true)
			definition["name"] = vname
			merged.append(definition)
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
			var var_name = VariableUtils.normalize_name_spaces(str(var_data.get("name", "")))
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
	var read_path := GLOBAL_VARS_PATH
	if not FileAccess.file_exists(read_path) and FileAccess.file_exists(LEGACY_GLOBAL_VARS_PATH):
		read_path = LEGACY_GLOBAL_VARS_PATH
	var file = FileAccess.open(read_path, FileAccess.READ)
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
				if var_data is Dictionary and not var_data.get("global", false):
					panel.variables_data.append(var_data.duplicate(true))
	if panel.editor_interface:
		var scene_root = panel.editor_interface.get_edited_scene_root()
		var loaded_project_globals := false
		if ProjectSettings.has_setting(GLOBAL_VARS_SETTING):
			var saved_project_globals = ProjectSettings.get_setting(GLOBAL_VARS_SETTING, [])
			if saved_project_globals is Array:
				for var_data in saved_project_globals:
					if var_data is Dictionary:
						panel.global_vars_data.append(var_data.duplicate(true))
				loaded_project_globals = true
		if not loaded_project_globals:
			# Migration path for projects created before globals became project-wide.
			if scene_root and scene_root.has_meta("logic_bricks_global_vars"):
				var saved_globals = scene_root.get_meta("logic_bricks_global_vars")
				if saved_globals is Array:
					for var_data in saved_globals:
						if var_data is Dictionary:
							_merge_legacy_global_definition(var_data)

			# Very old projects stored globals in each node's logic_bricks_variables
			# array with global=true. Recover those definitions from the whole scene.
			# This only runs before the project-wide setting exists, so intentionally
			# deleted globals cannot be resurrected later by stale node metadata.
			if panel.global_vars_data.is_empty() and scene_root:
				_recover_legacy_globals_recursive(scene_root)

			# Final fallback: recover declarations from either the new project file or
			# the old addon-local global_vars.gd if it still exists.
			if panel.global_vars_data.is_empty():
				for var_data in read_global_vars_from_script():
					_merge_legacy_global_definition(var_data)
	ensure_global_var_ids()
	if panel.editor_interface and not ProjectSettings.has_setting(GLOBAL_VARS_SETTING):
		# Persist migrated globals immediately so subsequent scenes use the same list.
		ProjectSettings.set_setting(GLOBAL_VARS_SETTING, panel.global_vars_data.duplicate(true))
		ProjectSettings.save()
		update_global_vars_script()
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


func _merge_legacy_global_definition(var_data: Dictionary) -> void:
	var legacy_name := str(var_data.get("name", "")).strip_edges()
	if legacy_name.is_empty():
		return
	for existing in panel.global_vars_data:
		if str(existing.get("name", "")) == legacy_name:
			return
	var migrated := var_data.duplicate(true)
	migrated["global"] = true
	panel.global_vars_data.append(migrated)


func _recover_legacy_globals_recursive(node: Node) -> void:
	if node == null:
		return
	if node.has_meta("logic_bricks_variables"):
		var saved_vars = node.get_meta("logic_bricks_variables")
		if saved_vars is Array:
			for var_data in saved_vars:
				if var_data is Dictionary and bool(var_data.get("global", false)):
					_merge_legacy_global_definition(var_data)
	for child in node.get_children():
		_recover_legacy_globals_recursive(child)


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
		var var_name = VariableUtils.normalize_name_spaces(str(var_data.get("name", "")))
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
		var var_name = VariableUtils.normalize_name_spaces(str(var_data.get("name", "")))
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
		var fallback_value = VariableUtils.to_gdscript_value_literal(VariableUtils.get_default_value_for_variable_type(var_type), var_type)
		lines.append("\t\treturn _gv.get(\"%s\") if _gv and \"%s\" in _gv else %s" % [var_name, var_name, fallback_value])
		lines.append("\tset(val):")
		lines.append("\t\tvar _gv = get_node_or_null(\"/root/GlobalVars\")")
		if var_type in ["int", "float"] and (use_min or use_max):
			lines.append("\t\tif _gv and \"%s\" in _gv: _gv.set(\"%s\", %s)" % [var_name, var_name, build_clamp_expr("val", var_type, use_min, min_val, use_max, max_val)])
		else:
			lines.append("\t\tif _gv and \"%s\" in _gv: _gv.set(\"%s\", val)" % [var_name, var_name])
	if lines.is_empty():
		return ""
	lines.append("")
	return "\n".join(lines)

