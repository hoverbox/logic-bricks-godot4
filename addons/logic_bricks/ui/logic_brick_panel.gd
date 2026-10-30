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
const VersionHelper = preload("res://addons/logic_bricks/ui/panel_version_helper.gd")
const GraphSnapshot = preload("res://addons/logic_bricks/core/graph_snapshot.gd")
const NodeReferenceSync = preload("res://addons/logic_bricks/core/node_reference_sync.gd")
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
var _graph_column: VBoxContainer  # Graph, graph toolbar, and instance controls move together
var _toolbar_separator: HSeparator  # Separator above the toolbar (moved with toolbar)
var _toolbar: HBoxContainer         # Bottom toolbar with Add Frame / Apply Code (moved on popout)
var _apply_code_button: Button = null
var _has_unapplied_changes: bool = false
var _dirty_indicator_token: int = 0
var _apply_validation_active: bool = false
var _typing_notice: MenuButton = null
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
var _version_helper = VersionHelper.new()
var _variables_helper = VariablesHelper.new()
var _states_helper = StatesHelper.new()
var _export_helper = ExportHelper.new()
var _runtime_debug_helper = preload("res://addons/logic_bricks/ui/panel_runtime_debug_helper.gd").new()
var _side_panel_builder = preload("res://addons/logic_bricks/ui/panel_side_panel_builder.gd").new()
var _add_menu_helper = preload("res://addons/logic_bricks/ui/panel_add_menu_helper.gd").new()
var _apply_helper = preload("res://addons/logic_bricks/ui/panel_apply_helper.gd").new()
var _window_helper = preload("res://addons/logic_bricks/ui/panel_window_helper.gd").new()

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
var _expanded_text_layout: VBoxContainer = null
var _expanded_typing_data: Dictionary = {}
var _expanded_text_syncing := false


func show_expanded_line_edit_if_needed(source: LineEdit) -> void:
	_window_helper.show_expanded_line_edit_if_needed(source)


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
	_version_helper.setup(self)
	_variables_helper.setup(self)
	_states_helper.setup(self)
	_export_helper.setup(self)
	_runtime_debug_helper.setup(self)
	_side_panel_builder.setup(self)
	_add_menu_helper.setup(self)
	_apply_helper.setup(self)
	_window_helper.setup(self)

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
	# Keep the native graph controls outside the pannable canvas. Bricks and
	# reroutes use z_index 100 to sit above frames, which covered the old menu.
	_graph_column = VBoxContainer.new()
	_graph_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_column.add_theme_constant_override("separation", 0)
	_main_hsplit.add_child(_graph_column)
	var graph_toolbar := PanelContainer.new()
	graph_toolbar.name = "GraphToolbar"
	_graph_column.add_child(graph_toolbar)
	var graph_menu := graph_edit.get_menu_hbox()
	graph_menu.reparent(graph_toolbar, false)
	graph_edit.show_menu = false
	graph_toolbar.visible = graph_edit.visible
	graph_edit.visibility_changed.connect(func(): graph_toolbar.visible = graph_edit.visible)
	_states_helper.create_view_filter(graph_menu)
	_graph_column.add_child(graph_edit)

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
	_version_helper.create_notice(_toolbar)
	_typing_notice = MenuButton.new()
	_typing_notice.text = "⚠ Check names"
	_typing_notice.add_theme_color_override("font_color", Color(1.0, 0.75, 0.25))
	_typing_notice.tooltip_text = "Click a warning to go to its brick. Apply Code remains available."
	_typing_notice.visible = false
	_toolbar.add_child(_typing_notice)
	_typing_notice.get_popup().id_pressed.connect(func(id: int):
		var popup := _typing_notice.get_popup()
		var index := popup.get_item_index(id)
		if index < 0: return
		var brick_name := str(popup.get_item_metadata(index))
		var brick := graph_edit.get_node_or_null(NodePath(brick_name)) as GraphNode
		if brick:
			for data in _property_helper.typing_assistance.fields_in(brick):
				if not str(data.message).is_empty():
					var ancestor: Node = data.wrapper.get_parent()
					while ancestor and ancestor != brick:
						if str(ancestor.name) == "GroupBody": ancestor.show()
						ancestor = ancestor.get_parent()
			for child in graph_edit.get_children():
				if child is GraphNode: child.selected = child == brick
			graph_edit.scroll_offset = brick.position_offset * graph_edit.zoom - graph_edit.size * 0.25
	)


func _ready() -> void:
	_load_editor_customization()


func _on_documentation_pressed() -> void:
	DocumentationHelper.open_home()


func _on_add_script_pressed() -> void:
	_apply_helper._on_add_script_pressed()


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
	_add_menu_helper._create_add_menu()


func _refresh_add_menu_from_registry(force_rescan: bool = false) -> void:
	_add_menu_helper._refresh_add_menu_from_registry(force_rescan)


func _create_side_panel() -> void:
	_side_panel_builder._create_side_panel()


func _apply_side_tab_icons() -> void:
	_side_panel_builder._apply_side_tab_icons()


func _apply_side_panel_visibility() -> void:
	_side_panel_builder._apply_side_panel_visibility()


func _create_customize_tab() -> void:
	_customization_helper.create_customize_tab()

func _load_editor_customization() -> void:
	_customization_helper.load_editor_customization()

func _apply_popup_menu_size(menu: PopupMenu) -> void:
	_customization_helper.apply_popup_menu_size(menu)

func _apply_popup_menu_sizes() -> void:
	_customization_helper.apply_popup_menu_sizes()

func _apply_add_menu_colors() -> void:
	_customization_helper.apply_add_menu_colors()


func _create_states_tab() -> void:
	_states_helper.create_states_tab()

func _load_states_from_metadata(suppress_graph_save: bool = false) -> void:
	_states_helper.load_states_from_metadata(suppress_graph_save)

func _style_debug_watch_button(button: Button, active: bool) -> void:
	_side_panel_builder._style_debug_watch_button(button, active)

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
	_states_helper.refresh_view_filter()


func _refresh_variable_brick_context_ui() -> void:
	_selection_helper.refresh_variable_brick_context_ui()

## ── Pop-out / dock ────────────────────────────────────────────────────────────

func _on_popout_pressed() -> void:
	_window_helper._on_popout_pressed()


func _dock_window() -> void:
	_window_helper._dock_window()


func _popup_host() -> Node:
	return _window_helper._popup_host()


func _usable_screen_rect_at(screen_point: Vector2) -> Rect2i:
	return _window_helper._usable_screen_rect_at(screen_point)


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

	_script_parent_warning = Label.new()
	_script_parent_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_script_parent_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_script_parent_warning.add_theme_font_size_override("font_size", 18)
	_script_parent_warning.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	_script_parent_warning.visible = false
	vbox.add_child(_script_parent_warning)

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

	_script_select_parent_button = Button.new()
	_script_select_parent_button.text = "Select Parent"
	_script_select_parent_button.tooltip_text = "Select the nearest parent that already has a script or Logic Bricks"
	_script_select_parent_button.custom_minimum_size = Vector2(220, 40)
	_script_select_parent_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_script_select_parent_button.visible = false
	_script_select_parent_button.pressed.connect(_on_select_parent_pressed)
	vbox.add_child(_script_select_parent_button)

func _get_parent_with_script_or_logic() -> Node:
	return _selection_helper.get_parent_with_script_or_logic()


func _on_select_parent_pressed() -> void:
	_selection_helper.on_select_parent_pressed()

func _on_open_original_pressed() -> void:
	_selection_helper.on_open_original_pressed()


func _on_edit_instance_pressed() -> void:
	_selection_helper.on_edit_instance_pressed()


func _on_reset_instance_overrides_pressed() -> void:
	_selection_helper.on_reset_instance_overrides_pressed()


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
	frame_order.clear()
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
	_states_helper.apply_view_filter.call_deferred()


## Take a deep copy of the current graph metadata for undo/redo snapshots
func _take_graph_snapshot(target_node: Node = current_node) -> Dictionary:
	return _clipboard_helper.take_graph_snapshot(target_node)

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
	_states_helper.apply_view_filter.call_deferred()


## Called by the plugin when brick data on nodes of the edited scene is about
## to be changed from outside the graph (a node rename). change is a Callable
## returning a Dictionary with "changed": [{node, count}]; the open graph is
## saved first and reloaded afterwards if its node was changed.
func apply_external_brick_change(change: Callable) -> Dictionary:
	# The open graph may hold edits not yet in metadata; store them first so
	# the change works on current data and reloading the graph loses nothing.
	var showing_node: Node = current_node if is_instance_valid(current_node) else null
	if showing_node:
		_suppress_dirty_mark = true
		_save_graph_to_metadata("Edit Logic Bricks", false)
		_suppress_dirty_mark = false
	var result: Dictionary = change.call()
	if showing_node:
		for entry in result.get("changed", []):
			if entry["node"] == showing_node:
				await _selection_helper.update_ui()
				_mark_unapplied_changes()
				break
	return result


func _mark_unapplied_changes() -> void:
	_apply_helper._mark_unapplied_changes()


func _clear_unapplied_changes() -> void:
	_apply_helper._clear_unapplied_changes()


func _warning_node_name(graph_node: GraphNode) -> String:
	return _apply_helper._warning_node_name(graph_node)


func _remove_apply_warning(graph_node: GraphNode) -> void:
	_apply_helper._remove_apply_warning(graph_node)


func _clear_all_apply_warnings() -> void:
	_apply_helper._clear_all_apply_warnings()


func _on_popup_request(position: Vector2) -> void:
	_add_menu_helper._on_popup_request(position)


func _get_selected_framed_bricks() -> Array:
	return _add_menu_helper._get_selected_framed_bricks()


func _on_main_menu_id_pressed(id: int) -> void:
	_add_menu_helper._on_main_menu_id_pressed(id)


func _open_search_popup(screen_pos: Vector2, initial_text: String = "") -> void:
	_search_helper.open_search_popup(screen_pos, initial_text)


func _create_reroute_node(position: Vector2, port_color: Color = Color.WHITE, save_now: bool = true) -> GraphNode:
	return _connections_helper.create_reroute_node(position, port_color, save_now)

func _center_reroute_ports(reroute: GraphNode) -> void:
	_connections_helper.center_reroute_ports(reroute)

func _on_connection_style_selected(index: int) -> void:
	_connections_helper.on_connection_style_selected(index)

func _apply_connection_style(style: String) -> void:
	_connections_helper.apply_connection_style(style)


func _apply_brick_visual_style(graph_node: GraphNode, brick_type: String) -> void:
	_bricks_helper.apply_brick_visual_style(graph_node, brick_type)

func _font_with_graph_oversampling(source: Font) -> Font:
	return _bricks_helper._font_with_graph_oversampling(source)

func _create_graph_node(brick_type: String, brick_class: String, position: Vector2) -> void:
	_bricks_helper.create_graph_node(brick_type, brick_class, position)

func _create_graph_node_from_data(node_data: Dictionary) -> GraphNode:
	return _bricks_helper.create_graph_node_from_data(node_data)

func _create_brick_ui(graph_node: GraphNode, brick_instance) -> void:
	_property_helper._create_brick_ui(graph_node, brick_instance)


func _on_lock_toggled() -> void:
	_selection_helper.on_lock_toggled()

func _on_graph_node_context_menu(id: int, graph_node: GraphNode) -> void:
	await _bricks_helper.on_graph_node_context_menu(id, graph_node)

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

func _on_view_chain_code(controller_node: GraphNode) -> void:
	_apply_helper._on_view_chain_code(controller_node)

func _on_rebuild_from_script_pressed() -> void:
	if not current_node:
		push_error("Logic Bricks: No node selected!")
		return
	if not manager:
		push_error("Logic Bricks: Manager not initialized!")
		return
	# Graph data gone (node re-created, metadata wiped) but the script holds a
	# snapshot: put the whole graph back exactly, layout and frames included.
	var block: String = _script_rebuild_helper._read_generated_block(current_node)
	var graph_nodes = current_node.get_meta("logic_bricks_graph", {}).get("nodes", []) if current_node.get_meta("logic_bricks_graph", {}) is Dictionary else []
	if manager.get_chains(current_node).is_empty() and graph_nodes.is_empty() and not GraphSnapshot.read(block).is_empty():
		await _script_rebuild_helper.rebuild_from_script()
		return
	var synced: bool = await _script_rebuild_helper.sync_from_script()
	if not synced:
		# Legacy scripts created before two-way source-map markers can still use
		# the original best-effort reconstruction path.
		await _script_rebuild_helper.rebuild_from_script()


func _on_apply_code_pressed() -> void:
	await _apply_helper._on_apply_code_pressed()

func _update_global_vars_script() -> void:
	_variables_helper.update_global_vars_script()

func _read_global_vars_from_script() -> Array[Dictionary]:
	return _variables_helper.read_global_vars_from_script()

func _load_variables_from_metadata() -> void:
	_variables_helper.load_variables_from_metadata()

func get_variables_code() -> String:
	return _variables_helper.get_variables_code()

## UI/editing behavior lives in panel_variables_helper.gd. Persistence/code generation live there too.
## ============================================================================

func _on_add_variable_pressed() -> void:
	_variables_helper.add_local_variable()


func _on_add_global_variable_pressed() -> void:
	_variables_helper.add_global_variable()

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

func _on_rename_dialog_confirmed(dialog: AcceptDialog, line_edit: LineEdit) -> void:
	_frames_helper.on_rename_dialog_confirmed(self, dialog, line_edit)

func _on_rename_dialog_canceled(dialog: AcceptDialog) -> void:
	_frames_helper.on_rename_dialog_canceled(self, dialog)

func _mark_scene_modified() -> void:
	_apply_helper._mark_scene_modified()


func clear_runtime_live_debug() -> void:
	_runtime_debug_helper.clear_runtime_live_debug()


func receive_runtime_graph_snapshot_batch(batch: Array) -> void:
	_runtime_debug_helper.receive_runtime_graph_snapshot_batch(batch)


func receive_runtime_brick_activity_batch(batch: Array) -> void:
	_runtime_debug_helper.receive_runtime_brick_activity_batch(batch)


func receive_runtime_brick_activity(runtime_node_path: String, brick_id: String, _state: String = "active") -> void:
	_runtime_debug_helper.receive_runtime_brick_activity(runtime_node_path, brick_id, _state)


