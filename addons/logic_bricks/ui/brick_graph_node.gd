@tool
extends GraphNode

## Visual graph node for a logic brick

signal property_changed(graph_node: GraphNode, property_name: String, value: Variant)

var brick_instance = null
var properties_container: VBoxContainer


func _init() -> void:
	# Basic setup
	resizable = false
	draggable = true
	selectable = true
	
	# Create main container
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Properties container
	properties_container = VBoxContainer.new()
	vbox.add_child(properties_container)


func setup(brick) -> void:
	brick_instance = brick
	
	if not brick_instance:
		return
	
	# Clear existing properties
	for child in properties_container.get_children():
		child.queue_free()
	
	# Create property editors
	var property_defs = brick_instance.get_property_definitions()
	for prop_def in property_defs:
		_create_property_editor(prop_def)


func _create_property_editor(prop_def: Dictionary) -> void:
	var prop_name = prop_def["name"]
	var prop_type = prop_def["type"]
	var current_value = brick_instance.get_property(prop_name, prop_def.get("default"))
	
	# Create label
	var hbox = HBoxContainer.new()
	properties_container.add_child(hbox)
	
	var label = Label.new()
	label.text = prop_name.capitalize() + ":"
	label.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(label)
	
	# Create editor based on type
	match prop_type:
		TYPE_BOOL:
			var check_box = CheckBox.new()
			check_box.button_pressed = current_value
			check_box.toggled.connect(func(pressed): _on_property_changed(prop_name, pressed))
			hbox.add_child(check_box)
		
		TYPE_INT:
			if prop_def.get("hint") == PROPERTY_HINT_ENUM:
				var option_button = OptionButton.new()
				var options = prop_def.get("hint_string", "").split(",")
				var selected_idx = 0
				for i in range(options.size()):
					var opt = options[i]
					if ":" in opt:
						var parts = opt.split(":")
						option_button.add_item(parts[0], int(parts[1]))
						if int(parts[1]) == current_value:
							selected_idx = i
					else:
						option_button.add_item(opt, i)
						if i == current_value:
							selected_idx = i
				option_button.selected = selected_idx
				option_button.custom_minimum_size = Vector2(150, 0)
				option_button.item_selected.connect(func(idx): _on_property_changed(prop_name, option_button.get_item_id(idx)))
				hbox.add_child(option_button)
			else:
				var spin_box = SpinBox.new()
				spin_box.value = current_value
				spin_box.min_value = -999999
				spin_box.max_value = 999999
				spin_box.step = 1
				spin_box.custom_minimum_size = Vector2(80, 0)
				spin_box.value_changed.connect(func(value): _on_property_changed(prop_name, int(value)))
				hbox.add_child(spin_box)
		
		TYPE_FLOAT:
			var spin_box = SpinBox.new()
			spin_box.value = current_value
			spin_box.min_value = -999999
			spin_box.max_value = 999999
			spin_box.step = 0.1
			spin_box.custom_minimum_size = Vector2(80, 0)
			spin_box.value_changed.connect(func(value): _on_property_changed(prop_name, value))
			hbox.add_child(spin_box)
		
		TYPE_STRING:
			if prop_def.get("hint") == PROPERTY_HINT_ENUM:
				var option_button = OptionButton.new()
				var options = prop_def.get("hint_string", "").split(",")
				for i in range(options.size()):
					option_button.add_item(options[i])
					if options[i].to_lower().replace(" ", "_") == current_value:
						option_button.selected = i
				option_button.custom_minimum_size = Vector2(150, 0)
				option_button.item_selected.connect(func(idx): _on_property_changed(prop_name, option_button.get_item_text(idx).to_lower().replace(" ", "_")))
				hbox.add_child(option_button)
			else:
				var line_edit = LineEdit.new()
				line_edit.text = str(current_value)
				line_edit.custom_minimum_size = Vector2(150, 0)
				line_edit.text_changed.connect(func(text): _on_property_changed(prop_name, text))
				hbox.add_child(line_edit)


func _on_property_changed(prop_name: String, value: Variant) -> void:
	if brick_instance:
		brick_instance.set_property(prop_name, value)
	property_changed.emit(self, prop_name, value)
