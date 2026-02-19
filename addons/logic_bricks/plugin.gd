@tool
extends EditorPlugin

const LogicBrickPanel = preload("res://addons/logic_bricks/ui/logic_brick_panel.gd")
const LogicBrickManager = preload("res://addons/logic_bricks/core/logic_brick_manager.gd")

var panel: Control
var manager: LogicBrickManager


func _enter_tree() -> void:
	# Create the manager
	manager = LogicBrickManager.new()
	manager.editor_interface = get_editor_interface()  # FIX: Pass editor interface to manager
	
	# Create the panel programmatically
	panel = LogicBrickPanel.new()
	panel.manager = manager
	panel.editor_interface = get_editor_interface()
	panel.plugin = self
	
	# Add to bottom panel
	add_control_to_bottom_panel(panel, "Logic Bricks")
	
	# Connect to selection changes
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)
	
	print("Logic Bricks Plugin: Enabled")


func _exit_tree() -> void:
	# Disconnect signals
	if get_editor_interface().get_selection().selection_changed.is_connected(_on_selection_changed):
		get_editor_interface().get_selection().selection_changed.disconnect(_on_selection_changed)
	
	# Remove the panel
	if panel:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
	
	print("Logic Bricks Plugin: Disabled")


func _on_selection_changed() -> void:
	if panel:
		var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
		if selected_nodes.size() > 0:
			panel.set_selected_node(selected_nodes[0])
		else:
			panel.set_selected_node(null)


## Register the GlobalVars autoload singleton
## Uses EditorPlugin API so it takes effect immediately without restart
func ensure_global_vars_autoload(script_path: String) -> void:
	if not ProjectSettings.has_setting("autoload/GlobalVars"):
		add_autoload_singleton("GlobalVars", script_path)
		print("Logic Bricks: Registered GlobalVars autoload")
