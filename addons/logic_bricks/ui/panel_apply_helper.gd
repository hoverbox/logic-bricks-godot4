@tool
extends RefCounted

## Apply Code: writing the generated script, creating the scene nodes bricks
## need, the "unapplied changes" marker, per-brick warnings after Apply, and
## View Chain Code / Add Script.

var panel = null


func setup(target_panel) -> void:
	panel = target_panel


func _on_add_script_pressed() -> void:
	if not panel.current_node or panel.current_node.get_script():
		panel._update_ui()
		return

	# Physics scene roots own gameplay logic for their scene. Do not let a child
	# accidentally receive its own script, even if the root has no script yet.
	if panel._get_parent_with_script_or_logic():
		push_warning("Logic Bricks: Cannot add a script to a child of a physics object. Add Logic Bricks to the physics parent instead.")
		panel._update_ui()
		return

	var scene_root = panel.editor_interface.get_edited_scene_root() if panel.editor_interface else null
	var scene_dir = scene_root.scene_file_path.get_base_dir() if scene_root and not scene_root.scene_file_path.is_empty() else "res://"
	var base_name = panel.current_node.name.to_snake_case().validate_filename()
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
	file.store_string("extends %s\n" % panel.current_node.get_class())
	file.close()

	if panel.editor_interface:
		panel.editor_interface.get_resource_filesystem().update_file(script_path)
	var script = ResourceLoader.load(script_path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	if not script:
		push_error("Logic Bricks: Script was created but could not be loaded: %s" % script_path)
		return

	panel.current_node.set_script(script)
	if panel.editor_interface:
		panel.editor_interface.mark_scene_as_unsaved()
	panel._update_ui()


func _mark_unapplied_changes() -> void:
	if panel._suppress_dirty_mark:
		return
	panel._has_unapplied_changes = true
	panel._dirty_indicator_token += 1
	var token = panel._dirty_indicator_token
	# Deliberately delayed so the UI does not nag during every click/keystroke.
	panel.get_tree().create_timer(1.5).timeout.connect(func():
		if token == panel._dirty_indicator_token and panel._has_unapplied_changes and is_instance_valid(panel._apply_code_button):
			panel._apply_code_button.text = "Apply Code  •"
			panel._apply_code_button.tooltip_text = "The graph has changes that have not been applied to the script yet."
	)


func _clear_unapplied_changes() -> void:
	panel._has_unapplied_changes = false
	panel._dirty_indicator_token += 1
	if is_instance_valid(panel._apply_code_button):
		panel._apply_code_button.text = "Apply Code"
		panel._apply_code_button.tooltip_text = ""


func _warning_node_name(graph_node: GraphNode) -> String:
	return "apply_warning_" + str(graph_node.name)


func _remove_apply_warning(graph_node: GraphNode) -> void:
	var warning = panel.graph_edit.get_node_or_null(NodePath(_warning_node_name(graph_node)))
	if warning:
		panel.graph_edit.remove_child(warning)
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
	panel.graph_edit.add_child(warning)
	warning.size = warning.get_combined_minimum_size()
	warning.position_offset = graph_node.position_offset + Vector2(0, -warning.size.y - 10)


func _show_apply_toast(report: Dictionary, severity: int) -> void:
	var message := str(report.get("message", "")).strip_edges()
	if message.is_empty() or not panel.editor_interface:
		return
	var toaster = panel.editor_interface.get_editor_toaster()
	if toaster:
		toaster.push_toast("Logic Bricks: " + message, severity)


func _refresh_apply_validation_warnings() -> void:
	if not panel._apply_validation_active or not is_instance_valid(panel.graph_edit):
		return
	# Apply Code is the validation checkpoint. Rebuild the warning set from
	# exactly the bricks that exist at this moment; later edits do not add
	# warnings until Apply Code is pressed again.
	_clear_all_apply_warnings()
	var typing_popup: PopupMenu = panel._typing_notice.get_popup() if panel._typing_notice else null
	if typing_popup: typing_popup.clear()
	var typing_count := 0
	var connections = panel.graph_edit.get_connection_list()
	var has_character_physics_chain := _has_always_character_physics_chain()
	for child in panel.graph_edit.get_children():
		if not (child is GraphNode and child.has_meta("brick_data")):
			continue
		var messages: Array[String] = []
		if not panel._graph_helper.is_brick_in_complete_chain(child, connections):
			messages.append("Incomplete Brick Chain")
		var brick_data: Dictionary = child.get_meta("brick_data")
		var brick_instance = brick_data.get("brick_instance")
		for text in panel._property_helper.typing_assistance.warnings_for(child):
			messages.append(text)
			if typing_popup:
				typing_popup.add_item(child.title + ": " + text, typing_count)
				typing_popup.set_item_metadata(typing_count, str(child.name))
			typing_count += 1
		if brick_instance and brick_instance.has_method("get_configuration_warnings"):
			for message in brick_instance.call("get_configuration_warnings", panel.current_node):
				var text := str(message).strip_edges()
				if not text.is_empty():
					messages.append(text)
		if str(brick_data.get("brick_class", "")) == "PositionActuator" and brick_instance != null:
			var movement_method := str(brick_instance.get_property("movement_method", "character_velocity")).to_lower().replace(" ", "_")
			if movement_method == "character_velocity" and not has_character_physics_chain:
				messages.append("Character Velocity needs an Always connected to Character Physics")
		var report: Dictionary = panel.manager.last_apply_report if panel.manager else {}
		if not str(report.get("graph_node_id", "")).is_empty() and str(report["graph_node_id"]) == str(child.name):
			messages.append(str(report.get("short_message", "Generated code error")))
		_set_apply_warning(child, messages)
	if panel._typing_notice:
		panel._typing_notice.text = "⚠ Names: %d" % typing_count
		panel._typing_notice.visible = typing_count > 0


func _has_always_character_physics_chain() -> bool:
	for chain in panel._graph_helper.extract_chains_from_graph(false):
		var has_always := false
		var has_character_physics := false
		for sensor in chain.get("sensors", []):
			if str(sensor.get("type", "")) == "AlwaysSensor":
				has_always = true
				break
		for actuator in chain.get("actuators", []):
			if str(actuator.get("type", "")) == "CharacterActuator":
				has_character_physics = true
				break
		if has_always and has_character_physics:
			return true
	return false


func _clear_all_apply_warnings() -> void:
	if panel._typing_notice:
		panel._typing_notice.visible = false
		panel._typing_notice.get_popup().clear()
	# Ignore late callbacks during plugin teardown/reload.
	if not is_instance_valid(panel.graph_edit):
		return
	var warnings_to_remove: Array[Node] = []
	for child in panel.graph_edit.get_children():
		if child is GraphNode and str(child.name).begins_with("apply_warning_"):
			warnings_to_remove.append(child)
	for warning in warnings_to_remove:
		panel.graph_edit.remove_child(warning)
		warning.queue_free()


func _on_view_chain_code(controller_node: GraphNode) -> void:
	# Open the generated script and jump to this chain's function
	if not panel.current_node or not panel.editor_interface:
		return

	var script = panel.current_node.get_script()
	if not script:
		push_warning("Logic Bricks: No script on this node. Click 'Apply Code' first.")
		return

	# Get chain name from controller node
	var func_name: String = panel._graph_helper.get_chain_function_name(controller_node)
	if func_name.is_empty():
		push_warning("Logic Bricks: This chain is not complete yet, so it has no code. Connect a trigger and an action, then click 'Apply Code'.")
		return

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
	panel.editor_interface.set_main_screen_editor("Script")
	panel.editor_interface.edit_script(script, line_number)


func _on_apply_code_pressed() -> void:
	panel._variables_helper.flush_pending_typing()
	pass

	if not panel.current_node:
		push_error("Logic Bricks: No node selected!")
		return

	if not panel.manager:
		push_error("Logic Bricks: Manager not initialized!")
		return

	if not panel.editor_interface:
		push_error("Logic Bricks: Editor interface not available!")
		return

	# Check for a script before touching anything. This used to run after the
	# chain metadata was removed, so Apply on a script-less node deleted the
	# chains that Rebuild from Script and the plugin rely on.
	if not panel.current_node.get_script():
		push_error("Logic Bricks: Selected node has no script. Click Add Script to Node first.")
		return

	# Two-way source sync: if a student edited generated GDScript since the
	# previous Apply, import recoverable values into the bricks before regenerating.
	var apply_node: Node = panel.current_node
	await panel._script_rebuild_helper.sync_from_script_if_changed()
	# The sync can wait for frames. If another node was selected meanwhile,
	# stop rather than apply this node's request to the other node.
	if panel.current_node != apply_node:
		push_warning("Logic Bricks: Apply Code was cancelled because the selection changed. Press Apply Code again.")
		return

	# Forget the previous Apply's generated-code error until this Apply decides.
	panel.manager.last_apply_report = {}
	panel._apply_validation_active = true
	_refresh_apply_validation_warnings()

	panel._graph_helper.sync_graph_ui_to_bricks()
	panel._save_graph_to_metadata()

	# Extract chains
	var chains = panel._graph_helper.extract_chains_from_graph()

	# Clear old metadata (only reached when the node has a script; see above).
	if panel.current_node.has_meta("logic_bricks"):
		panel.current_node.remove_meta("logic_bricks")

	# Get script path before regeneration
	var script_path = panel.current_node.get_script().resource_path

	# Get variables code
	var variables_code = panel.get_variables_code()

	# Save graph metadata first, then regenerate. The manager parse-checks the
	# candidate: it still writes when the error comes from generated code (so an
	# incomplete brick never blocks Apply), and returns false only when the write
	# failed or the student's own code would have been damaged.
	panel.manager.save_chains(panel.current_node, chains)
	if not panel.manager.regenerate_script(panel.current_node, variables_code):
		_show_apply_toast(panel.manager.last_apply_report, EditorToaster.SEVERITY_ERROR)
		push_error("Logic Bricks: Apply Code failed. Your existing script was not modified.")
		return
	panel._script_rebuild_helper.record_current_script_hash()
	_apply_required_project_settings(chains)
	if str(panel.manager.last_apply_report.get("status", "ok")) != "ok":
		_show_apply_toast(panel.manager.last_apply_report, EditorToaster.SEVERITY_WARNING)
	# Show (or clear) a generated-code error on the brick that produced it.
	_refresh_apply_validation_warnings()

	# Phase 1: create any required scene nodes (CanvasLayer, ColorRect, etc.)
	# @export var assignment happens in Phase 2 AFTER set_script() below,
	# because set_script() resets all properties to their defaults.
	_apply_scene_setup_create(panel.current_node, chains)

	# Get script path if we didn't have one
	if script_path.is_empty() and panel.current_node.get_script():
		script_path = panel.current_node.get_script().resource_path

	if script_path.is_empty():
		push_error("Logic Bricks: No script path available!")
		return

	# Do not save the scene here. Apply Code should only regenerate/reload the
	# script and create required helper nodes in the live editor scene. Saving the
	# whole scene on every click is expensive in larger projects and makes Apply
	# Code feel slow. The minimize/restore refresh below is intentionally kept; it
	# is still the reliable way to make Godot refresh the script/export state.

	# Force filesystem to update
	var filesystem = panel.editor_interface.get_resource_filesystem()
	filesystem.update_file(script_path)

	# Snapshot current_node before awaiting — the user may click away during the
	# yield, setting current_node to null or a different node.
	var _apply_node = panel.current_node

	# Wait a frame
	await panel.get_tree().process_frame

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
	panel._version_helper.refresh_notice()

	# Phase 2: assign @export vars now that the new script is live.
	# This MUST come after set_script() or the assignments get wiped.
	await panel.get_tree().process_frame
	if is_instance_valid(_apply_node):
		_apply_scene_setup_assign(_apply_node, chains)

	# Minimize/restore is the only reliable way to force Godot to rebuild
	# the inspector's @export slots after a script reload.
	# Hide all secondary Window nodes first — any visible child Window (including
	# the addon pop-out or other editor sub-windows) can prevent the OS-level
	# focus loss that makes the hack work, and can also steal the restore signal
	# leaving the main window stuck minimized.
	var was_popout_open = panel._popout_window != null
	if was_popout_open:
		panel._popout_window.hide()

	# Also hide any other top-level Windows that are currently visible.
	var other_windows: Array[Window] = []
	for child in panel.get_tree().root.get_children():
		if child is Window and child.visible and child != panel.get_tree().root:
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
	_finish_apply_window_refresh.call_deferred(restore_mode, other_windows, was_popout_open, reloaded_script)


## Mark the scene as modified so changes are saved
func _mark_scene_modified() -> void:
	if not panel.editor_interface:
		return

	# Mark the currently edited scene as unsaved
	# This is the correct way to tell Godot the scene needs saving
	panel.editor_interface.mark_scene_as_unsaved()


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

	if was_popout_open and panel._popout_window:
		panel._popout_window.show()

	# Open the script in the script editor after the refresh snap-back.
	if is_instance_valid(reloaded_script):
		panel.editor_interface.edit_script(reloaded_script, 1)


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


## Turns on project settings that bricks on this node need
## (LogicBrick.get_required_project_settings()), saves project.godot and says
## so. Engine-wide settings such as physics interpolation must be on before a
## scene loads; switching them from generated code at runtime breaks the scene.
func _apply_required_project_settings(chains: Array) -> void:
	var needed := {}
	for chain in chains:
		for key in ["sensors", "controllers", "actuators"]:
			for brick_data in chain.get(key, []):
				if not (brick_data is Dictionary):
					continue
				var brick = panel.manager._instantiate_brick(brick_data)
				if brick and brick.has_method("get_required_project_settings"):
					needed.merge(brick.get_required_project_settings(), true)
	var changed := PackedStringArray()
	for setting in needed:
		if ProjectSettings.get_setting(setting) != needed[setting]:
			ProjectSettings.set_setting(setting, needed[setting])
			changed.append(setting)
	if changed.is_empty():
		return
	ProjectSettings.save()
	var message := "Logic Bricks turned on a project setting this node's bricks need: %s. Restart the running game for it to take effect." % ", ".join(changed)
	print(message)
	if panel.editor_interface and panel.editor_interface.has_method("get_editor_toaster"):
		panel.editor_interface.get_editor_toaster().push_toast(message, EditorToaster.SEVERITY_INFO)
