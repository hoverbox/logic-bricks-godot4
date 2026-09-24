@tool
extends ItemList

var logic_panel: Control = null
var _drag_index: int = -1


func setup(owner_panel: Control) -> void:
	logic_panel = owner_panel


func _get_drag_data(at_position: Vector2) -> Variant:
	var index: int = get_item_at_position(at_position, true)
	if index < 0:
		return null
	_drag_index = index
	select(index)
	var preview := Label.new()
	preview.text = get_item_text(index)
	preview.add_theme_constant_override("outline_size", 4)
	set_drag_preview(preview)
	return {
		"logic_bricks_frame_reorder": true,
		"index": index,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and bool(data.get("logic_bricks_frame_reorder", false))


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if logic_panel == null or not logic_panel.has_method("_reorder_frame"):
		return
	var from_index: int = int(data.get("index", -1))
	var target_index: int = get_item_at_position(at_position, false)
	if target_index < 0:
		target_index = get_item_count()
	elif at_position.y > get_item_rect(target_index).get_center().y:
		target_index += 1
	logic_panel._reorder_frame(from_index, target_index)
	_drag_index = -1
