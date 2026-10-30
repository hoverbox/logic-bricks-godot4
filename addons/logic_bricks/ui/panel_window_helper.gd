@tool
extends RefCounted

## The pop-out window and the popups that must follow it (Add menu, brick
## documentation menu, search, expanded text editor), including keeping
## popups on the monitor the graph is on.

var panel = null


func setup(target_panel) -> void:
	panel = target_panel


func show_expanded_line_edit_if_needed(source: LineEdit) -> void:
	if not is_instance_valid(source) or not source.is_visible_in_tree():
		return
	# SpinBox already owns a purpose-built numeric editor; this helper is for
	# normal brick text fields that can hide longer names, paths, and expressions.
	if source.get_parent() is SpinBox:
		return
	var font := source.get_theme_font("font")
	var font_size := source.get_theme_font_size("font_size")
	var text_width := font.get_string_size(source.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font else 0.0
	if text_width <= maxf(0.0, source.size.x - 24.0):
		return
	_ensure_expanded_text_popup()
	panel._expanded_text_source = source
	panel._expanded_text_syncing = true
	panel._expanded_text_edit.text = source.text
	panel._expanded_text_syncing = false
	if source.has_meta("typing_assistance"):
		var source_data: Dictionary = source.get_meta("typing_assistance")
		if panel._expanded_typing_data.is_empty():
			panel._expanded_typing_data = panel._property_helper.typing_assistance.attach(panel._expanded_text_layout, panel._expanded_text_edit, source_data.graph, source_data.brick, source_data.definition, _on_expanded_text_changed)
		else:
			panel._expanded_typing_data.graph = source_data.graph
			panel._expanded_typing_data.brick = source_data.brick
			panel._expanded_typing_data.definition = source_data.definition
		panel._expanded_typing_data.dismissed = false
		panel._property_helper.typing_assistance.refresh(panel._expanded_typing_data)
	elif not panel._expanded_typing_data.is_empty():
		panel._expanded_typing_data.definition = {}
		panel._expanded_typing_data.warning.hide()
		panel._expanded_typing_data.choices.hide()

	var usable := _usable_screen_rect_at(source.get_screen_position())
	var desired_width := int(ceil(maxf(source.size.x + 80.0, text_width + 48.0)))
	desired_width = mini(desired_width, maxi(320, usable.size.x - 24))
	var desired_height := maxi(int(ceil(source.size.y + 12.0)), 42)
	if source.has_meta("typing_assistance"): desired_height = maxi(desired_height, 160)
	var pos := Vector2i(source.get_screen_position()) - Vector2i(6, 6)
	pos.x = clampi(pos.x, usable.position.x + 8, usable.end.x - desired_width - 8)
	pos.y = clampi(pos.y, usable.position.y + 8, usable.end.y - desired_height - 8)
	panel._expanded_text_popup.position = pos
	panel._expanded_text_popup.size = Vector2i(desired_width, desired_height)
	panel._expanded_text_popup.popup()
	panel._expanded_text_edit.grab_focus()
	panel._expanded_text_edit.call_deferred("select_all")


func _ensure_expanded_text_popup() -> void:
	if is_instance_valid(panel._expanded_text_popup):
		return
	panel._expanded_text_popup = PopupPanel.new()
	panel._expanded_text_popup.name = "ExpandedBrickTextPopup"
	_popup_host().add_child(panel._expanded_text_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel._expanded_text_popup.add_child(margin)
	panel._expanded_text_layout = VBoxContainer.new()
	margin.add_child(panel._expanded_text_layout)

	panel._expanded_text_edit = LineEdit.new()
	panel._expanded_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel._expanded_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel._expanded_text_layout.add_child(panel._expanded_text_edit)
	panel._expanded_text_edit.text_changed.connect(_on_expanded_text_changed)
	panel._expanded_text_edit.text_submitted.connect(func(_text): panel._expanded_text_popup.hide())
	panel._expanded_text_edit.focus_exited.connect(func():
		if is_instance_valid(panel._expanded_text_popup):
			panel._expanded_text_popup.call_deferred("hide")
	)
	panel._expanded_text_popup.popup_hide.connect(_on_expanded_text_popup_hidden)


func _on_expanded_text_popup_hidden() -> void:
	var source = panel._expanded_text_source
	panel._expanded_text_source = null
	if not panel._expanded_typing_data.is_empty():
		panel._expanded_typing_data.definition = {}
		panel._expanded_typing_data.choices.hide()
	if is_instance_valid(source):
		# PopupPanel may restore focus to the control that opened it after hiding.
		# Defer this so the original field ends in a fully inactive state.
		_release_expanded_text_source_focus.call_deferred(source)


func _release_expanded_text_source_focus(source: LineEdit) -> void:
	if not is_instance_valid(source):
		return
	source.deselect()
	source.release_focus()


func _on_expanded_text_changed(new_text: String) -> void:
	if panel._expanded_text_syncing or not is_instance_valid(panel._expanded_text_source):
		return
	panel._expanded_text_syncing = true
	panel._expanded_text_source.text = new_text
	panel._expanded_text_source.caret_column = new_text.length()
	panel._expanded_text_source.text_changed.emit(new_text)
	panel._expanded_text_syncing = false


func _on_popout_pressed() -> void:
	if panel._popout_window:
		_dock_window()
	else:
		_popout_window_open()


func _popout_window_open() -> void:
	# Create the floating window
	panel._popout_window = Window.new()
	panel._popout_window.title = "Logic Bricks"
	panel._popout_window.size = Vector2i(1280, 720)
	panel._popout_window.wrap_controls = true
	panel._popout_window.min_size = Vector2i(640, 400)
	panel._popout_window.close_requested.connect(_dock_window)

	# Root container inside the window (mirrors the bottom panel VBox structure)
	var win_root = VBoxContainer.new()
	win_root.add_theme_constant_override("separation", 8)
	win_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel._popout_window.add_child(win_root)

	# Move instructions label into the window root
	panel.remove_child(panel._instructions_label)
	win_root.add_child(panel._instructions_label)

	# Re-create the hsplit inside the window
	var win_hsplit = HSplitContainer.new()
	win_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win_hsplit.split_offset = panel._main_hsplit.split_offset
	win_root.add_child(win_hsplit)

	# Move the whole graph column, including its toolbar and instance controls.
	panel._main_hsplit.remove_child(panel._graph_column)
	panel._main_hsplit.remove_child(panel.side_panel)
	win_hsplit.add_child(panel._graph_column)
	win_hsplit.add_child(panel.side_panel)

	# Move toolbar separator and toolbar into the window root
	panel.remove_child(panel._toolbar_separator)
	panel.remove_child(panel._toolbar)
	win_root.add_child(panel._toolbar_separator)
	win_root.add_child(panel._toolbar)

	# Re-parent the panel's popups into the floating window so right-click
	# menus, search and text popups appear on the correct monitor (popups
	# always follow their owner window).
	_move_floating_popups(panel, panel._popout_window)

	# Hide the now-empty bottom panel hsplit
	panel._main_hsplit.visible = false

	# Update button
	panel._popout_button.text = "⬅"
	panel._popout_button.tooltip_text = "Dock back into the bottom panel"

	# Add the window to the editor
	panel.get_tree().root.add_child(panel._popout_window)
	panel._popout_window.popup_centered()


func _dock_window() -> void:
	if not panel._popout_window:
		return

	# Retrieve the window's hsplit so we can restore split_offset
	var win_root = panel._popout_window.get_child(0) if panel._popout_window.get_child_count() > 0 else null
	var win_hsplit: HSplitContainer = null
	if win_root:
		for child in win_root.get_children():
			if child is HSplitContainer:
				win_hsplit = child
				break

	# Restore split offset from window if available
	if win_hsplit:
		panel._main_hsplit.split_offset = win_hsplit.split_offset
		win_hsplit.remove_child(panel._graph_column)
		win_hsplit.remove_child(panel.side_panel)

	# Move instructions label back
	if win_root:
		win_root.remove_child(panel._instructions_label)
	panel.add_child(panel._instructions_label)
	panel.move_child(panel._instructions_label, panel.get_child_count() - 1)

	# Re-parent back into the bottom panel hsplit
	panel._main_hsplit.add_child(panel._graph_column)
	panel._main_hsplit.add_child(panel.side_panel)
	panel._main_hsplit.visible = true

	# Move toolbar separator and toolbar back
	if win_root:
		win_root.remove_child(panel._toolbar_separator)
		win_root.remove_child(panel._toolbar)
	panel.add_child(panel._toolbar_separator)
	panel.add_child(panel._toolbar)

	# Move the popups back to the main panel
	_move_floating_popups(panel._popout_window, panel)

	# Close and free the window
	panel._popout_window.close_requested.disconnect(_dock_window)
	panel._popout_window.queue_free()
	panel._popout_window = null

	# Restore button
	panel._popout_button.text = "⧉"
	panel._popout_button.tooltip_text = "Pop out into a floating window (useful for 2nd screen)"


## Popups the panel owns that must live in whichever window shows the graph.
func _floating_popups() -> Array:
	var popups: Array = []
	for popup in [panel.add_menu, panel._brick_menu_context_popup, panel._expanded_text_popup, panel._search_helper.search_popup]:
		if is_instance_valid(popup):
			popups.append(popup)
	return popups


func _move_floating_popups(from: Node, to: Node) -> void:
	for popup in _floating_popups():
		if popup.get_parent() == from:
			popup.hide()
			from.remove_child(popup)
			to.add_child(popup)


## Parent for popups created after the panel was built, so a popup made
## while popped out still opens in the floating window.
func _popup_host() -> Node:
	return panel._popout_window if is_instance_valid(panel._popout_window) else panel


## Usable rect of the monitor that contains screen_point (falls back to the
## monitor showing the graph). Used to keep popups on the user's monitor.
func _usable_screen_rect_at(screen_point: Vector2) -> Rect2i:
	for i in DisplayServer.get_screen_count():
		var rect := DisplayServer.screen_get_usable_rect(i)
		if Rect2(rect).has_point(screen_point):
			return rect
	return DisplayServer.screen_get_usable_rect(panel.graph_edit.get_window().current_screen)
