@tool
extends PanelContainer

## UI component for displaying and editing a single brick

signal brick_removed(brick_index: int)
signal property_changed(brick_index: int, property_name: String, value: Variant)

var brick_index: int = -1
var brick_data: Dictionary = {}
var brick_instance = null

var brick_name_label: Label
var remove_button: Button
var properties_container: VBoxContainer


func _init() -> void:
	# Create the UI structure
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Header
	var header_hbox = HBoxContainer.new()
	vbox.add_child(header_hbox)
	
	brick_name_label = Label.new()
	brick_name_label.text = "Brick Name"
	brick_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(brick_name_label)
	
	remove_button = Button.new()
	remove_button.text = "×"
	remove_button.pressed.connect(_on_remove_pressed)
	header_hbox.add_child(remove_button)
	
	# Properties container
	properties_container = VBoxContainer.new()
	vbox.add_child(properties_container)


func setup(index: int, data: Dictionary, brick_obj) -> void:
	brick_index = index
	brick_data = data
	brick_instance = brick_obj
	
	_update_ui()


func _update_ui() -> void:
	if not brick_instance:
		return
	
	# Update brick name
	if brick_name_label:
		brick_name_label.text = brick_instance.get_brick_name()
	
	# Clear existing properties
	if properties_container:
		for child in properties_container.get_children():
			child.queue_free()
	
	# Create property editors
	var property_defs = brick_instance.get_property_definitions()
	for prop_def in property_defs:
		_create_property_editor(prop_def)


func _create_property_editor(prop_def: Dictionary) -> void:
	var prop_name = prop_def["name"]
	var prop_type = prop_def["type"]
	var current_value = brick_data.get("properties", {}).get(prop_name, prop_def.get("default"))
	
	# Create label
	var hbox = HBoxContainer.new()
	properties_container.add_child(hbox)
	
	var label = Label.new()
	label.text = prop_name.capitalize() + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
				option_button.item_selected.connect(func(idx): _on_property_changed(prop_name, option_button.get_item_id(idx)))
				hbox.add_child(option_button)
			else:
				var spin_box = SpinBox.new()
				spin_box.value = current_value
				spin_box.min_value = -999999
				spin_box.max_value = 999999
				spin_box.step = 1
				spin_box.value_changed.connect(func(value): _on_property_changed(prop_name, int(value)))
				hbox.add_child(spin_box)
		
		TYPE_FLOAT:
			var spin_box = SpinBox.new()
			spin_box.value = current_value
			spin_box.min_value = -999999
			spin_box.max_value = 999999
			spin_box.step = 0.1
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
				option_button.item_selected.connect(func(idx): _on_property_changed(prop_name, option_button.get_item_text(idx).to_lower().replace(" ", "_")))
				hbox.add_child(option_button)
			else:
				var line_edit = LineEdit.new()
				line_edit.text = str(current_value)
				line_edit.text_changed.connect(func(text): _on_property_changed(prop_name, text))
				hbox.add_child(line_edit)


func _on_property_changed(prop_name: String, value: Variant) -> void:
	property_changed.emit(brick_index, prop_name, value)


func _on_remove_pressed() -> void:
	brick_removed.emit(brick_index)
