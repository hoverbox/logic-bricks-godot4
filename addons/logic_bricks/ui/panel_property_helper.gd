extends RefCounted

var panel = null

func setup(target_panel) -> void:
	panel = target_panel


func _create_brick_ui(graph_node: GraphNode, brick_instance) -> void:
	var properties = brick_instance.get_properties()
	var prop_definitions = brick_instance.get_property_definitions()
	
	# Get tooltip definitions - try brick first, then centralized file
	var tooltips = {}
	if brick_instance.has_method("get_tooltip_definitions"):
		tooltips = brick_instance.get_tooltip_definitions()
	if tooltips.is_empty():
		var BrickTooltips = load("res://addons/logic_bricks/core/brick_tooltips.gd")
		if BrickTooltips:
			var brick_data = graph_node.get_meta("brick_data") if graph_node.has_meta("brick_data") else null
			if brick_data:
				tooltips = BrickTooltips.get_tooltips(brick_data["brick_class"])
	
	# Apply brick description tooltip to the GraphNode itself
	if tooltips.has("_description"):
		graph_node.tooltip_text = tooltips["_description"]
	
	# Add instance name field first
	var name_hbox = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = "Name:"
	name_hbox.add_child(name_label)
	
	var name_edit = LineEdit.new()
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
			
			var ui_element = null
			
			# === Collapsible group header (hint == 999) ===
			if property_type == TYPE_NIL and hint == 999:
				# Outer container so we can set_meta on it
				var group_outer = VBoxContainer.new()
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
			
			# Regular int spinbox
			elif property_type == TYPE_INT and hint != PROPERTY_HINT_ENUM:
				var hbox = HBoxContainer.new()
				var label = Label.new()
				label.text = _format_property_name(property_name) + ":"
				hbox.add_child(label)
				
				var spinbox = SpinBox.new()
				spinbox.name = "PropertyControl_" + property_name
				spinbox.min_value = -10000
				spinbox.max_value = 10000
				spinbox.value = float(str(property_value))
				spinbox.value_changed.connect(func(val: float): _on_property_changed(int(val), graph_node, property_name))
				hbox.add_child(spinbox)
				ui_element = hbox
			
			# Regular float spinbox
			elif property_type == TYPE_FLOAT:
				var hbox = HBoxContainer.new()
				var label = Label.new()
				label.text = _format_property_name(property_name) + ":"
				hbox.add_child(label)
				
				var spinbox = SpinBox.new()
				spinbox.name = "PropertyControl_" + property_name
				# Parse range from hint_string if provided (format: "min,max,step")
				if hint == PROPERTY_HINT_RANGE and not hint_string.is_empty():
					var range_parts = hint_string.split(",")
					if range_parts.size() >= 1: spinbox.min_value = float(range_parts[0])
					if range_parts.size() >= 2: spinbox.max_value = float(range_parts[1])
					if range_parts.size() >= 3: spinbox.step = float(range_parts[2])
					else: spinbox.step = 0.01
				else:
					spinbox.step = 0.01
					spinbox.min_value = -10000
					spinbox.max_value = 10000
				spinbox.value = float(str(property_value))
				spinbox.value_changed.connect(_on_property_changed.bind(graph_node, property_name))
				hbox.add_child(spinbox)
				ui_element = hbox
			
			# File path with picker button
			elif property_type == TYPE_STRING and hint == PROPERTY_HINT_FILE:
				var hbox = HBoxContainer.new()
				var label = Label.new()
				label.text = _format_property_name(property_name) + ":"
				hbox.add_child(label)
				
				var line_edit = LineEdit.new()
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
			
			# Regular string line edit
			elif property_type == TYPE_STRING and hint != PROPERTY_HINT_ENUM:
				var hbox = HBoxContainer.new()
				var label = Label.new()
				label.text = _format_property_name(property_name) + ":"
				hbox.add_child(label)
				
				var line_edit = LineEdit.new()
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
					# Sync waypoint Node3D children if this is a WaypointPathActuator
					if property_name == "waypoints" and panel.current_node is Node3D:
						var WaypointPathActuator = load("res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd")
						if WaypointPathActuator:
							WaypointPathActuator.sync_waypoint_nodes(panel.current_node, brick_instance)
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


func _get_animations_from_player(graph_node: GraphNode, anim_player_name: String) -> Array[String]:
	# Get list of animation names from the AnimationPlayer on panel.current_node
	var animations: Array[String] = []
	
	if not panel.current_node:
		return animations
	
	# Try to find AnimationPlayer as child of panel.current_node
	var anim_player = panel.current_node.get_node_or_null(anim_player_name)
	if not anim_player or not anim_player is AnimationPlayer:
		return animations
	
	# Get all animation names
	var anim_list = anim_player.get_animation_list()
	for anim_name in anim_list:
		animations.append(anim_name)
	
	return animations


func _get_animations_from_node_path(graph_node: GraphNode, node_path: String) -> Array[String]:
	# Get list of animation names from AnimationPlayer on the specified child node
	var animations: Array[String] = []
	
	if not panel.current_node or node_path.is_empty():
		return animations
	
	# Find the node specified by the path
	var target_node = panel.current_node.get_node_or_null(node_path)
	if not target_node:
		return animations
	
	# Find AnimationPlayer as child of that node
	for child in target_node.get_children():
		if child is AnimationPlayer:
			var anim_list = child.get_animation_list()
			for anim_name in anim_list:
				animations.append(anim_name)
			break
	
	return animations


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
				row.add_child(linked_le)
		
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
			# Sync waypoint Node3D children if this is a WaypointPathActuator
			if property_name == "waypoints" and panel.current_node is Node3D:
				var WaypointPathActuator = load("res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd")
				if WaypointPathActuator:
					WaypointPathActuator.sync_waypoint_nodes(panel.current_node, brick_instance)
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


func _rebuild_dependent_property(graph_node: GraphNode, property_name: String) -> void:
	# Find and rebuild the UI for a property that depends on another property
	if not graph_node.has_meta("brick_data"):
		return
	
	var brick_data = graph_node.get_meta("brick_data")
	var brick_instance = brick_data["brick_instance"]
	var properties = brick_instance.get_properties()
	
	# Find the property control in the graph node
	var property_control = graph_node.get_node_or_null("PropertyControl_" + property_name)
	if not property_control:
		# Try to find it in an HBoxContainer
		for child in graph_node.get_children():
			if child is HBoxContainer:
				var ctrl = child.get_node_or_null("PropertyControl_" + property_name)
				if ctrl:
					property_control = ctrl
					break
	
	if not property_control or not property_control is OptionButton:
		return
	
	# Clear and repopulate the dropdown
	var option_button: OptionButton = property_control
	option_button.clear()
	
	# Get the animation list (legacy path kept for other bricks that may use it)
	var animation_list: Array[String] = []
	
	var current_value = properties.get(property_name, "")
	var selected_index = 0
	
	if animation_list.is_empty():
		option_button.add_item("(No animations found)", 0)
		option_button.disabled = true
	else:
		option_button.disabled = false
		for i in range(animation_list.size()):
			var anim_name = animation_list[i]
			option_button.add_item(anim_name, i)
			option_button.set_item_metadata(i, anim_name)
			
			if anim_name == current_value:
				selected_index = i
		
		option_button.selected = selected_index


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
	# Update visibility of UI elements based on current property values
	var brick_class = brick_instance.get_script().resource_path.get_file().get_basename()
	var properties = brick_instance.get_properties()
	
	# Define visibility rules for specific brick types
	match brick_class:
		"end_object_actuator":  # Edit Object Actuator
			var edit_type = properties.get("edit_type", "end")
			# Normalize to lowercase
			if typeof(edit_type) == TYPE_STRING:
				edit_type = edit_type.to_lower()
			
			# Find and show/hide relevant property controls
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"scene_path":
							child.visible = (edit_type == "add_object")
						"end_mode":
							child.visible = (edit_type == "end_object")
						"mesh_path":
							child.visible = (edit_type == "replace_mesh")
		
		"move_towards_actuator":  # Move Towards Actuator
			var behavior = properties.get("behavior", "seek")
			if typeof(behavior) == TYPE_STRING:
				behavior = behavior.to_lower().replace(" ", "_")
			
			# use_navmesh_normal is only relevant for path_follow
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					if prop_name == "use_navmesh_normal":
						child.visible = (behavior == "path_follow")
		
		"variable_actuator":  # Variable Actuator
			var mode = properties.get("mode", "assign")
			# Normalize to lowercase
			if typeof(mode) == TYPE_STRING:
				mode = mode.to_lower()
			
			# Show/hide fields based on mode
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"value":
							child.visible = (mode in ["assign", "add"])
						"source_variable":
							child.visible = (mode == "copy")
		
		"variable_sensor":  # Variable Sensor
			var eval_type = properties.get("evaluation_type", "equal")
			# Normalize to lowercase
			if typeof(eval_type) == TYPE_STRING:
				eval_type = eval_type.to_lower().replace(" ", "_")
			
			# Show/hide fields based on evaluation type
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"value":
							child.visible = (eval_type in ["equal", "not_equal", "greater_than", "less_than", "greater_or_equal", "less_or_equal"])
						"min_value", "max_value":
							child.visible = (eval_type == "interval")
		
		"proximity_sensor":  # Proximity Sensor
			var store_obj = properties.get("store_object", false)
			
			# Show object_variable only when store_object is true
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					if prop_name == "object_variable":
						child.visible = store_obj
		
		"random_sensor":  # Random Sensor
			var trigger_mode = properties.get("trigger_mode", "value")
			var use_seed = properties.get("use_seed", false)
			var store_val = properties.get("store_value", false)
			
			# Normalize trigger_mode
			if typeof(trigger_mode) == TYPE_STRING:
				trigger_mode = trigger_mode.to_lower()
			
			# Show/hide fields based on settings
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"target_value":
							child.visible = (trigger_mode == "value")
						"target_min", "target_max":
							child.visible = (trigger_mode == "range")
						"chance_percent":
							child.visible = (trigger_mode == "chance")
						"seed_value":
							child.visible = use_seed
						"value_variable":
							child.visible = store_val
		
		"movement_sensor":  # Movement Sensor
			var detection_mode = properties.get("detection_mode", "any_movement")
			
			# Normalize detection_mode
			if typeof(detection_mode) == TYPE_STRING:
				detection_mode = detection_mode.to_lower().replace(" ", "_")
			
			# Show/hide fields based on detection mode
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"axis", "direction":
							# Only show for specific_axis mode
							child.visible = (detection_mode == "specific_axis")
		
		"animation_actuator":  # Animation Actuator
			var anim_mode = properties.get("mode", "play").to_lower().replace(" ", "_")
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"play_backwards", "from_end":
							child.visible = (anim_mode == "play")
						"blend_time":
							child.visible = (anim_mode in ["play", "ping_pong", "flipper"])
						"speed":
							child.visible = (anim_mode != "stop" and anim_mode != "pause")
		
		"sprite_frames_actuator":  # Sprite Frames Actuator
			var sf_mode = properties.get("mode", "play").to_lower()
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"animation_name", "loop", "speed_scale":
							child.visible = (sf_mode == "play")
		
		"motion_actuator":  # Motion Actuator
			var motion_type = properties.get("motion_type", "location")
			var movement_method = properties.get("movement_method", "character_velocity")
			
			# Normalize
			if typeof(motion_type) == TYPE_STRING:
				motion_type = motion_type.to_lower().replace(" ", "_")
			if typeof(movement_method) == TYPE_STRING:
				movement_method = movement_method.to_lower().replace(" ", "_")
			
			var is_location = (motion_type == "location")
			var is_character_velocity = (movement_method == "character_velocity")
			
			# Show/hide fields based on motion type and movement method
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"movement_method":
							# Only shown for location type
							child.visible = is_location
						"call_move_and_slide":
							# Only relevant when using character velocity
							child.visible = is_location and is_character_velocity
		
		"physics_actuator":  # Physics Actuator
			var physics_action = properties.get("physics_action", "suspend")
			
			# Normalize
			if typeof(physics_action) == TYPE_STRING:
				physics_action = physics_action.to_lower().replace(" ", "_")
			
			# Show/hide fields based on physics action
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"mass":
							child.visible = (physics_action == "set_mass")
						"gravity_scale":
							child.visible = (physics_action == "set_gravity_scale")
						"linear_damp":
							child.visible = (physics_action == "set_linear_damping")
						"angular_damp":
							child.visible = (physics_action == "set_angular_damping")
		
		"collision_sensor":  # Collision Sensor
			var filter_type = properties.get("filter_type", "any")
			
			# Normalize
			if typeof(filter_type) == TYPE_STRING:
				filter_type = filter_type.to_lower()
			
			# Show filter_value only when filtering by group or name
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					if prop_name == "filter_value":
						child.visible = (filter_type in ["group", "name"])
		
		"random_actuator":  # Random Actuator
			var distribution = properties.get("distribution", "int_uniform")
			var use_seed = properties.get("use_seed", false)
			
			# Normalize distribution
			if typeof(distribution) == TYPE_STRING:
				distribution = distribution.to_lower().replace(" ", "_")
			
			# Show/hide fields based on distribution type
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						# Bool properties
						"bool_value":
							child.visible = (distribution == "bool_constant")
						"bool_probability":
							child.visible = (distribution == "bool_bernoulli")
						# Int properties
						"int_value":
							child.visible = (distribution == "int_constant")
						"int_min", "int_max":
							child.visible = (distribution == "int_uniform")
						"int_lambda":
							child.visible = (distribution == "int_poisson")
						# Float properties
						"float_value":
							child.visible = (distribution == "float_constant")
						"float_min", "float_max":
							child.visible = (distribution == "float_uniform")
						"float_mean", "float_stddev":
							child.visible = (distribution == "float_normal")
						"float_lambda":
							child.visible = (distribution == "float_neg_exp")
						# Seed
						"seed_value":
							child.visible = use_seed
		
		"scene_actuator":  # Scene Actuator
			var mode = properties.get("mode", "restart")
			
			# Normalize mode
			if typeof(mode) == TYPE_STRING:
				mode = mode.to_lower().replace(" ", "_")
			
			# Hide scene_path when mode is restart
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					if prop_name == "scene_path":
						child.visible = (mode == "set_scene")
		
		"parent_actuator":  # Parent Actuator
			var mode = properties.get("mode", "set_parent")
			
			# Normalize mode
			if typeof(mode) == TYPE_STRING:
				mode = mode.to_lower().replace(" ", "_")
			
			# Show parent_node only in set_parent mode
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					if prop_name == "parent_node":
						child.visible = (mode == "set_parent")
		
		"property_actuator":  # Property Actuator
			var node_type = properties.get("node_type", "node_3d")
			if typeof(node_type) == TYPE_STRING:
				node_type = node_type.to_lower().replace(" ", "_")
			
			# All groups and their node type prefix
			var group_type_map = {
				"_group_n3d_visibility": "node_3d",
				"_group_n3d_transform":  "node_3d",
				"_group_mesh_basic":     "mesh_instance_3d",
				"_group_col_basic":      "collision_shape_3d",
				"_group_light_basic":    "light_3d",
				"_group_light_color":    "light_3d",
				"_group_light_shadow":   "light_3d",
				"_group_rb_basic":       "rigid_body_3d",
				"_group_rb_damping":     "rigid_body_3d",
				"_group_cb_basic":       "character_body_3d",
				"_group_cb_floor":       "character_body_3d",
				"_group_anim_basic":     "animation_player",
				"_group_ctrl_basic":     "control",
				"_group_ctrl_transform": "control",
				"_group_lbl_basic":      "label",
				"_group_btn_basic":      "button",
				"_group_cam_basic":      "camera_3d",
				"_group_spr_basic":     "sprite_3d",
				"_group_spr_display":   "sprite_3d",
				"_group_spr_frames":    "sprite_3d",
				"_group_custom":         "custom",
			}
			# All property keys and their node type
			var prop_type_map = {
				"n3d_visible": "node_3d", "n3d_pos_x": "node_3d", "n3d_pos_y": "node_3d",
				"n3d_pos_z": "node_3d", "n3d_rot_x": "node_3d", "n3d_rot_y": "node_3d",
				"n3d_rot_z": "node_3d", "n3d_scale_x": "node_3d", "n3d_scale_y": "node_3d",
				"n3d_scale_z": "node_3d",
				"mesh_visible": "mesh_instance_3d", "mesh_cast_shadow": "mesh_instance_3d",
				"col_disabled": "collision_shape_3d",
				"light_visible": "light_3d", "light_energy": "light_3d",
				"light_color": "light_3d", "light_shadow": "light_3d",
				"rb_freeze": "rigid_body_3d", "rb_mass": "rigid_body_3d",
				"rb_gravity_scale": "rigid_body_3d", "rb_linear_damp": "rigid_body_3d",
				"rb_angular_damp": "rigid_body_3d",
				"cb_up_dir_y": "character_body_3d", "cb_max_slides": "character_body_3d",
				"cb_floor_max_angle": "character_body_3d", "cb_stop_on_slope": "character_body_3d",
				"cb_block_on_wall": "character_body_3d", "cb_slide_on_ceiling": "character_body_3d",
				"anim_speed_scale": "animation_player",
				"ctrl_visible": "control", "ctrl_modulate": "control",
				"ctrl_size_x": "control", "ctrl_size_y": "control",
				"ctrl_pos_x": "control", "ctrl_pos_y": "control",
				"ctrl_rotation": "control", "ctrl_scale_x": "control", "ctrl_scale_y": "control",
				"lbl_text": "label", "lbl_visible": "label", "lbl_modulate": "label",
				"btn_disabled": "button", "btn_text": "button", "btn_visible": "button",
				"cam_fov": "camera_3d", "cam_near": "camera_3d",
				"cam_far": "camera_3d", "cam_current": "camera_3d",
				"spr_visible": "sprite_3d", "spr_modulate": "sprite_3d",
				"spr_flip_h": "sprite_3d", "spr_flip_v": "sprite_3d",
				"spr_pixel_size": "sprite_3d", "spr_billboard": "sprite_3d",
				"spr_transparent": "sprite_3d", "spr_shaded": "sprite_3d",
				"spr_double_sided": "sprite_3d", "spr_frame": "sprite_3d",
				"spr_hframes": "sprite_3d", "spr_vframes": "sprite_3d",
				"custom_property": "custom", "custom_value": "custom",
			}
			
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					if prop_name in group_type_map:
						child.visible = (group_type_map[prop_name] == node_type)
					elif prop_name in prop_type_map:
						child.visible = (prop_type_map[prop_name] == node_type)
				# Also check inside group bodies
				elif child is VBoxContainer:
					for subchild in child.get_children():
						if subchild.has_meta("property_name"):
							var prop_name = subchild.get_meta("property_name")
							if prop_name in prop_type_map:
								# Parent group visibility handles this —
								# individual items inside groups don't need separate handling
								pass
		
		"mouse_sensor":  # Mouse Sensor
			var detection_type = properties.get("detection_type", "button")
			
			# Normalize
			if typeof(detection_type) == TYPE_STRING:
				detection_type = detection_type.to_lower().replace(" ", "_")
			
			# Show/hide fields based on detection type
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"mouse_button", "button_state":
							child.visible = (detection_type == "button")
						"wheel_direction":
							child.visible = (detection_type == "wheel")
						"movement_threshold":
							child.visible = (detection_type == "movement")
						"area_node_name":
							child.visible = (detection_type == "hover_object")
		
		"mouse_actuator":  # Mouse Actuator
			var mode = properties.get("mode", "cursor_visibility")
			
			# Normalize
			if typeof(mode) == TYPE_STRING:
				mode = mode.to_lower().replace(" ", "_")
			
			# Show/hide fields based on mode
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"cursor_visible":
							child.visible = (mode == "cursor_visibility")
						"use_x_axis", "use_y_axis", "x_sensitivity", "y_sensitivity", "x_threshold", "y_threshold", "x_min_degrees", "x_max_degrees", "y_min_degrees", "y_max_degrees", "x_rotation_axis", "y_rotation_axis", "x_use_local", "y_use_local", "recenter_cursor":
							child.visible = (mode == "mouse_look")
		
		"edit_object_actuator":  # Edit Object Actuator
			var edit_type = properties.get("edit_type", "end")
			
			# Normalize
			if typeof(edit_type) == TYPE_STRING:
				edit_type = edit_type.to_lower().replace(" ", "_")
			
			# Show/hide fields based on edit_type
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"spawn_object", "spawn_point", "velocity_x", "velocity_y", "velocity_z", "velocity_local", "lifespan":
							child.visible = (edit_type == "add_object")
						"end_mode":
							child.visible = (edit_type == "end_object")
						"mesh_path":
							child.visible = (edit_type == "replace_mesh")
		
		"audio_2d_actuator":  # Audio 2D Actuator
			var mode = properties.get("mode", "play")
			if typeof(mode) == TYPE_STRING:
				mode = mode.to_lower().replace(" ", "_")
			var is_play     = (mode == "play")
			var is_fade     = (mode in ["fade_in", "fade_out"])
			var needs_file  = (mode in ["play", "fade_in"])
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"sound_file":
							child.visible = needs_file
						"player_type", "play_mode", "loop", "pitch_random", "audio_bus":
							child.visible = is_play
						"fade_duration":
							child.visible = is_fade
						"volume", "pitch":
							child.visible = (mode != "stop")
		
		"modulate_actuator":  # Modulate Actuator
			var transition = properties.get("transition", false)
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					if prop_name == "transition_speed":
						child.visible = transition
		
		"visibility_actuator":  # Visibility Actuator
			var target_mode = properties.get("target_mode", "self")
			if typeof(target_mode) == TYPE_STRING:
				target_mode = target_mode.to_lower()
			# No extra fields to show/hide — target_mode controls @export presence via code gen
		
		"progress_bar_actuator":  # Progress Bar Actuator
			var set_value = properties.get("set_value", true)
			var set_min = properties.get("set_min", false)
			var set_max = properties.get("set_max", false)
			var transition = properties.get("transition", false)
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"value":
							child.visible = set_value
						"min_value":
							child.visible = set_min
						"max_value":
							child.visible = set_max
						"transition_speed":
							child.visible = transition and set_value
		
		"tween_actuator":  # Tween Actuator
			var target_mode = properties.get("target_mode", "self")
			if typeof(target_mode) == TYPE_STRING:
				target_mode = target_mode.to_lower()
			# No fields conditionally hidden — all always relevant
		
		"impulse_actuator":  # Impulse Actuator
			var impulse_type = properties.get("impulse_type", "central")
			if typeof(impulse_type) == TYPE_STRING:
				impulse_type = impulse_type.to_lower()
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"pos_x", "pos_y", "pos_z":
							child.visible = (impulse_type == "positional")
						"space":
							child.visible = (impulse_type != "torque")
		
		"music_actuator":  # Music Actuator
			var music_mode = properties.get("music_mode", "tracks")
			if typeof(music_mode) == TYPE_STRING:
				music_mode = music_mode.to_lower()
			var is_tracks  = (music_mode == "tracks")
			var is_set     = (music_mode == "set")
			var is_control = (music_mode == "control")
			var control_action = properties.get("control_action", "play")
			if typeof(control_action) == TYPE_STRING:
				control_action = control_action.to_lower()
			var is_crossfade = (control_action == "crossfade")
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"tracks", "volume_db", "loop", "audio_bus", "persist":
							child.visible = is_tracks
						"set_track", "set_play":
							child.visible = is_set
						"control_action":
							child.visible = is_control
						"to_track", "crossfade_time":
							child.visible = is_control and is_crossfade
		
		"screen_flash_actuator":  # Screen Flash Actuator — no conditional fields
			pass
		
		"screen_shake_actuator":  # Screen Shake Actuator — hide tune fields when export_params is on
			var export_params = properties.get("export_params", false)
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"trauma", "max_offset", "decay", "noise_speed":
							child.visible = not export_params
		
		"rumble_actuator":  # Rumble Actuator
			var action = properties.get("action", "vibrate")
			if typeof(action) == TYPE_STRING:
				action = action.to_lower()
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"weak_motor", "strong_motor", "duration":
							child.visible = (action == "vibrate")
		
		"shader_param_actuator":  # Shader Parameter Actuator (legacy — removed from menu)
			pass
		
		"light_actuator":  # Light Actuator
			var light_type = properties.get("light_type", "omni").to_lower().replace(" ", "_")
			var fx         = properties.get("fx", "normal").to_lower().replace(" ", "_")
			var is_spot    = (light_type == "spotlight3d")
			var is_omni_or_spot = (light_type in ["omnilight3d", "spotlight3d"])
			for node in _find_prop_nodes(graph_node):
				var prop_name = node.get_meta("property_name")
				match prop_name:
					"set_range", "light_range":
						node.visible = is_omni_or_spot
					"set_spot_angle", "spot_angle", "set_spot_attenuation", "spot_attenuation":
						node.visible = is_spot
					"fx_params_group":
						node.visible = (fx != "normal")
					"flicker_normal_energy", "flicker_min", "flicker_max", "flicker_idle_min", "flicker_idle_max", "flicker_burst_duration":
						node.visible = (fx == "flicker")
					"strobe_frequency", "strobe_on_energy", "strobe_off_energy":
						node.visible = (fx == "strobe")
					"pulse_min", "pulse_max", "pulse_speed":
						node.visible = (fx == "pulse")
					"fade_target", "fade_speed":
						node.visible = (fx in ["fade_in", "fade_out"])
		
		"third_person_camera_actuator":  # 3rd Person Camera Actuator
			var input_mode = properties.get("input_mode", "mouse").to_lower()
			var use_joy = input_mode in ["joystick", "both"]
			for node in _find_prop_nodes(graph_node):
				var prop_name = node.get_meta("property_name")
				match prop_name:
					"joy_group", "joystick_device", "joy_stick", "joy_deadzone", "joy_sensitivity":
						node.visible = use_joy
					"capture_mouse":
						node.visible = input_mode in ["mouse", "both"]
		
		"camera_zoom_actuator":  # Camera Zoom Actuator
			var camera_type = properties.get("camera_type", "camera_3d")
			if typeof(camera_type) == TYPE_STRING:
				camera_type = camera_type.to_lower().replace(" ", "_")
			var transition = properties.get("transition", true)
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"fov":
							child.visible = (camera_type == "camera_3d")
						"zoom":
							child.visible = (camera_type == "camera_2d")
						"transition_speed":
							child.visible = transition
		
		"object_pool_actuator":  # Object Pool Actuator
			var action = properties.get("action", "spawn")
			if typeof(action) == TYPE_STRING:
				action = action.to_lower().replace(" ", "_")
			var spawn_at_self = properties.get("spawn_at_self", true)
			var is_spawn = (action == "spawn")
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"pool_sizes":
							child.visible = false  # managed automatically by the scenes array
						"scenes", "spawn_mode", "spawn_delay", "spawn_at_self", "inherit_rotation", "lifespan":
							child.visible = is_spawn
						"spawn_node":
							child.visible = is_spawn and not spawn_at_self
		
		"game_actuator":  # Game Actuator
			var action = properties.get("action", "exit")
			
			# Normalize
			if typeof(action) == TYPE_STRING:
				action = action.to_lower()
			
			# Show/hide fields based on action
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"save_path":
							child.visible = (action == "save" or action == "load")
						"screenshot_path":
							child.visible = (action == "screenshot")
		
		"controller", "script_controller":  # Controller
			var all_states = properties.get("all_states", false)
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					if prop_name == "state_id":
						child.visible = not all_states
		
		"rotate_towards_actuator":  # Rotate Towards Actuator
			var axes = properties.get("axes", "y_only")
			if typeof(axes) == TYPE_STRING:
				axes = axes.to_lower().split("(")[0].strip_edges().replace(" ", "_")
			var clamp_x = properties.get("clamp_x", false)
			var show_clamp = (axes in ["x_only", "both"])
			
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"clamp_x":
							child.visible = show_clamp
						"clamp_x_min", "clamp_x_max":
							child.visible = show_clamp and clamp_x
		
		"input_map_sensor":  # Input Map Sensor
			var input_mode = properties.get("input_mode", "pressed")
			
			# Normalize
			if typeof(input_mode) == TYPE_STRING:
				input_mode = input_mode.to_lower().replace(" ", "_")
			
			var is_button = input_mode in ["pressed", "just_pressed", "just_released"]
			var is_axis = (input_mode == "axis")
			
			for child in graph_node.get_children():
				if child.has_meta("property_name"):
					var prop_name = child.get_meta("property_name")
					match prop_name:
						"action_name":
							child.visible = is_button
						"negative_action", "positive_action", "store_in", "deadzone":
							child.visible = is_axis
						"invert":
							child.visible = true  # Invert is useful for all input modes



func _on_property_changed(value, graph_node: GraphNode, property_name: String) -> void:
	if graph_node.has_meta("brick_data"):
		var brick_data = graph_node.get_meta("brick_data")
		var brick_instance = brick_data["brick_instance"]
		brick_instance.set_property(property_name, value)

		if brick_data.get("brick_type", "") == "controller" and property_name in ["state_id", "all_states"]:
			_update_controller_title(graph_node, brick_instance)

		_update_conditional_visibility(graph_node, brick_instance)
		panel._save_graph_to_metadata()


func _update_controller_title(graph_node: GraphNode, brick_instance) -> void:
	var props = brick_instance.properties
	var all_states = props.get("all_states", false)
	var state_id = str(props.get("state_id", ""))
	var state_name = panel.get_state_display_name(state_id) if panel and panel.has_method("get_state_display_name") else state_id
	if all_states:
		graph_node.title = "Controller [ALL]"
	else:
		graph_node.title = "Controller [%s]" % (state_name if not state_name.is_empty() else "No State")


func _on_instance_name_changed(new_name: String, graph_node: GraphNode, brick_instance) -> void:
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
	if hint_string in ["__ANIMATION_LIST__", "__ANIMATION_PLAYER_LIST__", "__STATE_LIST__"] and option_button:
		# Get the value directly from the item metadata
		value = option_button.get_item_metadata(index)
		#print("Logic Bricks: Special list - got value from metadata: '%s'" % value)
	else:
		# Parse the enum value the same way the UI setup does (regular enums)
		var enum_parts = hint_string.split(",")
		if index < 0 or index >= enum_parts.size():
			return
		
		var part = enum_parts[index].strip_edges()
		value = part.to_lower().replace(" ", "_")
		
		# Check if it has an explicit value (like "Display:value")
		if ":" in part:
			var split = part.split(":")
			value = split[1]
		
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
	
	# When a screen shake preset is selected, populate the value fields
	if brick_class == "ScreenShakeActuator" and property_name == "preset":
		if brick_instance.has_method("get_preset_values"):
			var preset_vals = brick_instance.get_preset_values(str(value))
			if preset_vals.size() == 4:
				var field_names = ["trauma", "max_offset", "decay", "noise_speed"]
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
	#print("Logic Bricks: Property '%s' changed to: '%s'" % [property_name, value])
	
	# Update conditional visibility for fields that depend on this enum
	_update_conditional_visibility(graph_node, brick_instance)




func _populate_dynamic_enum(option_button: OptionButton, brick_instance, property_name: String, hint_string: String, property_value) -> bool:
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
			#print("Logic Bricks: Property '%s' set to: %s" % [property_name, path])
		file_dialog.queue_free()
	)
	
	# Close dialog if cancelled
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)
	
	# Add to scene tree and show
	panel.add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.6)

