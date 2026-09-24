extends RefCounted

var panel = null

func setup(target_panel) -> void:
	panel = target_panel

func create_graph_image_dialog() -> void:
	panel._graph_image_dialog = FileDialog.new()
	panel._graph_image_dialog.title = "Export Logic Bricks Graph Image"
	panel._graph_image_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	panel._graph_image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	panel._graph_image_dialog.filters = PackedStringArray(["*.png ; PNG Image"])
	panel._graph_image_dialog.current_file = "logic_bricks_graph.png"
	panel._graph_image_dialog.file_selected.connect(on_graph_image_path_selected)
	panel.add_child(panel._graph_image_dialog)

func on_export_graph_image_pressed() -> void:
	if not panel.current_node:
		push_warning("Logic Bricks: Select a node before exporting the graph.")
		return
	panel._graph_image_dialog.popup_centered_ratio(0.65)

func on_graph_image_path_selected(path: String) -> void:
	await export_graph_image(path)

func export_graph_image(path: String) -> void:
	if not path.to_lower().ends_with(".png"):
		path += ".png"

	var selected_names: Dictionary = {}
	var export_items: Array[GraphElement] = []
	var bounds := Rect2()
	var has_bounds := false

	for child in panel.graph_edit.get_children():
		if child is GraphNode and child.selected:
			selected_names[child.name] = true

	var selection_only := not selected_names.is_empty()
	var included_frame_names: Dictionary = {}
	if selection_only:
		for frame_name in panel.frame_node_mapping.keys():
			var members: Array = panel.frame_node_mapping.get(frame_name, [])
			for member_name in members:
				if selected_names.has(str(member_name)):
					included_frame_names[str(frame_name)] = true
					break

	for child in panel.graph_edit.get_children():
		if not (child is GraphNode or child is GraphFrame):
			continue
		if selection_only:
			if child is GraphNode and not selected_names.has(child.name):
				continue
			if child is GraphFrame and not included_frame_names.has(child.name):
				continue
		export_items.append(child)
		var item_rect := Rect2(child.position_offset, child.size)
		bounds = item_rect if not has_bounds else bounds.merge(item_rect)
		has_bounds = true

	if not has_bounds:
		push_warning("Logic Bricks: There are no bricks to export.")
		return

	# Render cloned graph elements on a standalone canvas. GraphEdit is not used
	# here because it clamps scrolling and applies viewport transforms that can
	# crop or offset an off-screen export.
	var render_scale := 2.0
	var margin := 50.0
	var export_origin := bounds.position - Vector2(margin, margin)
	var export_size := bounds.size + Vector2(margin * 2.0, margin * 2.0)
	var output_width := maxi(1, int(ceil(export_size.x * render_scale)))
	var output_height := maxi(1, int(ceil(export_size.y * render_scale)))

	var export_viewport := SubViewport.new()
	export_viewport.name = "LogicBricksGraphExportViewport"
	export_viewport.size = Vector2i(output_width, output_height)
	export_viewport.disable_3d = true
	export_viewport.transparent_bg = false
	export_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	panel.add_child(export_viewport)

	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	export_viewport.add_child(canvas)

	var background := ColorRect.new()
	background.color = Color.WHITE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.z_index = -100
	canvas.add_child(background)

	# Draw frames first so they sit behind connections and bricks. GraphFrame is
	# designed to live inside GraphEdit, so render a publication-friendly frame
	# directly on the standalone canvas instead of cloning the editor control.
	for item in export_items:
		if item is GraphFrame:
			_add_export_frame(canvas, item as GraphFrame, export_origin, render_scale)

	# Draw connections after frames so cloned bricks appear above them.
	var exported_node_names: Dictionary = {}
	for item in export_items:
		if item is GraphNode:
			exported_node_names[item.name] = true

	for conn in panel.graph_edit.get_connection_list():
		if not exported_node_names.has(conn["from_node"]) or not exported_node_names.has(conn["to_node"]):
			continue
		var from_node := panel.graph_edit.get_node_or_null(NodePath(str(conn["from_node"]))) as GraphNode
		var to_node := panel.graph_edit.get_node_or_null(NodePath(str(conn["to_node"]))) as GraphNode
		if from_node == null or to_node == null:
			continue
		var from_port := int(conn["from_port"])
		var to_port := int(conn["to_port"])
		var start_point := (from_node.position_offset + from_node.get_output_port_position(from_port) - export_origin) * render_scale
		var end_point := (to_node.position_offset + to_node.get_input_port_position(to_port) - export_origin) * render_scale
		var connection_color := from_node.get_output_port_color(from_port)
		_add_export_connection(canvas, start_point, end_point, connection_color, render_scale)

	for item in export_items:
		if not item is GraphNode:
			continue
		var node_copy := item.duplicate(Node.DUPLICATE_USE_INSTANTIATION) as GraphNode
		if node_copy == null:
			continue
		node_copy.position = (item.position_offset - export_origin) * render_scale
		node_copy.scale = Vector2.ONE * render_scale
		node_copy.selected = false
		node_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node_copy.z_index = 10
		canvas.add_child(node_copy)

	await panel.get_tree().process_frame
	await panel.get_tree().process_frame
	await RenderingServer.frame_post_draw

	var exported: Image = export_viewport.get_texture().get_image()
	if exported.get_format() != Image.FORMAT_RGBA8:
		exported.convert(Image.FORMAT_RGBA8)
	var result := exported.save_png(path)
	export_viewport.queue_free()

	if result != OK:
		push_error("Logic Bricks: Failed to export graph image to %s (error %s)." % [path, result])
	else:
		print("Logic Bricks: Exported graph image to ", path)

func _add_export_frame(canvas: Control, frame: GraphFrame, export_origin: Vector2, render_scale: float) -> void:
	var frame_panel := PanelContainer.new()
	frame_panel.position = (frame.position_offset - export_origin) * render_scale
	frame_panel.size = frame.size * render_scale
	frame_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_panel.z_index = -10

	# GraphFrame displays its tint composited over the GraphEdit background.
	# Recreate that visible result as an opaque export color so a white export
	# background does not make translucent frame colors appear brighter.
	var tint: Color = frame.tint_color if frame.tint_color_enabled else Color(0.3, 0.5, 0.7, 0.5)
	var graph_background := Color(0.06, 0.06, 0.06, 1.0)
	var graph_panel: StyleBox = panel.graph_edit.get_theme_stylebox("panel")
	if graph_panel is StyleBoxFlat:
		graph_background = (graph_panel as StyleBoxFlat).bg_color
	var fill := Color(
		lerpf(graph_background.r, tint.r, tint.a),
		lerpf(graph_background.g, tint.g, tint.a),
		lerpf(graph_background.b, tint.b, tint.a),
		1.0
	)
	var border := Color(tint.r, tint.g, tint.b, 1.0)

	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(maxi(2, int(round(2.0 * render_scale))))
	style.corner_radius_top_left = int(round(6.0 * render_scale))
	style.corner_radius_top_right = int(round(6.0 * render_scale))
	style.corner_radius_bottom_left = int(round(6.0 * render_scale))
	style.corner_radius_bottom_right = int(round(6.0 * render_scale))
	style.content_margin_left = 12.0 * render_scale
	style.content_margin_right = 12.0 * render_scale
	style.content_margin_top = 8.0 * render_scale
	style.content_margin_bottom = 8.0 * render_scale
	frame_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(frame_panel)

	var text_box := VBoxContainer.new()
	text_box.add_theme_constant_override("separation", 8)
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_panel.add_child(text_box)

	var title_label := Label.new()
	title_label.text = str(panel.frame_titles.get(frame.name, frame.title))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var editor_title_size := frame.get_theme_font_size("title_font_size")
	if editor_title_size <= 0:
		editor_title_size = 18
	var editor_title_color := frame.get_theme_color("title_color")
	if editor_title_color.a <= 0.0:
		editor_title_color = Color.WHITE
	title_label.add_theme_font_size_override("font_size", maxi(16, int(round(float(editor_title_size) * render_scale))))
	title_label.add_theme_color_override("font_color", editor_title_color)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_child(title_label)

	var comment: String = str(panel.frame_comments.get(frame.name, "")).strip_edges()
	if not comment.is_empty():
		var comment_label := Label.new()
		comment_label.text = comment
		comment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		comment_label.add_theme_font_size_override("font_size", maxi(11, int(round(12.0 * render_scale))))
		comment_label.add_theme_color_override("font_color", Color(0.18, 0.18, 0.18, 1.0))
		comment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_box.add_child(comment_label)

func _add_export_connection(canvas: Control, start_point: Vector2, end_point: Vector2, color: Color, render_scale: float) -> void:
	var line := Line2D.new()
	line.width = 3.0 * render_scale
	line.default_color = color
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.z_index = 0
	canvas.add_child(line)

	var horizontal_distance := absf(end_point.x - start_point.x)
	var handle_length := maxf(40.0 * render_scale, horizontal_distance * 0.5)
	var control_1 := start_point + Vector2(handle_length, 0.0)
	var control_2 := end_point - Vector2(handle_length, 0.0)
	var segments := 32
	for index in range(segments + 1):
		var amount := float(index) / float(segments)
		line.add_point(start_point.bezier_interpolate(control_1, control_2, end_point, amount))
