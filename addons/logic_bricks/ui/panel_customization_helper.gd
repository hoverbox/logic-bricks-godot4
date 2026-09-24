extends RefCounted

const DEFAULT_BRICK_SENSOR_COLOR := Color("038AA8")
const DEFAULT_BRICK_CONTROLLER_COLOR := Color("6703A1")
const DEFAULT_BRICK_ACTUATOR_COLOR := Color("B80449")
const DEFAULT_BRICK_HEADER_TEXT_COLOR := Color("FFFFFF")
const DEFAULT_BRICK_BODY_COLOR := Color("202020")
const DEFAULT_GRAPH_BACKGROUND_COLOR := Color("111111")
const EDITOR_COLOR_SETTING_PREFIX := "logic_bricks/editor_colors/"
const EDITOR_SIZE_SETTING_PREFIX := "logic_bricks/editor_sizes/"
const DEFAULT_MENU_SIZE_SCALE := 1.0
const DEFAULT_BRICK_SIZE_SCALE := 1.0

var panel = null

func setup(target_panel) -> void:
	panel = target_panel

func create_customize_tab() -> void:
	panel.customize_panel = VBoxContainer.new()
	panel.customize_panel.add_theme_constant_override("separation", 8)
	panel.customize_panel.name = "Customize"
	panel.customize_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var title = Label.new()
	title.text = "Customize Editor"
	var title_font = title.get_theme_font("bold", "EditorFonts")
	if title_font:
		title.add_theme_font_override("font", title_font)
	panel.customize_panel.add_child(title)

	var hint = Label.new()
	hint.text = "Colors and display sizes are saved for this editor user."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	hint.add_theme_font_size_override("font_size", 10)
	panel.customize_panel.add_child(hint)

	panel.customize_panel.add_child(HSeparator.new())
	_add_color_row("Trigger Header", "sensor_header", panel._brick_sensor_color)
	_add_color_row("Gate Header", "controller_header", panel._brick_controller_color)
	_add_color_row("Action Header", "actuator_header", panel._brick_actuator_color)
	_add_color_row("Header Text", "header_text", panel._brick_header_text_color)
	_add_color_row("Brick Body", "brick_body", panel._brick_body_color)
	_add_color_row("Graph Background", "graph_background", panel._graph_background_color)

	panel.customize_panel.add_child(HSeparator.new())
	var size_title = Label.new()
	size_title.text = "Screenshot Sizing"
	if title_font:
		size_title.add_theme_font_override("font", title_font)
	panel.customize_panel.add_child(size_title)
	_add_size_row("Menu Size", "menu", panel._menu_size_scale)
	_add_size_row("Brick Size", "brick", panel._brick_size_scale)

	var reset_sizes_button = Button.new()
	reset_sizes_button.text = "Reset Sizes"
	reset_sizes_button.tooltip_text = "Restore the default menu and brick sizes"
	reset_sizes_button.pressed.connect(reset_sizes)
	panel.customize_panel.add_child(reset_sizes_button)

	panel.customize_panel.add_child(HSeparator.new())
	var reset_button = Button.new()
	reset_button.text = "Reset Colors"
	reset_button.tooltip_text = "Restore the default Logic Bricks editor colors"
	reset_button.pressed.connect(reset_colors)
	panel.customize_panel.add_child(reset_button)

func _add_color_row(label_text: String, key: String, color: Color) -> void:
	var row = HBoxContainer.new()
	panel.customize_panel.add_child(row)
	var label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker = ColorPickerButton.new()
	picker.color = color
	picker.edit_alpha = false
	picker.custom_minimum_size = Vector2(72, 28)
	picker.tooltip_text = "Change " + label_text.to_lower()
	picker.color_changed.connect(_on_color_changed.bind(key))
	row.add_child(picker)
	panel._customize_color_pickers[key] = picker

func _add_size_row(label_text: String, key: String, value: float) -> void:
	var row = HBoxContainer.new()
	panel.customize_panel.add_child(row)
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(78, 0)
	row.add_child(label)
	var slider = HSlider.new()
	slider.min_value = 0.5
	slider.max_value = 2.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = "Scale " + label_text.to_lower() + " for clearer screenshots"
	slider.value_changed.connect(_on_size_changed.bind(key))
	row.add_child(slider)
	var value_label = Label.new()
	value_label.text = "%d%%" % int(round(value * 100.0))
	value_label.custom_minimum_size = Vector2(48, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	panel._customize_size_sliders[key] = slider
	panel._customize_size_labels[key] = value_label

func _on_size_changed(value: float, key: String) -> void:
	set_size(key, value)
	save_size(key, value)
	sync_size_controls()
	apply_editor_sizes()

func set_size(key: String, value: float) -> void:
	match key:
		"menu": panel._menu_size_scale = clampf(value, 0.5, 2.0)
		"brick": panel._brick_size_scale = clampf(value, 0.5, 2.0)

func _on_color_changed(color: Color, key: String) -> void:
	set_color(key, color)
	save_color(key, color)
	apply_editor_customization()

func set_color(key: String, color: Color) -> void:
	match key:
		"sensor_header": panel._brick_sensor_color = color
		"controller_header": panel._brick_controller_color = color
		"actuator_header": panel._brick_actuator_color = color
		"header_text": panel._brick_header_text_color = color
		"brick_body": panel._brick_body_color = color
		"graph_background": panel._graph_background_color = color

func _get_editor_settings():
	if panel.editor_interface and panel.editor_interface.has_method("get_editor_settings"):
		return panel.editor_interface.get_editor_settings()
	return null

func load_editor_customization() -> void:
	var settings = _get_editor_settings()
	if settings:
		for key in ["sensor_header", "controller_header", "actuator_header", "header_text", "brick_body", "graph_background"]:
			var setting_name = EDITOR_COLOR_SETTING_PREFIX + key
			if settings.has_setting(setting_name):
				var saved = settings.get_setting(setting_name)
				if saved is Color:
					set_color(key, saved)
		for key in ["menu", "brick"]:
			var setting_name = EDITOR_SIZE_SETTING_PREFIX + key
			if settings.has_setting(setting_name):
				var saved = settings.get_setting(setting_name)
				if typeof(saved) == TYPE_FLOAT or typeof(saved) == TYPE_INT:
					set_size(key, float(saved))
	sync_color_pickers()
	sync_size_controls()
	apply_editor_customization()
	apply_editor_sizes()

func save_color(key: String, color: Color) -> void:
	var settings = _get_editor_settings()
	if settings:
		settings.set_setting(EDITOR_COLOR_SETTING_PREFIX + key, color)

func sync_color_pickers() -> void:
	var colors = {
		"sensor_header": panel._brick_sensor_color,
		"controller_header": panel._brick_controller_color,
		"actuator_header": panel._brick_actuator_color,
		"header_text": panel._brick_header_text_color,
		"brick_body": panel._brick_body_color,
		"graph_background": panel._graph_background_color,
	}
	for key in colors:
		var picker = panel._customize_color_pickers.get(key)
		if is_instance_valid(picker):
			picker.color = colors[key]

func save_size(key: String, value: float) -> void:
	var settings = _get_editor_settings()
	if settings:
		settings.set_setting(EDITOR_SIZE_SETTING_PREFIX + key, value)

func sync_size_controls() -> void:
	var sizes = {"menu": panel._menu_size_scale, "brick": panel._brick_size_scale}
	for key in sizes:
		var slider = panel._customize_size_sliders.get(key)
		if is_instance_valid(slider) and not is_equal_approx(slider.value, sizes[key]):
			slider.set_value_no_signal(sizes[key])
		var value_label = panel._customize_size_labels.get(key)
		if is_instance_valid(value_label):
			value_label.text = "%d%%" % int(round(sizes[key] * 100.0))

func reset_sizes() -> void:
	set_size("menu", DEFAULT_MENU_SIZE_SCALE)
	set_size("brick", DEFAULT_BRICK_SIZE_SCALE)
	save_size("menu", panel._menu_size_scale)
	save_size("brick", panel._brick_size_scale)
	sync_size_controls()
	apply_editor_sizes()

func apply_popup_menu_size(menu: PopupMenu) -> void:
	if not is_instance_valid(menu):
		return
	if not menu.has_meta("logic_bricks_base_menu_metrics"):
		menu.set_meta("logic_bricks_base_menu_metrics", {
			"font_size": menu.get_theme_font_size("font_size", "PopupMenu"),
			"separator_size": menu.get_theme_font_size("font_separator_size", "PopupMenu"),
			"v_separation": menu.get_theme_constant("v_separation", "PopupMenu"),
			"start_padding": menu.get_theme_constant("item_start_padding", "PopupMenu"),
			"end_padding": menu.get_theme_constant("item_end_padding", "PopupMenu"),
		})
	var base: Dictionary = menu.get_meta("logic_bricks_base_menu_metrics")
	menu.add_theme_font_size_override("font_size", maxi(8, int(round(float(base["font_size"]) * panel._menu_size_scale))))
	menu.add_theme_font_size_override("font_separator_size", maxi(8, int(round(float(base["separator_size"]) * panel._menu_size_scale))))
	menu.add_theme_constant_override("v_separation", maxi(1, int(round(float(base["v_separation"]) * panel._menu_size_scale))))
	menu.add_theme_constant_override("item_start_padding", maxi(1, int(round(float(base["start_padding"]) * panel._menu_size_scale))))
	menu.add_theme_constant_override("item_end_padding", maxi(1, int(round(float(base["end_padding"]) * panel._menu_size_scale))))

func apply_editor_sizes() -> void:
	if is_instance_valid(panel.graph_edit):
		panel.graph_edit.zoom = panel._brick_size_scale
	apply_popup_menu_sizes()

func apply_popup_menu_sizes() -> void:
	for menu in [panel.add_menu, panel.sensors_menu, panel.controllers_menu, panel.actuators_menu, panel.options_menu, panel._brick_menu_context_popup]:
		apply_popup_menu_size(menu)
	for submenu in panel.actuator_submenus.values():
		apply_popup_menu_size(submenu)

func reset_colors() -> void:
	var defaults = {
		"sensor_header": DEFAULT_BRICK_SENSOR_COLOR,
		"controller_header": DEFAULT_BRICK_CONTROLLER_COLOR,
		"actuator_header": DEFAULT_BRICK_ACTUATOR_COLOR,
		"header_text": DEFAULT_BRICK_HEADER_TEXT_COLOR,
		"brick_body": DEFAULT_BRICK_BODY_COLOR,
		"graph_background": DEFAULT_GRAPH_BACKGROUND_COLOR,
	}
	for key in defaults:
		set_color(key, defaults[key])
		save_color(key, defaults[key])
	sync_color_pickers()
	apply_editor_customization()

func _make_menu_color_icon(color: Color) -> ImageTexture:
	var image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func apply_add_menu_colors() -> void:
	if not is_instance_valid(panel.add_menu):
		return
	panel.add_menu.set_item_icon(0, _make_menu_color_icon(panel._brick_sensor_color))
	panel.add_menu.set_item_icon(1, _make_menu_color_icon(panel._brick_controller_color))
	panel.add_menu.set_item_icon(2, _make_menu_color_icon(panel._brick_actuator_color))

func apply_editor_customization() -> void:
	apply_add_menu_colors()
	if panel.graph_edit:
		var graph_style = StyleBoxFlat.new()
		graph_style.bg_color = panel._graph_background_color
		panel.graph_edit.add_theme_stylebox_override("panel", graph_style)
		for child in panel.graph_edit.get_children():
			if child is GraphNode and child.has_meta("brick_data"):
				var brick_data = child.get_meta("brick_data")
				panel._apply_brick_visual_style(child, str(brick_data.get("brick_type", "")))
