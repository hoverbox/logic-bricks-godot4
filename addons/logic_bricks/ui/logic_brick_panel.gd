@tool
extends VBoxContainer

## Main panel UI for the Logic Bricks plugin (bottom panel)
## Visual node graph editor for connecting logic bricks

const BrickGraphNode    = preload("res://addons/logic_bricks/ui/brick_graph_node.gd")
const VariableUtils = preload("res://addons/logic_bricks/core/logic_brick_variable_utils.gd")
const BrickRegistry = preload("res://addons/logic_bricks/core/brick_registry.gd")
const DocumentationHelper = preload("res://addons/logic_bricks/core/documentation_helper.gd")
const FrameReorderList = preload("res://addons/logic_bricks/ui/frame_reorder_list.gd")
const LogicGraphEdit = preload("res://addons/logic_bricks/ui/logic_graph_edit.gd")
const CustomizationHelper = preload("res://addons/logic_bricks/ui/panel_customization_helper.gd")
const ConnectionsHelper = preload("res://addons/logic_bricks/ui/panel_connections_helper.gd")
const BricksHelper = preload("res://addons/logic_bricks/ui/panel_bricks_helper.gd")
const SelectionHelper = preload("res://addons/logic_bricks/ui/panel_selection_helper.gd")
const VariablesHelper = preload("res://addons/logic_bricks/ui/panel_variables_helper.gd")
const StatesHelper = preload("res://addons/logic_bricks/ui/panel_states_helper.gd")
const ExportHelper = preload("res://addons/logic_bricks/ui/panel_export_helper.gd")

var manager = null
var editor_interface = null
var plugin = null  # Reference to the EditorPlugin (for autoload registration)
var current_node: Node = null
var current_brick_domain: String = ""
var _clipboard_graph: Dictionary = {}  # Stored graph data for copy/paste (whole node)
var _clipboard_vars: Array = []  # Stored variables for copy/paste (whole node)
var _selection_clipboard: Dictionary = {}  # Selected bricks only — survives node switching
var is_locked: bool = false  # Lock to prevent losing current_node on selection change
var _instance_override: bool = false  # Allow editing instanced nodes when true
var _instance_panel: PanelContainer = null  # The instance warning/choice panel
var _script_required_overlay: CenterContainer = null  # Blocks Logic Bricks until the node has a script
var _script_required_desc: Label = null
var _script_parent_warning: Label = null
var _script_select_parent_button: Button = null

var node_info_label: Label
var add_script_button: Button
var lock_button: Button
var _template_save_dialog: FileDialog
var _template_load_dialog: FileDialog
var _graph_image_dialog: FileDialog
var options_menu: PopupMenu
var _popout_button: Button         # Toggles floating window
var _popout_window: Window = null  # The detached floating window (null when docked)
var _main_hsplit: HSplitContainer  # The bottom-panel hsplit (kept as member for re-docking)
var _toolbar_separator: HSeparator  # Separator above the toolbar (moved with toolbar)
var _toolbar: HBoxContainer         # Bottom toolbar with Add Frame / Apply Code (moved on popout)
var _apply_code_button: Button = null
var _has_unapplied_changes: bool = false
var _dirty_indicator_token: int = 0
var _apply_validation_active: bool = false
var _suppress_dirty_mark: bool = false
var _instructions_label: Label      # "Select a node" label (moved with graph area)
var graph_edit: GraphEdit
var _connection_style_option: OptionButton = null
var add_menu: PopupMenu
var sensors_menu: PopupMenu
var controllers_menu: PopupMenu
var actuators_menu: PopupMenu
var actuator_submenus: Dictionary = {}  # name -> PopupMenu, for sub-submenu ID lookup
var _brick_menu_context_popup: PopupMenu = null
var _brick_menu_context_class: String = ""
var _brick_menu_context_domain: String = ""
var next_node_id: int = 0
var last_mouse_position: Vector2 = Vector2.ZERO

# Search popup (lazy-created)

# Side panel (vertical nav: Variables, Globals, Frames, States)
var side_panel: PanelContainer          # Outer wrapper added to _main_hsplit
var _side_hbox: HBoxContainer           # nav buttons | content stack
var _side_nav_panel: PanelContainer      # wrapper for the nav rail
var _side_nav: VBoxContainer            # left column of nav buttons
var _side_content_scroll: ScrollContainer # right content column
var _side_stack: VBoxContainer          # right column — only one child visible at a time
var _collapse_button: Button            # collapses to icon rail only
var _side_collapsed: bool = false
var _expanded_side_width: int = 360
var _active_tab_index: int = 0          # 0=Variables, 1=Globals, 2=States, 3=Frames, 4=Customize
var _nav_buttons: Array[Button] = []    # Kept so we can update active highlight
var variables_panel: VBoxContainer
var variables_list: VBoxContainer
var variables_data: Array[Dictionary] = []  # Local variables for this node
var global_vars_data: Array[Dictionary] = []  # Global variables (scene-wide, stored on scene root)
var global_vars_panel: VBoxContainer  # Tab panel for global variables
var global_vars_list: VBoxContainer  # UI container for the globals section
var frames_panel: VBoxContainer
var frames_list: ItemList
var frame_order: Array = []
var states_panel: VBoxContainer
var customize_panel: VBoxContainer
var states_data: Array[Dictionary] = []
var states_list: VBoxContainer
var state_debug_button: Button
var frame_settings_container: VBoxContainer
var selected_frame: GraphFrame = null
var _frames_helper = preload("res://addons/logic_bricks/ui/panel_frames_helper.gd").new()
var _search_helper = preload("res://addons/logic_bricks/ui/panel_search_helper.gd").new()
var _clipboard_helper = preload("res://addons/logic_bricks/ui/panel_clipboard_helper.gd").new()
var _graph_helper = preload("res://addons/logic_bricks/ui/panel_graph_helper.gd").new()
var _property_helper = preload("res://addons/logic_bricks/ui/panel_property_helper.gd").new()
var _script_rebuild_helper = preload("res://addons/logic_bricks/ui/panel_script_rebuild_helper.gd").new()

var _customization_helper = CustomizationHelper.new()
var _connections_helper = ConnectionsHelper.new()
var _bricks_helper = BricksHelper.new()
var _selection_helper = SelectionHelper.new()
var _variables_helper = VariablesHelper.new()
var _states_helper = StatesHelper.new()
var _export_helper = ExportHelper.new()

var _brick_sensor_color := CustomizationHelper.DEFAULT_BRICK_SENSOR_COLOR
var _brick_controller_color := CustomizationHelper.DEFAULT_BRICK_CONTROLLER_COLOR
var _brick_actuator_color := CustomizationHelper.DEFAULT_BRICK_ACTUATOR_COLOR
var _brick_header_text_color := CustomizationHelper.DEFAULT_BRICK_HEADER_TEXT_COLOR
var _brick_body_color := CustomizationHelper.DEFAULT_BRICK_BODY_COLOR
var _graph_background_color := CustomizationHelper.DEFAULT_GRAPH_BACKGROUND_COLOR
var _customize_color_pickers: Dictionary = {}
var _menu_size_scale := CustomizationHelper.DEFAULT_MENU_SIZE_SCALE
var _brick_size_scale := CustomizationHelper.DEFAULT_BRICK_SIZE_SCALE
var _customize_size_sliders: Dictionary = {}
var _customize_size_labels: Dictionary = {}
var _crisp_brick_font: Font = null
var _crisp_brick_title_font: Font = null
var _expanded_text_popup: PopupPanel = null
var _expanded_text_edit: LineEdit = null
var _expanded_text_source: LineEdit = null
var _expanded_text_syncing := false


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
	_expanded_text_source = source
	_expanded_text_syncing = true
	_expanded_text_edit.text = source.text
	_expanded_text_syncing = false

	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var desired_width := int(ceil(maxf(source.size.x + 80.0, text_width + 48.0)))
	desired_width = mini(desired_width, maxi(320, usable.size.x - 24))
	var desired_height := maxi(int(ceil(source.size.y + 12.0)), 42)
	var pos := Vector2i(source.get_screen_position()) - Vector2i(6, 6)
	pos.x = clampi(pos.x, usable.position.x + 8, usable.end.x - desired_width - 8)
	pos.y = clampi(pos.y, usable.position.y + 8, usable.end.y - desired_height - 8)
	_expanded_text_popup.position = pos
	_expanded_text_popup.size = Vector2i(desired_width, desired_height)
	_expanded_text_popup.popup()
	_expanded_text_edit.grab_focus()
	_expanded_text_edit.call_deferred("select_all")


func _ensure_expanded_text_popup() -> void:
	if is_instance_valid(_expanded_text_popup):
		return
	_expanded_text_popup = PopupPanel.new()
	_expanded_text_popup.name = "ExpandedBrickTextPopup"
	add_child(_expanded_text_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_expanded_text_popup.add_child(margin)

	_expanded_text_edit = LineEdit.new()
	_expanded_text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expanded_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_expanded_text_edit)
	_expanded_text_edit.text_changed.connect(_on_expanded_text_changed)
	_expanded_text_edit.text_submitted.connect(func(_text): _expanded_text_popup.hide())
	_expanded_text_edit.focus_exited.connect(func():
		if is_instance_valid(_expanded_text_popup):
			_expanded_text_popup.call_deferred("hide")
	)
	_expanded_text_popup.popup_hide.connect(_on_expanded_text_popup_hidden)


func _on_expanded_text_popup_hidden() -> void:
	var source := _expanded_text_source
	_expanded_text_source = null
	if is_instance_valid(source):
		# PopupPanel may restore focus to the control that opened it after hiding.
		# Defer this so the original field ends in a fully inactive state.
		call_deferred("_release_expanded_text_source_focus", source)


func _release_expanded_text_source_focus(source: LineEdit) -> void:
	if not is_instance_valid(source):
		return
	source.deselect()
	source.release_focus()


func _on_expanded_text_changed(new_text: String) -> void:
	if _expanded_text_syncing or not is_instance_valid(_expanded_text_source):
		return
	_expanded_text_syncing = true
	_expanded_text_source.text = new_text
	_expanded_text_source.caret_column = new_text.length()
	_expanded_text_syncing = false


func _init() -> void:
	# Set minimum size for the bottom panel
	custom_minimum_size = Vector2(0, 300)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_search_helper.setup(self)
	_clipboard_helper.setup(self)
	_graph_helper.setup(self)
	_property_helper.setup(self)
	_script_rebuild_helper.setup(self)
	_customization_helper.setup(self)
	_connections_helper.setup(self)
	_bricks_helper.setup(self)
	_selection_helper.setup(self)
	_variables_helper.setup(self)
	_states_helper.setup(self)
	_export_helper.setup(self)

	# Create header
	var header_hbox = HBoxContainer.new()
	add_child(header_hbox)

	var documentation_button = Button.new()
	documentation_button.text = "Documentation"
	documentation_button.tooltip_text = "Open the bundled Logic Bricks documentation in your web browser"
	documentation_button.pressed.connect(_on_documentation_pressed)
	header_hbox.add_child(documentation_button)


	var title_label = Label.new()
	title_label.text = "Logic Bricks - Node Graph"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font = title_label.get_theme_font("bold", "EditorFonts")
	if title_font:
		title_label.add_theme_font_override("font", title_font)
	header_hbox.add_child(title_label)

	node_info_label = Label.new()
	node_info_label.text = "No node selected"
	header_hbox.add_child(node_info_label)

	# Lock button to prevent losing selection
	lock_button = Button.new()
	lock_button.text = "🔓"  # Unlocked icon
	lock_button.tooltip_text = "Lock selection (prevents panel from changing when clicking elsewhere)"
	lock_button.pressed.connect(_on_lock_toggled)
	header_hbox.add_child(lock_button)

	_create_template_dialogs()

	_popout_button = Button.new()
	_popout_button.text = "⧉"
	_popout_button.tooltip_text = "Pop out into a floating window (useful for 2nd screen)"
	_popout_button.pressed.connect(_on_popout_pressed)
	header_hbox.add_child(_popout_button)

	# Separator
	var separator1 = HSeparator.new()
	add_child(separator1)

	# Create horizontal split: graph on left, variables on right
	_main_hsplit = HSplitContainer.new()
	_main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_hsplit.split_offset = -360  # Keep variable controls, including delete, visible by default
	add_child(_main_hsplit)

	# GraphEdit for visual node connections (LEFT SIDE)
	graph_edit = LogicGraphEdit.new()
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.right_disconnects = true
	graph_edit.show_zoom_label = true
	graph_edit.minimap_enabled = true
	graph_edit.minimap_size = Vector2(200, 150)

	_create_script_required_overlay()

	# Enable panning - allow dragging the canvas
	graph_edit.panning_scheme = GraphEdit.SCROLL_ZOOMS  # Mouse wheel zooms, drag pans

	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
	graph_edit.popup_request.connect(_on_popup_request)
	graph_edit.gui_input.connect(_on_graph_edit_input)
	graph_edit.visible = false  # Hidden until node selected
	_main_hsplit.add_child(graph_edit)

	# Side Panel (RIGHT SIDE) - Tabbed: Variables, Globals, Frames
	_create_side_panel()
	_main_hsplit.add_child(side_panel)

	# Create add node menu
	_create_add_menu()

	# Instructions label (shown when graph is hidden)
	_instructions_label = Label.new()
	_instructions_label.name = "InstructionsLabel"
	_instructions_label.text = "👆 Select 3D, 2D or UI Node in your scene tree to start creating logic bricks"
	_instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instructions_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instructions_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_instructions_label.add_theme_font_size_override("font_size", 16)
	add_child(_instructions_label)

	# Toolbar
	_toolbar_separator = HSeparator.new()
	add_child(_toolbar_separator)

	_toolbar = HBoxContainer.new()
	add_child(_toolbar)

	_connection_style_option = OptionButton.new()
	_connection_style_option.tooltip_text = "Connection Style"
	_connection_style_option.add_item("Bezier", 0)
	_connection_style_option.add_item("Stepped", 1)
	_connection_style_option.item_selected.connect(_on_connection_style_selected)
	_toolbar.add_child(_connection_style_option)

	var help_label = Label.new()
	help_label.text = "  Right-click: Add nodes | Alt+Click wire: Add reroute | Drag nodes: Move | Middle-click drag: Pan | Scroll: Zoom"
	help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar.add_child(help_label)

	var add_frame_button = Button.new()
	add_frame_button.text = "Add Frame"
	add_frame_button.pressed.connect(_on_add_frame_pressed)
	_toolbar.add_child(add_frame_button)

	_apply_code_button = Button.new()
	_apply_code_button.text = "Apply Code"
	_apply_code_button.pressed.connect(_on_apply_code_pressed)
	_toolbar.add_child(_apply_code_button)


func _ready() -> void:
	_load_editor_customization()


func _on_documentation_pressed() -> void:
	DocumentationHelper.open_home()


func _on_add_script_pressed() -> void:
	if not current_node or current_node.get_script():
		_update_ui()
		return

	var scene_root = editor_interface.get_edited_scene_root() if editor_interface else null
	var scene_dir = scene_root.scene_file_path.get_base_dir() if scene_root and not scene_root.scene_file_path.is_empty() else "res://"
	var base_name = current_node.name.to_snake_case().validate_filename()
	if base_name.is_empty():
		base_name = "logic_brick_node"

	var script_path = scene_dir.path_join(base_name + ".gd")
	var suffix = 2
	while FileAccess.file_exists(script_path):
		script_path = scene_dir.path_join("%s_%d.gd" % [base_name, suffix])
		suffix += 1

	var file = FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		push_error("Logic Bricks: Could not create script at %s" % script_path)
		return
	file.store_string("extends %s\n" % current_node.get_class())
	file.close()

	if editor_interface:
		editor_interface.get_resource_filesystem().update_file(script_path)
	var script = ResourceLoader.load(script_path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	if not script:
		push_error("Logic Bricks: Script was created but could not be loaded: %s" % script_path)
		return

	current_node.set_script(script)
	if editor_interface:
		editor_interface.mark_scene_as_unsaved()
	_update_ui()


func _create_template_dialogs() -> void:
	_template_save_dialog = FileDialog.new()
	_template_save_dialog.title = "Save Logic Bricks Template"
	_template_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_template_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_template_save_dialog.filters = PackedStringArray(["*.lbtemplate ; Logic Bricks Template"])
	_template_save_dialog.current_file = "logic_bricks_template.lbtemplate"
	_template_save_dialog.file_selected.connect(_on_template_save_path_selected)
	add_child(_template_save_dialog)

	_template_load_dialog = FileDialog.new()
	_template_load_dialog.title = "Load Logic Bricks Template"
	_template_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_template_load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_template_load_dialog.filters = PackedStringArray(["*.lbtemplate ; Logic Bricks Template"])
	_template_load_dialog.file_selected.connect(_on_template_load_path_selected)
	add_child(_template_load_dialog)

	_export_helper.create_graph_image_dialog()


func _on_save_template_pressed() -> void:
	if not current_node:
		push_warning("Logic Bricks: Select a node before saving a template.")
		return
	_template_save_dialog.popup_centered_ratio(0.65)


func _on_load_template_pressed() -> void:
	if not current_node:
		push_warning("Logic Bricks: Select a node before loading a template.")
		return
	if _is_part_of_instance(current_node):
		push_warning("Logic Bricks: Cannot load a template into an instanced node.")
		return
	_template_load_dialog.popup_centered_ratio(0.65)


func _on_template_save_path_selected(path: String) -> void:
	_clipboard_helper.save_template_to_file(path)


func _on_template_load_path_selected(path: String) -> void:
	await _clipboard_helper.load_template_from_file(path)

func _create_add_menu() -> void:
	add_menu = PopupMenu.new()
	add_menu.name = "AddMenu"
	add_child(add_menu)

	sensors_menu = PopupMenu.new()
	sensors_menu.name = "SensorsMenu"
	add_menu.add_child(sensors_menu)
	sensors_menu.id_pressed.connect(_on_add_menu_item_selected)
	_enable_brick_menu_doc_right_click(sensors_menu)

	controllers_menu = PopupMenu.new()
	controllers_menu.name = "ControllersMenu"
	add_menu.add_child(controllers_menu)
	controllers_menu.id_pressed.connect(_on_add_menu_item_selected)
	_enable_brick_menu_doc_right_click(controllers_menu)

	actuators_menu = PopupMenu.new()
	actuators_menu.name = "ActuatorsMenu"
	add_menu.add_child(actuators_menu)
	actuators_menu.id_pressed.connect(_on_add_menu_item_selected)
	_enable_brick_menu_doc_right_click(actuators_menu)

	add_menu.add_submenu_item("Triggers", "SensorsMenu", 0)
	add_menu.add_submenu_item("Gates", "ControllersMenu", 1)
	add_menu.add_submenu_item("Actions", "ActuatorsMenu", 2)
	_apply_add_menu_colors()
	add_menu.add_separator()
	add_menu.add_item("🔍 Search…", 4)
	add_menu.add_separator()

	# Context menu shown after right-clicking a specific brick entry in one of
	# the Add submenus. Keep this separate from the Add menu itself so a right
	# click never adds the brick or opens the browser immediately.
	_brick_menu_context_popup = PopupMenu.new()
	_brick_menu_context_popup.name = "BrickMenuDocumentationContext"
	_brick_menu_context_popup.add_item("View Documentation", 0)
	_brick_menu_context_popup.id_pressed.connect(_on_brick_menu_context_id_pressed)
	add_child(_brick_menu_context_popup)

	options_menu = PopupMenu.new()
	options_menu.name = "OptionsMenu"
	add_menu.add_child(options_menu)
	options_menu.add_item("Copy", 100)
	options_menu.add_item("Paste", 101)
	options_menu.add_item("Duplicate", 102)
	options_menu.add_separator()
	options_menu.add_item("Save Template", 103)
	options_menu.add_item("Load Template", 104)
	options_menu.add_separator()
	options_menu.add_item("Export Graph Image", 105)
	options_menu.add_item("Rebuild from Script", 106)
	options_menu.add_item("Clear Bricks", 107)
	options_menu.id_pressed.connect(_on_options_menu_id_pressed)
	add_menu.add_submenu_item("Options", "OptionsMenu", 7)
	add_menu.id_pressed.connect(_on_main_menu_id_pressed)

	_refresh_add_menu_from_registry(false)


func _refresh_add_menu_from_registry(force_rescan: bool = false) -> void:
	# Rebuild the brick submenus from the registry instead of relying on
	# hard-coded menu IDs. This keeps the right-click menu in sync with any
	# .gd files dropped into the bricks/sensors, bricks/controllers, or
	# bricks/actuators folders.
	if force_rescan:
		BrickRegistry.refresh()
	else:
		BrickRegistry.ensure_scanned()

	sensors_menu.clear()
	controllers_menu.clear()
	actuators_menu.clear()

	for submenu in actuator_submenus.values():
		if is_instance_valid(submenu):
			actuators_menu.remove_child(submenu)
			submenu.queue_free()
	actuator_submenus.clear()

	var domain := current_brick_domain
	_populate_brick_menu_flat(sensors_menu, BrickRegistry.get_bricks_by_type("sensor", domain))
	_populate_brick_menu_flat(controllers_menu, BrickRegistry.get_bricks_by_type("controller", domain))
	_populate_actuator_menu(BrickRegistry.get_bricks_by_type("actuator", domain))
	_apply_popup_menu_sizes()


func _enable_brick_menu_doc_right_click(menu: PopupMenu) -> void:
	# PopupMenu activates brick entries with a left click. Listen to the popup
	# window as well so a right click can offer a documentation-only context
	# action without adding the brick.
	menu.window_input.connect(_on_brick_menu_window_input.bind(menu))


func _on_brick_menu_window_input(event: InputEvent, menu: PopupMenu) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or not mouse_event.pressed:
		return

	# PopupMenu focuses the item under the pointer. Every actual brick entry
	# stores its registered class in metadata; category/submenu rows do not.
	var item_index: int = menu.get_focused_item()
	if item_index < 0 or item_index >= menu.get_item_count():
		return
	if menu.is_item_disabled(item_index) or menu.is_item_separator(item_index):
		return

	var metadata: Variant = menu.get_item_metadata(item_index)
	if not metadata is Dictionary:
		return
	var brick_class: String = str(metadata.get("class", ""))
	if brick_class.is_empty():
		return

	_brick_menu_context_class = brick_class
	_brick_menu_context_domain = current_brick_domain

	# Close the Add-menu stack, then leave a small context menu at the pointer.
	# The browser is opened only if the user explicitly chooses View Documentation.
	menu.hide()
	if is_instance_valid(add_menu):
		add_menu.hide()
	if is_instance_valid(_brick_menu_context_popup):
		_brick_menu_context_popup.position = DisplayServer.mouse_get_position()
		_brick_menu_context_popup.popup()


func _on_brick_menu_context_id_pressed(id: int) -> void:
	if id != 0 or _brick_menu_context_class.is_empty():
		return
	DocumentationHelper.open_brick(_brick_menu_context_class, _brick_menu_context_domain)
	_brick_menu_context_class = ""
	_brick_menu_context_domain = ""


func _menu_display_name(info: Dictionary) -> String:
	var display_name := str(info.get("name", info.get("class", "Brick")))
	if str(info.get("type", "")) == "controller":
		if display_name == "Controller":
			display_name = "Gate"
		elif display_name == "Script Controller":
			display_name = "Script Gate"
	return display_name


func _prepare_menu_bricks(bricks: Array) -> Array:
	# Prefer a domain-specific brick over a common brick when both expose the
	# same menu name (for example UI Always vs common Always), then sort the
	# visible entries alphabetically.
	var by_name: Dictionary = {}
	for info in bricks:
		var display_name := _menu_display_name(info)
		var display_key := display_name.to_lower()
		if not by_name.has(display_key):
			by_name[display_key] = info
			continue
		var current: Dictionary = by_name[display_key]
		var candidate_domain := str(info.get("domain", "common"))
		var current_domain := str(current.get("domain", "common"))
		if candidate_domain == current_brick_domain and current_domain != current_brick_domain:
			by_name[display_key] = info

	var result: Array = by_name.values()
	result.sort_custom(func(a, b):
		return _menu_display_name(a).to_lower() < _menu_display_name(b).to_lower()
	)
	return result


func _populate_brick_menu_flat(menu: PopupMenu, bricks: Array) -> void:
	for info in _prepare_menu_bricks(bricks):
		var id := int(info.get("menu_id", 0))
		var display_name := _menu_display_name(info)
		menu.add_item(display_name, id)
		var idx := menu.get_item_index(id)
		menu.set_item_metadata(idx, {"type": str(info.get("type", "")), "class": str(info.get("class", ""))})
		var description := str(info.get("description", ""))
		if not description.is_empty():
			menu.set_item_tooltip(idx, description)


func _populate_actuator_menu(bricks: Array) -> void:
	# UI nodes only have a small set of UI actuators, so keep that menu flat.
	# The existing categorized submenu layout is still used for 3D nodes where
	# the actuator list is much larger.
	if current_brick_domain == "ui":
		_populate_brick_menu_flat(actuators_menu, bricks)
		return

	var groups: Dictionary = {}
	var group_order: Array = []
	for info in _prepare_menu_bricks(bricks):
		var category := str(info.get("category", "General"))
		if category.is_empty():
			category = "General"
		if not groups.has(category):
			groups[category] = []
			group_order.append(category)
		groups[category].append(info)

	group_order.sort_custom(func(a, b):
		return str(a).to_lower() < str(b).to_lower()
	)

	for category in group_order:
		var group_items: Array = groups[category]
		if group_items.size() == 1 and category == "General":
			_populate_brick_menu_flat(actuators_menu, group_items)
		else:
			var submenu = PopupMenu.new()
			var submenu_name = "ActuatorSub_" + category.replace(" ", "_").replace("/", "_")
			submenu.name = submenu_name
			actuators_menu.add_child(submenu)
			submenu.id_pressed.connect(_on_add_menu_item_selected)
			_enable_brick_menu_doc_right_click(submenu)
			actuator_submenus[submenu_name] = submenu
			_populate_brick_menu_flat(submenu, group_items)
			actuators_menu.add_submenu_item(category, submenu_name)


func _create_side_panel() -> void:
	# Outer container — replaces the old TabContainer
	side_panel = PanelContainer.new()
	side_panel.custom_minimum_size = Vector2.ZERO
	side_panel.size_flags_horizontal = Control.SIZE_FILL
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.visible = false  # Hidden until node selected

	# Horizontal split: Blender-like icon rail | content column
	_side_hbox = HBoxContainer.new()
	_side_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_child(_side_hbox)

	# Left nav column
	_side_nav_panel = PanelContainer.new()
	_side_nav_panel.custom_minimum_size = Vector2.ZERO
	_side_nav_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_hbox.add_child(_side_nav_panel)

	_side_nav = VBoxContainer.new()
	_side_nav.add_theme_constant_override("separation", 8)
	_side_nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_nav.alignment = BoxContainer.ALIGNMENT_BEGIN
	_side_nav_panel.add_child(_side_nav)

	_collapse_button = Button.new()
	_collapse_button.flat = true
	_collapse_button.focus_mode = Control.FOCUS_NONE
	_collapse_button.custom_minimum_size = Vector2(32, 32)
	_collapse_button.tooltip_text = "Collapse to icon rail"
	_collapse_button.expand_icon = false
	_collapse_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapse_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_collapse_button.text = "<"
	_collapse_button.pressed.connect(_toggle_side_panel_collapsed)
	_side_nav.add_child(_collapse_button)

	# Right content stack (inside a scroll container so the split can get very thin)
	_side_content_scroll = ScrollContainer.new()
	_side_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_side_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_side_hbox.add_child(_side_content_scroll)

	_side_stack = VBoxContainer.new()
	_side_stack.add_theme_constant_override("separation", 8)
	_side_stack.custom_minimum_size = Vector2.ZERO
	_side_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_content_scroll.add_child(_side_stack)

	# Build the content panels
	_create_variables_tab()
	_create_global_variables_tab()
	_create_frames_tab()
	_create_states_tab()
	_create_customize_tab()

	_side_stack.add_child(variables_panel)
	_side_stack.add_child(global_vars_panel)
	_side_stack.add_child(states_panel)
	_side_stack.add_child(frames_panel)
	_side_stack.add_child(customize_panel)

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
		_side_nav.add_child(btn)
		_nav_buttons.append(btn)

	# Keep editor customization at the bottom of the rail.
	var nav_spacer = Control.new()
	nav_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_nav.add_child(nav_spacer)

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
	_side_nav.add_child(customize_btn)
	_nav_buttons.append(customize_btn)

	_apply_side_tab_icons()
	_update_collapse_button_icon()

	# Show first tab by default
	_select_side_tab(0)


func _on_side_tab_pressed(index: int) -> void:
	if _side_collapsed:
		_set_side_panel_collapsed(false)
	_select_side_tab(index)


func _select_side_tab(index: int) -> void:
	_active_tab_index = index
	for i in range(_side_stack.get_child_count()):
		_side_stack.get_child(i).visible = (i == index)
	# Update button highlight
	for i in range(_nav_buttons.size()):
		var btn = _nav_buttons[i]
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
	_set_side_panel_collapsed(not _side_collapsed)


func _set_side_panel_collapsed(collapsed: bool) -> void:
	if _side_collapsed == collapsed:
		return
	if collapsed:
		_expanded_side_width = maxi(_expanded_side_width, int(side_panel.size.x))
	_side_collapsed = collapsed
	if _side_content_scroll:
		_side_content_scroll.visible = not collapsed
	_update_collapse_button_icon()
	call_deferred("_apply_side_collapse_split")


func _apply_side_collapse_split() -> void:
	if not side_panel or not _side_nav_panel:
		return
	var active_hsplit: HSplitContainer = side_panel.get_parent() as HSplitContainer
	if not active_hsplit:
		return
	if _side_collapsed:
		# The nav panel stretches to fill the old sidebar width once the content is hidden,
		# so its live size is not a valid collapse target. Keep the icon rail fixed.
		var rail_width := 40
		active_hsplit.split_offset = -rail_width
	else:
		var target_width := maxi(_expanded_side_width, 140)
		active_hsplit.split_offset = -target_width


func _update_collapse_button_icon() -> void:
	if not _collapse_button:
		return
	var icon_name := "Forward" if _side_collapsed else "Back"
	var fallback := ">" if _side_collapsed else "<"
	var icon = null
	if has_theme_icon(icon_name, "EditorIcons"):
		icon = get_theme_icon(icon_name, "EditorIcons")
	_collapse_button.icon = icon
	_collapse_button.text = "" if icon != null else fallback
	_collapse_button.tooltip_text = "Expand panel" if _side_collapsed else "Collapse to icon rail"


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


func _make_hover_nav_stylebox() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


func _apply_side_tab_icons() -> void:
	if _nav_buttons.is_empty():
		return
	for btn in _nav_buttons:
		if not is_instance_valid(btn):
			continue
		var icon_name = str(btn.get_meta("icon_name", ""))
		var fallback_text = str(btn.get_meta("fallback_text", ""))
		var icon = null
		if has_theme_icon(icon_name, "EditorIcons"):
			icon = get_theme_icon(icon_name, "EditorIcons")
		btn.icon = icon
		btn.text = "" if icon != null else fallback_text


func _apply_side_panel_visibility() -> void:
	if not side_panel:
		return
	side_panel.visible = graph_edit.visible
	if graph_edit.visible:
		call_deferred("_apply_side_collapse_split")


func _create_customize_tab() -> void:
	_customization_helper.create_customize_tab()

func _on_customize_size_changed(value: float, key: String) -> void:
	_customization_helper._on_size_changed(value, key)

func _set_customization_size(key: String, value: float) -> void:
	_customization_helper.set_size(key, value)

func _on_customize_color_changed(color: Color, key: String) -> void:
	_customization_helper._on_color_changed(color, key)

func _set_customization_color(key: String, color: Color) -> void:
	_customization_helper.set_color(key, color)

func _load_editor_customization() -> void:
	_customization_helper.load_editor_customization()

func _save_editor_customization_color(key: String, color: Color) -> void:
	_customization_helper.save_color(key, color)

func _sync_customize_color_pickers() -> void:
	_customization_helper.sync_color_pickers()

func _save_editor_customization_size(key: String, value: float) -> void:
	_customization_helper.save_size(key, value)

func _sync_customize_size_controls() -> void:
	_customization_helper.sync_size_controls()

func _reset_editor_sizes() -> void:
	_customization_helper.reset_sizes()

func _apply_popup_menu_size(menu: PopupMenu) -> void:
	_customization_helper.apply_popup_menu_size(menu)

func _apply_editor_sizes() -> void:
	_customization_helper.apply_editor_sizes()

func _apply_popup_menu_sizes() -> void:
	_customization_helper.apply_popup_menu_sizes()

func _reset_editor_customization() -> void:
	_customization_helper.reset_colors()

func _apply_add_menu_colors() -> void:
	_customization_helper.apply_add_menu_colors()

func _apply_editor_customization() -> void:
	_customization_helper.apply_editor_customization()

func _create_variables_tab() -> void:
	# Create the variables management tab
	variables_panel = VBoxContainer.new()
	variables_panel.add_theme_constant_override("separation", 8)
	variables_panel.name = "Variables"
	variables_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add Variable button doubles as the tab header so it stays visible in narrow panels.
	var add_var_button = Button.new()
	add_var_button.text = "+ Add Variable"
	add_var_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_var_button.pressed.connect(_on_add_variable_pressed)
	variables_panel.add_child(add_var_button)

	var sep = HSeparator.new()
	variables_panel.add_child(sep)

	# Scrollable list of local variables
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	variables_panel.add_child(scroll)

	variables_list = VBoxContainer.new()
	variables_list.add_theme_constant_override("separation", 8)
	variables_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(variables_list)


func _create_global_variables_tab() -> void:
	# Create the global variables management tab (scene-wide, stored on scene root)
	global_vars_panel = VBoxContainer.new()
	global_vars_panel.add_theme_constant_override("separation", 8)
	global_vars_panel.name = "Globals"
	global_vars_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Add Global Variable button doubles as the tab header so it stays visible in narrow panels.
	var add_global_button = Button.new()
	add_global_button.text = "+ Add Global Variable"
	add_global_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_global_button.pressed.connect(_on_add_global_variable_pressed)
	global_vars_panel.add_child(add_global_button)

	var sep = HSeparator.new()
	global_vars_panel.add_child(sep)

	var hint = Label.new()
	hint.text = "Shared across all nodes and all scenes (via GlobalVars autoload)"
	hint.clip_text = true
	hint.custom_minimum_size = Vector2(0, 0)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hint.add_theme_font_size_override("font_size", 10)
	global_vars_panel.add_child(hint)

	var global_scroll = ScrollContainer.new()
	global_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	global_vars_panel.add_child(global_scroll)

	global_vars_list = VBoxContainer.new()
	global_vars_list.add_theme_constant_override("separation", 8)
	global_vars_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	global_scroll.add_child(global_vars_list)


func _create_frames_tab() -> void:
	# Create the frames management tab
	frames_panel = VBoxContainer.new()
	frames_panel.add_theme_constant_override("separation", 8)
	frames_panel.name = "Frames"
	frames_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Header
	var header = HBoxContainer.new()
	frames_panel.add_child(header)

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
	sort_frames_button.pressed.connect(_on_sort_frames_pressed)
	header.add_child(sort_frames_button)

	# Separator
	var sep1 = HSeparator.new()
	frames_panel.add_child(sep1)

	# Frame list with controls
	var list_container = HBoxContainer.new()
	frames_panel.add_child(list_container)

	# Frame list
	frames_list = FrameReorderList.new()
	frames_list.setup(self)
	frames_list.custom_minimum_size = Vector2(0, 150)
	frames_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frames_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frames_list.tooltip_text = "Double-click a frame to center and fit it in the graph."
	frames_list.item_selected.connect(_on_frame_list_item_selected)
	frames_list.item_activated.connect(_on_frame_list_item_activated)  # Double-click to navigate to frame
	list_container.add_child(frames_list)

	# Separator
	var sep2 = HSeparator.new()
	frames_panel.add_child(sep2)

	# Frame settings (shown when a frame is selected)
	frame_settings_container = VBoxContainer.new()
	frame_settings_container.add_theme_constant_override("separation", 8)
	frame_settings_container.name = "FrameSettings"
	frame_settings_container.visible = false
	frames_panel.add_child(frame_settings_container)

	var settings_label = Label.new()
	settings_label.text = "Frame Settings:"
	var settings_font = settings_label.get_theme_font("bold", "EditorFonts")
	if settings_font:
		settings_label.add_theme_font_override("font", settings_font)
	frame_settings_container.add_child(settings_label)

	# Frame name field
	var name_label = Label.new()
	name_label.text = "Name:"
	frame_settings_container.add_child(name_label)

	var name_edit = LineEdit.new()
	name_edit.name = "FrameNameEdit"
	name_edit.placeholder_text = "Enter frame name..."
	name_edit.text_changed.connect(_on_frame_name_changed)
	frame_settings_container.add_child(name_edit)

	# Optional frame comment / description
	var comment_label = Label.new()
	comment_label.text = "Comment:"
	frame_settings_container.add_child(comment_label)

	var comment_edit = TextEdit.new()
	comment_edit.name = "FrameCommentEdit"
	comment_edit.placeholder_text = "Describe what this frame does..."
	comment_edit.custom_minimum_size = Vector2(0, 90)
	comment_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comment_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	comment_edit.text_changed.connect(_on_frame_comment_changed)
	frame_settings_container.add_child(comment_edit)

	# Frame color picker
	var color_label = Label.new()
	color_label.text = "Color:"
	frame_settings_container.add_child(color_label)

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
	swatch_style.border_color = get_theme_color("contrast_color_2", "Editor")
	swatch_style.corner_radius_top_left = 4
	swatch_style.corner_radius_top_right = 4
	swatch_style.corner_radius_bottom_left = 4
	swatch_style.corner_radius_bottom_right = 4
	color_picker.add_theme_stylebox_override("normal", swatch_style)

	var swatch_hover_style = swatch_style.duplicate()
	swatch_hover_style.border_color = get_theme_color("accent_color", "Editor")
	color_picker.add_theme_stylebox_override("hover", swatch_hover_style)
	color_picker.add_theme_stylebox_override("pressed", swatch_hover_style)

	color_picker.color_changed.connect(_on_frame_color_changed)
	frame_settings_container.add_child(color_picker)

	# Manual size controls
	var size_label = Label.new()
	size_label.text = "Frame Size:"
	frame_settings_container.add_child(size_label)

	var size_hbox = HBoxContainer.new()
	frame_settings_container.add_child(size_hbox)

	var width_label = Label.new()
	width_label.text = "W:"
	size_hbox.add_child(width_label)

	var width_spin = SpinBox.new()
	width_spin.name = "FrameWidthSpin"
	width_spin.min_value = 100
	width_spin.max_value = 2000
	width_spin.step = 10
	width_spin.value_changed.connect(_on_frame_width_changed)
	size_hbox.add_child(width_spin)

	var height_label = Label.new()
	height_label.text = "H:"
	size_hbox.add_child(height_label)

	var height_spin = SpinBox.new()
	height_spin.name = "FrameHeightSpin"
	height_spin.min_value = 100
	height_spin.max_value = 2000
	height_spin.step = 10
	height_spin.value_changed.connect(_on_frame_height_changed)
	size_hbox.add_child(height_spin)

	# Auto-resize button
	var resize_button = Button.new()
	resize_button.text = "Auto-Resize to Fit Nodes"
	resize_button.pressed.connect(_on_frame_resize_pressed)
	frame_settings_container.add_child(resize_button)

	# Delete frame button
	var delete_button = Button.new()
	delete_button.text = "Delete Frame"
	delete_button.modulate = Color(1, 0.5, 0.5)
	delete_button.pressed.connect(_on_frame_delete_pressed)
	frame_settings_container.add_child(delete_button)




func _create_states_tab() -> void:
	_states_helper.create_states_tab()


func _sanitize_state_id(text_value: String) -> String:
	return _states_helper.sanitize_state_id(text_value)


func _generate_unique_state_id(base_name: String) -> String:
	return _states_helper.generate_unique_state_id(base_name)


func _get_default_states() -> Array[Dictionary]:
	return _states_helper.get_default_states()


func _load_states_from_metadata(suppress_graph_save: bool = false) -> void:
	_states_helper.load_states_from_metadata(suppress_graph_save)


func _save_states_to_metadata() -> void:
	_states_helper.save_states_to_metadata()


func _refresh_states_ui() -> void:
	_states_helper.refresh_states_ui()


func _on_state_debug_watch_toggled(enabled: bool, button: Button) -> void:
	_states_helper.on_state_debug_watch_toggled(enabled, button)


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


func _on_add_state_pressed() -> void:
	_states_helper.add_state()


func _on_delete_state_pressed(index: int) -> void:
	_states_helper.delete_state(index)


func _on_state_name_changed(new_text: String, index: int) -> void:
	_states_helper.on_state_name_changed(new_text, index)


func get_state_options() -> Array:
	return _states_helper.get_state_options()


func get_state_display_name(state_id: String) -> String:
	return _states_helper.get_state_display_name(state_id)


func _enter_tree() -> void:
	# Apply editor icons now that the theme is available.
	_apply_side_tab_icons()


func set_selected_node(node: Node) -> void:
	_selection_helper.set_selected_node(node)


func _update_ui() -> void:
	await _selection_helper.update_ui()


func _refresh_brick_state_ui() -> void:
	_selection_helper.refresh_brick_state_ui()


func _refresh_variable_brick_context_ui() -> void:
	_selection_helper.refresh_variable_brick_context_ui()


func _is_supported_node(node: Node) -> bool:
	return _selection_helper.is_supported_node(node)


func _get_selected_node_domain() -> String:
	return _selection_helper.get_selected_node_domain()


## ── Pop-out / dock ────────────────────────────────────────────────────────────

func _on_popout_pressed() -> void:
	if _popout_window:
		_dock_window()
	else:
		_popout_window_open()


func _popout_window_open() -> void:
	# Create the floating window
	_popout_window = Window.new()
	_popout_window.title = "Logic Bricks"
	_popout_window.size = Vector2i(1280, 720)
	_popout_window.wrap_controls = true
	_popout_window.min_size = Vector2i(640, 400)
	_popout_window.close_requested.connect(_dock_window)

	# Root container inside the window (mirrors the bottom panel VBox structure)
	var win_root = VBoxContainer.new()
	win_root.add_theme_constant_override("separation", 8)
	win_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popout_window.add_child(win_root)

	# Move instructions label into the window root
	remove_child(_instructions_label)
	win_root.add_child(_instructions_label)

	# Re-create the hsplit inside the window
	var win_hsplit = HSplitContainer.new()
	win_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	win_hsplit.split_offset = _main_hsplit.split_offset
	win_root.add_child(win_hsplit)

	# Move graph_edit and side_panel into the window hsplit
	_main_hsplit.remove_child(graph_edit)
	_main_hsplit.remove_child(side_panel)
	win_hsplit.add_child(graph_edit)
	win_hsplit.add_child(side_panel)

	# Move toolbar separator and toolbar into the window root
	remove_child(_toolbar_separator)
	remove_child(_toolbar)
	win_root.add_child(_toolbar_separator)
	win_root.add_child(_toolbar)

	# Re-parent add_menu into the floating window so right-click popups
	# appear on the correct monitor (popups always follow their owner window)
	remove_child(add_menu)
	_popout_window.add_child(add_menu)

	# Hide the now-empty bottom panel hsplit
	_main_hsplit.visible = false

	# Update button
	_popout_button.text = "⬅"
	_popout_button.tooltip_text = "Dock back into the bottom panel"

	# Add the window to the editor
	get_tree().root.add_child(_popout_window)
	_popout_window.popup_centered()


func _dock_window() -> void:
	if not _popout_window:
		return

	# Retrieve the window's hsplit so we can restore split_offset
	var win_root = _popout_window.get_child(0) if _popout_window.get_child_count() > 0 else null
	var win_hsplit: HSplitContainer = null
	if win_root:
		for child in win_root.get_children():
			if child is HSplitContainer:
				win_hsplit = child
				break

	# Restore split offset from window if available
	if win_hsplit:
		_main_hsplit.split_offset = win_hsplit.split_offset
		win_hsplit.remove_child(graph_edit)
		win_hsplit.remove_child(side_panel)

	# Move instructions label back
	if win_root:
		win_root.remove_child(_instructions_label)
	add_child(_instructions_label)
	move_child(_instructions_label, get_child_count() - 1)

	# Re-parent back into the bottom panel hsplit
	_main_hsplit.add_child(graph_edit)
	_main_hsplit.add_child(side_panel)
	_main_hsplit.visible = true

	# Move toolbar separator and toolbar back
	if win_root:
		win_root.remove_child(_toolbar_separator)
		win_root.remove_child(_toolbar)
	add_child(_toolbar_separator)
	add_child(_toolbar)

	# Move add_menu back to the main panel
	_popout_window.remove_child(add_menu)
	add_child(add_menu)

	# Close and free the window
	_popout_window.close_requested.disconnect(_dock_window)
	_popout_window.queue_free()
	_popout_window = null

	# Restore button
	_popout_button.text = "⧉"
	_popout_button.tooltip_text = "Pop out into a floating window (useful for 2nd screen)"


func _create_script_required_overlay() -> void:
	_script_required_overlay = CenterContainer.new()
	_script_required_overlay.name = "ScriptRequiredOverlay"
	_script_required_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_script_required_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_script_required_overlay.visible = false
	graph_edit.add_child(_script_required_overlay)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 250)
	_script_required_overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "⚠  Script Required"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	vbox.add_child(title)

	_script_required_desc = Label.new()
	_script_required_desc.text = "Logic Bricks cannot be added to this node until it has a script."
	_script_required_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_script_required_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_script_required_desc)

	add_script_button = Button.new()
	add_script_button.text = "Add Script to Node"
	add_script_button.tooltip_text = "Create and attach the script required by Logic Bricks"
	add_script_button.custom_minimum_size = Vector2(220, 44)
	add_script_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_script_button.pressed.connect(_on_add_script_pressed)
	vbox.add_child(add_script_button)

	_script_parent_warning = Label.new()
	_script_parent_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_script_parent_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_script_parent_warning.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	_script_parent_warning.visible = false
	vbox.add_child(_script_parent_warning)

	_script_select_parent_button = Button.new()
	_script_select_parent_button.text = "Select Parent"
	_script_select_parent_button.tooltip_text = "Select the nearest parent that already has a script or Logic Bricks"
	_script_select_parent_button.custom_minimum_size = Vector2(220, 40)
	_script_select_parent_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_script_select_parent_button.visible = false
	_script_select_parent_button.pressed.connect(_on_select_parent_pressed)
	vbox.add_child(_script_select_parent_button)


func _show_script_required_overlay() -> void:
	_selection_helper.show_script_required_overlay()


func _get_parent_with_script_or_logic() -> Node:
	return _selection_helper.get_parent_with_script_or_logic()


func _on_select_parent_pressed() -> void:
	_selection_helper.on_select_parent_pressed()


func _hide_script_required_overlay() -> void:
	_selection_helper.hide_script_required_overlay()


func _show_instance_panel() -> void:
	_selection_helper.show_instance_panel()


func _hide_instance_panel() -> void:
	_selection_helper.hide_instance_panel()


func _on_open_original_pressed() -> void:
	_selection_helper.on_open_original_pressed()


func _on_edit_instance_pressed() -> void:
	_selection_helper.on_edit_instance_pressed()


func _is_part_of_instance(node: Node) -> bool:
	return _selection_helper.is_part_of_instance(node)


func _clear_graph_display() -> void:
	graph_edit.clear_connections()
	var children_to_remove = []
	for child in graph_edit.get_children():
		if child is GraphNode or child is GraphFrame:
			children_to_remove.append(child)
	for child in children_to_remove:
		graph_edit.remove_child(child)
		child.free()

	# Frames belong to the selected node just like bricks do. Clear the in-memory
	# frame state too so a node with no Logic Bricks metadata starts truly empty.
	frame_node_mapping.clear()
	frame_titles.clear()
	frame_comments.clear()
	selected_frame = null
	if frame_settings_container:
		frame_settings_container.visible = false
	if frames_list:
		frames_list.clear()


func _load_graph_from_metadata() -> void:
	# Clear existing graph before loading the selected node.
	_clear_graph_display()

	if not current_node or not current_node.has_meta("logic_bricks_graph"):
		_apply_connection_style("bezier")
		return

	# Snapshot the node we are loading for — current_node may change during the
	# await below if the user clicks another node while this coroutine is suspended.
	var _loading_for_node = current_node
	var graph_data = _loading_for_node.get_meta("logic_bricks_graph")
	_apply_connection_style(str(graph_data.get("connection_style", "bezier")))

	# Restore nodes
	for node_data in graph_data.get("nodes", []):
		_create_graph_node_from_data(node_data)

	# Restore connections (must happen after all nodes are created)
	await get_tree().process_frame

	# If the user switched nodes while we were suspended, discard this load —
	# the new set_selected_node call will handle the correct node's graph.
	if current_node != _loading_for_node:
		graph_edit.clear_connections()
		for child in graph_edit.get_children():
			if child is GraphNode:
				child.queue_free()
		return

	for conn in graph_data.get("connections", []):
		pass
		graph_edit.connect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])

	next_node_id = graph_data.get("next_id", 0)


## Take a deep copy of the current graph metadata for undo/redo snapshots
func _take_graph_snapshot() -> Dictionary:
	return _clipboard_helper.take_graph_snapshot()


## Restore a graph snapshot: write it back to metadata and rebuild the visual graph.
## The metadata write is synchronous; the visual rebuild is deferred one frame.
func _restore_graph_snapshot(snapshot: Dictionary) -> void:
	_restore_graph_snapshot_for_node(current_node, snapshot)

func _restore_graph_snapshot_for_node(target_node: Node, snapshot: Dictionary) -> void:
	_clipboard_helper.restore_graph_snapshot(target_node, snapshot)


## Called deferred after a snapshot restore so the visual graph rebuilds cleanly
func _reload_graph_deferred(target_node: Node = current_node) -> void:
	await _clipboard_helper.reload_graph_deferred(target_node)


## Record an undoable graph action.
## Call BEFORE making changes (before_snapshot) and AFTER (after_snapshot).
func _record_undo(action_name: String, before_snapshot: Dictionary, after_snapshot: Dictionary, target_node: Node = current_node, merge: bool = false) -> void:
	_clipboard_helper.record_undo(action_name, before_snapshot, after_snapshot, target_node, merge)


func _save_graph_to_metadata(action_name: String = "Edit Logic Bricks", record_change: bool = true, merge: bool = true) -> void:
	_clipboard_helper.save_graph_to_metadata(action_name, record_change, merge)


func _mark_unapplied_changes() -> void:
	if _suppress_dirty_mark:
		return
	_has_unapplied_changes = true
	_dirty_indicator_token += 1
	var token = _dirty_indicator_token
	# Deliberately delayed so the UI does not nag during every click/keystroke.
	get_tree().create_timer(1.5).timeout.connect(func():
		if token == _dirty_indicator_token and _has_unapplied_changes and is_instance_valid(_apply_code_button):
			_apply_code_button.text = "Apply Code  •"
			_apply_code_button.tooltip_text = "The graph has changes that have not been applied to the script yet."
	)


func _clear_unapplied_changes() -> void:
	_has_unapplied_changes = false
	_dirty_indicator_token += 1
	if is_instance_valid(_apply_code_button):
		_apply_code_button.text = "Apply Code"
		_apply_code_button.tooltip_text = ""


func _warning_node_name(graph_node: GraphNode) -> String:
	return "apply_warning_" + str(graph_node.name)


func _remove_apply_warning(graph_node: GraphNode) -> void:
	var warning = graph_edit.get_node_or_null(NodePath(_warning_node_name(graph_node)))
	if warning:
		graph_edit.remove_child(warning)
		warning.queue_free()


func _set_apply_warning(graph_node: GraphNode, messages: Array[String]) -> void:
	_remove_apply_warning(graph_node)
	if messages.is_empty():
		return
	var warning = GraphNode.new()
	warning.name = _warning_node_name(graph_node)
	warning.title = ""
	warning.draggable = false
	warning.selectable = false
	warning.resizable = false
	warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning.z_index = 100
	var label = Label.new()
	label.text = "⚠ " + " • ".join(messages)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning.add_child(label)
	var box = StyleBoxFlat.new()
	box.bg_color = Color("5a430d")
	box.border_color = Color("f2b84b")
	box.set_border_width_all(2)
	box.content_margin_left = 10
	box.content_margin_right = 20
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.corner_radius_top_left = 5
	box.corner_radius_top_right = 5
	box.corner_radius_bottom_left = 5
	box.corner_radius_bottom_right = 5
	warning.add_theme_stylebox_override("panel", box)
	warning.add_theme_stylebox_override("panel_selected", box)
	var empty_title = StyleBoxEmpty.new()
	warning.add_theme_stylebox_override("titlebar", empty_title)
	warning.add_theme_stylebox_override("titlebar_selected", empty_title)
	graph_edit.add_child(warning)
	warning.size = warning.get_combined_minimum_size()
	warning.position_offset = graph_node.position_offset + Vector2(0, -warning.size.y - 10)


func _refresh_apply_validation_warnings() -> void:
	if not _apply_validation_active or not is_instance_valid(graph_edit):
		return
	# Apply Code is the validation checkpoint. Rebuild the warning set from
	# exactly the bricks that exist at this moment; later edits do not add
	# warnings until Apply Code is pressed again.
	_clear_all_apply_warnings()
	var connections = graph_edit.get_connection_list()
	for child in graph_edit.get_children():
		if not (child is GraphNode and child.has_meta("brick_data")):
			continue
		var messages: Array[String] = []
		if not _graph_helper.is_brick_in_complete_chain(child, connections):
			messages.append("Incomplete Brick Chain")
		var brick_data: Dictionary = child.get_meta("brick_data")
		var brick_instance = brick_data.get("brick_instance")
		if brick_instance and brick_instance.has_method("get_configuration_warnings"):
			for message in brick_instance.call("get_configuration_warnings", current_node):
				var text := str(message).strip_edges()
				if not text.is_empty():
					messages.append(text)
		_set_apply_warning(child, messages)


func _clear_all_apply_warnings() -> void:
	# Ignore late callbacks during plugin teardown/reload.
	if not is_instance_valid(graph_edit):
		return
	var warnings_to_remove: Array[Node] = []
	for child in graph_edit.get_children():
		if child is GraphNode and str(child.name).begins_with("apply_warning_"):
			warnings_to_remove.append(child)
	for warning in warnings_to_remove:
		graph_edit.remove_child(warning)
		warning.queue_free()


func _on_popup_request(position: Vector2) -> void:
	if not current_node or current_node.get_script() == null:
		return
	# Store the position accounting for scroll offset
	# position is in local graph coordinates, we need to add scroll offset
	last_mouse_position = (position + graph_edit.scroll_offset) / graph_edit.zoom
	# Rescan before opening so newly added brick scripts appear without
	# manual registration or hard-coded menu edits.
	_refresh_add_menu_from_registry(true)

	# Position the menu at the click location in screen coordinates
	var screen_pos = graph_edit.get_screen_position() + position
	add_menu.position = screen_pos
	add_menu.popup()


func _on_main_menu_id_pressed(id: int) -> void:
	if id == 4:
		_open_search_popup(add_menu.position)


func _on_options_menu_id_pressed(id: int) -> void:
	match id:
		100:
			_on_copy_bricks_pressed()
		101:
			await _on_paste_bricks_pressed()
		102:
			await _on_duplicate_bricks_pressed()
		103:
			_on_save_template_pressed()
		104:
			_on_load_template_pressed()
		105:
			_on_export_graph_image_pressed()
		106:
			await _on_rebuild_from_script_pressed()
		107:
			await _on_clear_bricks_pressed()


func _on_clear_bricks_pressed() -> void:
	if not current_node:
		return

	# Confirm before wiping — this is destructive and not undo-able via the
	# standard undo stack (metadata removal is not tracked by UndoRedo).
	var confirm = ConfirmationDialog.new()
	confirm.title = "Clear Bricks"
	confirm.dialog_text = "Remove all bricks from \"%s\"?\n\nYou can undo this action." % current_node.name
	confirm.ok_button_text = "Clear"
	add_child(confirm)
	confirm.popup_centered()

	await confirm.confirmed
	confirm.queue_free()

	if not current_node or not is_instance_valid(current_node):
		return

	# Clear the visual canvas
	var before_snapshot = _take_graph_snapshot()
	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()
	await get_tree().process_frame

	# Remove all logic-brick metadata keys from the node
	for key in ["logic_bricks", "logic_bricks_graph", "logic_bricks_states",
				"logic_bricks_variables", "logic_bricks_global_usage",
				"logic_bricks_debug_watch_state"]:
		if current_node.has_meta(key):
			current_node.remove_meta(key)

	# Persist the now-empty graph so downstream saves don't resurrect old data
	_save_graph_to_metadata("Clear Logic Bricks", false)
	_mark_scene_modified()
	_record_undo("Clear Logic Bricks", before_snapshot, _take_graph_snapshot())

	# Reset state UI to defaults
	_load_states_from_metadata(true)
	_load_variables_from_metadata()

	push_warning("Logic Bricks: All bricks cleared from '%s'. Script markers remain — remove them manually if needed." % current_node.name)


func _open_search_popup(screen_pos: Vector2, initial_text: String = "") -> void:
	_search_helper.open_search_popup(screen_pos, initial_text)


func _create_reroute_node(position: Vector2, port_color: Color = Color.WHITE, save_now: bool = true) -> GraphNode:
	return _connections_helper.create_reroute_node(position, port_color, save_now)

func _center_reroute_ports(reroute: GraphNode) -> void:
	_connections_helper.center_reroute_ports(reroute)

func _insert_reroute_on_connection(connection: Dictionary, mouse_position: Vector2) -> void:
	_connections_helper.insert_reroute_on_connection(connection, mouse_position)

func _on_connection_style_selected(index: int) -> void:
	_connections_helper.on_connection_style_selected(index)

func _apply_connection_style(style: String) -> void:
	_connections_helper.apply_connection_style(style)

func _on_add_menu_item_selected(id: int) -> void:
	var metadata = _get_brick_menu_metadata(id)
	if metadata:
		var brick_type = metadata["type"]
		var brick_class = metadata["class"]
		var before_snapshot = _take_graph_snapshot()
		_create_graph_node(brick_type, brick_class, last_mouse_position)
		_record_undo("Add Logic Brick", before_snapshot, _take_graph_snapshot())


func _get_brick_menu_metadata(id: int):
	# Auto-discovered bricks use registry-assigned IDs, so do not assume
	# sensors/controllers/actuators live in fixed numeric ranges.
	for menu in [sensors_menu, controllers_menu, actuators_menu]:
		var item_index = menu.get_item_index(id)
		if item_index >= 0:
			return menu.get_item_metadata(item_index)

	for submenu in actuator_submenus.values():
		if not is_instance_valid(submenu):
			continue
		var sub_index = submenu.get_item_index(id)
		if sub_index >= 0:
			return submenu.get_item_metadata(sub_index)

	return null


func _apply_brick_visual_style(graph_node: GraphNode, brick_type: String) -> void:
	_bricks_helper.apply_brick_visual_style(graph_node, brick_type)

func _apply_brick_connection_ports(graph_node: GraphNode, brick_type: String) -> void:
	_bricks_helper.apply_brick_connection_ports(graph_node, brick_type)

func _font_with_graph_oversampling(source: Font) -> Font:
	return _bricks_helper._font_with_graph_oversampling(source)

func _apply_crisp_brick_fonts(graph_node: GraphNode) -> void:
	_bricks_helper.apply_crisp_brick_fonts(graph_node)

func _add_brick_bottom_padding(graph_node: GraphNode) -> void:
	_bricks_helper.add_brick_bottom_padding(graph_node)

func _create_graph_node(brick_type: String, brick_class: String, position: Vector2) -> void:
	_bricks_helper.create_graph_node(brick_type, brick_class, position)

func _create_graph_node_from_data(node_data: Dictionary) -> GraphNode:
	return _bricks_helper.create_graph_node_from_data(node_data)

func _create_brick_instance(brick_class: String):
	return _bricks_helper.create_brick_instance(brick_class)

func _create_brick_ui(graph_node: GraphNode, brick_instance) -> void:
	_property_helper._create_brick_ui(graph_node, brick_instance)


func _on_lock_toggled() -> void:
	_selection_helper.on_lock_toggled()


func _setup_graph_node_context_menu(graph_node: GraphNode) -> void:
	_bricks_helper.setup_graph_node_context_menu(graph_node)

func _on_graph_node_context_menu(id: int, graph_node: GraphNode) -> void:
	await _bricks_helper.on_graph_node_context_menu(id, graph_node)

func _duplicate_graph_node(original_node: GraphNode) -> GraphNode:
	return await _clipboard_helper.duplicate_graph_node(original_node)


func _generate_unique_brick_name(base_name: String) -> String:
	return _clipboard_helper.generate_unique_brick_name(base_name)


func _on_connection_request(from_node: String, from_port: int, to_node: String, to_port: int) -> void:
	_connections_helper.on_connection_request(from_node, from_port, to_node, to_port)

func _on_graph_edit_input(event: InputEvent) -> void:
	if not current_node or current_node.get_script() == null:
		return
	if _connections_helper.try_insert_reroute_from_input(event):
		graph_edit.accept_event()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Ctrl+D to duplicate selected nodes
		if event.keycode == KEY_D and event.ctrl_pressed:
			_duplicate_selected_nodes()
			graph_edit.accept_event()
		# Ctrl+C — copy selected bricks, or whole node if nothing selected
		elif event.keycode == KEY_C and event.ctrl_pressed:
			_on_copy_bricks_pressed()
			graph_edit.accept_event()
		# Ctrl+V — paste selection clipboard if available, else whole-node clipboard
		elif event.keycode == KEY_V and event.ctrl_pressed:
			_on_paste_bricks_pressed()
			graph_edit.accept_event()
		# Type-to-search: any printable character (no modifiers except Shift) opens the search popup
		elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
			var ch = event.as_text()
			# as_text() returns the printable character(s); skip special key names (len > 1 means it's e.g. "Escape", "F1", etc.)
			if ch.length() == 1 and ch.unicode_at(0) >= 32:
				# Store position under mouse for placing the new brick
				last_mouse_position = (graph_edit.get_local_mouse_position() + graph_edit.scroll_offset) / graph_edit.zoom
				var screen_pos = graph_edit.get_screen_position() + graph_edit.get_local_mouse_position()
				_open_search_popup(screen_pos, ch)
				graph_edit.accept_event()


func _duplicate_selected_nodes() -> void:
	await _clipboard_helper.duplicate_selected_nodes()


func _on_disconnection_request(from_node: String, from_port: int, to_node: String, to_port: int) -> void:
	_connections_helper.on_disconnection_request(from_node, from_port, to_node, to_port)

func _on_delete_nodes_request(nodes: Array) -> void:
	_clipboard_helper.on_delete_nodes_request(nodes)


func _on_property_changed(value, graph_node: GraphNode, property_name: String) -> void:
	_property_helper._on_property_changed(value, graph_node, property_name)


func _update_controller_title(graph_node: GraphNode, brick_instance) -> void:
	_property_helper._update_controller_title(graph_node, brick_instance)


func _on_instance_name_changed(new_name: String, graph_node: GraphNode, brick_instance) -> void:
	_property_helper._on_instance_name_changed(new_name, graph_node, brick_instance)


func _on_debug_enabled_changed(enabled: bool, graph_node: GraphNode, brick_instance) -> void:
	_property_helper._on_debug_enabled_changed(enabled, graph_node, brick_instance)


func _on_debug_message_changed(new_message: String, graph_node: GraphNode, brick_instance) -> void:
	_property_helper._on_debug_message_changed(new_message, graph_node, brick_instance)


func _on_copy_bricks_pressed() -> void:
	_clipboard_helper.on_copy_bricks_pressed()


## Capture selected graph nodes and their internal connections
## into a portable dictionary that can be pasted onto any node.
func _capture_selection(selected_nodes: Array) -> Dictionary:
	return _clipboard_helper.capture_selection(selected_nodes)


func _on_paste_bricks_pressed() -> void:
	await _clipboard_helper.on_paste_bricks_pressed()


## Paste the selection clipboard into the current graph.
## Pasted nodes are offset slightly so they don't land on top of existing bricks.
## Internal connections are recreated. The clipboard is not cleared so the user
## can paste the same set multiple times or switch nodes and paste again.
func _paste_selection(clipboard: Dictionary) -> void:
	await _clipboard_helper.paste_selection(clipboard)




func _on_duplicate_bricks_pressed() -> void:
	var selected_nodes: Array = []
	for child in graph_edit.get_children():
		if child is GraphNode and child.selected:
			selected_nodes.append(child)
	if selected_nodes.is_empty():
		push_warning("Logic Bricks: Select one or more bricks to duplicate.")
		return
	var duplicate_data := _capture_selection(selected_nodes)
	await _paste_selection(duplicate_data)


func _on_export_graph_image_pressed() -> void:
	_export_helper.on_export_graph_image_pressed()


func _on_graph_image_path_selected(path: String) -> void:
	await _export_helper.on_graph_image_path_selected(path)


func _export_graph_image(path: String) -> void:
	await _export_helper.export_graph_image(path)

func _on_view_chain_code(controller_node: GraphNode) -> void:
	# Open the generated script and jump to this chain's function
	if not current_node or not editor_interface:
		return

	var script = current_node.get_script()
	if not script:
		push_warning("Logic Bricks: No script on this node. Click 'Apply Code' first.")
		return

	# Get chain name from controller node
	var chain_name = _graph_helper.get_chain_name_for_controller(controller_node)
	var func_name = "_logic_brick_%s" % chain_name

	# Read the script to find the line number
	var script_path = script.resource_path
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		push_warning("Logic Bricks: Could not read script file.")
		return

	var line_number = 1
	var found = false
	while not file.eof_reached():
		var line = file.get_line()
		if line.strip_edges().begins_with("func " + func_name):
			found = true
			break
		line_number += 1
	file.close()

	if not found:
		push_warning("Logic Bricks: Chain function '%s' not found in script. Try 'Apply Code' first." % func_name)
		return

	# Open script editor at the line
	editor_interface.set_main_screen_editor("Script")
	editor_interface.edit_script(script, line_number)


func _on_rebuild_metadata_pressed() -> void:
	if not current_node:
		push_error("Logic Bricks: No node selected!")
		return

	if not manager:
		push_error("Logic Bricks: Manager not initialized!")
		return

	if not current_node.has_meta("logic_bricks_graph"):
		push_warning("Logic Bricks: No saved graph metadata found on this node.")
		return

	await _load_graph_from_metadata()
	await get_tree().process_frame
	_graph_helper.sync_graph_ui_to_bricks()

	var chains = _graph_helper.extract_chains_from_graph(true)
	if chains.is_empty():
		push_warning("Logic Bricks: Could not rebuild metadata because no controller-rooted chains were found in the saved graph.")
		return

	manager.save_chains(current_node, chains)

	var complete_count := 0
	for chain in chains:
		var controllers = chain.get("controllers", [])
		var is_script_controller = controllers.size() > 0 and controllers[0].get("type", "") == "ScriptController"
		var has_sensors = chain.get("sensors", []).size() > 0
		var has_actuators = chain.get("actuators", []).size() > 0
		if has_sensors and (has_actuators or is_script_controller):
			complete_count += 1

	if complete_count < chains.size():
		push_warning("Logic Bricks: Rebuilt %d chain(s) from graph data, but %d are incomplete and will not generate code until their connections are restored." % [chains.size(), chains.size() - complete_count])
	else:
		print("Logic Bricks: Rebuilt logic_bricks metadata for %s from saved graph data." % current_node.name)


func _on_rebuild_from_script_pressed() -> void:
	if not current_node:
		push_error("Logic Bricks: No node selected!")
		return
	if not manager:
		push_error("Logic Bricks: Manager not initialized!")
		return
	await _script_rebuild_helper.rebuild_from_script()


func _on_apply_code_pressed() -> void:
	pass

	if not current_node:
		push_error("Logic Bricks: No node selected!")
		return

	if not manager:
		push_error("Logic Bricks: Manager not initialized!")
		return

	if not editor_interface:
		push_error("Logic Bricks: Editor interface not available!")
		return

	_apply_validation_active = true
	_refresh_apply_validation_warnings()

	_graph_helper.sync_graph_ui_to_bricks()
	_save_graph_to_metadata()

	# Extract chains
	var chains = _graph_helper.extract_chains_from_graph()

	# Clear old metadata
	if current_node.has_meta("logic_bricks"):
		current_node.remove_meta("logic_bricks")

	if not current_node.get_script():
		push_error("Logic Bricks: Selected node has no script. Click Add Script to Node first.")
		return

	# Get script path before regeneration
	var script_path = current_node.get_script().resource_path

	# Get variables code
	var variables_code = get_variables_code()

	# Save graph metadata first, then regenerate. The manager validates the full
	# candidate script before touching the working file and returns false on any
	# preflight/write failure.
	manager.save_chains(current_node, chains)
	if not manager.regenerate_script(current_node, variables_code):
		push_error("Logic Bricks: Apply Code failed. Your existing script was not modified.")
		return

	# Phase 1: create any required scene nodes (CanvasLayer, ColorRect, etc.)
	# @export var assignment happens in Phase 2 AFTER set_script() below,
	# because set_script() resets all properties to their defaults.
	_apply_scene_setup_create(current_node, chains)

	# Get script path if we didn't have one
	if script_path.is_empty() and current_node.get_script():
		script_path = current_node.get_script().resource_path

	if script_path.is_empty():
		push_error("Logic Bricks: No script path available!")
		return

	# Do not save the scene here. Apply Code should only regenerate/reload the
	# script and create required helper nodes in the live editor scene. Saving the
	# whole scene on every click is expensive in larger projects and makes Apply
	# Code feel slow. The minimize/restore refresh below is intentionally kept; it
	# is still the reliable way to make Godot refresh the script/export state.

	# Force filesystem to update
	var filesystem = editor_interface.get_resource_filesystem()
	filesystem.update_file(script_path)

	# Snapshot current_node before awaiting — the user may click away during the
	# yield, setting current_node to null or a different node.
	var _apply_node = current_node

	# Wait a frame
	await get_tree().process_frame

	# Guard: node must still be valid after the yield
	if not is_instance_valid(_apply_node):
		push_error("Logic Bricks: Node was freed during Apply Code — try again.")
		return

	# Reload the script with cache bypass
	var reloaded_script = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE)

	if not reloaded_script:
		push_error("Logic Bricks: Failed to reload script from disk!")
		return

	# Apply the reloaded script to the node
	_apply_node.set_script(reloaded_script)
	_clear_unapplied_changes()

	# Phase 2: assign @export vars now that the new script is live.
	# This MUST come after set_script() or the assignments get wiped.
	await get_tree().process_frame
	if is_instance_valid(_apply_node):
		_apply_scene_setup_assign(_apply_node, chains)

	# Minimize/restore is the only reliable way to force Godot to rebuild
	# the inspector's @export slots after a script reload.
	# Hide all secondary Window nodes first — any visible child Window (including
	# the addon pop-out or other editor sub-windows) can prevent the OS-level
	# focus loss that makes the hack work, and can also steal the restore signal
	# leaving the main window stuck minimized.
	var was_popout_open = _popout_window != null
	if was_popout_open:
		_popout_window.hide()

	# Also hide any other top-level Windows that are currently visible.
	var other_windows: Array[Window] = []
	for child in get_tree().root.get_children():
		if child is Window and child.visible and child != get_tree().root:
			other_windows.append(child)
			child.hide()

	# Capture the restore mode *before* minimizing.
	# Always restore to WINDOWED or MAXIMIZED — never back to MINIMIZED — so
	# that a pre-existing minimized state (e.g. caused by another window) does
	# not leave us stuck.
	var prev_window_mode = DisplayServer.window_get_mode()
	var restore_mode = DisplayServer.WINDOW_MODE_WINDOWED
	if prev_window_mode == DisplayServer.WINDOW_MODE_MAXIMIZED or \
		prev_window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or \
		prev_window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		restore_mode = prev_window_mode

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	# Restore on the next idle step instead of awaiting a full process frame here.
	# This keeps the refresh hack, but makes the visible minimize/restore snap back
	# faster and lets Apply Code finish without blocking on the window animation.
	call_deferred("_finish_apply_window_refresh", restore_mode, other_windows, was_popout_open, reloaded_script)




## ============================================================================
## VARIABLES PANEL FUNCTIONS
## Variables/Globals are owned by panel_variables_helper.gd.
## These wrappers preserve the panel API used by bricks/helpers and older editor code.
func _generate_global_var_id() -> String:
	return _variables_helper.generate_global_var_id()

func _ensure_global_var_ids() -> void:
	_variables_helper.ensure_global_var_ids()

func _get_global_usage_map() -> Dictionary:
	return _variables_helper.get_global_usage_map()

func _is_global_used_in_current_script(var_data: Dictionary) -> bool:
	return _variables_helper.is_global_used_in_current_script(var_data)

func _set_global_used_in_current_script(index: int, enabled: bool) -> void:
	_variables_helper.set_global_used_in_current_script(index, enabled)

func _save_variables_to_metadata(record_change: bool = true, action_name: String = "Edit Logic Brick Variable") -> void:
	_variables_helper.save_variables_to_metadata(record_change, action_name)

func _save_global_vars_to_metadata(record_change: bool = true, action_name: String = "Edit Global Logic Brick Variable") -> void:
	_variables_helper.save_global_vars_to_metadata(record_change, action_name)

func _update_global_vars_script() -> void:
	_variables_helper.update_global_vars_script()

func _read_global_vars_from_script() -> Array[Dictionary]:
	return _variables_helper.read_global_vars_from_script()

func _ensure_global_vars_autoload(script_path: String) -> void:
	_variables_helper.ensure_global_vars_autoload(script_path)

func _load_variables_from_metadata() -> void:
	_variables_helper.load_variables_from_metadata()

func _build_export_range_str(var_type: String, use_min: bool, min_val: String, use_max: bool, max_val: String) -> String:
	return _variables_helper.build_export_range_str(var_type, use_min, min_val, use_max, max_val)

func _build_clamp_expr(val_var: String, var_type: String, use_min: bool, min_val: String, use_max: bool, max_val: String) -> String:
	return _variables_helper.build_clamp_expr(val_var, var_type, use_min, min_val, use_max, max_val)

func _value_to_line_edit_text(value) -> String:
	return _variables_helper.value_to_line_edit_text(value)

func get_variables_code() -> String:
	return _variables_helper.get_variables_code()

## UI/editing behavior lives in panel_variables_helper.gd. Persistence/code generation live there too.
## ============================================================================

func _on_add_variable_pressed() -> void:
	_variables_helper.add_local_variable()


func _on_add_global_variable_pressed() -> void:
	_variables_helper.add_global_variable()


func _refresh_variables_ui() -> void:
	_variables_helper.refresh_local_variables_ui()


func _refresh_global_vars_ui() -> void:
	_variables_helper.refresh_global_variables_ui()


func _clear_variable_drop_indicators() -> void:
	_variables_helper.clear_drop_indicators()


func _reorder_variable(from_index: int, target_index: int, is_global: bool) -> void:
	_variables_helper.reorder_variable(from_index, target_index, is_global)


## Add a new frame to the graph

## Frame tracking: maps frame names to arrays of node names
var frame_node_mapping: Dictionary = {}  # {"frame_name": ["node1", "node2", ...]}
var frame_titles: Dictionary = {}  # {"frame_name": "Custom Title"}
var frame_comments: Dictionary = {}  # {"frame_name": "Optional multiline comment"}


## Add a new frame to the graph
func _on_add_frame_pressed() -> void:
	_frames_helper.on_add_frame_pressed(self)


## Handle frame click to select it in side panel (DISABLED - was blocking editor input)
#func _on_frame_gui_input(event: InputEvent, frame: GraphFrame) -> void:
#    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
#        _select_frame_in_side_panel(frame)





## Handle brick node being dragged
func _on_brick_node_dragged(from: Vector2, to: Vector2, node: GraphNode) -> void:
	var warning = graph_edit.get_node_or_null(NodePath(_warning_node_name(node)))
	if warning is GraphNode:
		warning.position_offset = node.position_offset + Vector2(0, -warning.size.y - 10)
	# Check if node entered/left any frames
	_frames_helper.check_node_frame_membership(self, node)

	# Auto-resize frames that contain this node
	for frame_name in frame_node_mapping.keys():
		if node.name in frame_node_mapping[frame_name]:
			var frame = graph_edit.get_node_or_null(NodePath(frame_name))
			if frame and frame is GraphFrame:
				_frames_helper.auto_resize_frame(self, frame)

	# Save node positions
	_save_graph_to_metadata()


func _on_reroute_dragged(from: Vector2, to: Vector2, reroute: GraphNode) -> void:
	_connections_helper.on_reroute_dragged(from, to, reroute)

func _point_to_segment_distance(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	return _connections_helper.point_to_segment_distance(point, seg_a, seg_b)

## Handle frame being dragged
func _on_frame_dragged(from: Vector2, to: Vector2, frame: GraphFrame) -> void:
	_frames_helper.on_frame_dragged(self, from, to, frame)

## Handle frame resize
func _on_frame_resize_request(new_size: Vector2, frame: GraphFrame) -> void:
	_frames_helper.on_frame_resize_request(self, new_size, frame)




## Frame Panel Callbacks

func _update_frames_list() -> void:
	_frames_helper.update_frames_list(self)


func _reorder_frame(from_index: int, target_index: int) -> void:
	_frames_helper.reorder_frame(self, from_index, target_index)


func _on_sort_frames_pressed() -> void:
	_frames_helper.sort_frames_alphabetically(self)


func _save_frames_to_metadata(record_change: bool = true, action_name: String = "Edit Logic Brick Frame") -> void:
	_frames_helper.save_frames_to_metadata(self, record_change, action_name)


func _update_frame_settings_ui() -> void:
	_frames_helper.update_frame_settings_ui(self)


func _select_frame_in_side_panel(frame: GraphFrame) -> void:
	_frames_helper.select_frame_in_side_panel(self, frame)


func _on_frame_list_item_selected(index: int) -> void:
	_frames_helper.on_frame_list_item_selected(self, index)


func _on_frame_name_changed(new_name: String) -> void:
	_frames_helper.on_frame_name_changed(self, new_name)

func _on_frame_comment_changed() -> void:
	_frames_helper.on_frame_comment_changed(self)

func _on_frame_color_changed(new_color: Color) -> void:
	_frames_helper.on_frame_color_changed(self, new_color)

func _on_frame_resize_pressed() -> void:
	_frames_helper.on_frame_resize_pressed(self)

func _on_frame_width_changed(new_width: float) -> void:
	_frames_helper.on_frame_width_changed(self, new_width)

func _on_frame_height_changed(new_height: float) -> void:
	_frames_helper.on_frame_height_changed(self, new_height)

func _on_frame_delete_pressed() -> void:
	_frames_helper.on_frame_delete_pressed(self)



func _on_frame_list_item_activated(index: int) -> void:
	_frames_helper.on_frame_list_item_activated(self, index)

func _on_frame_rename_button_pressed() -> void:
	_frames_helper.on_frame_rename_button_pressed(self)

func _on_rename_dialog_confirmed(dialog: AcceptDialog, line_edit: LineEdit) -> void:
	_frames_helper.on_rename_dialog_confirmed(self, dialog, line_edit)

func _on_rename_dialog_canceled(dialog: AcceptDialog) -> void:
	_frames_helper.on_rename_dialog_canceled(self, dialog)

func _on_frame_list_color_changed(new_color: Color) -> void:
	_frames_helper.on_frame_list_color_changed(self, new_color)

## Mark the scene as modified so changes are saved
func _mark_scene_modified() -> void:
	if not editor_interface:
		return

	# Mark the currently edited scene as unsaved
	# This is the correct way to tell Godot the scene needs saving
	editor_interface.mark_scene_as_unsaved()


## Build, update, or remove scene nodes required by special actuators.
## Called after Apply Code so nodes exist in the scene before the script runs.
func _apply_scene_setup_create(node: Node, chains: Array) -> void:
	# Phase 1 of Apply Code scene setup: create scene nodes and clean up stale ones.
	# @export var assignments are done separately in _apply_scene_setup_assign(),
	# which must run AFTER set_script() so the assignments aren't wiped.
	var scene_root = node.get_tree().edited_scene_root if node.get_tree() else null
	if not scene_root:
		return

	# ── Waypoint Path: create Path3D helper nodes when Path3D mode is selected ──
	for chain in chains:
		for actuator_data in chain.get("actuators", []):
			if actuator_data.get("type", "") != "WaypointPathActuator":
				continue
			var brick_script = load("res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd")
			if not brick_script:
				push_warning("Logic Bricks: Could not load waypoint_path_actuator.gd")
				continue
			var brick = brick_script.new()
			brick.deserialize(actuator_data)
			if node is Node3D:
				brick_script.sync_path3d_node(node, brick)

	# ── Waypoint Path 2D: create Path2D helper nodes when Path2D mode is selected ──
	for chain in chains:
		for actuator_data in chain.get("actuators", []):
			if actuator_data.get("type", "") != "WaypointPath2DActuator":
				continue
			var brick_script_2d = load("res://addons/logic_bricks/bricks/actuators/2d/waypoint_path_2d_actuator.gd")
			if not brick_script_2d:
				push_warning("Logic Bricks: Could not load waypoint_path_2d_actuator.gd")
				continue
			var brick_2d = brick_script_2d.new()
			brick_2d.deserialize(actuator_data)
			if node is Node2D:
				brick_script_2d.sync_path2d_node(node, brick_2d)

	# ── SplitScreen: free stale _ss_canvas_* nodes if the actuator was removed ──
	var has_split_screen := false
	for chain in chains:
		for actuator in chain.get("actuators", []):
			if actuator.get("type", "") == "SplitScreenActuator":
				has_split_screen = true
				break
		if has_split_screen:
			break

	if not has_split_screen:
		var stale_ss: Array = []
		for child in scene_root.get_children():
			if child is CanvasLayer and child.name.begins_with("_ss_canvas_"):
				stale_ss.append(child)
		for cl in stale_ss:
			cl.free()

	# ── ScreenFlash: create/update CanvasLayer + ColorRect nodes ────────────
	var active_flash_layers: Array = []

	for chain in chains:
		for actuator_data in chain.get("actuators", []):
			if actuator_data.get("type", "") != "ScreenFlashActuator":
				continue

			var brick_script = load("res://addons/logic_bricks/bricks/actuators/common/screen_flash_actuator.gd")
			if not brick_script:
				push_warning("Logic Bricks: Could not load screen_flash_actuator.gd")
				continue
			var brick = brick_script.new()
			brick.deserialize(actuator_data)
			var gen = brick.generate_code(node, chain.get("name", "chain"))
			var setup = gen.get("scene_setup", {})
			if setup.get("type", "") != "ScreenFlash":
				continue

			var flash_var: String  = setup.get("flash_var", "")
			var cam_name: String   = setup.get("camera_name", "").strip_edges()
			if flash_var.is_empty():
				continue

			var layer_name := "__FlashLayer_%s" % flash_var
			active_flash_layers.append(layer_name)

			# Determine size to match the target camera's viewport
			var flash_size := Vector2(
				ProjectSettings.get_setting("display/window/size/viewport_width",  1280),
				ProjectSettings.get_setting("display/window/size/viewport_height", 720)
			)

			if not cam_name.is_empty():
				var cam := _find_camera_by_name(scene_root, cam_name)
				if is_instance_valid(cam):
					var p := cam.get_parent()
					while is_instance_valid(p):
						if p is SubViewportContainer:
							flash_size = (p as SubViewportContainer).size
							break
						elif p is SubViewport:
							flash_size = Vector2((p as SubViewport).size)
							break
						p = p.get_parent()
				else:
					push_warning("Screen Flash Action: Camera '%s' not found — using full window size" % cam_name)

			# Find or create the CanvasLayer
			var canvas_layer: CanvasLayer = null
			for child in scene_root.get_children():
				if child is CanvasLayer and child.name == layer_name:
					canvas_layer = child as CanvasLayer
					break
			if not is_instance_valid(canvas_layer):
				canvas_layer = CanvasLayer.new()
				canvas_layer.name = layer_name
				canvas_layer.layer = 128
				scene_root.add_child(canvas_layer)
				canvas_layer.owner = scene_root

			# Find or create the ColorRect inside the CanvasLayer
			var color_rect: ColorRect = canvas_layer.get_node_or_null("ColorRect") as ColorRect
			if not is_instance_valid(color_rect):
				color_rect = ColorRect.new()
				color_rect.name = "ColorRect"
				canvas_layer.add_child(color_rect)
				color_rect.owner = scene_root

			# Full-screen flash layers should stretch with the viewport instead of
			# relying on a one-time editor size snapshot.
			color_rect.anchor_left   = 0.0
			color_rect.anchor_top    = 0.0
			color_rect.anchor_right  = 1.0
			color_rect.anchor_bottom = 1.0
			color_rect.offset_left   = 0.0
			color_rect.offset_top    = 0.0
			color_rect.offset_right  = 0.0
			color_rect.offset_bottom = 0.0
			color_rect.position      = Vector2.ZERO
			color_rect.color         = Color(0, 0, 0, 0)
			color_rect.visible       = false
			color_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	# Free stale flash layers from removed ScreenFlashActuator bricks
	var stale_flash: Array = []
	for child in scene_root.get_children():
		if child is CanvasLayer and child.name.begins_with("__FlashLayer_")                 and child.name not in active_flash_layers:
			stale_flash.append(child)
	for cl in stale_flash:
		cl.free()



func _finish_apply_window_refresh(restore_mode: int, other_windows: Array, was_popout_open: bool, reloaded_script: Script) -> void:
	DisplayServer.window_set_mode(restore_mode)
	DisplayServer.window_move_to_foreground()

	# Restore all secondary windows that were hidden above.
	for w in other_windows:
		if is_instance_valid(w):
			w.show()

	if was_popout_open and _popout_window:
		_popout_window.show()

	# Open the script in the script editor after the refresh snap-back.
	if is_instance_valid(reloaded_script):
		editor_interface.edit_script(reloaded_script, 1)

func _apply_scene_setup_assign(node: Node, chains: Array) -> void:
	# Phase 2 of Apply Code scene setup: assign @export vars to the pre-created nodes.
	# Must run AFTER set_script() — set_script() resets all properties, so any
	# assignment done before it would be silently discarded.
	#
	# NOTE: ScreenFlash no longer uses @export vars. The generated actuator code
	# resolves the ColorRect by node path at runtime via get_tree().root.get_node_or_null().
	# No assignment is needed here for that actuator type.
	pass

func _find_camera_by_name(root: Node, cam_name: String) -> Camera3D:
	if not is_instance_valid(root): return null
	for child in root.get_children():
		if not is_instance_valid(child): continue
		if child is Camera3D and child.name == cam_name:
			return child
		elif not child is SubViewport:
			var found = _find_camera_by_name(child, cam_name)
			if found:
				return found
	return null
