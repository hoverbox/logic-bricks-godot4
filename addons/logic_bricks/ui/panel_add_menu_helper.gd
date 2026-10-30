@tool
extends RefCounted

## The right-click Add menu (Triggers / Gates / Actions built from the brick
## registry), its Options submenu, and the per-brick documentation menu.

const BrickRegistry = preload("res://addons/logic_bricks/core/brick_registry.gd")
const DocumentationHelper = preload("res://addons/logic_bricks/core/documentation_helper.gd")

var panel = null


func setup(target_panel) -> void:
	panel = target_panel


func _create_add_menu() -> void:
	panel.add_menu = PopupMenu.new()
	panel.add_menu.name = "AddMenu"
	panel.add_child(panel.add_menu)

	panel.sensors_menu = PopupMenu.new()
	panel.sensors_menu.name = "SensorsMenu"
	panel.add_menu.add_child(panel.sensors_menu)
	panel.sensors_menu.id_pressed.connect(_on_add_menu_item_selected)
	_enable_brick_menu_doc_right_click(panel.sensors_menu)

	panel.controllers_menu = PopupMenu.new()
	panel.controllers_menu.name = "ControllersMenu"
	panel.add_menu.add_child(panel.controllers_menu)
	panel.controllers_menu.id_pressed.connect(_on_add_menu_item_selected)
	_enable_brick_menu_doc_right_click(panel.controllers_menu)

	panel.actuators_menu = PopupMenu.new()
	panel.actuators_menu.name = "ActuatorsMenu"
	panel.add_menu.add_child(panel.actuators_menu)
	panel.actuators_menu.id_pressed.connect(_on_add_menu_item_selected)
	_enable_brick_menu_doc_right_click(panel.actuators_menu)

	panel.add_menu.add_submenu_item("Triggers", "SensorsMenu", 0)
	panel.add_menu.add_submenu_item("Gates", "ControllersMenu", 1)
	panel.add_menu.add_submenu_item("Actions", "ActuatorsMenu", 2)
	panel._apply_add_menu_colors()
	panel.add_menu.add_separator()
	panel.add_menu.add_item("🔍 Search…", 4)
	panel.add_menu.add_separator()
	panel.add_menu.about_to_popup.connect(_update_frame_removal_menu)

	# Context menu shown after right-clicking a specific brick entry in one of
	# the Add submenus. Keep this separate from the Add menu itself so a right
	# click never adds the brick or opens the browser immediately.
	panel._brick_menu_context_popup = PopupMenu.new()
	panel._brick_menu_context_popup.name = "BrickMenuDocumentationContext"
	panel._brick_menu_context_popup.add_item("View Documentation", 0)
	panel._brick_menu_context_popup.id_pressed.connect(_on_brick_menu_context_id_pressed)
	panel.add_child(panel._brick_menu_context_popup)

	panel.options_menu = PopupMenu.new()
	panel.options_menu.name = "OptionsMenu"
	panel.add_menu.add_child(panel.options_menu)
	panel.options_menu.add_item("Copy", 100)
	panel.options_menu.add_item("Paste", 101)
	panel.options_menu.add_item("Duplicate", 102)
	panel.options_menu.add_separator()
	panel.options_menu.add_item("Save Template", 103)
	panel.options_menu.add_item("Load Template", 104)
	panel.options_menu.add_separator()
	panel.options_menu.add_item("Export Graph Image", 105)
	panel.options_menu.add_item("Sync Bricks from Script", 106)
	panel.options_menu.add_item("Clear Bricks", 107)
	panel.options_menu.add_separator()
	panel.options_menu.add_item("Find Outdated Scripts", 108)
	panel.options_menu.id_pressed.connect(_on_options_menu_id_pressed)
	panel.add_menu.add_submenu_item("Options", "OptionsMenu", 7)
	panel.add_menu.id_pressed.connect(_on_main_menu_id_pressed)

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

	panel.sensors_menu.clear()
	panel.controllers_menu.clear()
	panel.actuators_menu.clear()

	for submenu in panel.actuator_submenus.values():
		if is_instance_valid(submenu):
			panel.actuators_menu.remove_child(submenu)
			submenu.queue_free()
	panel.actuator_submenus.clear()

	var domain = panel.current_brick_domain
	_populate_brick_menu_flat(panel.sensors_menu, BrickRegistry.get_bricks_by_type("sensor", domain))
	_populate_brick_menu_flat(panel.controllers_menu, BrickRegistry.get_bricks_by_type("controller", domain))
	_populate_actuator_menu(BrickRegistry.get_bricks_by_type("actuator", domain))
	panel._apply_popup_menu_sizes()


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

	panel._brick_menu_context_class = brick_class
	panel._brick_menu_context_domain = panel.current_brick_domain
	# Same coordinate space Popup.position uses, so this is also right when
	# the editor embeds popups (single-window mode). Taken before hiding.
	var context_pos: Vector2i = menu.position + Vector2i(menu.get_mouse_position())

	# Close the Add-menu stack, then leave a small context menu at the pointer.
	# The browser is opened only if the user explicitly chooses View Documentation.
	menu.hide()
	if is_instance_valid(panel.add_menu):
		panel.add_menu.hide()
	if is_instance_valid(panel._brick_menu_context_popup):
		panel._brick_menu_context_popup.position = context_pos
		panel._brick_menu_context_popup.reset_size()
		panel._brick_menu_context_popup.popup()


func _on_brick_menu_context_id_pressed(id: int) -> void:
	if id != 0 or panel._brick_menu_context_class.is_empty():
		return
	DocumentationHelper.open_brick(panel._brick_menu_context_class, panel._brick_menu_context_domain)
	panel._brick_menu_context_class = ""
	panel._brick_menu_context_domain = ""


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
		if candidate_domain == panel.current_brick_domain and current_domain != panel.current_brick_domain:
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
	if panel.current_brick_domain == "ui":
		_populate_brick_menu_flat(panel.actuators_menu, bricks)
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
			_populate_brick_menu_flat(panel.actuators_menu, group_items)
		else:
			var submenu = PopupMenu.new()
			var submenu_name = "ActuatorSub_" + category.replace(" ", "_").replace("/", "_")
			submenu.name = submenu_name
			panel.actuators_menu.add_child(submenu)
			submenu.id_pressed.connect(_on_add_menu_item_selected)
			_enable_brick_menu_doc_right_click(submenu)
			panel.actuator_submenus[submenu_name] = submenu
			_populate_brick_menu_flat(submenu, group_items)
			panel.actuators_menu.add_submenu_item(category, submenu_name)


func _on_popup_request(position: Vector2) -> void:
	if not panel.current_node or panel.current_node.get_script() == null:
		return
	# Store the position accounting for scroll offset
	# position is in local graph coordinates, we need to add scroll offset
	panel.last_mouse_position = (position + panel.graph_edit.scroll_offset) / panel.graph_edit.zoom
	# Rescan before opening so newly added brick scripts appear without
	# manual registration or hard-coded menu edits.
	_refresh_add_menu_from_registry(true)

	# Position the menu at the click location in screen coordinates
	var screen_pos = panel.graph_edit.get_screen_position() + position
	_update_frame_removal_menu()
	panel.add_menu.position = screen_pos
	panel.add_menu.popup()


func _get_selected_framed_bricks() -> Array:
	var bricks: Array = []
	for child in panel.graph_edit.get_children():
		if child is GraphNode and child.selected and child.has_meta("brick_data") and panel._frames_helper._get_smallest_mapped_frame_for_node(panel, child) != null:
			bricks.append(child)
	return bricks


func _update_frame_removal_menu() -> void:
	var index = panel.add_menu.get_item_index(5)
	if index >= 0:
		panel.add_menu.remove_item(index)
	if not _get_selected_framed_bricks().is_empty():
		panel.add_menu.add_item("Remove From Frame", 5)
	panel.add_menu.reset_size()


func _on_main_menu_id_pressed(id: int) -> void:
	if id == 4:
		panel._open_search_popup(panel.add_menu.position)
	elif id == 5:
		var bricks := _get_selected_framed_bricks()
		if bricks.is_empty():
			return
		var before_snapshot = panel._take_graph_snapshot()
		for brick in bricks:
			panel._frames_helper.remove_node_from_frames(panel, brick, false)
		panel._record_undo("Remove Logic Bricks from Frames", before_snapshot, panel._take_graph_snapshot(), panel.current_node, false)


func _on_options_menu_id_pressed(id: int) -> void:
	match id:
		100:
			panel._on_copy_bricks_pressed()
		101:
			await panel._on_paste_bricks_pressed()
		102:
			await panel._on_duplicate_bricks_pressed()
		103:
			panel._on_save_template_pressed()
		104:
			panel._on_load_template_pressed()
		105:
			panel._on_export_graph_image_pressed()
		106:
			await panel._on_rebuild_from_script_pressed()
		107:
			await _on_clear_bricks_pressed()
		108:
			panel._version_helper.show_outdated_scripts_report()


func _on_clear_bricks_pressed() -> void:
	if not panel.current_node:
		return

	# Confirm before wiping; the custom graph snapshot below provides undo.
	var confirm = ConfirmationDialog.new()
	confirm.title = "Clear Bricks"
	confirm.dialog_text = "Remove all Logic Bricks data from \"%s\"?\n\nThis clears bricks, frames, variables, and states. You can undo this action." % panel.current_node.name
	confirm.ok_button_text = "Clear"
	panel.add_child(confirm)
	# Wait for either button (or the window's close box). Awaiting only
	# "confirmed" left the dialog and this coroutine alive after every Cancel.
	var choice := {"done": false, "ok": false}
	confirm.confirmed.connect(func(): choice["ok"] = true; choice["done"] = true)
	confirm.canceled.connect(func(): choice["done"] = true)
	confirm.popup_centered()
	while not choice["done"] and is_instance_valid(confirm) and panel.is_inside_tree():
		await panel.get_tree().process_frame
	if is_instance_valid(confirm):
		confirm.queue_free()
	if not choice["ok"]:
		return

	if not panel.current_node or not is_instance_valid(panel.current_node):
		return

	# Clear the visual canvas, including frames and their in-memory state.
	var before_snapshot = panel._take_graph_snapshot()
	panel._clear_graph_display()

	# Remove all node-specific Logic Bricks metadata.
	for key in ["logic_bricks", "logic_bricks_graph", "logic_bricks_frames",
				"logic_bricks_states", "logic_bricks_variables",
				"logic_bricks_global_usage", "logic_bricks_debug_watch_state",
				"logic_bricks_generated_source_hash"]:
		if panel.current_node.has_meta(key):
			panel.current_node.remove_meta(key)

	# Persist the now-empty graph so downstream saves don't resurrect old data
	panel._save_graph_to_metadata("Clear Logic Bricks", false)
	panel._mark_scene_modified()
	panel._record_undo("Clear Logic Bricks", before_snapshot, panel._take_graph_snapshot())

	# Reset state UI to defaults
	panel._load_states_from_metadata(true)
	panel._load_variables_from_metadata()

	push_warning("Logic Bricks: All node logic cleared from '%s'. Script markers remain — remove them manually if needed." % panel.current_node.name)


func _on_add_menu_item_selected(id: int) -> void:
	var metadata = _get_brick_menu_metadata(id)
	if metadata:
		var brick_type = metadata["type"]
		var brick_class = metadata["class"]
		var before_snapshot = panel._take_graph_snapshot()
		panel._create_graph_node(brick_type, brick_class, panel.last_mouse_position)
		panel._record_undo("Add Logic Brick", before_snapshot, panel._take_graph_snapshot())


func _get_brick_menu_metadata(id: int):
	# Auto-discovered bricks use registry-assigned IDs, so do not assume
	# sensors/controllers/actuators live in fixed numeric ranges.
	for menu in [panel.sensors_menu, panel.controllers_menu, panel.actuators_menu]:
		var item_index = menu.get_item_index(id)
		if item_index >= 0:
			return menu.get_item_metadata(item_index)

	for submenu in panel.actuator_submenus.values():
		if not is_instance_valid(submenu):
			continue
		var sub_index = submenu.get_item_index(id)
		if sub_index >= 0:
			return submenu.get_item_metadata(sub_index)

	return null
