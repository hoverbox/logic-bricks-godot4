@tool
extends RefCounted

## Applies each brick's field visibility to its graph node. The rules live in
## the bricks: get_field_visibility_rules() and "visible_if" in property
## definitions (see core/logic_brick.gd).

var panel = null
var properties_ui = null


func setup(target_panel, target_properties_ui) -> void:
	panel = target_panel
	properties_ui = target_properties_ui


func update(graph_node: GraphNode, brick_instance) -> void:
	# Each brick decides which of its fields are shown
	# (LogicBrick.get_field_visibility(): its own rules plus "visible_if").
	var shown: Dictionary = brick_instance.get_field_visibility(panel.current_node) if brick_instance.has_method("get_field_visibility") else {}
	if not shown.is_empty():
		for child in properties_ui._find_prop_nodes(graph_node):
			var field_name := str(child.get_meta("property_name", ""))
			if shown.has(field_name):
				child.visible = bool(shown[field_name])

	# Group picker buttons follow their mode field without affecting the text field itself.
	properties_ui._update_group_picker_buttons(graph_node, brick_instance)
