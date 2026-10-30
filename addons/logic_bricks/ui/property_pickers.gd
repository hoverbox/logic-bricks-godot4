@tool
extends RefCounted

## Brick property fields that pick something from the project or scene:
## node references (with drag-and-drop and "create child" buttons), input
## actions, variables, groups, files, animations and node properties.
## Used by panel_property_helper.gd when it builds a brick's fields.

const NodeReferenceLineEdit = preload("res://addons/logic_bricks/ui/node_reference_line_edit.gd")

var panel = null
var properties_ui = null


func setup(target_panel, target_properties_ui) -> void:
	panel = target_panel
	properties_ui = target_properties_ui


func _get_animation_players(graph_node: GraphNode) -> Array[String]:
	# Get list of AnimationPlayer node names that are children of panel.current_node
	var players: Array[String] = []

	if not panel.current_node:
		return players

	# Search all children for AnimationPlayer nodes
	for child in panel.current_node.get_children():
		if child is AnimationPlayer:
			players.append(child.name)

	return players


func _get_all_animations_in_scene() -> Array[String]:
	# Recursively search panel.current_node's entire subtree for AnimationPlayer nodes
	# and collect all unique animation names across all of them
	var animations: Array[String] = []

	if not panel.current_node:
		return animations

	var players: Array[AnimationPlayer] = []
	_find_animation_players_recursive(panel.current_node, players)

	for player in players:
		for anim_name in player.get_animation_list():
			if anim_name not in animations:
				animations.append(anim_name)

	animations.sort()
	return animations


func _find_animation_players_recursive(node: Node, result: Array[AnimationPlayer]) -> void:
	for child in node.get_children():
		if child is AnimationPlayer:
			result.append(child)
		_find_animation_players_recursive(child, result)


func _get_animation_tree_conditions() -> Array[String]:
	# Find the first AnimationTree under panel.current_node and collect all
	# parameters/conditions/<name> entries exposed in its property list.
	var conditions: Array[String] = []
	if not panel.current_node:
		return conditions
	var anim_tree = _find_first_animation_tree_node(panel.current_node)
	if not anim_tree:
		return conditions
	for prop in anim_tree.get_property_list():
		var prop_name: String = str(prop.get("name", ""))
		if prop_name.begins_with("parameters/conditions/"):
			var cond_name = prop_name.trim_prefix("parameters/conditions/")
			if not cond_name.is_empty() and cond_name not in conditions:
				conditions.append(cond_name)
	conditions.sort()
	return conditions


func _find_first_animation_tree_node(node: Node) -> AnimationTree:
	for child in node.get_children():
		if child is AnimationTree:
			return child
		var found = _find_first_animation_tree_node(child)
		if found:
			return found
	return null


func _create_node_reference_picker(graph_node: GraphNode, brick_instance, prop_def: Dictionary, property_name: String, property_value) -> Control:
	var wrapper := VBoxContainer.new()
	var hbox := HBoxContainer.new()
	wrapper.add_child(hbox)
	var label := Label.new()
	label.text = properties_ui._format_property_name(property_name) + ":"
	hbox.add_child(label)

	var accepted_types: Array = properties_ui.typing_assistance.accepted_node_types(brick_instance, prop_def)
	var line_edit = NodeReferenceLineEdit.new()
	line_edit.configure(panel.editor_interface, property_name, accepted_types, panel.current_node)
	line_edit.store_relative_path = bool(prop_def.get("node_reference_drop_path", false))
	properties_ui._select_line_edit_text_on_focus(line_edit)
	line_edit.name = "PropertyControl_" + property_name
	var force_self := property_name == "area_node_name" and _node_matches_types(panel.current_node, accepted_types)
	line_edit.text = "Self" if force_self else str(property_value)
	line_edit.placeholder_text = "Enter " + properties_ui._format_property_name(property_name).to_lower()
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.editable = not force_self
	if force_self:
		line_edit.tooltip_text = "This Collision trigger uses this Area node. Duplicated instances stay independent."
	else:
		line_edit.text_changed.connect(properties_ui._on_property_changed.bind(graph_node, property_name))
		line_edit.node_reference_dropped.connect(properties_ui._on_property_changed.bind(graph_node, property_name))
	hbox.add_child(line_edit)

	var menu_button := MenuButton.new()
	menu_button.text = "▾"
	menu_button.tooltip_text = "Choose a compatible child node"
	menu_button.custom_minimum_size = Vector2(28, 0)
	menu_button.disabled = force_self
	hbox.add_child(menu_button)

	var collision_setup_row: HBoxContainer = null
	if property_name == "area_node_name" and not force_self:
		var direct_areas := _compatible_direct_child_nodes(panel.current_node, accepted_types)
		if direct_areas.is_empty():
			collision_setup_row = HBoxContainer.new()
			collision_setup_row.name = "CollisionAreaSetupWarning"
			var warning := Label.new()
			warning.text = "⚠ Selected node doesn't have a child Area3D."
			warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			warning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			warning.add_theme_color_override("font_color", Color(1.0, 0.72, 0.2))
			collision_setup_row.add_child(warning)
			var add_button := Button.new()
			add_button.text = "Add Collision Area"
			add_button.tooltip_text = "Creates an Area3D with a CollisionShape3D and BoxShape3D under the selected node."
			add_button.pressed.connect(_create_collision_area3d_setup.bind(line_edit, graph_node, property_name, collision_setup_row))
			collision_setup_row.add_child(add_button)
			wrapper.add_child(collision_setup_row)

	var popup := menu_button.get_popup()
	var rebuild_popup = func():
		popup.clear()
		var typing_context: Dictionary = properties_ui.typing_assistance.context(brick_instance, prop_def)
		if str(typing_context.get("kind", "")) == "variable":
			var variables: Array[Dictionary] = properties_ui.typing_assistance.candidates(brick_instance, prop_def, typing_context)
			for index in variables.size():
				popup.add_item(str(variables[index].label), index)
				popup.set_item_metadata(index, variables[index].value)
			if variables.is_empty():
				popup.add_item("No compatible String variables")
				popup.set_item_disabled(0, true)
			return
		var picker_root: Node = panel.current_node
		var matches: Array[Node] = []
		if property_name == "area_node_name":
			# Collision Areas belong to the node being programmed. Showing Areas
			# elsewhere in the scene is misleading and can bind duplicate objects
			# to the same trigger.
			matches = _compatible_direct_child_nodes(panel.current_node, accepted_types)
		else:
			if str(prop_def.get("node_picker_scope", "scene")) == "scene" and panel.editor_interface != null:
				picker_root = panel.editor_interface.get_edited_scene_root()
			matches = _compatible_child_nodes(picker_root, accepted_types)
			if picker_root != panel.current_node and _node_matches_types(picker_root, accepted_types):
				matches.push_front(picker_root)
		var item_id := 0

		# Collision sensors deliberately use a blank field to mean self when the
		# Logic Bricks owner is already the matching Area node.
		if property_name == "area_node_name" and _node_matches_types(panel.current_node, accepted_types):
			popup.add_item("Use Self (" + str(panel.current_node.name) + ")", item_id)
			popup.set_item_metadata(popup.get_item_index(item_id), "")
			item_id += 1
			if not matches.is_empty():
				popup.add_separator()

		for child in matches:
			var relative_path := str(picker_root.get_path_to(child))
			popup.add_item(relative_path, item_id)
			var stored_value := str(child.name)
			if str(prop_def.get("node_reference_store", "name")) == "path" and panel.current_node != null:
				stored_value = str(panel.current_node.get_path_to(child))
			popup.set_item_metadata(popup.get_item_index(item_id), stored_value)
			item_id += 1

		if matches.is_empty() and not _node_matches_types(panel.current_node, accepted_types):
			if property_name == "area_node_name":
				popup.add_item("No child Area3D nodes", item_id)
				popup.set_item_disabled(popup.get_item_index(item_id), true)
			else:
				var create_type := _creatable_reference_type(accepted_types)
				if not create_type.is_empty():
					if item_id > 0:
						popup.add_separator()
					popup.add_item("+ Create " + create_type, item_id)
					popup.set_item_metadata(popup.get_item_index(item_id), {"create": create_type})
				elif item_id == 0:
					popup.add_item("No compatible child nodes", item_id)
					popup.set_item_disabled(popup.get_item_index(item_id), true)

	popup.about_to_popup.connect(rebuild_popup)
	popup.id_pressed.connect(func(id: int):
		var index := popup.get_item_index(id)
		if index < 0:
			return
		var selected = popup.get_item_metadata(index)
		if selected is Dictionary and selected.has("create"):
			_create_reference_child(str(selected["create"]), line_edit, graph_node, property_name)
			return
		var value := str(selected)
		line_edit.text = value
		line_edit.caret_column = value.length()
		properties_ui._on_property_changed(value, graph_node, property_name)
	)
	rebuild_popup.call()
	return wrapper


func _compatible_direct_child_nodes(root: Node, accepted_types: Array) -> Array[Node]:
	var result: Array[Node] = []
	if root == null:
		return result
	for child in root.get_children():
		if child is Node and _node_matches_types(child, accepted_types):
			result.append(child)
	return result


func _create_collision_area3d_setup(line_edit: LineEdit, graph_node: GraphNode, property_name: String, warning_row: Control) -> void:
	if panel == null or panel.current_node == null or panel.editor_interface == null:
		return
	var parent: Node = panel.current_node
	var area := Area3D.new()
	area.name = "Area3D"
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = BoxShape3D.new()
	var scene_root: Node = panel.editor_interface.get_edited_scene_root()
	var save_owner: Node = parent.owner if parent.owner != null else scene_root
	var undo_redo: EditorUndoRedoManager = panel.editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Create Collision Area for Logic Bricks")
	undo_redo.add_do_method(parent, "add_child", area, true)
	undo_redo.add_do_method(area, "add_child", collision_shape, true)
	if save_owner != null:
		undo_redo.add_do_method(area, "set_owner", save_owner)
		undo_redo.add_do_method(collision_shape, "set_owner", save_owner)
	undo_redo.add_do_reference(area)
	undo_redo.add_do_reference(collision_shape)
	undo_redo.add_undo_method(area, "remove_child", collision_shape)
	undo_redo.add_undo_method(parent, "remove_child", area)
	undo_redo.commit_action()

	var value := str(area.name)
	line_edit.text = value
	line_edit.caret_column = value.length()
	properties_ui._on_property_changed(value, graph_node, property_name)
	if is_instance_valid(warning_row):
		warning_row.visible = false


func _compatible_child_nodes(root: Node, accepted_types: Array) -> Array[Node]:
	var result: Array[Node] = []
	if root == null:
		return result
	var stack: Array[Node] = []
	for child in root.get_children():
		if child is Node:
			stack.append(child)
	while not stack.is_empty():
		var node := stack.pop_front()
		if _node_matches_types(node, accepted_types):
			result.append(node)
		for child in node.get_children():
			if child is Node:
				stack.append(child)
	return result


func _node_matches_types(node: Node, accepted_types: Array) -> bool:
	if node == null:
		return false
	if accepted_types.is_empty():
		return true
	for type_name in accepted_types:
		if node.is_class(str(type_name)):
			return true
	return false


func _creatable_reference_type(accepted_types: Array) -> String:
	if accepted_types.size() != 1:
		return ""
	var type_name := str(accepted_types[0])
	return type_name if type_name in ["Area3D", "Area2D"] else ""


func _create_reference_child(type_name: String, line_edit: LineEdit, graph_node: GraphNode, property_name: String) -> void:
	if panel == null or panel.current_node == null or panel.editor_interface == null:
		return
	var created: Object = ClassDB.instantiate(type_name)
	if not created is Node:
		return
	var new_node := created as Node
	new_node.name = type_name
	var parent: Node = panel.current_node
	var scene_root: Node = panel.editor_interface.get_edited_scene_root()
	var save_owner: Node = parent.owner if parent.owner != null else scene_root
	var undo_redo: EditorUndoRedoManager = panel.editor_interface.get_editor_undo_redo()
	undo_redo.create_action("Create " + type_name + " for Logic Bricks")
	undo_redo.add_do_method(parent, "add_child", new_node, true)
	if save_owner != null:
		undo_redo.add_do_method(new_node, "set_owner", save_owner)
	undo_redo.add_do_reference(new_node)
	undo_redo.add_undo_method(parent, "remove_child", new_node)
	undo_redo.commit_action()

	var value := str(new_node.name)
	line_edit.text = value
	line_edit.caret_column = value.length()
	properties_ui._on_property_changed(value, graph_node, property_name)


func _accepted_node_types(prop_def: Dictionary, property_name: String) -> Array:
	var explicit = prop_def.get("accepted_node_types", [])
	var result: Array = []
	if explicit is Array:
		for item in explicit:
			result.append(str(item))
	if not result.is_empty():
		return result

	# Sensible type guards for the most common specialized node references.
	if property_name in ["camera_name", "camera_node_name", "camera_1_node_name", "camera_2_node_name", "camera_3_node_name", "camera_4_node_name"]:
		return ["Camera3D", "Camera2D"]
	if property_name == "animation_tree_name" or property_name == "animation_tree_node_name":
		return ["AnimationTree"]
	if property_name == "navigation_agent_node_name":
		return ["NavigationAgent3D", "NavigationAgent2D"]
	if property_name == "raycast_node_name":
		return ["RayCast3D", "RayCast2D"]
	if property_name == "area_node_name":
		return ["Area3D", "Area2D"]
	return []


func _resolve_property_actuator_target(brick_instance):
	if panel == null or panel.current_node == null:
		return null
	var target_name = str(brick_instance.get_property("target_node", "self")).strip_edges()
	if target_name.is_empty() or target_name.to_lower() == "self":
		return panel.current_node
	var tree = panel.current_node.get_tree()
	if tree != null and tree.root != null:
		var found = tree.root.find_child(target_name, true, false)
		if found != null:
			return found
	return panel.current_node.find_child(target_name, true, false)


func _populate_target_node_property_enum(option_button: OptionButton, brick_instance, property_value) -> void:
	var target = _resolve_property_actuator_target(brick_instance)
	if target == null:
		option_button.add_item("(Target node not found)")
		option_button.disabled = true
		return

	_style_target_node_property_sections(option_button)
	option_button.disabled = false
	option_button.add_item("(Select property)")
	option_button.set_item_metadata(0, "")
	var selected_index = 0
	var editable_count = 0

	# Godot's raw property list is commonly base-class first, while the Inspector
	# displays inheritance sections most-derived first. Build category blocks in
	# their native order, then reverse only the blocks. Property order inside each
	# block stays untouched.
	var sections = []
	var orphan_properties = []
	var current_section_name = ""
	var current_section_properties = []

	for info in target.get_property_list():
		var usage = int(info.get("usage", 0))
		var prop_name = str(info.get("name", ""))

		if (usage & PROPERTY_USAGE_CATEGORY) != 0:
			if not current_section_name.is_empty() and not current_section_properties.is_empty():
				sections.append({"name": current_section_name, "properties": current_section_properties})
			current_section_name = prop_name
			current_section_properties = []
			continue

		if int(info.get("type", TYPE_NIL)) == TYPE_NIL:
			continue
		if prop_name.is_empty() or prop_name == "script":
			continue
		if (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue

		if current_section_name.is_empty():
			orphan_properties.append(info)
		else:
			current_section_properties.append(info)

	if not current_section_name.is_empty() and not current_section_properties.is_empty():
		sections.append({"name": current_section_name, "properties": current_section_properties})

	sections.reverse()

	# Godot exposes the attached script as its own Inspector category (usually
	# the script filename, e.g. "soft_body_3d.gd"). It appears above the native
	# class sections in the Inspector, but it is rarely useful in this brick, so
	# keep the native node properties first and move that whole category last.
	var script_section = null
	var attached_script = target.get_script()
	if attached_script != null:
		var script_file = str(attached_script.resource_path.get_file())
		if not script_file.is_empty():
			for i in range(sections.size() - 1, -1, -1):
				if str(sections[i].get("name", "")) == script_file:
					script_section = sections[i]
					sections.remove_at(i)
					break

	# Script-exported properties that arrive outside a category belong at the
	# bottom for the same reason.
	if not orphan_properties.is_empty():
		sections.push_back({"name": "Script", "properties": orphan_properties})
	if script_section != null:
		sections.push_back(script_section)

	for section in sections:
		option_button.add_separator(str(section["name"]))
		for info in section["properties"]:
			var prop_name = str(info.get("name", ""))
			var index = option_button.item_count
			option_button.add_item(prop_name.replace("_", " ").capitalize())
			option_button.set_item_metadata(index, prop_name)
			editable_count += 1
			if prop_name == str(property_value):
				selected_index = index

	if editable_count == 0:
		option_button.clear()
		option_button.add_item("(No editable Inspector properties)")
		option_button.disabled = true
		selected_index = 0
	option_button.selected = selected_index
	option_button.tooltip_text = "Inspector properties for %s (%s)" % [str(target.name), target.get_class()]


func _style_target_node_property_sections(option_button: OptionButton) -> void:
	var popup = option_button.get_popup()
	if popup == null:
		return

	var header_color = Color(0.6, 0.3, 0.1, 0.9)
	var header_text_color = Color.WHITE
	if panel != null:
		var configured_header = panel.get("_brick_actuator_color")
		var configured_text = panel.get("_brick_header_text_color")
		if configured_header is Color:
			header_color = configured_header
		if configured_text is Color:
			header_text_color = configured_text

	# PopupMenu draws labeled separators with a left and right StyleBox. Expand
	# both underneath the label so the category reads as one colored header bar.
	var left = StyleBoxFlat.new()
	left.bg_color = header_color
	left.content_margin_top = 4.0
	left.content_margin_bottom = 4.0
	left.set_expand_margin(SIDE_RIGHT, 96.0)

	var right = StyleBoxFlat.new()
	right.bg_color = header_color
	right.content_margin_top = 4.0
	right.content_margin_bottom = 4.0
	right.set_expand_margin(SIDE_LEFT, 96.0)

	popup.add_theme_stylebox_override("labeled_separator_left", left)
	popup.add_theme_stylebox_override("labeled_separator_right", right)
	popup.add_theme_color_override("font_separator_color", header_text_color)
	popup.add_theme_color_override("font_separator_outline_color", Color.TRANSPARENT)
	popup.add_theme_constant_override("separator_outline_size", 0)


func _refresh_target_node_property_dropdown(graph_node: GraphNode, brick_instance) -> void:
	var control = graph_node.find_child("PropertyControl_property_name", true, false)
	if control == null or not control is OptionButton:
		return
	var option_button = control as OptionButton
	var current_value = brick_instance.get_property("property_name", "")
	option_button.clear()
	_populate_target_node_property_enum(option_button, brick_instance, current_value)
	if option_button.selected == 0 and not str(current_value).is_empty():
		brick_instance.set_property("property_name", "")


func _get_project_input_actions() -> Array[String]:
	var actions: Array[String] = []
	var config := ConfigFile.new()
	if config.load("res://project.godot") != OK or not config.has_section("input"):
		return actions
	for key in config.get_section_keys("input"):
		var action_name := str(key).strip_edges()
		if not action_name.is_empty():
			actions.append(action_name)
	actions.sort()
	return actions


func _get_builtin_input_actions(project_actions: Array[String]) -> Array[String]:
	var actions: Array[String] = []
	for property_info in ProjectSettings.get_property_list():
		var setting_name := str(property_info.get("name", ""))
		if not setting_name.begins_with("input/"):
			continue
		var action_name := setting_name.trim_prefix("input/")
		if action_name.is_empty() or project_actions.has(action_name):
			continue
		actions.append(action_name)
	actions.sort()
	return actions


func _find_input_map_tab(root: Node) -> Dictionary:
	for candidate in root.find_children("*", "TabContainer", true, false):
		var tabs := candidate as TabContainer
		if tabs == null:
			continue
		for i in range(tabs.get_tab_count()):
			if tabs.get_tab_title(i).strip_edges() == "Input Map":
				return {"tabs": tabs, "index": i}
	return {}


func _activate_input_map_tab(root: Node) -> void:
	var result := _find_input_map_tab(root)
	if not result.is_empty():
		(result["tabs"] as TabContainer).current_tab = int(result["index"])


func _open_input_map_settings() -> void:
	if panel == null or panel.editor_interface == null:
		return
	var root: Control = panel.editor_interface.get_base_control()
	if root == null:
		return

	# Use Godot's own Project Settings menu action so the dialog initializes
	# exactly as it would when opened from Project > Project Settings.
	for candidate in root.find_children("*", "PopupMenu", true, false):
		var popup := candidate as PopupMenu
		if popup == null:
			continue
		for i in range(popup.get_item_count()):
			if popup.get_item_text(i).contains("Project Settings"):
				popup.emit_signal("id_pressed", popup.get_item_id(i))
				call_deferred("_activate_input_map_tab", root)
				return

	# Fallback: if the menu structure changes, locate the existing Project
	# Settings dialog by its Input Map tab and show it directly.
	var result := _find_input_map_tab(root)
	if result.is_empty():
		return
	var tabs := result["tabs"] as TabContainer
	tabs.current_tab = int(result["index"])
	var owner := tabs.get_parent()
	while owner != null and not (owner is Window):
		owner = owner.get_parent()
	if owner is Window:
		(owner as Window).popup_centered_ratio(0.8)


func _create_open_input_maps_button() -> Button:
	var button := Button.new()
	button.text = "Open Input Maps"
	button.tooltip_text = "Open Project Settings > Input Map"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(_open_input_map_settings)
	return button


func _create_input_action_picker(graph_node: GraphNode, brick_instance, property_name: String, property_value) -> Control:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = properties_ui._format_property_name(property_name) + ":"
	hbox.add_child(label)

	var line_edit = LineEdit.new()
	properties_ui._select_line_edit_text_on_focus(line_edit)
	line_edit.name = "PropertyControl_" + property_name
	line_edit.text = str(property_value)
	line_edit.placeholder_text = "Enter Input action"
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.text_changed.connect(properties_ui._on_property_changed.bind(graph_node, property_name))
	hbox.add_child(line_edit)

	var menu_button = MenuButton.new()
	menu_button.text = "▾"
	menu_button.tooltip_text = "Choose a custom action from Project Settings > Input Map"
	menu_button.custom_minimum_size = Vector2(28, 0)
	hbox.add_child(menu_button)

	var popup := menu_button.get_popup()
	var rebuild_popup = func():
		popup.clear()
		var project_actions := _get_project_input_actions()
		var builtin_actions := _get_builtin_input_actions(project_actions)
		var item_id := 0

		if not project_actions.is_empty():
			popup.add_separator("Project Inputs")
			for action_name in project_actions:
				popup.add_item(action_name, item_id)
				popup.set_item_metadata(popup.get_item_index(item_id), action_name)
				item_id += 1

		if not builtin_actions.is_empty():
			popup.add_separator("Built-in Inputs")
			for action_name in builtin_actions:
				popup.add_item(action_name, item_id)
				popup.set_item_metadata(popup.get_item_index(item_id), action_name)
				item_id += 1

	popup.about_to_popup.connect(rebuild_popup)
	popup.id_pressed.connect(func(id: int):
		var index := popup.get_item_index(id)
		if index < 0:
			return
		var selected := str(popup.get_item_metadata(index))
		if selected.is_empty():
			return
		line_edit.text = selected
		properties_ui._on_property_changed(selected, graph_node, property_name)
	)
	rebuild_popup.call()
	return hbox


func _create_variable_picker(graph_node: GraphNode, brick_instance, property_name: String, property_value) -> Control:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = properties_ui._format_property_name(property_name) + ":"
	hbox.add_child(label)

	var line_edit = LineEdit.new()
	properties_ui._select_line_edit_text_on_focus(line_edit)
	line_edit.name = "PropertyControl_" + property_name
	line_edit.text = str(property_value)
	line_edit.placeholder_text = "Enter variable name"
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.text_changed.connect(properties_ui._on_property_changed.bind(graph_node, property_name))
	hbox.add_child(line_edit)

	var menu_button = MenuButton.new()
	menu_button.text = "▾"
	menu_button.tooltip_text = "Choose a Logic Bricks variable"
	menu_button.custom_minimum_size = Vector2(28, 0)
	hbox.add_child(menu_button)

	var popup := menu_button.get_popup()
	var rebuild_popup = func():
		popup.clear()
		var definition := {"name": property_name, "variable_picker": true}
		var info: Dictionary = properties_ui.typing_assistance.context(brick_instance, definition)
		var options: Array[Dictionary] = properties_ui.typing_assistance.candidates(brick_instance, definition, info)
		for index in options.size():
			popup.add_item(str(options[index].label), index)
			popup.set_item_metadata(index, options[index].value)
		if options.is_empty():
			popup.add_item("No compatible variables found")
			popup.set_item_disabled(0, true)

	popup.about_to_popup.connect(rebuild_popup)
	popup.id_pressed.connect(func(id: int):
		var index := popup.get_item_index(id)
		if index < 0 or popup.is_item_disabled(index):
			return
		var selected := str(popup.get_item_metadata(index))
		if selected.is_empty():
			return
		line_edit.text = selected
		properties_ui._on_property_changed(selected, graph_node, property_name)
	)
	rebuild_popup.call()
	return hbox


func _collect_project_group_names() -> Array[String]:
	var groups: Array[String] = []

	# Groups actually used by nodes in the currently edited scene.
	if panel != null and panel.editor_interface != null:
		var scene_root: Node = panel.editor_interface.get_edited_scene_root()
		if scene_root != null:
			var pending: Array[Node] = [scene_root]
			while not pending.is_empty():
				var current: Node = pending.pop_back()
				for group_value in current.get_groups():
					var scene_group_name := str(group_value).strip_edges()
					if not scene_group_name.is_empty() and not scene_group_name.begins_with("_") and not groups.has(scene_group_name):
						groups.append(scene_group_name)
				for child in current.get_children():
					if child is Node:
						pending.append(child as Node)

	# Also include globally-declared groups even when no node in this scene uses them yet.
	for property_info in ProjectSettings.get_property_list():
		var setting_name := str(property_info.get("name", ""))
		if setting_name.begins_with("global_group/"):
			var global_group_name := setting_name.trim_prefix("global_group/").strip_edges()
			if not global_group_name.is_empty() and not groups.has(global_group_name):
				groups.append(global_group_name)

	# ConfigFile fallback keeps this compatible with projects that serialize global groups as a section.
	var config := ConfigFile.new()
	if config.load("res://project.godot") == OK:
		for section_name in ["global_group", "global_groups"]:
			if config.has_section(section_name):
				for key in config.get_section_keys(section_name):
					var config_group_name := str(key).strip_edges()
					if not config_group_name.is_empty() and not groups.has(config_group_name):
						groups.append(config_group_name)

	groups.sort()
	return groups


func _group_picker_condition_matches(brick_instance, condition: Dictionary) -> bool:
	if condition.is_empty():
		return true
	for property_name in condition:
		var actual := str(brick_instance.get_property(str(property_name), "")).to_lower().replace(" ", "_")
		var expected = condition[property_name]
		if expected is Array:
			var matched := false
			for option in expected:
				if actual == str(option).to_lower().replace(" ", "_"):
					matched = true
					break
			if not matched:
				return false
		elif actual != str(expected).to_lower().replace(" ", "_"):
			return false
	return true


func _update_group_picker_buttons(graph_node: GraphNode, brick_instance) -> void:
	for property_control in properties_ui._find_prop_nodes(graph_node):
		var button := property_control.find_child("GroupPickerButton", true, false) as MenuButton
		if button == null:
			continue
		var condition: Dictionary = property_control.get_meta("group_picker_if", {})
		button.visible = _group_picker_condition_matches(brick_instance, condition)


func _create_group_picker(graph_node: GraphNode, brick_instance, prop_def: Dictionary, property_name: String, property_value) -> Control:
	var hbox := HBoxContainer.new()
	var label := Label.new()
	label.text = properties_ui._format_property_name(property_name) + ":"
	hbox.add_child(label)

	var line_edit: LineEdit
	if properties_ui._is_node_reference_property(prop_def, property_name):
		var node_edit := NodeReferenceLineEdit.new()
		node_edit.configure(panel.editor_interface, property_name, _accepted_node_types(prop_def, property_name), panel.current_node)
		node_edit.node_reference_dropped.connect(properties_ui._on_property_changed.bind(graph_node, property_name))
		line_edit = node_edit
	else:
		line_edit = LineEdit.new()
	properties_ui._select_line_edit_text_on_focus(line_edit)
	line_edit.name = "PropertyControl_" + property_name
	line_edit.text = str(property_value)
	line_edit.placeholder_text = str(prop_def.get("placeholder", "Enter group name"))
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.text_changed.connect(properties_ui._on_property_changed.bind(graph_node, property_name))
	hbox.add_child(line_edit)

	var menu_button := MenuButton.new()
	menu_button.name = "GroupPickerButton"
	menu_button.text = "▾"
	menu_button.tooltip_text = "Choose a group used in this project"
	menu_button.custom_minimum_size = Vector2(28, 0)
	hbox.add_child(menu_button)
	hbox.set_meta("group_picker_if", prop_def.get("group_picker_if", {}))

	var popup := menu_button.get_popup()
	var rebuild_popup = func():
		popup.clear()
		var groups := _collect_project_group_names()
		if groups.is_empty():
			popup.add_item("(No groups found)", 0)
			popup.set_item_disabled(0, true)
			return
		for i in range(groups.size()):
			popup.add_item(groups[i], i)
			popup.set_item_metadata(i, groups[i])

	popup.about_to_popup.connect(rebuild_popup)
	popup.id_pressed.connect(func(id: int):
		var index := popup.get_item_index(id)
		if index < 0:
			return
		var selected := str(popup.get_item_metadata(index)).strip_edges()
		if selected.is_empty():
			return
		var new_value := selected
		if bool(prop_def.get("group_picker_multi", false)):
			var existing: Array[String] = []
			for part in line_edit.text.split(","):
				var group_name := str(part).strip_edges()
				if not group_name.is_empty() and not existing.has(group_name):
					existing.append(group_name)
			if not existing.has(selected):
				existing.append(selected)
			new_value = ", ".join(existing)
		line_edit.text = new_value
		properties_ui._on_property_changed(new_value, graph_node, property_name)
	)
	rebuild_popup.call()
	return hbox


func _on_file_picker_pressed(graph_node: GraphNode, property_name: String, filter: String) -> void:
	# Open a file dialog to select a file path
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	file_dialog.use_native_dialog = false

	# Set filters from hint_string (e.g., "*.tscn,*.scn")
	if not filter.is_empty():
		file_dialog.filters = PackedStringArray([filter])

	# When file is selected, update the property
	file_dialog.file_selected.connect(func(path: String):
		if graph_node.has_meta("brick_data"):
			var brick_data = graph_node.get_meta("brick_data")
			brick_data["brick_instance"].set_property(property_name, path)

			# Update the LineEdit to show just the filename
			for child in graph_node.get_children():
				if child.has_meta("property_name") and child.get_meta("property_name") == property_name:
					var line_edit = child.get_node_or_null("PropertyControl_" + property_name)
					if line_edit:
						line_edit.text = path.get_file()
						line_edit.tooltip_text = path
					break

			panel._save_graph_to_metadata()
		file_dialog.queue_free()
	)

	# Close dialog if cancelled
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)

	# Add to scene tree and show
	panel.add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.6)
