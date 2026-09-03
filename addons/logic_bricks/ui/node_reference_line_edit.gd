@tool
extends LineEdit

## LineEdit that accepts nodes dragged from Godot's Scene dock.
## Existing bricks continue storing node names, so dropping a node writes node.name.
## Ctrl/Cmd may cause Godot's Scene dock to include the Logic Bricks owner in the
## drag payload as part of a multi-selection. The owner is filtered out so the
## node the user is actually dragging is used as the reference.

signal node_reference_dropped(value: String)

var editor_interface: EditorInterface = null
var accepted_node_types: Array = []
var property_name: String = ""
var logic_bricks_owner: Node = null


func configure(
	p_editor_interface: EditorInterface,
	p_property_name: String,
	p_accepted_types: Array = [],
	p_logic_bricks_owner: Node = null
) -> void:
	editor_interface = p_editor_interface
	property_name = p_property_name
	accepted_node_types = p_accepted_types
	logic_bricks_owner = p_logic_bricks_owner
	tooltip_text = _build_tooltip()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var node := _node_from_drag_data(data)
	if node == null:
		return false
	return _accepts_node(node)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var node := _node_from_drag_data(data)
	if node == null or not _accepts_node(node):
		return

	# LineEdit has native text-drop behavior that can insert dropped text at the
	# caret after this callback. Apply our node reference deferred so it always
	# REPLACES the existing/default value instead of being appended to it.
	call_deferred("_replace_with_dropped_reference", str(node.name))


func _replace_with_dropped_reference(value: String) -> void:
	# Save exactly one node reference. Defaults such as MeshInstance3D and any
	# manually entered text are intentionally discarded on a successful drop.
	set_block_signals(true)
	text = value
	caret_column = text.length()
	set_block_signals(false)
	node_reference_dropped.emit(value)


func _node_from_drag_data(data: Variant) -> Node:
	if editor_interface == null or typeof(data) != TYPE_DICTIONARY:
		return null

	var drag: Dictionary = data
	var dragged_nodes = drag.get("nodes", null)
	if dragged_nodes == null:
		# Some editor controls expose a single node/object instead of a nodes array.
		var direct = drag.get("node", drag.get("object", null))
		if direct is Node and direct != logic_bricks_owner:
			return direct
		return null

	if not (dragged_nodes is Array or dragged_nodes is PackedStringArray):
		return null

	# Resolve every item in the Scene-dock payload, then remove the node whose
	# Logic Bricks are currently open. Ctrl/Cmd can add that node to the Scene
	# selection, causing Godot to include it alongside the node being dragged.
	var candidates: Array[Node] = []
	for item in dragged_nodes:
		var resolved := _resolve_dragged_node(item)
		if resolved == null:
			continue
		if logic_bricks_owner != null and resolved == logic_bricks_owner:
			continue
		if not candidates.has(resolved):
			candidates.append(resolved)

	# A node-reference field intentionally accepts one reference at a time.
	# After filtering the Logic Bricks owner there should normally be exactly one.
	if candidates.size() == 1:
		return candidates[0]

	# Some Godot versions also expose the initiating node separately. Prefer it
	# when the Scene selection produced a larger multi-node payload.
	var direct = drag.get("node", drag.get("object", null))
	if direct is Node and direct != logic_bricks_owner and candidates.has(direct):
		return direct

	return null


func _resolve_dragged_node(item: Variant) -> Node:
	if item is Node:
		return item

	var root := editor_interface.get_edited_scene_root()
	if root == null:
		return null

	var path_text := str(item)
	var path := NodePath(path_text)
	var node := root.get_node_or_null(path)
	if node != null:
		return node

	# Scene-dock node paths are commonly absolute from the edited scene root.
	if path_text.begins_with("/"):
		var tree := root.get_tree()
		if tree != null and tree.root != null:
			node = tree.root.get_node_or_null(path)
			if node != null:
				return node

	# Last fallback: the first path component may be the edited root's own name.
	var root_prefix := str(root.name) + "/"
	if path_text.begins_with(root_prefix):
		node = root.get_node_or_null(NodePath(path_text.substr(root_prefix.length())))
		if node != null:
			return node

	return null


func _accepts_node(node: Node) -> bool:
	if accepted_node_types.is_empty():
		return true
	for type_name in accepted_node_types:
		if node.is_class(type_name):
			return true
	return false


func _build_tooltip() -> String:
	var base := "Type a node name, or Ctrl-drag a node here from the Scene dock."
	if accepted_node_types.is_empty():
		return base
	return base + "\nAccepted: " + ", ".join(accepted_node_types)
