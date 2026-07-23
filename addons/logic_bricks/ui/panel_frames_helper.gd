extends RefCounted

func on_add_frame_pressed(panel) -> void:
	var selected_nodes: Array[Node] = []
	for child in panel.graph_edit.get_children():
		if child is GraphNode and child.selected:
			selected_nodes.append(child)

	var frame = GraphFrame.new()
	var frame_id = Time.get_ticks_msec()
	frame.name = "Frame_%d" % frame_id
	frame.resizable = true
	frame.draggable = true
	frame.tint_color_enabled = true
	frame.tint_color = Color(0.3, 0.5, 0.7, 0.5)

	panel.frame_titles[frame.name] = "New Frame"
	panel.frame_comments[frame.name] = ""

	if not selected_nodes.is_empty():
		fit_frame_to_nodes(panel, frame, selected_nodes)
		var node_names: Array = []
		for node in selected_nodes:
			node_names.append(node.name)
		panel.frame_node_mapping[frame.name] = node_names
	else:
		frame.position_offset = panel.graph_edit.scroll_offset + Vector2(100, 100)
		frame.size = Vector2(400, 300)
		panel.frame_node_mapping[frame.name] = []

	create_frame_ui(panel, frame)
	frame.dragged.connect(panel._on_frame_dragged.bind(frame))
	frame.resize_request.connect(panel._on_frame_resize_request.bind(frame))
	panel.graph_edit.add_child(frame)
	update_frames_list(panel)
	save_frames_to_metadata(panel)

func create_frame_ui(panel, frame: GraphFrame) -> void:
	frame.title = panel.frame_titles.get(frame.name, "New Frame")
	_apply_frame_comment_tooltip(panel, frame)

func _apply_frame_comment_tooltip(panel, frame: GraphFrame) -> void:
	var comment: String = str(panel.frame_comments.get(frame.name, "")).strip_edges()
	frame.tooltip_text = comment if not comment.is_empty() else frame.title

func fit_frame_to_nodes(panel, frame: GraphFrame, nodes: Array[Node]) -> void:
	if nodes.is_empty():
		return

	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)

	for node in nodes:
		if node is GraphNode:
			min_pos.x = min(min_pos.x, node.position_offset.x)
			min_pos.y = min(min_pos.y, node.position_offset.y)
			max_pos.x = max(max_pos.x, node.position_offset.x + node.size.x)
			max_pos.y = max(max_pos.y, node.position_offset.y + node.size.y)

	var padding = Vector2(20, 40)
	frame.position_offset = min_pos - padding
	frame.size = (max_pos - min_pos) + padding * 2

func auto_resize_frame(panel, frame: GraphFrame) -> void:
	if not panel.frame_node_mapping.has(frame.name):
		return

	var nodes_to_fit: Array[Node] = []
	for node_name in panel.frame_node_mapping[frame.name]:
		var node = panel.graph_edit.get_node_or_null(NodePath(node_name))
		if node and node is GraphNode:
			nodes_to_fit.append(node)

	fit_frame_to_nodes(panel, frame, nodes_to_fit)
	save_frames_to_metadata(panel)

func on_graph_node_dragged(panel, node: GraphNode, from: Vector2, to: Vector2) -> void:
	check_node_frame_membership(panel, node)

	for frame_name in panel.frame_node_mapping.keys():
		if node.name in panel.frame_node_mapping[frame_name]:
			var frame = panel.graph_edit.get_node_or_null(NodePath(frame_name))
			if frame and frame is GraphFrame:
				auto_resize_frame(panel, frame)

func on_frame_dragged(panel, from: Vector2, to: Vector2, frame: GraphFrame) -> void:
	var delta = to - from

	if panel.frame_node_mapping.has(frame.name):
		for node_name in panel.frame_node_mapping[frame.name]:
			var node = panel.graph_edit.get_node_or_null(NodePath(node_name))
			if node and node is GraphNode:
				node.position_offset += delta

	save_frames_to_metadata(panel)

func on_frame_resize_request(panel, new_size: Vector2, frame: GraphFrame) -> void:
	frame.size = new_size
	save_frames_to_metadata(panel)

func check_node_frame_membership(panel, moved_node: GraphNode) -> void:
	if not moved_node:
		return

	var node_rect = Rect2(moved_node.position_offset, moved_node.size)
	var node_center = node_rect.get_center()

	for child in panel.graph_edit.get_children():
		if not (child is GraphFrame):
			continue

		var frame = child as GraphFrame
		var current_members = panel.frame_node_mapping.get(frame.name, [])

		if moved_node.name in current_members:
			auto_resize_frame(panel, frame)
			save_frames_to_metadata(panel)
		else:
			var frame_rect = Rect2(frame.position_offset, frame.size)
			var is_inside = frame_rect.has_point(node_center)
			if is_inside:
				current_members.append(moved_node.name)
				panel.frame_node_mapping[frame.name] = current_members
				auto_resize_frame(panel, frame)
				save_frames_to_metadata(panel)

func save_frames_to_metadata(panel, record_change: bool = true, action_name: String = "Edit Logic Brick Frame") -> void:
	if not panel.current_node or not is_instance_valid(panel.current_node):
		return

	var target_node = panel.current_node
	var before_snapshot = panel._take_graph_snapshot()
	var frames_data = []
	for child in panel.graph_edit.get_children():
		if child is GraphFrame and not child.is_queued_for_deletion():
			frames_data.append({
				"name": child.name,
				"title": panel.frame_titles.get(child.name, "Frame"),
				"comment": panel.frame_comments.get(child.name, ""),
				"position": child.position_offset,
				"size": child.size,
				"color": child.tint_color,
				"nodes": panel.frame_node_mapping.get(child.name, [])
			})

	target_node.set_meta("logic_bricks_frames", frames_data)
	panel._mark_scene_modified()
	if record_change:
		panel._record_undo(action_name, before_snapshot, panel._take_graph_snapshot(), target_node, true)

func load_frames_from_metadata(panel) -> void:
	if not panel.graph_edit:
		return

	var frames_to_remove = []
	for child in panel.graph_edit.get_children():
		if child is GraphFrame:
			frames_to_remove.append(child)
	for frame in frames_to_remove:
		panel.graph_edit.remove_child(frame)
		frame.free()

	panel.frame_node_mapping.clear()
	panel.frame_titles.clear()
	panel.frame_comments.clear()

	if panel.current_node and panel.current_node.has_meta("logic_bricks_frames"):
		var frames_data = panel.current_node.get_meta("logic_bricks_frames")
		for frame_data in frames_data:
			var frame = GraphFrame.new()
			frame.name = frame_data.get("name", "Frame")
			frame.position_offset = frame_data.get("position", Vector2.ZERO)
			frame.size = frame_data.get("size", Vector2(400, 300))
			frame.tint_color = frame_data.get("color", Color(0.3, 0.5, 0.7, 0.5))
			frame.tint_color_enabled = true
			frame.resizable = true
			frame.draggable = true

			panel.frame_titles[frame.name] = frame_data.get("title", "Frame")
			panel.frame_comments[frame.name] = frame_data.get("comment", "")
			panel.frame_node_mapping[frame.name] = frame_data.get("nodes", [])

			create_frame_ui(panel, frame)
			frame.dragged.connect(panel._on_frame_dragged.bind(frame))
			frame.resize_request.connect(panel._on_frame_resize_request.bind(frame))
			panel.graph_edit.add_child(frame)

	update_frames_list(panel)

func on_frame_list_item_selected(panel, index: int) -> void:
	var frame_name = panel.frames_list.get_item_metadata(index)
	panel.selected_frame = panel.graph_edit.get_node_or_null(NodePath(frame_name))

	if panel.selected_frame:
		update_frame_settings_ui(panel)
		panel.frame_settings_container.visible = true

		var color_wheel = panel.frames_panel.find_child("FrameListColorPicker", true, false)
		if color_wheel:
			color_wheel.color = panel.selected_frame.tint_color
	else:
		panel.frame_settings_container.visible = false

func update_frame_settings_ui(panel) -> void:
	if not panel.selected_frame:
		return

	var name_edit = panel.frame_settings_container.find_child("FrameNameEdit", true, false)
	var comment_edit = panel.frame_settings_container.find_child("FrameCommentEdit", true, false)
	var color_picker = panel.frame_settings_container.find_child("FrameColorPicker", true, false)
	var width_spin = panel.frame_settings_container.find_child("FrameWidthSpin", true, false)
	var height_spin = panel.frame_settings_container.find_child("FrameHeightSpin", true, false)

	if name_edit:
		name_edit.text = panel.frame_titles.get(panel.selected_frame.name, panel.selected_frame.name)
	if comment_edit:
		comment_edit.text = panel.frame_comments.get(panel.selected_frame.name, "")
	if color_picker:
		color_picker.color = panel.selected_frame.tint_color
	if width_spin:
		width_spin.value = panel.selected_frame.size.x
	if height_spin:
		height_spin.value = panel.selected_frame.size.y

func on_frame_name_changed(panel, new_name: String) -> void:
	if not panel.selected_frame:
		return

	panel.frame_titles[panel.selected_frame.name] = new_name
	panel.selected_frame.title = new_name
	update_frames_list(panel)
	save_frames_to_metadata(panel)

func on_frame_comment_changed(panel) -> void:
	if not panel.selected_frame:
		return

	var comment_edit = panel.frame_settings_container.find_child("FrameCommentEdit", true, false)
	if not comment_edit:
		return

	panel.frame_comments[panel.selected_frame.name] = comment_edit.text
	_apply_frame_comment_tooltip(panel, panel.selected_frame)
	update_frames_list(panel)
	save_frames_to_metadata(panel)

func on_frame_color_changed(panel, new_color: Color) -> void:
	if not panel.selected_frame:
		return

	panel.selected_frame.tint_color = new_color
	panel.selected_frame.tint_color_enabled = true
	panel.selected_frame.queue_redraw()

	var color_wheel = panel.frames_panel.find_child("FrameListColorPicker", true, false)
	if color_wheel:
		color_wheel.color = new_color

	save_frames_to_metadata(panel)

func on_frame_resize_pressed(panel) -> void:
	if panel.selected_frame:
		auto_resize_frame(panel, panel.selected_frame)

func on_frame_width_changed(panel, new_width: float) -> void:
	if panel.selected_frame:
		panel.selected_frame.size.x = new_width
		save_frames_to_metadata(panel)

func on_frame_height_changed(panel, new_height: float) -> void:
	if panel.selected_frame:
		panel.selected_frame.size.y = new_height
		save_frames_to_metadata(panel)

func on_frame_delete_pressed(panel) -> void:
	if not panel.selected_frame:
		return

	var frame_to_delete = panel.selected_frame
	var frame_name = frame_to_delete.name

	panel.selected_frame = null
	panel.frame_node_mapping.erase(frame_name)
	panel.frame_titles.erase(frame_name)
	panel.frame_comments.erase(frame_name)

	if is_instance_valid(frame_to_delete):
		var parent = frame_to_delete.get_parent()
		if parent:
			parent.remove_child(frame_to_delete)
		frame_to_delete.free()

	panel.frame_settings_container.visible = false

	panel.frames_list.deselect_all()

	update_frames_list(panel)
	save_frames_to_metadata(panel)

func update_frames_list(panel) -> void:
	panel.frames_list.clear()

	for child in panel.graph_edit.get_children():
		if child is GraphFrame and not child.is_queued_for_deletion():
			var display_name = panel.frame_titles.get(child.name, child.name)
			panel.frames_list.add_item(display_name)
			var item_index: int = panel.frames_list.get_item_count() - 1
			panel.frames_list.set_item_metadata(item_index, child.name)
			var comment: String = str(panel.frame_comments.get(child.name, "")).strip_edges()
			panel.frames_list.set_item_tooltip(item_index, comment if not comment.is_empty() else display_name)

func select_frame_in_side_panel(panel, frame: GraphFrame) -> void:
	if not frame:
		return

	panel.side_panel.current_tab = 2
	for i in range(panel.frames_list.get_item_count()):
		if panel.frames_list.get_item_metadata(i) == frame.name:
			panel.frames_list.select(i)
			on_frame_list_item_selected(panel, i)
			break

func on_frame_list_item_activated(panel, index: int) -> void:
	# Double-clicking a frame in the side panel navigates directly to it.
	on_frame_list_item_selected(panel, index)
	center_graph_on_frame(panel, panel.selected_frame)

func center_graph_on_frame(panel, frame: GraphFrame) -> void:
	if not is_instance_valid(frame) or not is_instance_valid(panel.graph_edit):
		return

	var viewport_size: Vector2 = panel.graph_edit.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	# Fit the complete frame in view while leaving a comfortable margin.
	var margin := Vector2(100.0, 100.0)
	var available_size := Vector2(
		maxf(viewport_size.x - margin.x, 1.0),
		maxf(viewport_size.y - margin.y, 1.0)
	)
	var frame_size := Vector2(maxf(frame.size.x, 1.0), maxf(frame.size.y, 1.0))
	var target_zoom: float = minf(available_size.x / frame_size.x, available_size.y / frame_size.y)
	target_zoom = clampf(target_zoom, panel.graph_edit.zoom_min, panel.graph_edit.zoom_max)
	panel.graph_edit.zoom = target_zoom

	var frame_center: Vector2 = frame.position_offset + frame.size * 0.5
	panel.graph_edit.scroll_offset = frame_center * target_zoom - viewport_size * 0.5

func on_frame_rename_button_pressed(panel) -> void:
	if not panel.selected_frame:
		return

	var selected_index = -1
	for i in range(panel.frames_list.get_item_count()):
		if panel.frames_list.is_selected(i):
			selected_index = i
			break

	if selected_index < 0:
		return

	var dialog = AcceptDialog.new()
	dialog.title = "Rename Frame"
	dialog.dialog_autowrap = true

	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)

	var label = Label.new()
	label.text = "New frame name:"
	vbox.add_child(label)

	var line_edit = LineEdit.new()
	line_edit.text = panel.frame_titles.get(panel.selected_frame.name, panel.selected_frame.name)
	line_edit.custom_minimum_size = Vector2(200, 0)
	line_edit.select_all()
	vbox.add_child(line_edit)

	dialog.confirmed.connect(panel._on_rename_dialog_confirmed.bind(dialog, line_edit))
	dialog.canceled.connect(panel._on_rename_dialog_canceled.bind(dialog))

	panel.add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()

func on_rename_dialog_confirmed(panel, dialog: AcceptDialog, line_edit: LineEdit) -> void:
	var new_name = line_edit.text.strip_edges()
	if not new_name.is_empty():
		panel.frame_titles[panel.selected_frame.name] = new_name
		panel.selected_frame.title = new_name

		var name_edit = panel.frame_settings_container.get_node_or_null("FrameNameEdit")
		if name_edit:
			name_edit.text = new_name

		update_frames_list(panel)
		save_frames_to_metadata(panel)
	dialog.queue_free()

func on_rename_dialog_canceled(panel, dialog: AcceptDialog) -> void:
	dialog.queue_free()

func on_frame_list_color_changed(panel, new_color: Color) -> void:
	if not panel.selected_frame:
		return

	panel.selected_frame.tint_color = new_color
	panel.selected_frame.tint_color_enabled = true
	panel.selected_frame.queue_redraw()

	var settings_color_picker = panel.frame_settings_container.find_child("FrameColorPicker", true, false)
	if settings_color_picker:
		settings_color_picker.color = new_color

	save_frames_to_metadata(panel)
