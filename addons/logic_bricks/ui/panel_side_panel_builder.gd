@tool
extends RefCounted

## Builds the side panel (Variables, Globals, Frames, States, Customize tabs),
## its tab buttons and collapse behaviour.

const FrameReorderList = preload("res://addons/logic_bricks/ui/frame_reorder_list.gd")

var panel = null


func setup(target_panel) -> void:
	panel = target_panel


func _create_side_panel() -> void:
	# Outer container — replaces the old TabContainer
	panel.side_panel = PanelContainer.new()
	panel.side_panel.custom_minimum_size = Vector2.ZERO
	panel.side_panel.size_flags_horizontal = Control.SIZE_FILL
	panel.side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.side_panel.visible = false  # Hidden until node selected

	# Horizontal split: Blender-like icon rail | content column
	panel._side_hbox = HBoxContainer.new()
	panel._side_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel._side_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.side_panel.add_child(panel._side_hbox)

	# Left nav column
	panel._side_nav_panel = PanelContainer.new()
	panel._side_nav_panel.custom_minimum_size = Vector2.ZERO
	panel._side_nav_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel._side_hbox.add_child(panel._side_nav_panel)

	panel._side_nav = VBoxContainer.new()
	panel._side_nav.add_theme_constant_override("separation", 8)
	panel._side_nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel._side_nav.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel._side_nav_panel.add_child(panel._side_nav)

	panel._collapse_button = Button.new()
	panel._collapse_button.flat = true
	panel._collapse_button.focus_mode = Control.FOCUS_NONE
	panel._collapse_button.custom_minimum_size = Vector2(32, 32)
	panel._collapse_button.tooltip_text = "Collapse to icon rail"
	panel._collapse_button.expand_icon = false
	panel._collapse_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel._collapse_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	panel._collapse_button.text = "<"
	panel._collapse_button.pressed.connect(_toggle_side_panel_collapsed)
	panel._side_nav.add_child(panel._collapse_button)

	# Right content stack (inside a scroll container so the split can get very thin)
	panel._side_content_scroll = ScrollContainer.new()
	panel._side_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel._side_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel._side_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel._side_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	panel._side_hbox.add_child(panel._side_content_scroll)

	panel._side_stack = VBoxContainer.new()
	panel._side_stack.add_theme_constant_override("separation", 8)
	panel._side_stack.custom_minimum_size = Vector2.ZERO
	panel._side_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel._side_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel._side_content_scroll.add_child(panel._side_stack)

	# Build the content panels
	_create_variables_tab()
	_create_global_variables_tab()
	_create_frames_tab()
	panel._create_states_tab()
	panel._create_customize_tab()

	panel._side_stack.add_child(panel.variables_panel)
	panel._side_stack.add_child(panel.global_vars_panel)
	panel._side_stack.add_child(panel.states_panel)
	panel._side_stack.add_child(panel.frames_panel)
	panel._side_stack.add_child(panel.customize_panel)

	# Build nav buttons (one per panel)
	var tab_defs = [
		{"tooltip": "Variables", "icon": "LocalVariable", "fallback": "V"},
		{"tooltip": "Globals", "icon": "WorldEnvironment", "fallback": "G"},
		{"tooltip": "States", "icon": "StateMachine", "fallback": "S"},
		{"tooltip": "Frames", "icon": "KeyEasedSelected", "fallback": "F"},
	]
	for i in range(tab_defs.size()):
		var btn = Button.new()
		btn.flat = false
		btn.toggle_mode = false
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size = Vector2(32, 32)
		btn.tooltip_text = str(tab_defs[i]["tooltip"])
		btn.text = str(tab_defs[i]["fallback"])
		btn.expand_icon = false
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.theme_type_variation = "FlatButton"
		btn.set_meta("icon_name", str(tab_defs[i]["icon"]))
		btn.set_meta("fallback_text", str(tab_defs[i]["fallback"]))
		var idx = i  # capture for closure
		btn.pressed.connect(func(): _on_side_tab_pressed(idx))
		panel._side_nav.add_child(btn)
		panel._nav_buttons.append(btn)

	# Keep editor customization at the bottom of the rail.
	var nav_spacer = Control.new()
	nav_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel._side_nav.add_child(nav_spacer)

	var customize_btn = Button.new()
	customize_btn.flat = false
	customize_btn.toggle_mode = false
	customize_btn.focus_mode = Control.FOCUS_NONE
	customize_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	customize_btn.custom_minimum_size = Vector2(32, 32)
	customize_btn.tooltip_text = "Customize Editor"
	customize_btn.text = "C"
	customize_btn.expand_icon = false
	customize_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	customize_btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	customize_btn.theme_type_variation = "FlatButton"
	customize_btn.set_meta("icon_name", "Color")
	customize_btn.set_meta("fallback_text", "C")
	customize_btn.pressed.connect(func(): _on_side_tab_pressed(4))
	panel._side_nav.add_child(customize_btn)
	panel._nav_buttons.append(customize_btn)

	_apply_side_tab_icons()
	_update_collapse_button_icon()

	# Show first tab by default
	_select_side_tab(0)


func _on_side_tab_pressed(index: int) -> void:
	if panel._side_collapsed:
		_set_side_panel_collapsed(false)
	_select_side_tab(index)


func _select_side_tab(index: int) -> void:
	panel._active_tab_index = index
	for i in range(panel._side_stack.get_child_count()):
		panel._side_stack.get_child(i).visible = (i == index)
	# Update button highlight
	for i in range(panel._nav_buttons.size()):
		var btn = panel._nav_buttons[i]
		if i == index:
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			var active_sb = _make_active_nav_stylebox()
			btn.add_theme_stylebox_override("normal", active_sb)
			btn.add_theme_stylebox_override("hover", active_sb)
			btn.add_theme_stylebox_override("pressed", active_sb)
			btn.add_theme_stylebox_override("focus", active_sb)
		else:
			btn.remove_theme_color_override("font_color")
			var inactive_sb = _make_inactive_nav_stylebox()
			btn.add_theme_stylebox_override("normal", inactive_sb)
			btn.add_theme_stylebox_override("hover", inactive_sb)
			btn.add_theme_stylebox_override("pressed", inactive_sb)
			btn.add_theme_stylebox_override("focus", inactive_sb)


func _toggle_side_panel_collapsed() -> void:
	_set_side_panel_collapsed(not panel._side_collapsed)


func _set_side_panel_collapsed(collapsed: bool) -> void:
	if panel._side_collapsed == collapsed:
		return
	if collapsed:
		panel._expanded_side_width = maxi(panel._expanded_side_width, int(panel.side_panel.size.x))
	panel._side_collapsed = collapsed
	if panel._side_content_scroll:
		panel._side_content_scroll.visible = not collapsed
	_update_collapse_button_icon()
	_apply_side_collapse_split.call_deferred()


func _apply_side_collapse_split() -> void:
	if not panel.side_panel or not panel._side_nav_panel:
		return
	var active_hsplit: HSplitContainer = panel.side_panel.get_parent() as HSplitContainer
	if not active_hsplit:
		return
	if panel._side_collapsed:
		# The nav panel stretches to fill the old sidebar width once the content is hidden,
		# so its live size is not a valid collapse target. Keep the icon rail fixed.
		var rail_width := 40
		active_hsplit.split_offset = -rail_width
	else:
		var target_width := maxi(panel._expanded_side_width, 140)
		active_hsplit.split_offset = -target_width


func _update_collapse_button_icon() -> void:
	if not panel._collapse_button:
		return
	var icon_name := "Forward" if panel._side_collapsed else "Back"
	var fallback := ">" if panel._side_collapsed else "<"
	var icon = null
	if panel.has_theme_icon(icon_name, "EditorIcons"):
		icon = panel.get_theme_icon(icon_name, "EditorIcons")
	panel._collapse_button.icon = icon
	panel._collapse_button.text = "" if icon != null else fallback
	panel._collapse_button.tooltip_text = "Expand panel" if panel._side_collapsed else "Collapse to icon rail"


func _make_active_nav_stylebox() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.45, 0.75, 0.85)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


func _make_inactive_nav_stylebox() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	return sb


func _apply_side_tab_icons() -> void:
	if panel._nav_buttons.is_empty():
		return
	for btn in panel._nav_buttons:
		if not is_instance_valid(btn):
			continue
		var icon_name = str(btn.get_meta("icon_name", ""))
		var fallback_text = str(btn.get_meta("fallback_text", ""))
		var icon = null
		if panel.has_theme_icon(icon_name, "EditorIcons"):
			icon = panel.get_theme_icon(icon_name, "EditorIcons")
		btn.icon = icon
		btn.text = "" if icon != null else fallback_text


func _apply_side_panel_visibility() -> void:
	if not panel.side_panel:
		return
	panel.side_panel.visible = panel.graph_edit.visible
	if panel.graph_edit.visible:
		_apply_side_collapse_split.call_deferred()


func _create_variables_tab() -> void:
	# Create the variables management tab
	panel.variables_panel = VBoxContainer.new()
	panel.variables_panel.add_theme_constant_override("separation", 8)
	panel.variables_panel.name = "Variables"
	panel.variables_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add Variable button doubles as the tab header so it stays visible in narrow panels.
	var add_var_button = Button.new()
	add_var_button.text = "+ Add Variable"
	add_var_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_var_button.pressed.connect(panel._on_add_variable_pressed)
	panel.variables_panel.add_child(add_var_button)

	var sep = HSeparator.new()
	panel.variables_panel.add_child(sep)

	# Scrollable list of local variables
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.variables_panel.add_child(scroll)

	panel.variables_list = VBoxContainer.new()
	panel.variables_list.add_theme_constant_override("separation", 8)
	panel.variables_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel.variables_list)


func _create_global_variables_tab() -> void:
	# Create the global variables management tab (scene-wide, stored on scene root)
	panel.global_vars_panel = VBoxContainer.new()
	panel.global_vars_panel.add_theme_constant_override("separation", 8)
	panel.global_vars_panel.name = "Globals"
	panel.global_vars_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add Global Variable button doubles as the tab header so it stays visible in narrow panels.
	var add_global_button = Button.new()
	add_global_button.text = "+ Add Global Variable"
	add_global_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_global_button.pressed.connect(panel._on_add_global_variable_pressed)
	panel.global_vars_panel.add_child(add_global_button)

	var sep = HSeparator.new()
	panel.global_vars_panel.add_child(sep)

	var hint = Label.new()
	hint.text = "Shared across all nodes and all scenes (via GlobalVars autoload)"
	hint.clip_text = true
	hint.custom_minimum_size = Vector2(0, 0)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_size_override("font_size", 10)
	panel.global_vars_panel.add_child(hint)

	var global_scroll = ScrollContainer.new()
	global_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.global_vars_panel.add_child(global_scroll)

	panel.global_vars_list = VBoxContainer.new()
	panel.global_vars_list.add_theme_constant_override("separation", 8)
	panel.global_vars_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	global_scroll.add_child(panel.global_vars_list)


func _create_frames_tab() -> void:
	# Create the frames management tab
	panel.frames_panel = VBoxContainer.new()
	panel.frames_panel.add_theme_constant_override("separation", 8)
	panel.frames_panel.name = "Frames"
	panel.frames_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Header
	var header = HBoxContainer.new()
	panel.frames_panel.add_child(header)

	var title = Label.new()
	title.text = "Frames"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font = title.get_theme_font("bold", "EditorFonts")
	if title_font:
		title.add_theme_font_override("font", title_font)
	header.add_child(title)

	var sort_frames_button = Button.new()
	sort_frames_button.text = "A/Z"
	sort_frames_button.tooltip_text = "Sort frames alphabetically"
	sort_frames_button.custom_minimum_size = Vector2(44, 0)
	sort_frames_button.pressed.connect(panel._on_sort_frames_pressed)
	header.add_child(sort_frames_button)

	# Separator
	var sep1 = HSeparator.new()
	panel.frames_panel.add_child(sep1)

	# Frame list with controls
	var list_container = HBoxContainer.new()
	panel.frames_panel.add_child(list_container)

	# Frame list
	panel.frames_list = FrameReorderList.new()
	panel.frames_list.setup(panel)
	panel.frames_list.custom_minimum_size = Vector2(0, 150)
	panel.frames_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.frames_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.frames_list.tooltip_text = "Double-click a frame to center and fit it in the graph."
	panel.frames_list.item_selected.connect(panel._on_frame_list_item_selected)
	panel.frames_list.item_activated.connect(panel._on_frame_list_item_activated)  # Double-click to navigate to frame
	list_container.add_child(panel.frames_list)

	# Separator
	var sep2 = HSeparator.new()
	panel.frames_panel.add_child(sep2)

	# Frame settings (shown when a frame is selected)
	panel.frame_settings_container = VBoxContainer.new()
	panel.frame_settings_container.add_theme_constant_override("separation", 8)
	panel.frame_settings_container.name = "FrameSettings"
	panel.frame_settings_container.visible = false
	panel.frames_panel.add_child(panel.frame_settings_container)

	var settings_label = Label.new()
	settings_label.text = "Frame Settings:"
	var settings_font = settings_label.get_theme_font("bold", "EditorFonts")
	if settings_font:
		settings_label.add_theme_font_override("font", settings_font)
	panel.frame_settings_container.add_child(settings_label)

	# Frame name field
	var name_label = Label.new()
	name_label.text = "Name:"
	panel.frame_settings_container.add_child(name_label)

	var name_edit = LineEdit.new()
	name_edit.name = "FrameNameEdit"
	name_edit.placeholder_text = "Enter frame name..."
	name_edit.text_changed.connect(panel._on_frame_name_changed)
	panel.frame_settings_container.add_child(name_edit)

	# Optional frame comment / description
	var comment_label = Label.new()
	comment_label.text = "Comment:"
	panel.frame_settings_container.add_child(comment_label)

	var comment_edit = TextEdit.new()
	comment_edit.name = "FrameCommentEdit"
	comment_edit.placeholder_text = "Describe what this frame does..."
	comment_edit.custom_minimum_size = Vector2(0, 90)
	comment_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comment_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	comment_edit.text_changed.connect(panel._on_frame_comment_changed)
	panel.frame_settings_container.add_child(comment_edit)

	# Frame color picker
	var color_label = Label.new()
	color_label.text = "Color:"
	panel.frame_settings_container.add_child(color_label)

	var color_picker = ColorPickerButton.new()
	color_picker.name = "FrameColorPicker"
	color_picker.edit_alpha = true
	color_picker.custom_minimum_size = Vector2(96, 40)
	color_picker.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	color_picker.tooltip_text = "Current frame color. Click to choose a different color."

	# Give the color swatch a clear control outline so it cannot be mistaken
	# for a separator in the frame settings panel.
	var swatch_style = StyleBoxFlat.new()
	swatch_style.bg_color = Color(0, 0, 0, 0)
	swatch_style.border_width_left = 2
	swatch_style.border_width_top = 2
	swatch_style.border_width_right = 2
	swatch_style.border_width_bottom = 2
	swatch_style.border_color = panel.get_theme_color("contrast_color_2", "Editor")
	swatch_style.corner_radius_top_left = 4
	swatch_style.corner_radius_top_right = 4
	swatch_style.corner_radius_bottom_left = 4
	swatch_style.corner_radius_bottom_right = 4
	color_picker.add_theme_stylebox_override("normal", swatch_style)

	var swatch_hover_style = swatch_style.duplicate()
	swatch_hover_style.border_color = panel.get_theme_color("accent_color", "Editor")
	color_picker.add_theme_stylebox_override("hover", swatch_hover_style)
	color_picker.add_theme_stylebox_override("pressed", swatch_hover_style)

	color_picker.color_changed.connect(panel._on_frame_color_changed)
	panel.frame_settings_container.add_child(color_picker)

	# Manual size controls
	var size_label = Label.new()
	size_label.text = "Frame Size:"
	panel.frame_settings_container.add_child(size_label)

	var size_hbox = HBoxContainer.new()
	panel.frame_settings_container.add_child(size_hbox)

	var width_label = Label.new()
	width_label.text = "W:"
	size_hbox.add_child(width_label)

	var width_spin = SpinBox.new()
	width_spin.name = "FrameWidthSpin"
	width_spin.min_value = 100
	width_spin.max_value = 2000
	width_spin.step = 10
	width_spin.value_changed.connect(panel._on_frame_width_changed)
	size_hbox.add_child(width_spin)

	var height_label = Label.new()
	height_label.text = "H:"
	size_hbox.add_child(height_label)

	var height_spin = SpinBox.new()
	height_spin.name = "FrameHeightSpin"
	height_spin.min_value = 100
	height_spin.max_value = 2000
	height_spin.step = 10
	height_spin.value_changed.connect(panel._on_frame_height_changed)
	size_hbox.add_child(height_spin)

	# Auto-resize button
	var resize_button = Button.new()
	resize_button.text = "Auto-Resize to Fit Nodes"
	resize_button.pressed.connect(panel._on_frame_resize_pressed)
	panel.frame_settings_container.add_child(resize_button)

	# Delete frame button
	var delete_button = Button.new()
	delete_button.text = "Delete Frame"
	delete_button.modulate = Color(1, 0.5, 0.5)
	delete_button.pressed.connect(panel._on_frame_delete_pressed)
	panel.frame_settings_container.add_child(delete_button)


func _style_debug_watch_button(button: Button, active: bool) -> void:
	button.text = "🐞"
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(34, 28)
	button.tooltip_text = "Show in Runtime Debug Overlay"
	var normal := StyleBoxFlat.new()
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	if active:
		normal.bg_color = Color(1.0, 0.72, 0.12, 1.0)
		normal.border_color = Color(1.0, 0.9, 0.35, 1.0)
		button.add_theme_color_override("font_color", Color(0.08, 0.06, 0.0, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.08, 0.06, 0.0, 1.0))
	else:
		normal.bg_color = Color(0.18, 0.18, 0.18, 1.0)
		normal.border_color = Color(0.36, 0.36, 0.36, 1.0)
		button.add_theme_color_override("font_color", Color(0.62, 0.62, 0.62, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.62, 0.62, 0.62, 1.0))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("hover_pressed", normal)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_stylebox_override("disabled", normal)
	var icon_color := Color(0.08, 0.06, 0.0, 1.0) if active else Color(0.62, 0.62, 0.62, 1.0)
	button.add_theme_color_override("font_hover_color", icon_color)
	button.add_theme_color_override("font_hover_pressed_color", icon_color)
	button.add_theme_color_override("font_focus_color", icon_color)
