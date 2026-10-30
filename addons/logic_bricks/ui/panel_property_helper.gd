extends RefCounted

const LogicBrickBase = preload("res://addons/logic_bricks/core/logic_brick.gd")
const NodeReferenceLineEdit = preload("res://addons/logic_bricks/ui/node_reference_line_edit.gd")
const NodeReferenceSync = preload("res://addons/logic_bricks/core/node_reference_sync.gd")
const TypingAssistance = preload("res://addons/logic_bricks/ui/typing_assistance.gd")
const VariableUtils = preload("res://addons/logic_bricks/core/logic_brick_variable_utils.gd")

var panel = null
var typing_assistance = TypingAssistance.new()
var _visibility_rules = preload("res://addons/logic_bricks/ui/brick_visibility_rules.gd").new()
var _pickers = preload("res://addons/logic_bricks/ui/property_pickers.gd").new()

func setup(target_panel) -> void:
	panel = target_panel
	typing_assistance.setup(panel, self)
	_visibility_rules.setup(panel, self)
	_pickers.setup(panel, self)


func _refresh_compatibility_ui(graph_node: GraphNode, brick_instance) -> void:
	graph_node.modulate = Color.WHITE
	var warning = graph_node.get_node_or_null("CompatibilityWarning")
	var compatibility_error = ""
	if panel.current_node and brick_instance.has_method("get_compatibility_error"):
		compatibility_error = str(brick_instance.call("get_compatibility_error", panel.current_node))
	if compatibility_error.is_empty():
		if warning:
			warning.queue_free()
		return
	graph_node.modulate = Color(1.0, 0.55, 0.55, 1.0)
	if not warning:
		warning = Label.new()
		warning.name = "CompatibilityWarning"
		graph_node.add_child(warning)
	warning.text = "⚠ " + compatibility_error
	warning.tooltip_text = compatibility_error

func _select_line_edit_text_on_focus(line_edit: LineEdit) -> void:
	if line_edit == null:
		return
	line_edit.focus_entered.connect(func():
		line_edit.call_deferred("select_all")
		if panel and panel.has_method("show_expanded_line_edit_if_needed"):
			panel.call_deferred("show_expanded_line_edit_if_needed", line_edit)
	)


func _select_spinbox_text_on_focus(spinbox: SpinBox) -> void:
	if spinbox == null:
		return
	var line_edit = spinbox.get_line_edit()
	_select_line_edit_text_on_focus(line_edit)
	spinbox.focus_entered.connect(func():
		var edit = spinbox.get_line_edit()
		if edit != null:
			edit.call_deferred("select_all")
	)

func _create_brick_ui(graph_node: GraphNode, brick_instance) -> void:
	var properties = brick_instance.get_properties()
	var prop_definitions = brick_instance.get_property_definitions()

	# Keep incompatible bricks visible, but make the problem obvious.
	_refresh_compatibility_ui(graph_node, brick_instance)

	# Tooltips come only from the brick itself (get_tooltip_definitions()).
	# The old centralized brick_tooltips.gd table has been folded into the
	# bricks and is no longer read.
	var tooltips: Dictionary = brick_instance.get_tooltip_definitions()

	# Apply brick description tooltip to the GraphNode itself
	if tooltips.has("_description"):
		graph_node.tooltip_text = tooltips["_description"]

	# Add instance name field first
	var name_hbox = HBoxContainer.new()
	name_hbox.name = "BrickConnectionRow"
	var name_label = Label.new()
	name_label.text = "Name:"
	name_hbox.add_child(name_label)

	var name_edit = LineEdit.new()
	_select_line_edit_text_on_focus(name_edit)
	name_edit.name = "InstanceNameEdit"
	var inst_name = brick_instance.get_instance_name()
	name_edit.text = inst_name if inst_name is String else ""
	name_edit.placeholder_text = "brick_name"
	name_edit.custom_minimum_size = Vector2(150, 0)
	name_edit.text_changed.connect(_on_instance_name_changed.bind(graph_node, brick_instance))
	name_hbox.add_child(name_edit)
	name_hbox.tooltip_text = "Unique name for this brick instance. Used as variable prefix in generated code."

	graph_node.add_child(name_hbox)

	# Add separator if there are properties
	if prop_definitions.size() > 0:
		var separator = HSeparator.new()
		graph_node.add_child(separator)

	# Create UI based on property definitions if available
	if prop_definitions.size() > 0:
		var current_group_container: VBoxContainer = null  # Active group body

		for prop_def in prop_definitions:
			var property_name = prop_def["name"]
			var property_value = properties.get(property_name, prop_def.get("default", null))
			var property_type = prop_def.get("type", TYPE_NIL)
			var hint = prop_def.get("hint", PROPERTY_HINT_NONE)
			var hint_string = prop_def.get("hint_string", "")
			hint_string = _variable_brick_hint_override(brick_instance, property_name, hint_string)

			var ui_element = null

			# === Collapsible group header (hint == 999) ===
			if property_type == TYPE_NIL and hint == 999:
				# Outer container so we can set_meta on it
				var group_outer = VBoxContainer.new()
				group_outer.add_theme_constant_override("separation", 8)
				group_outer.set_meta("property_name", property_name)

				# Check if this group should start collapsed
				var start_collapsed = prop_def.get("collapsed", false)

				# Header button
				var group_btn = Button.new()
				group_btn.text = ("▸ " if start_collapsed else "▾ ") + hint_string
				group_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				group_btn.flat = true
				group_btn.add_theme_font_size_override("font_size", 11)
				group_outer.add_child(group_btn)

				# Body container (holds the properties in this group)
				var group_body = VBoxContainer.new()
				group_body.add_theme_constant_override("separation", 8)
				group_body.name = "GroupBody"
				group_body.visible = not start_collapsed
				group_outer.add_child(group_body)

				# Toggle collapse on click
				group_btn.pressed.connect(func():
					group_body.visible = not group_body.visible
					group_btn.text = ("▾ " if group_body.visible else "▸ ") + hint_string
					graph_node.reset_size()
				)

				graph_node.add_child(group_outer)
				current_group_container = group_body
				continue

			# Check if this is an enum
			if hint == PROPERTY_HINT_ENUM and not hint_string.is_empty():
				var hbox = HBoxContainer.new()
				var label = Label.new()
				label.text = _format_property_name(property_name) + ":"
				hbox.add_child(label)

				var option_button = OptionButton.new()
				option_button.name = "PropertyControl_" + property_name

				# Special case: AnimationPlayer list (find AnimationPlayer children)
				if hint_string == "__ANIMATION_PLAYER_LIST__":
					var anim_player_list = _get_animation_players(graph_node)

					var selected_index = 0
					for i in range(anim_player_list.size()):
						var player_name = anim_player_list[i]
						option_button.add_item(player_name, i)
						option_button.set_item_metadata(i, player_name)

						if player_name == property_value:
							selected_index = i

					# Add empty option if no AnimationPlayers found
					if anim_player_list.is_empty():
						option_button.add_item("(No AnimationPlayers found)", 0)
						option_button.disabled = true

					option_button.selected = selected_index

				# Special case: Animation list — scans scene tree for all AnimationPlayers
				elif hint_string == "__ANIMATION_LIST__":
					option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

					# Populate from all AnimationPlayers found in the scene tree
					var animation_list = _get_all_animations_in_scene()

					var selected_index = 0
					if animation_list.is_empty():
						option_button.add_item("(Click ↻ to load animations)", 0)
						option_button.disabled = true
					else:
						option_button.disabled = false
						for i in range(animation_list.size()):
							var anim_name = animation_list[i]
							option_button.add_item(anim_name, i)
							option_button.set_item_metadata(i, anim_name)
							if anim_name == property_value:
								selected_index = i
						option_button.selected = selected_index

					# Add a Refresh button to rescan the scene
					var refresh_btn = Button.new()
					refresh_btn.text = "↻"
					refresh_btn.tooltip_text = "Scan scene for AnimationPlayer nodes and reload animation list"
					refresh_btn.custom_minimum_size = Vector2(28, 0)
					refresh_btn.pressed.connect(func():
						var new_list = _get_all_animations_in_scene()
						option_button.clear()
						if new_list.is_empty():
							option_button.add_item("(No animations found)", 0)
							option_button.disabled = true
						else:
							option_button.disabled = false
							var new_selected = 0
							var current_val = brick_instance.get_property(property_name, "")
							for i in range(new_list.size()):
								var anim_name = new_list[i]
								option_button.add_item(anim_name, i)
								option_button.set_item_metadata(i, anim_name)
								if anim_name == current_val:
									new_selected = i
							option_button.selected = new_selected
						graph_node.reset_size()
					)

					option_button.item_selected.connect(_on_enum_property_changed.bind(graph_node, property_name, property_type))
					hbox.add_child(option_button)
					hbox.add_child(refresh_btn)
					ui_element = hbox
					# Skip the normal item_selected connection below since we connected it above
					graph_node.add_child(ui_element)
					ui_element.set_meta("property_name", property_name)
					continue

				# AnimationTree condition list — scans current node's AnimationTree for conditions
				elif hint_string == "__ANIM_TREE_CONDITION_LIST__":
					option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

					var condition_list = _get_animation_tree_conditions()

					var selected_index = 0
					if condition_list.is_empty():
						option_button.add_item("(Click ↻ to load conditions)", 0)
						option_button.disabled = true
					else:
						option_button.disabled = false
						for i in range(condition_list.size()):
							var cond_name = condition_list[i]
							option_button.add_item(cond_name, i)
							option_button.set_item_metadata(i, cond_name)
							if cond_name == property_value:
								selected_index = i
						option_button.selected = selected_index

					# Refresh button to re-scan the AnimationTree
					var refresh_btn = Button.new()
					refresh_btn.text = "↻"
					refresh_btn.tooltip_text = "Scan AnimationTree for conditions and reload list"
					refresh_btn.custom_minimum_size = Vector2(28, 0)
					refresh_btn.pressed.connect(func():
						var new_list = _get_animation_tree_conditions()
						option_button.clear()
						if new_list.is_empty():
							option_button.add_item("(No conditions found)", 0)
							option_button.disabled = true
						else:
							option_button.disabled = false
							var new_selected = 0
							var current_val = brick_instance.get_property(property_name, "")
							for i in range(new_list.size()):
								var cond_name = new_list[i]
								option_button.add_item(cond_name, i)
								option_button.set_item_metadata(i, cond_name)
								if cond_name == current_val:
									new_selected = i
							option_button.selected = new_selected
						graph_node.reset_size()
					)

					option_button.item_selected.connect(_on_enum_property_changed.bind(graph_node, property_name, property_type))
					hbox.add_child(option_button)
					hbox.add_child(refresh_btn)
					ui_element = hbox
					# Skip the normal item_selected connection below since we connected it above
					graph_node.add_child(ui_element)
					ui_element.set_meta("property_name", property_name)
					continue

				# Dynamic state-layer/state dropdowns
				elif _populate_dynamic_enum(option_button, brick_instance, property_name, hint_string, property_value):
					pass

				# Regular enum dropdown
				else:
					# Parse enum string (format: "Display1:value1,Display2:value2" or "Display1,Display2")
					var enum_parts = hint_string.split(",")
					var selected_index = 0

					for i in range(enum_parts.size()):
						var part = enum_parts[i].strip_edges()
						var display_name = part
						var value = part.to_lower().replace(" ", "_")

						# Check if it has a value specified (like "Space:32")
						if ":" in part:
							var split = part.split(":")
							display_name = split[0]
							value = split[1]

						option_button.add_item(display_name, i)
						option_button.set_item_metadata(i, value)

						# Check if this is the current value
						var current_value_str = str(property_value).to_lower().replace(" ", "_")
						var value_str = str(value).to_lower().replace(" ", "_")

						if property_type == TYPE_INT:
							# For int enums, compare as integers
							if str(value) == str(property_value):
								selected_index = i
						else:
							# For string enums, compare as strings
							if current_value_str == value_str:
								selected_index = i

					option_button.selected = selected_index

				option_button.item_selected.connect(_on_enum_property_changed.bind(graph_node, property_name, property_type))
				hbox.add_child(option_button)
				ui_element = hbox

			# Regular bool checkbox
			elif property_type == TYPE_BOOL:
				ui_element = CheckBox.new()
				ui_element.name = "PropertyControl_" + property_name
				ui_element.button_pressed = property_value
				ui_element.text = _format_property_name(property_name)
				ui_element.toggled.connect(_on_property_changed.bind(graph_node, property_name))

			# Number fields: a number, a variable, or math such as speed * 2.
			elif property_type in [TYPE_INT, TYPE_FLOAT] and hint != PROPERTY_HINT_ENUM:
				ui_element = _create_number_field(graph_node, brick_instance, prop_def, property_name, property_value, property_type)

			# File path with picker button
			elif property_type == TYPE_STRING and hint == PROPERTY_HINT_FILE:
				var hbox = HBoxContainer.new()
				var label = Label.new()
				label.text = _format_property_name(property_name) + ":"
				hbox.add_child(label)

				var line_edit = LineEdit.new()
				_select_line_edit_text_on_focus(line_edit)
				line_edit.name = "PropertyControl_" + property_name
				# Show just the filename, store full path in metadata
				var display_text = property_value.get_file() if not property_value.is_empty() else ""
				line_edit.text = display_text
				line_edit.placeholder_text = "Select file..."
				line_edit.custom_minimum_size = Vector2(120, 0)
				line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				line_edit.editable = false  # Use the file picker button instead
				line_edit.tooltip_text = property_value  # Full path on hover
				hbox.add_child(line_edit)

				var button = Button.new()
				button.text = "..."
				button.pressed.connect(_on_file_picker_pressed.bind(graph_node, property_name, hint_string))
				hbox.add_child(button)

				ui_element = hbox

			# Input Map action name: free text plus a dropdown of project actions.
			elif property_type == TYPE_STRING and prop_def.get("input_action_picker", false):
				ui_element = _create_input_action_picker(graph_node, brick_instance, property_name, property_value)

			# Logic Brick variable name: free text plus a dropdown of variables already created.
			elif property_type == TYPE_STRING and prop_def.get("variable_picker", false):
				ui_element = _create_variable_picker(graph_node, brick_instance, property_name, property_value)

			# Group name: free text / node drag plus a picker of groups used by the project.
			elif property_type == TYPE_STRING and prop_def.get("group_picker", false):
				ui_element = _create_group_picker(graph_node, brick_instance, prop_def, property_name, property_value)

			# Regular string line edit. Node-reference properties keep free typing and
			# Ctrl-drag, and also expose a filtered child-node picker.
			elif property_type == TYPE_STRING and hint != PROPERTY_HINT_ENUM:
				if _is_node_reference_property(prop_def, property_name):
					ui_element = _create_node_reference_picker(graph_node, brick_instance, prop_def, property_name, property_value)
				else:
					var hbox = HBoxContainer.new()
					var label = Label.new()
					label.text = _format_property_name(property_name) + ":"
					hbox.add_child(label)

					var line_edit = LineEdit.new()
					_select_line_edit_text_on_focus(line_edit)
					line_edit.name = "PropertyControl_" + property_name
					line_edit.text = str(property_value) if typeof(property_value) != TYPE_STRING else property_value
					line_edit.placeholder_text = "Enter " + _format_property_name(property_name).to_lower()
					line_edit.text_changed.connect(_on_property_changed.bind(graph_node, property_name))
					hbox.add_child(line_edit)
					ui_element = hbox

			# Color picker
			elif property_type == TYPE_COLOR:
				var hbox = HBoxContainer.new()
				var label = Label.new()
				label.text = _format_property_name(property_name) + ":"
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.add_child(label)

				var color_btn = ColorPickerButton.new()
				color_btn.name = "PropertyControl_" + property_name
				color_btn.custom_minimum_size = Vector2(80, 0)
				if typeof(property_value) == TYPE_COLOR:
					color_btn.color = property_value
				color_btn.color_changed.connect(_on_property_changed.bind(graph_node, property_name))
				hbox.add_child(color_btn)
				ui_element = hbox

			# === Dynamic array list (e.g. track list) ===
			elif property_type == TYPE_ARRAY:
				var item_hint        = prop_def.get("item_hint", PROPERTY_HINT_NONE)
				var item_hint_string = prop_def.get("item_hint_string", "")
				var item_label_text  = prop_def.get("item_label", "Item")

				var vbox = VBoxContainer.new()
				vbox.add_theme_constant_override("separation", 8)
				vbox.set_meta("property_name", property_name)

				# Header row: label + Add button
				var header = HBoxContainer.new()
				var arr_label = Label.new()
				arr_label.text = _format_property_name(property_name) + ":"
				arr_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				header.add_child(arr_label)
				var add_btn = Button.new()
				add_btn.text = "+"
				add_btn.custom_minimum_size = Vector2(28, 0)
				header.add_child(add_btn)
				vbox.add_child(header)

				# Item list container
				var list_vbox = VBoxContainer.new()
				list_vbox.add_theme_constant_override("separation", 8)
				list_vbox.name = "ArrayListContainer"
				vbox.add_child(list_vbox)

				# Build the list rows — called immediately and after any add/remove
				var capture_linked = prop_def.get("linked_array", "")
				var capture_linked_default = prop_def.get("linked_default", "")
				_build_array_property_list(
					list_vbox, graph_node, brick_instance,
					property_name, item_hint, item_hint_string, item_label_text,
					capture_linked, capture_linked_default
				)

				# Add button handler
				var capture_item_default = prop_def.get("item_default", "")
				add_btn.pressed.connect(func():
					var upd_arr: Array = brick_instance.get_property(property_name)
					if typeof(upd_arr) != TYPE_ARRAY:
						upd_arr = []
					upd_arr.append(capture_item_default)
					brick_instance.set_property(property_name, upd_arr)
					# If this array has a linked array, append its default value too
					var linked = prop_def.get("linked_array", "")
					var linked_default = prop_def.get("linked_default", "")
					if not linked.is_empty():
						var linked_arr: Array = brick_instance.get_property(linked)
						if typeof(linked_arr) != TYPE_ARRAY:
							linked_arr = []
						linked_arr.append(linked_default)
						brick_instance.set_property(linked, linked_arr)
					# Sync editable waypoint helper nodes for 3D and 2D waypoint actuators.
					if property_name == "waypoints":
						if panel.current_node is Node3D:
							var WaypointPathActuator = load("res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd")
							if WaypointPathActuator:
								WaypointPathActuator.sync_waypoint_nodes(panel.current_node, brick_instance)
						elif panel.current_node is Node2D:
							var WaypointPath2DActuator = load("res://addons/logic_bricks/bricks/actuators/2d/waypoint_path_2d_actuator.gd")
							if WaypointPath2DActuator:
								WaypointPath2DActuator.sync_waypoint_nodes(panel.current_node, brick_instance)
					panel._save_graph_to_metadata()
					_build_array_property_list(
						list_vbox, graph_node, brick_instance,
						property_name, item_hint, item_hint_string, item_label_text,
						linked, linked_default
					)
					graph_node.reset_size()
				)

				ui_element = vbox

			if ui_element:
				ui_element = typing_assistance.decorate(ui_element, graph_node, brick_instance, prop_def)
				# Store property name on the UI element for conditional visibility
				ui_element.set_meta("property_name", property_name)
				# Apply tooltip from brick's tooltip definitions
				if tooltips.has(property_name):
					ui_element.tooltip_text = tooltips[property_name]
				# Place inside active group container if one exists, otherwise on graph node
				if current_group_container != null:
					current_group_container.add_child(ui_element)
				else:
					graph_node.add_child(ui_element)
	else:
		# Fallback: create UI from properties directly (old behavior)
		for property_name in properties:
			var property_value = properties[property_name]
			var ui_element = null

			if property_value is bool:
				ui_element = CheckBox.new()
				ui_element.button_pressed = property_value
				ui_element.text = _format_property_name(property_name)
				ui_element.toggled.connect(_on_property_changed.bind(graph_node, property_name))

			elif property_value is int:
				var hbox = HBoxContainer.new()
				var label = Label.new()
				label.text = _format_property_name(property_name) + ":"
				hbox.add_child(label)

				ui_element = SpinBox.new()
				_select_spinbox_text_on_focus(ui_element)
				ui_element.min_value = -10000
				ui_element.max_value = 10000
				ui_element.value = property_value
				ui_element.value_changed.connect(_on_property_changed.bind(graph_node, property_name))
				hbox.add_child(ui_element)
				ui_element = hbox


			elif property_value is float:
				var hbox = HBoxContainer.new()
				var label = Label.new()
				label.text = _format_property_name(property_name) + ":"
				hbox.add_child(label)

				ui_element = SpinBox.new()
				_select_spinbox_text_on_focus(ui_element)
				ui_element.step = 0.01
				ui_element.min_value = -10000
				ui_element.max_value = 10000
				ui_element.value = property_value
				ui_element.value_changed.connect(_on_property_changed.bind(graph_node, property_name))
				hbox.add_child(ui_element)
				ui_element = hbox

			elif property_value is String:
				var hbox = HBoxContainer.new()
				var label = Label.new()
				label.text = _format_property_name(property_name) + ":"
				hbox.add_child(label)

				ui_element = LineEdit.new()
				_select_line_edit_text_on_focus(ui_element)
				ui_element.text = property_value
				ui_element.text_changed.connect(_on_property_changed.bind(graph_node, property_name))
				hbox.add_child(ui_element)
				ui_element = hbox

			if ui_element:
				# Store property name on the UI element for conditional visibility
				ui_element.set_meta("property_name", property_name)
				if tooltips.has(property_name):
					ui_element.tooltip_text = tooltips[property_name]
				graph_node.add_child(ui_element)

	var has_input_action_picker := false
	for prop_def in prop_definitions:
		if prop_def.get("input_action_picker", false):
			has_input_action_picker = true
			break
	if has_input_action_picker:
		graph_node.add_child(_create_open_input_maps_button())

	# Add debug section separator
	var debug_separator = HSeparator.new()
	graph_node.add_child(debug_separator)

	# Add debug checkbox
	var debug_hbox = HBoxContainer.new()
	var debug_check = CheckBox.new()
	debug_check.name = "DebugCheckbox"
	debug_check.button_pressed = brick_instance.debug_enabled
	debug_check.text = "Debug Print"
	debug_check.toggled.connect(_on_debug_enabled_changed.bind(graph_node, brick_instance))
	debug_hbox.add_child(debug_check)
	graph_node.add_child(debug_hbox)

	# Add debug message field
	var debug_msg_hbox = HBoxContainer.new()
	var debug_msg_label = Label.new()
	debug_msg_label.text = "Message:"
	debug_msg_hbox.add_child(debug_msg_label)

	var debug_msg_edit = LineEdit.new()
	_select_line_edit_text_on_focus(debug_msg_edit)
	debug_msg_edit.name = "DebugMessageEdit"
	debug_msg_edit.text = brick_instance.debug_message
	debug_msg_edit.placeholder_text = "Debug message..."
	debug_msg_edit.custom_minimum_size = Vector2(150, 0)
	debug_msg_edit.text_changed.connect(_on_debug_message_changed.bind(graph_node, brick_instance))
	debug_msg_hbox.add_child(debug_msg_edit)
	graph_node.add_child(debug_msg_hbox)

	# Apply initial conditional visibility based on current property values
	_update_conditional_visibility(graph_node, brick_instance)


func _format_property_name(property_name: String) -> String:
	if property_name == "state_id":
		return "State"
	if property_name == "all_states":
		return "All States"
	# Convert property_name to Display Name
	return property_name.replace("_", " ").capitalize()

func _get_animation_players(graph_node: GraphNode) -> Array[String]:
	return _pickers._get_animation_players(graph_node)


func _build_array_property_list(
		list_vbox: VBoxContainer,
		graph_node: GraphNode,
		brick_instance,
		property_name: String,
		item_hint: int,
		item_hint_string: String,
		item_label_text: String,
		linked_array: String = "",
		linked_default: String = "") -> void:
	# Clear existing rows
	for c in list_vbox.get_children():
		c.queue_free()

	var current_arr: Array = brick_instance.get_property(property_name)
	if typeof(current_arr) != TYPE_ARRAY:
		current_arr = []

	for idx in current_arr.size():
		var row = HBoxContainer.new()

		var idx_label = Label.new()
		idx_label.text = "%s %d:" % [item_label_text, idx]
		idx_label.custom_minimum_size = Vector2(56, 0)
		row.add_child(idx_label)

		if item_hint == PROPERTY_HINT_FILE:
			var le = LineEdit.new()
			_select_line_edit_text_on_focus(le)
			le.text = str(current_arr[idx])
			le.placeholder_text = "Select file..."
			le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			le.editable = false
			le.tooltip_text = le.text
			row.add_child(le)

			var pick_btn = Button.new()
			pick_btn.text = "..."
			pick_btn.custom_minimum_size = Vector2(28, 0)
			var capture_idx = idx
			var capture_le = le
			pick_btn.pressed.connect(func():
				var dialog = EditorFileDialog.new()
				dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
				for f in item_hint_string.split(","):
					dialog.add_filter(f.strip_edges())
				panel.add_child(dialog)
				dialog.popup_centered(Vector2(900, 700))
				var capture_linked2      = linked_array
				var capture_linked_def2  = linked_default
				dialog.file_selected.connect(func(path: String):
					# Update the scenes array
					var upd: Array = brick_instance.get_property(property_name)
					if typeof(upd) != TYPE_ARRAY: upd = []
					while upd.size() <= capture_idx: upd.append("")
					upd[capture_idx] = path
					brick_instance.set_property(property_name, upd)
					# Ensure the linked array (pool_sizes) has a matching entry
					if not capture_linked2.is_empty():
						var linked_upd: Array = brick_instance.get_property(capture_linked2)
						if typeof(linked_upd) != TYPE_ARRAY: linked_upd = []
						while linked_upd.size() <= capture_idx:
							linked_upd.append(capture_linked_def2)
						brick_instance.set_property(capture_linked2, linked_upd)
					panel._save_graph_to_metadata()
					dialog.queue_free()
					# Rebuild the list so the LineEdit shows the new path cleanly
					_build_array_property_list(
						list_vbox, graph_node, brick_instance,
						property_name, item_hint, item_hint_string, item_label_text,
						capture_linked2, capture_linked_def2
					)
					graph_node.reset_size()
				)
			)
			row.add_child(pick_btn)

			# If this array has a linked value (e.g. pool_sizes), show an editable
			# field for it inline on the same row, right after the file picker.
			if not linked_array.is_empty():
				var linked_arr: Array = brick_instance.get_property(linked_array)
				if typeof(linked_arr) != TYPE_ARRAY: linked_arr = []
				var linked_val = linked_arr[idx] if idx < linked_arr.size() else linked_default
				var linked_le = LineEdit.new()
				_select_line_edit_text_on_focus(linked_le)
				linked_le.text = str(linked_val)
				linked_le.placeholder_text = linked_default
				linked_le.custom_minimum_size = Vector2(64, 0)
				linked_le.tooltip_text = "Pool size (integer or variable name)"
				var capture_linked_idx = idx
				linked_le.text_changed.connect(func(val: String):
					var lupd: Array = brick_instance.get_property(linked_array)
					if typeof(lupd) != TYPE_ARRAY: lupd = []
					while lupd.size() <= capture_linked_idx: lupd.append(linked_default)
					lupd[capture_linked_idx] = val
					brick_instance.set_property(linked_array, lupd)
					panel._save_graph_to_metadata()
				)
				var linked_wrapper := VBoxContainer.new()
				linked_wrapper.add_child(linked_le)
				row.add_child(linked_wrapper)
				var linked_definition := {"name": linked_array, "typing_expression_types": ["int", "float"]}
				typing_assistance.attach(linked_wrapper, linked_le, graph_node, brick_instance, linked_definition, func(value: String): linked_le.text_changed.emit(value))

		# Remove button
		var rm_btn = Button.new()
		rm_btn.text = "-"
		rm_btn.custom_minimum_size = Vector2(28, 0)
		var capture_idx_rm = idx
		rm_btn.pressed.connect(func():
			var upd: Array = brick_instance.get_property(property_name)
			if typeof(upd) != TYPE_ARRAY: upd = []
			upd.remove_at(capture_idx_rm)
			brick_instance.set_property(property_name, upd)
			# Sync linked array if set
			if not linked_array.is_empty():
				var linked_upd: Array = brick_instance.get_property(linked_array)
				if typeof(linked_upd) != TYPE_ARRAY: linked_upd = []
				if capture_idx_rm < linked_upd.size():
					linked_upd.remove_at(capture_idx_rm)
					brick_instance.set_property(linked_array, linked_upd)
			# Sync editable waypoint helper nodes for 3D and 2D waypoint actuators.
			if property_name == "waypoints":
				if panel.current_node is Node3D:
					var WaypointPathActuator = load("res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd")
					if WaypointPathActuator:
						WaypointPathActuator.sync_waypoint_nodes(panel.current_node, brick_instance)
				elif panel.current_node is Node2D:
					var WaypointPath2DActuator = load("res://addons/logic_bricks/bricks/actuators/2d/waypoint_path_2d_actuator.gd")
					if WaypointPath2DActuator:
						WaypointPath2DActuator.sync_waypoint_nodes(panel.current_node, brick_instance)
			panel._save_graph_to_metadata()
			_build_array_property_list(
				list_vbox, graph_node, brick_instance,
				property_name, item_hint, item_hint_string, item_label_text,
				linked_array, linked_default
			)
			graph_node.reset_size()
		)
		row.add_child(rm_btn)
		list_vbox.add_child(row)


func _get_all_animations_in_scene() -> Array[String]:
	return _pickers._get_all_animations_in_scene()


func _get_animation_tree_conditions() -> Array[String]:
	return _pickers._get_animation_tree_conditions()


func _find_prop_nodes(graph_node: GraphNode) -> Array:
	var result = []
	for child in graph_node.get_children():
		if child.has_meta("property_name"):
			result.append(child)
			var group_body = child.get_node_or_null("GroupBody")
			if group_body:
				for grandchild in group_body.get_children():
					if grandchild.has_meta("property_name"):
						result.append(grandchild)
	return result


func _update_conditional_visibility(graph_node: GraphNode, brick_instance) -> void:
	_visibility_rules.update(graph_node, brick_instance)


func _logic_variable_type(variable_name: String) -> String:
	var wanted := variable_name.strip_edges()
	if wanted.is_empty() or panel == null:
		return ""
	# Prefer the panel's live data so type-aware bricks react immediately to editor changes.
	for data in panel.variables_data:
		if data is Dictionary and str(data.get("name", "")).strip_edges() == wanted:
			return str(data.get("type", ""))
	for data in panel.global_vars_data:
		if data is Dictionary and str(data.get("name", "")).strip_edges() == wanted:
			return str(data.get("type", ""))
	return ""

func _variable_brick_hint_override(brick_instance, property_name: String, fallback: String) -> String:
	var script_name: String = str(brick_instance.get_script().resource_path.get_file().get_basename())
	var var_type := _logic_variable_type(str(brick_instance.get_property("variable_name", "")))
	if var_type == "Array":
		if script_name == "variable_sensor" and property_name == "evaluation_type":
			return "Contains:contains,Does Not Contain:does_not_contain,Is Empty:is_empty,Is Not Empty:is_not_empty,Size Equals:size_equals,Size Greater Than:size_greater_than,Size Less Than:size_less_than,Changed:changed"
		if script_name == "variable_actuator" and property_name == "mode":
			return "Add Item:add_item,Remove Item:remove_item,Remove At Index:remove_at_index,Set Item At Index:set_item_at_index,Clear:clear,Assign:assign,Copy:copy"
	elif var_type == "String" and script_name == "variable_actuator" and property_name == "mode":
		return "Replace:replace,Add Before:prepend,Add After:append,Copy:copy"
	return fallback


func _refresh_variable_brick_operation_control(graph_node: GraphNode, brick_instance) -> void:
	var script_name: String = str(brick_instance.get_script().resource_path.get_file().get_basename())
	var property_name := "evaluation_type" if script_name == "variable_sensor" else ("mode" if script_name == "variable_actuator" else "")
	if property_name.is_empty():
		return
	var option: OptionButton = null
	for child in graph_node.get_children():
		if child is HBoxContainer:
			var candidate = child.get_node_or_null("PropertyControl_" + property_name)
			if candidate is OptionButton:
				option = candidate
				break
	if option == null:
		return
	var fallback := "Equal,Not Equal,Interval,Changed,Greater Than,Less Than,Greater or Equal,Less or Equal" if script_name == "variable_sensor" else "Assign:assign,Adjust By:add,Copy:copy,Toggle:toggle"
	var hint := _variable_brick_hint_override(brick_instance, property_name, fallback)
	var current := str(brick_instance.get_property(property_name, ""))
	option.clear()
	var selected := -1
	var parts = hint.split(",")
	for i in range(parts.size()):
		var part := str(parts[i]).strip_edges()
		var display := part
		var actual := part.to_lower().replace(" ", "_")
		if ":" in part:
			var pair = part.split(":", false, 1)
			display = pair[0]
			actual = pair[1]
		option.add_item(display, i)
		option.set_item_metadata(i, actual)
		if actual == current:
			selected = i
	if selected < 0 and option.item_count > 0:
		# Only coerce an incompatible operation after the variable type is known.
		# During project/node loading variables_data may briefly be empty; mutating
		# here would destroy a saved Array operation such as add_item/contains.
		var var_type := _logic_variable_type(str(brick_instance.get_property("variable_name", "")))
		if not var_type.is_empty():
			selected = 0
			brick_instance.set_property(property_name, str(option.get_item_metadata(0)))
	option.selected = selected
	_update_conditional_visibility(graph_node, brick_instance)
	graph_node.reset_size()


func _create_node_reference_picker(graph_node: GraphNode, brick_instance, prop_def: Dictionary, property_name: String, property_value) -> Control:
	return _pickers._create_node_reference_picker(graph_node, brick_instance, prop_def, property_name, property_value)


func _compatible_direct_child_nodes(root: Node, accepted_types: Array) -> Array[Node]:
	return _pickers._compatible_direct_child_nodes(root, accepted_types)


func _compatible_child_nodes(root: Node, accepted_types: Array) -> Array[Node]:
	return _pickers._compatible_child_nodes(root, accepted_types)


func _node_matches_types(node: Node, accepted_types: Array) -> bool:
	return _pickers._node_matches_types(node, accepted_types)


func _is_node_reference_property(prop_def: Dictionary, property_name: String) -> bool:
	# One definition shared with rename syncing (core/node_reference_sync.gd).
	return NodeReferenceSync.is_node_reference_property(prop_def, property_name)


func _accepted_node_types(prop_def: Dictionary, property_name: String) -> Array:
	return _pickers._accepted_node_types(prop_def, property_name)

## A text box for a number field. Plain numbers are stored as numbers (kept
## within the field's range when you leave the box); anything else is stored
## as text and used as a variable name or math in the generated code.
func _create_number_field(graph_node: GraphNode, brick_instance, prop_def: Dictionary, property_name: String, property_value, property_type: int) -> Control:
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = _format_property_name(property_name) + ":"
	hbox.add_child(label)
	var line_edit = LineEdit.new()
	_select_line_edit_text_on_focus(line_edit)
	line_edit.name = "PropertyControl_" + property_name
	line_edit.custom_minimum_size = Vector2(80, 0)
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shown = property_value
	if typeof(shown) in [TYPE_INT, TYPE_FLOAT] and (property_name == "minimum_landing_speed" or (property_name == "threshold" and brick_instance.brick_name == "Movement Detected")):
		shown = absf(shown)
	line_edit.text = _number_text(shown, property_type)
	line_edit.placeholder_text = "number or variable"
	line_edit.text_changed.connect(func(text: String):
		_on_property_changed(LogicBrickBase.numeric_value_from_text(text, property_type), graph_node, property_name))
	var commit := func():
		var value = LogicBrickBase.numeric_value_from_text(line_edit.text, property_type)
		if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			var clamped = _clamp_to_range(value, prop_def)
			if clamped != value or line_edit.text.strip_edges() != _number_text(clamped, property_type):
				line_edit.text = _number_text(clamped, property_type)
				_on_property_changed(clamped, graph_node, property_name)
	line_edit.focus_exited.connect(commit)
	line_edit.text_submitted.connect(func(_t): commit.call())
	hbox.add_child(line_edit)
	return hbox


static func _number_text(value, property_type: int) -> String:
	if typeof(value) == TYPE_FLOAT:
		if property_type == TYPE_INT:
			return str(int(value))
		var text := String.num(value, 4)
		return text if text.contains(".") else text + ".0"
	return str(value)


static func _clamp_to_range(value, prop_def: Dictionary):
	if int(prop_def.get("hint", PROPERTY_HINT_NONE)) != PROPERTY_HINT_RANGE:
		return value
	var parts = str(prop_def.get("hint_string", "")).split(",")
	if parts.size() < 2 or not parts[0].strip_edges().is_valid_float() or not parts[1].strip_edges().is_valid_float():
		return value
	var lo := float(parts[0])
	var hi := float(parts[1])
	if typeof(value) == TYPE_INT:
		return clampi(value, int(lo), int(hi))
	return clampf(value, lo, hi)


func _on_property_changed(value, graph_node: GraphNode, property_name: String) -> void:
	if graph_node.has_meta("brick_data"):
		var brick_data = graph_node.get_meta("brick_data")
		var brick_instance = brick_data["brick_instance"]
		if value is String:
			for definition in brick_instance.get_property_definitions():
				if str(definition.get("name", "")) != property_name:
					continue
				var is_variable := str(typing_assistance.context(brick_instance, definition).get("kind", "")) == "variable"
				if is_variable or property_name in ["vector_variable", "position_variable", "rotation_variable", "scale_variable"]:
					var edit := graph_node.find_child("PropertyControl_" + property_name, true, false) as LineEdit
					value = VariableUtils.normalize_name_edit(value, edit)
				break
		brick_instance.set_property(property_name, value)

		if property_name == "variable_name":
			_refresh_variable_brick_operation_control(graph_node, brick_instance)

		if property_name == "target_node" and brick_instance.get_script().resource_path.ends_with("property_actuator.gd"):
			_refresh_target_node_property_dropdown(graph_node, brick_instance)

		if brick_data.get("brick_type", "") == "controller" and property_name in ["state_id", "all_states"]:
			_update_controller_title(graph_node, brick_instance)

		_update_conditional_visibility(graph_node, brick_instance)
		_refresh_compatibility_ui(graph_node, brick_instance)
		panel._save_graph_to_metadata()
		typing_assistance.refresh_graph(graph_node)


func _update_controller_title(graph_node: GraphNode, brick_instance) -> void:
	var props = brick_instance.properties
	var all_states = props.get("all_states", false)
	var state_id = str(props.get("state_id", ""))
	var state_name = panel.get_state_display_name(state_id) if panel and panel.has_method("get_state_display_name") else state_id
	if all_states:
		graph_node.title = "Gate [ALL]"
	else:
		graph_node.title = "Gate [%s]" % (state_name if not state_name.is_empty() else "No State")


func _on_instance_name_changed(new_name: String, graph_node: GraphNode, brick_instance) -> void:
	var edit := graph_node.find_child("InstanceNameEdit", true, false) as LineEdit
	new_name = VariableUtils.normalize_name_edit(new_name, edit)
	var sanitized_name = new_name.strip_edges().to_lower().replace(" ", "_")
	sanitized_name = sanitized_name.replace("-", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	sanitized_name = regex.sub(sanitized_name, "", true)

	brick_instance.set_instance_name(sanitized_name)
	panel._save_graph_to_metadata()


func _on_debug_enabled_changed(enabled: bool, graph_node: GraphNode, brick_instance) -> void:
	brick_instance.debug_enabled = enabled
	panel._save_graph_to_metadata()


func _on_debug_message_changed(new_message: String, graph_node: GraphNode, brick_instance) -> void:
	brick_instance.debug_message = new_message
	panel._save_graph_to_metadata()


func _on_enum_property_changed(index: int, graph_node: GraphNode, property_name: String, property_type: int) -> void:
	# Handle enum property changes from OptionButton
	if not graph_node.has_meta("brick_data"):
		return

	var brick_data = graph_node.get_meta("brick_data")
	var brick_instance = brick_data["brick_instance"]

	# Get the hint_string from the brick's property definitions to derive the value
	var prop_defs = brick_instance.get_property_definitions()
	var hint_string = ""
	for prop_def in prop_defs:
		if prop_def["name"] == property_name:
			hint_string = prop_def.get("hint_string", "")
			break

	if hint_string.is_empty():
		return

	# Get the actual OptionButton control to access its metadata
	var option_button: OptionButton = null
	for child in graph_node.get_children():
		if child is HBoxContainer:
			var control = child.get_node_or_null("PropertyControl_" + property_name)
			if control and control is OptionButton:
				option_button = control
				break

	var value

	# Special handling for dynamic lists (they store actual values in metadata)
	if hint_string in ["__ANIMATION_LIST__", "__ANIMATION_PLAYER_LIST__", "__STATE_LIST__", "__ANIM_TREE_CONDITION_LIST__", "__TARGET_NODE_PROPERTY_LIST__"] and option_button:
		# Get the value directly from the item metadata
		value = option_button.get_item_metadata(index)
	else:
		# Regular enums store their actual values as item metadata. This also lets
		# type-aware variable bricks swap their operation lists dynamically.
		if option_button and index >= 0 and index < option_button.item_count:
			value = option_button.get_item_metadata(index)
		else:
			var enum_parts = hint_string.split(",")
			if index < 0 or index >= enum_parts.size():
				return
			var part = enum_parts[index].strip_edges()
			value = part.to_lower().replace(" ", "_")
			if ":" in part:
				value = part.split(":")[1]

		# Convert to correct type
		if property_type == TYPE_INT:
			# Use the raw index directly — converting the enum label string to int
			# (e.g. int("enable_monitoring")) always returns 0, which is wrong.
			value = index
		else:
			value = str(value)

	brick_instance.set_property(property_name, value)

	# Update controller title to reflect state changes
	var brick_class = brick_data.get("brick_class", "")
	if brick_data.get("brick_type", "") == "controller" and property_name in ["state_id", "all_states", "logic_mode"]:
		_update_controller_title(graph_node, brick_instance)

	# When a preset is selected, populate the related value fields.
	# Presets only write to the editable fields below them; the fields can still be numbers or variable names.
	if ((property_name == "preset") or (brick_class in ["ObjectShakeActuator", "ObjectShake2DActuator"] and property_name == "shake_type")) and brick_instance.has_method("get_preset_values"):
		var selected_preset = str(value) if property_name == "preset" else str(brick_instance.get_property("preset"))
		var preset_vals = brick_instance.get_preset_values(selected_preset)
		var field_names = []
		if brick_class == "ScreenShakeActuator" and preset_vals.size() == 4:
			field_names = ["trauma", "max_offset", "decay", "noise_speed"]
		elif brick_class == "HitStopActuator" and preset_vals.size() == 2:
			field_names = ["duration", "time_scale"]
		elif brick_class == "ObjectShakeActuator" and preset_vals.size() == 3:
			field_names = ["x", "y", "z"]
		elif brick_class == "ObjectShake2DActuator":
			var shake_type_2d = str(brick_instance.get_property("shake_type", "translate")).to_lower().replace(" ", "_")
			if shake_type_2d == "rotate" and preset_vals.size() == 1:
				field_names = ["rotation_degrees"]
			elif preset_vals.size() == 2:
				field_names = ["x", "y"]

		if field_names.size() == preset_vals.size():
			for i in field_names.size():
				var fname = field_names[i]
				var fval = preset_vals[i]
				brick_instance.set_property(fname, fval)
				for child in graph_node.get_children():
					if child.has_meta("property_name") and child.get_meta("property_name") == fname:
						var ctrl = child.find_child("PropertyControl_" + fname, true, false)
						if ctrl and ctrl is LineEdit:
							ctrl.text = fval
						break

	panel._save_graph_to_metadata()

	# Update conditional visibility for fields that depend on this enum
	_update_conditional_visibility(graph_node, brick_instance)
	_refresh_compatibility_ui(graph_node, brick_instance)
	typing_assistance.refresh_graph(graph_node)


func _populate_dynamic_enum(option_button: OptionButton, brick_instance, property_name: String, hint_string: String, property_value) -> bool:
	if hint_string == "__TARGET_NODE_PROPERTY_LIST__":
		_populate_target_node_property_enum(option_button, brick_instance, property_value)
		return true
	if hint_string == "__STATE_LIST__":
		var states: Array = panel.get_state_options() if panel and panel.has_method("get_state_options") else []
		if states.is_empty():
			option_button.add_item("(No states)", 0)
			option_button.disabled = true
			return true
		var selected_index := 0
		for i in range(states.size()):
			var item: Dictionary = states[i]
			option_button.add_item(str(item.get("name", item.get("id", ""))), i)
			option_button.set_item_metadata(i, str(item.get("id", "")))
			if str(item.get("id", "")) == str(property_value):
				selected_index = i
		option_button.selected = selected_index
		if str(property_value).strip_edges().is_empty() and option_button.item_count > 0:
			brick_instance.set_property(property_name, option_button.get_item_metadata(selected_index))
		return true
	return false


func _resolve_property_actuator_target(brick_instance):
	return _pickers._resolve_property_actuator_target(brick_instance)


func _populate_target_node_property_enum(option_button: OptionButton, brick_instance, property_value) -> void:
	_pickers._populate_target_node_property_enum(option_button, brick_instance, property_value)


func _refresh_target_node_property_dropdown(graph_node: GraphNode, brick_instance) -> void:
	_pickers._refresh_target_node_property_dropdown(graph_node, brick_instance)


func _refresh_state_dropdown(graph_node: GraphNode, brick_instance) -> void:
	for child in graph_node.get_children():
		var control = child.find_child("PropertyControl_state_id", true, false)
		if control and control is OptionButton:
			var option_button: OptionButton = control
			var current_value = brick_instance.get_property("state_id", "")
			option_button.clear()
			_populate_dynamic_enum(option_button, brick_instance, "state_id", "__STATE_LIST__", current_value)
			option_button.disabled = option_button.item_count == 0 or (option_button.item_count == 1 and str(option_button.get_item_text(0)).begins_with("("))
			if not option_button.disabled and option_button.selected >= 0:
				var new_value = option_button.get_item_metadata(option_button.selected)
				brick_instance.set_property("state_id", new_value)
			return


func _get_project_input_actions() -> Array[String]:
	return _pickers._get_project_input_actions()


func _get_builtin_input_actions(project_actions: Array[String]) -> Array[String]:
	return _pickers._get_builtin_input_actions(project_actions)


func _create_open_input_maps_button() -> Button:
	return _pickers._create_open_input_maps_button()


func _create_input_action_picker(graph_node: GraphNode, brick_instance, property_name: String, property_value) -> Control:
	return _pickers._create_input_action_picker(graph_node, brick_instance, property_name, property_value)


func _create_variable_picker(graph_node: GraphNode, brick_instance, property_name: String, property_value) -> Control:
	return _pickers._create_variable_picker(graph_node, brick_instance, property_name, property_value)


func _collect_project_group_names() -> Array[String]:
	return _pickers._collect_project_group_names()


func _group_picker_condition_matches(brick_instance, condition: Dictionary) -> bool:
	return _pickers._group_picker_condition_matches(brick_instance, condition)


func _update_group_picker_buttons(graph_node: GraphNode, brick_instance) -> void:
	_pickers._update_group_picker_buttons(graph_node, brick_instance)


func _create_group_picker(graph_node: GraphNode, brick_instance, prop_def: Dictionary, property_name: String, property_value) -> Control:
	return _pickers._create_group_picker(graph_node, brick_instance, prop_def, property_name, property_value)

func _on_file_picker_pressed(graph_node: GraphNode, property_name: String, filter: String) -> void:
	_pickers._on_file_picker_pressed(graph_node, property_name, filter)

