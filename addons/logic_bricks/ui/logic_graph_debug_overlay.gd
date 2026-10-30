@tool
extends Control

## Lightweight editor-only visualization for Logic Bricks Live Debug.
## Runtime sends only low-frequency active-chain snapshots. This overlay animates
## dots locally in the editor, so the running game pays no per-frame animation cost.

var graph_edit: GraphEdit = null
var _phase: float = 0.0

const DOT_COUNT := 3
const DOT_RADIUS := 4.0
const DOT_SPEED := 0.72
const ACTIVE_DOT_COLOR := Color(0.55, 1.0, 0.55, 1.0)
const DOT_OUTLINE_COLOR := Color(0.05, 0.12, 0.05, 0.8)


func setup(target_graph_edit: GraphEdit) -> void:
	graph_edit = target_graph_edit
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if graph_edit == null or not is_instance_valid(graph_edit):
		return
	if not graph_edit.has_method("has_live_debug_activity") or not bool(graph_edit.call("has_live_debug_activity")):
		return
	_phase = fmod(_phase + delta * DOT_SPEED, 1.0)
	queue_redraw()


func _draw() -> void:
	if graph_edit == null or not is_instance_valid(graph_edit):
		return
	if not graph_edit.has_method("is_live_debug_connection_active"):
		return

	for connection in graph_edit.get_connection_list():
		if not bool(graph_edit.call("is_live_debug_connection_active", connection)):
			continue
		for dot_index in range(DOT_COUNT):
			var t := fmod(_phase + float(dot_index) / float(DOT_COUNT), 1.0)
			var point_variant: Variant = graph_edit.call("get_live_debug_connection_point", connection, t)
			if not (point_variant is Vector2):
				continue
			var point := point_variant as Vector2
			draw_circle(point, DOT_RADIUS + 1.5, DOT_OUTLINE_COLOR)
			draw_circle(point, DOT_RADIUS, ACTIVE_DOT_COLOR)
