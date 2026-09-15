@tool
extends PanelContainer

var logic_panel: Control = null
var variable_index: int = -1
var is_global: bool = false
var display_name: String = "Variable"
var _drop_after: int = -1


func setup(owner_panel: Control, index: int, global_variable: bool, variable_name: String) -> void:
	logic_panel = owner_panel
	variable_index = index
	is_global = global_variable
	display_name = variable_name


func _get_drag_data(at_position: Vector2) -> Variant:
	# Only the compact header is a drag handle; editing fields below stays normal.
	if at_position.y > 36.0:
		return null
	var preview := Label.new()
	preview.text = display_name
	preview.add_theme_constant_override("outline_size", 4)
	set_drag_preview(preview)
	return {
		"logic_bricks_variable_reorder": true,
		"index": variable_index,
		"is_global": is_global,
	}


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var valid: bool = data is Dictionary \
		and bool(data.get("logic_bricks_variable_reorder", false)) \
		and bool(data.get("is_global", false)) == is_global
	if valid:
		if logic_panel != null and logic_panel.has_method("_clear_variable_drop_indicators"):
			logic_panel._clear_variable_drop_indicators()
		# Judge above/below from the compact header, not the full expanded panel.
		# Otherwise an expanded variable makes nearly its entire header count as "above".
		var header_height: float = minf(size.y, 36.0)
		_drop_after = 1 if at_position.y > header_height * 0.5 else 0
		queue_redraw()
	return valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if logic_panel == null or not logic_panel.has_method("_reorder_variable"):
		return
	var target_index := variable_index + _drop_after
	logic_panel._clear_variable_drop_indicators()
	logic_panel._reorder_variable(int(data.get("index", -1)), target_index, is_global)


func clear_drop_indicator() -> void:
	if _drop_after == -1:
		return
	_drop_after = -1
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and logic_panel != null and logic_panel.has_method("_clear_variable_drop_indicators"):
		logic_panel._clear_variable_drop_indicators()


func _draw() -> void:
	if _drop_after == -1:
		return
	var y := 1.0 if _drop_after == 0 else size.y - 1.0
	var line_color := get_theme_color("accent_color", "Editor")
	if line_color.a <= 0.0:
		line_color = Color(0.3, 0.65, 1.0)
	draw_line(Vector2(2.0, y), Vector2(size.x - 2.0, y), line_color, 2.0, true)
