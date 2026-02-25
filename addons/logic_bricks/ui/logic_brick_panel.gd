@tool
extends VBoxContainer

## Main panel UI for the Logic Bricks plugin (bottom panel)
## Visual node graph editor for connecting logic bricks

const BrickGraphNode = preload("res://addons/logic_bricks/ui/brick_graph_node.gd")

var manager = null
var editor_interface = null
var plugin = null  # Reference to the EditorPlugin (for autoload registration)
var current_node: Node = null
var _clipboard_graph: Dictionary = {}  # Stored graph data for copy/paste
var _clipboard_vars: Array = []  # Stored variables for copy/paste
var is_locked: bool = false  # Lock to prevent losing current_node on selection change

var node_info_label: Label
var lock_button: Button
var _copy_button: Button
var _paste_button: Button
var graph_edit: GraphEdit
var add_menu: PopupMenu
var sensors_menu: PopupMenu
var controllers_menu: PopupMenu
var actuators_menu: PopupMenu
var next_node_id: int = 0
var last_mouse_position: Vector2 = Vector2.ZERO

# Side panel (tabbed: Variables, Frames)
var side_panel: TabContainer
var variables_panel: VBoxContainer
var variables_list: VBoxContainer
var variables_data: Array[Dictionary] = []  # Store variable definitions
var frames_panel: VBoxContainer
var frames_list: ItemList
var frame_settings_container: VBoxContainer
var selected_frame: GraphFrame = null


func _init() -> void:
    # Set minimum size for the bottom panel
    custom_minimum_size = Vector2(0, 300)
    size_flags_vertical = Control.SIZE_EXPAND_FILL
    
    # Create header
    var header_hbox = HBoxContainer.new()
    add_child(header_hbox)
    
    var title_label = Label.new()
    title_label.text = "Logic Bricks - Node Graph"
    title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var title_font = title_label.get_theme_font("bold", "EditorFonts")
    if title_font:
        title_label.add_theme_font_override("font", title_font)
    header_hbox.add_child(title_label)
    
    node_info_label = Label.new()
    node_info_label.text = "No node selected"
    header_hbox.add_child(node_info_label)
    
    # Lock button to prevent losing selection
    lock_button = Button.new()
    lock_button.text = "🔓"  # Unlocked icon
    lock_button.tooltip_text = "Lock selection (prevents panel from changing when clicking elsewhere)"
    lock_button.pressed.connect(_on_lock_toggled)
    header_hbox.add_child(lock_button)
    
    _copy_button = Button.new()
    _copy_button.text = "C"
    _copy_button.tooltip_text = "Copy all logic bricks and variables from this node"
    _copy_button.pressed.connect(_on_copy_bricks_pressed)
    header_hbox.add_child(_copy_button)
    
    _paste_button = Button.new()
    _paste_button.text = "P"
    _paste_button.tooltip_text = "Paste copied logic bricks and variables to this node"
    _paste_button.pressed.connect(_on_paste_bricks_pressed)
    header_hbox.add_child(_paste_button)
    
    # Separator
    var separator1 = HSeparator.new()
    add_child(separator1)
    
    # Create horizontal split: graph on left, variables on right
    var hsplit = HSplitContainer.new()
    hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    hsplit.split_offset = -300  # Variables panel takes 300px from the right
    add_child(hsplit)
    
    # GraphEdit for visual node connections (LEFT SIDE)
    graph_edit = GraphEdit.new()
    graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    graph_edit.right_disconnects = true
    graph_edit.show_zoom_label = true
    graph_edit.minimap_enabled = true
    graph_edit.minimap_size = Vector2(200, 150)
    
    # Enable panning - allow dragging the canvas
    graph_edit.panning_scheme = GraphEdit.SCROLL_ZOOMS  # Mouse wheel zooms, drag pans
    
    graph_edit.connection_request.connect(_on_connection_request)
    graph_edit.disconnection_request.connect(_on_disconnection_request)
    graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
    graph_edit.popup_request.connect(_on_popup_request)
    graph_edit.gui_input.connect(_on_graph_edit_input)
    graph_edit.visible = false  # Hidden until node selected
    hsplit.add_child(graph_edit)
    
    # Side Panel (RIGHT SIDE) - Tabbed: Variables, Frames
    _create_side_panel()
    hsplit.add_child(side_panel)
    
    # Create add node menu
    _create_add_menu()
    
    # Instructions label (shown when graph is hidden)
    var instructions_label = Label.new()
    instructions_label.name = "InstructionsLabel"
    instructions_label.text = "👆 Select a 3D node in your scene tree to start creating logic bricks"
    instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    instructions_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    instructions_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    instructions_label.add_theme_font_size_override("font_size", 16)
    add_child(instructions_label)
    
    # Toolbar
    var separator2 = HSeparator.new()
    add_child(separator2)
    
    var toolbar = HBoxContainer.new()
    add_child(toolbar)
    
    var help_label = Label.new()
    help_label.text = "  Right-click: Add nodes | Drag nodes: Move | Middle-click drag: Pan | Scroll: Zoom | Select + Delete: Remove"
    help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    toolbar.add_child(help_label)
    
    var add_frame_button = Button.new()
    add_frame_button.text = "Add Frame"
    add_frame_button.pressed.connect(_on_add_frame_pressed)
    toolbar.add_child(add_frame_button)
    
    var apply_code_button = Button.new()
    apply_code_button.text = "Apply Code"
    apply_code_button.pressed.connect(_on_apply_code_pressed)
    toolbar.add_child(apply_code_button)


func _create_add_menu() -> void:
    # Main menu
    add_menu = PopupMenu.new()
    add_menu.name = "AddNodeMenu"
    add_child(add_menu)
    
    # Create submenus
    sensors_menu = PopupMenu.new()
    sensors_menu.name = "SensorsMenu"
    add_menu.add_child(sensors_menu)
    sensors_menu.id_pressed.connect(_on_add_menu_item_selected)
    
    controllers_menu = PopupMenu.new()
    controllers_menu.name = "ControllersMenu"
    add_menu.add_child(controllers_menu)
    controllers_menu.id_pressed.connect(_on_add_menu_item_selected)
    
    actuators_menu = PopupMenu.new()
    actuators_menu.name = "ActuatorsMenu"
    add_menu.add_child(actuators_menu)
    actuators_menu.id_pressed.connect(_on_add_menu_item_selected)
    
    # Add submenu items to main menu
    add_menu.add_submenu_item("Sensors", "SensorsMenu", 0)
    add_menu.add_submenu_item("Controllers", "ControllersMenu", 1)
    add_menu.add_submenu_item("Actuators", "ActuatorsMenu", 2)
    add_menu.add_separator()
    add_menu.add_item("Reroute", 3)
    add_menu.id_pressed.connect(_on_main_menu_id_pressed)
    
    # Populate Sensors submenu (alphabetical order)
    sensors_menu.add_item("Always", 100)
    sensors_menu.set_item_metadata(0, {"type": "sensor", "class": "AlwaysSensor"})
    sensors_menu.set_item_tooltip(0, "Always active. Fires every frame.\nUse for continuous actions like gravity or idle animations.")
    
    sensors_menu.add_item("Animation Tree", 101)
    sensors_menu.set_item_metadata(1, {"type": "sensor", "class": "AnimationTreeSensor"})
    sensors_menu.set_item_tooltip(1, "Detects animation tree state changes and conditions.")
    
    sensors_menu.add_item("Collision", 102)
    sensors_menu.set_item_metadata(2, {"type": "sensor", "class": "CollisionSensor"})
    sensors_menu.set_item_tooltip(2, "Detects collisions using an Area3D node.\nRequires an Area3D child or reference.\n⚠ Adds @export in Inspector — assign your Area3D.")
    
    sensors_menu.add_item("Compare Variable", 103)
    sensors_menu.set_item_metadata(3, {"type": "sensor", "class": "VariableSensor"})
    sensors_menu.set_item_tooltip(3, "Compares a logic brick variable against a value.\nTriggers when the comparison is true.")
    
    sensors_menu.add_item("Delay", 104)
    sensors_menu.set_item_metadata(4, {"type": "sensor", "class": "DelaySensor"})
    sensors_menu.set_item_tooltip(4, "Adds a delay before activating.\nStays active for a set duration, can repeat.")
    
    sensors_menu.add_item("InputMap", 105)
    sensors_menu.set_item_metadata(5, {"type": "sensor", "class": "InputMapSensor"})
    sensors_menu.set_item_tooltip(5, "Detects input actions from Project > Input Map.\nWorks with keyboard, gamepad, etc.")
    
    sensors_menu.add_item("Message", 106)
    sensors_menu.set_item_metadata(6, {"type": "sensor", "class": "MessageSensor"})
    sensors_menu.set_item_tooltip(6, "Listens for messages sent by a Message Actuator.\nFilters by subject.")
    
    sensors_menu.add_item("Mouse", 107)
    sensors_menu.set_item_metadata(7, {"type": "sensor", "class": "MouseSensor"})
    sensors_menu.set_item_tooltip(7, "Detects mouse button presses and releases.")
    
    sensors_menu.add_item("Movement", 108)
    sensors_menu.set_item_metadata(8, {"type": "sensor", "class": "MovementSensor"})
    sensors_menu.set_item_tooltip(8, "Detects if the node is moving or stationary.")
    
    sensors_menu.add_item("Proximity", 109)
    sensors_menu.set_item_metadata(9, {"type": "sensor", "class": "ProximitySensor"})
    sensors_menu.set_item_tooltip(9, "Detects nodes within a certain distance.\nChecks against nodes in a specified group.")
    
    sensors_menu.add_item("Random", 110)
    sensors_menu.set_item_metadata(10, {"type": "sensor", "class": "RandomSensor"})
    sensors_menu.set_item_tooltip(10, "Activates randomly based on a probability.\nUseful for random behaviors or AI variation.")
    
    sensors_menu.add_item("Raycast", 111)
    sensors_menu.set_item_metadata(11, {"type": "sensor", "class": "RaycastSensor"})
    sensors_menu.set_item_tooltip(11, "Casts a ray to detect objects in a direction.\nUseful for line-of-sight or ground detection.")
    
    sensors_menu.add_item("Timer", 112)
    sensors_menu.set_item_metadata(12, {"type": "sensor", "class": "TimerSensor"})
    sensors_menu.set_item_tooltip(12, "Activates after a set time duration. Can repeat.")
    
    # Populate Controllers submenu
    controllers_menu.add_item("Controller", 200)
    controllers_menu.set_item_metadata(0, {"type": "controller", "class": "Controller"})
    controllers_menu.set_item_tooltip(0, "Logic gate that combines sensor inputs.\nAND, OR, NAND, NOR, XOR modes.")
    
    # Populate Actuators submenu (alphabetical order)
    var _actuator_items = [
        ["Animation", 300, "AnimationActuator", "Plays, stops, or queues animations via AnimationPlayer.\n⚠ Adds @export in Inspector — assign your AnimationPlayer."],
        ["Animation Tree", 301, "AnimationTreeActuator", "Controls AnimationTree: travel states, set parameters/conditions.\n⚠ Adds @export in Inspector — assign your AnimationTree."],
        ["Camera", 302, "CameraActuator", "Camera follow, orbit, or positioning with smooth movement.\n⚠ Adds @export in Inspector — assign your Camera3D."],
        ["Character", 303, "CharacterActuator", "All-in-one: gravity, jumping, and ground detection."],
        ["Collision", 322, "CollisionActuator", "Modify collision properties: enable/disable shapes, layers, masks."],
        ["Edit Object", 304, "EditObjectActuator", "Add, remove, or replace objects in the scene at runtime."],
        ["Game", 305, "GameActuator", "Game-level actions: quit, restart, pause/unpause."],
        ["Look At Movement", 306, "LookAtMovementActuator", "Rotates a node to face the direction of movement.\n⚠ Adds @export in Inspector — assign the mesh/Node3D to rotate."],
        ["Message", 307, "MessageActuator", "Sends a message to all nodes in a target group."],
        ["Modify Variable", 308, "VariableActuator", "Modify a logic brick variable (assign, add, subtract, etc)."],
        ["Motion", 309, "MotionActuator", "Move or rotate: translation, velocity, force, torque."],
        ["Mouse", 310, "MouseActuator", "Mouse-based camera rotation with sensitivity and clamping."],
        ["Move Towards", 311, "MoveTowardsActuator", "Seek, flee, or path-follow toward a target node.\n⚠ Path Follow adds @export in Inspector — assign your NavigationAgent3D."],
        ["Parent", 312, "ParentActuator", "Change the node's parent in the scene tree."],
        ["Physics", 313, "PhysicsActuator", "Modify physics properties: gravity scale, mass, friction."],
        ["Property", 314, "PropertyActuator", "Set any property on a target node (visible, modulate, etc).\n⚠ Adds @export in Inspector — assign the target node."],
        ["Random", 315, "RandomActuator", "Set a variable to a random value within a range."],
        ["Save Game", 316, "SaveGameActuator", "Save/load position, rotation, and variables to JSON."],
        ["Scene", 317, "SceneActuator", "Change or reload scenes."],
        ["Sound", 318, "SoundActuator", "Play audio with random pitch, buses, and play modes."],
        ["State", 319, "StateActuator", "Change the logic brick state (1-30)."],
        ["Teleport", 320, "TeleportActuator", "Instantly move to a target node or coordinates.\n⚠ Target Node mode adds @export in Inspector — assign the destination."],
        ["Text", 321, "TextActuator", "Display text or variable values on a UI Label.\n⚠ Adds @export in Inspector — assign your text node."],
    ]
    for i in _actuator_items.size():
        actuators_menu.add_item(_actuator_items[i][0], _actuator_items[i][1])
        actuators_menu.set_item_metadata(i, {"type": "actuator", "class": _actuator_items[i][2]})
        actuators_menu.set_item_tooltip(i, _actuator_items[i][3])


func _create_side_panel() -> void:
    # Create the tabbed side panel with Variables and Frames tabs
    side_panel = TabContainer.new()
    side_panel.custom_minimum_size = Vector2(300, 0)
    side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    side_panel.visible = false  # Hidden until node selected
    
    # Variables Tab
    _create_variables_tab()
    side_panel.add_child(variables_panel)
    
    # Frames Tab
    _create_frames_tab()
    side_panel.add_child(frames_panel)


func _create_variables_tab() -> void:
    # Create the variables management tab
    variables_panel = VBoxContainer.new()
    variables_panel.name = "Variables"
    variables_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    
    # Header
    var header = HBoxContainer.new()
    variables_panel.add_child(header)
    
    var title = Label.new()
    title.text = "Variables"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var title_font = title.get_theme_font("bold", "EditorFonts")
    if title_font:
        title.add_theme_font_override("font", title_font)
    header.add_child(title)
    
    # Add Variable button
    var add_var_button = Button.new()
    add_var_button.text = "+ Add"
    add_var_button.pressed.connect(_on_add_variable_pressed)
    header.add_child(add_var_button)
    
    # Separator
    var sep = HSeparator.new()
    variables_panel.add_child(sep)
    
    # Scrollable list of variables
    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    variables_panel.add_child(scroll)
    
    variables_list = VBoxContainer.new()
    variables_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(variables_list)


func _create_frames_tab() -> void:
    # Create the frames management tab
    frames_panel = VBoxContainer.new()
    frames_panel.name = "Frames"
    frames_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    
    # Header
    var header = HBoxContainer.new()
    frames_panel.add_child(header)
    
    var title = Label.new()
    title.text = "Frames"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var title_font = title.get_theme_font("bold", "EditorFonts")
    if title_font:
        title.add_theme_font_override("font", title_font)
    header.add_child(title)
    
    # Separator
    var sep1 = HSeparator.new()
    frames_panel.add_child(sep1)
    
    # Frame list with controls
    var list_container = HBoxContainer.new()
    frames_panel.add_child(list_container)
    
    # Frame list
    frames_list = ItemList.new()
    frames_list.custom_minimum_size = Vector2(0, 150)
    frames_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    frames_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
    frames_list.item_selected.connect(_on_frame_list_item_selected)
    frames_list.item_activated.connect(_on_frame_list_item_activated)  # Double-click to rename
    list_container.add_child(frames_list)
    
    # Separator
    var sep2 = HSeparator.new()
    frames_panel.add_child(sep2)
    
    # Frame settings (shown when a frame is selected)
    frame_settings_container = VBoxContainer.new()
    frame_settings_container.name = "FrameSettings"
    frame_settings_container.visible = false
    frames_panel.add_child(frame_settings_container)
    
    var settings_label = Label.new()
    settings_label.text = "Frame Settings:"
    var settings_font = settings_label.get_theme_font("bold", "EditorFonts")
    if settings_font:
        settings_label.add_theme_font_override("font", settings_font)
    frame_settings_container.add_child(settings_label)
    
    # Frame name field
    var name_label = Label.new()
    name_label.text = "Name:"
    frame_settings_container.add_child(name_label)
    
    var name_edit = LineEdit.new()
    name_edit.name = "FrameNameEdit"
    name_edit.placeholder_text = "Enter frame name..."
    name_edit.text_changed.connect(_on_frame_name_changed)
    frame_settings_container.add_child(name_edit)
    
    # Frame color picker
    var color_label = Label.new()
    color_label.text = "Color:"
    frame_settings_container.add_child(color_label)
    
    var color_picker = ColorPickerButton.new()
    color_picker.name = "FrameColorPicker"
    color_picker.edit_alpha = true
    color_picker.color_changed.connect(_on_frame_color_changed)
    frame_settings_container.add_child(color_picker)
    
    # Manual size controls
    var size_label = Label.new()
    size_label.text = "Frame Size:"
    frame_settings_container.add_child(size_label)
    
    var size_hbox = HBoxContainer.new()
    frame_settings_container.add_child(size_hbox)
    
    var width_label = Label.new()
    width_label.text = "W:"
    size_hbox.add_child(width_label)
    
    var width_spin = SpinBox.new()
    width_spin.name = "FrameWidthSpin"
    width_spin.min_value = 100
    width_spin.max_value = 2000
    width_spin.step = 10
    width_spin.value_changed.connect(_on_frame_width_changed)
    size_hbox.add_child(width_spin)
    
    var height_label = Label.new()
    height_label.text = "H:"
    size_hbox.add_child(height_label)
    
    var height_spin = SpinBox.new()
    height_spin.name = "FrameHeightSpin"
    height_spin.min_value = 100
    height_spin.max_value = 2000
    height_spin.step = 10
    height_spin.value_changed.connect(_on_frame_height_changed)
    size_hbox.add_child(height_spin)
    
    # Auto-resize button
    var resize_button = Button.new()
    resize_button.text = "Auto-Resize to Fit Nodes"
    resize_button.pressed.connect(_on_frame_resize_pressed)
    frame_settings_container.add_child(resize_button)
    
    # Delete frame button
    var delete_button = Button.new()
    delete_button.text = "Delete Frame"
    delete_button.modulate = Color(1, 0.5, 0.5)
    delete_button.pressed.connect(_on_frame_delete_pressed)
    frame_settings_container.add_child(delete_button)


func _enter_tree() -> void:
    # Set editor icons now that the theme is available
    if _copy_button:
        _copy_button.icon = get_theme_icon("ActionCopy", "EditorIcons")
        _copy_button.text = ""
    if _paste_button:
        _paste_button.icon = get_theme_icon("ActionPaste", "EditorIcons")
        _paste_button.text = ""


func set_selected_node(node: Node) -> void:
    # Don't change selection if locked
    if is_locked:
        return
    
    # Save current state before switching (but NOT if current node is an instance)
    if current_node and not _is_part_of_instance(current_node):
        _save_graph_to_metadata()
        _save_frames_to_metadata()
    
    current_node = node
    _update_ui()


func _update_ui() -> void:
    var instructions_label = get_node_or_null("InstructionsLabel")
    
    if not current_node:
        node_info_label.text = "No node selected - Select a 3D node in the scene tree"
        graph_edit.visible = false
        side_panel.visible = false
        if instructions_label:
            instructions_label.visible = true
        return
    
    # Check if node is supported
    if not _is_supported_node(current_node):
        node_info_label.text = "Unsupported node type: %s - Use Node3D, CharacterBody3D, or RigidBody3D" % current_node.get_class()
        graph_edit.visible = false
        side_panel.visible = false
        if instructions_label:
            instructions_label.visible = true
        return
    
    # Check if node is part of an instanced scene
    if _is_part_of_instance(current_node):
        node_info_label.text = "⚠ INSTANCED NODE: %s\nThis node is from an instanced scene. Logic Bricks cannot be edited on instances.\nEdit the original scene file instead." % current_node.name
        node_info_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.0))
        graph_edit.visible = false
        side_panel.visible = false
        if instructions_label:
            instructions_label.visible = true
        return
    
    # Reset label color to normal
    node_info_label.remove_theme_color_override("font_color")
    
    # Update header
    node_info_label.text = "✓ Node: %s (%s) - Right-click to add bricks" % [current_node.name, current_node.get_class()]
    graph_edit.visible = true
    side_panel.visible = true
    if instructions_label:
        instructions_label.visible = false
    
    # Load graph, frames, and variables from metadata
    await _load_graph_from_metadata()
    _load_frames_from_metadata()
    _load_variables_from_metadata()


func _is_supported_node(node: Node) -> bool:
    return node is Node3D or node is CharacterBody3D or node is RigidBody3D


func _is_part_of_instance(node: Node) -> bool:
    """Check if the node is part of an instanced scene (not the root scene)"""
    if not editor_interface:
        return false
    
    var edited_scene_root = editor_interface.get_edited_scene_root()
    if not edited_scene_root:
        return false
    
    var current = node
    while current:
        if current == edited_scene_root:
            return false
        if current.scene_file_path != "" and current != edited_scene_root:
            return true
        current = current.get_parent()
    
    return false


func _load_graph_from_metadata() -> void:
    # Clear existing graph - disconnect first, then remove nodes immediately
    graph_edit.clear_connections()
    var children_to_remove = []
    for child in graph_edit.get_children():
        if child is GraphNode:
            children_to_remove.append(child)
    for child in children_to_remove:
        graph_edit.remove_child(child)
        child.free()
    
    if not current_node or not current_node.has_meta("logic_bricks_graph"):
        pass  #print("Logic Bricks: No saved graph data for %s" % (current_node.name if current_node else "null"))
        return
    
    var graph_data = current_node.get_meta("logic_bricks_graph")
    #print("Logic Bricks: Loading %d nodes and %d connections for %s" % [graph_data.get("nodes", []).size(), graph_data.get("connections", []).size(), current_node.name])
    
    # Restore nodes
    for node_data in graph_data.get("nodes", []):
        _create_graph_node_from_data(node_data)
    
    # Restore connections (must happen after all nodes are created)
    await get_tree().process_frame
    for conn in graph_data.get("connections", []):
        pass  #print("Logic Bricks: Restoring connection: %s:%d -> %s:%d" % [conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"]])
        graph_edit.connect_node(conn["from_node"], conn["from_port"], conn["to_node"], conn["to_port"])
    
    next_node_id = graph_data.get("next_id", 0)


func _save_graph_to_metadata() -> void:
    if not current_node:
        return
    
    # Never save to instanced nodes
    if _is_part_of_instance(current_node):
        return
    
    var graph_data = {
        "nodes": [],
        "connections": [],
        "next_id": next_node_id
    }
    
    # Save nodes
    for child in graph_edit.get_children():
        if child is GraphNode and child.has_meta("brick_data"):
            var brick_data = child.get_meta("brick_data")
            var node_data = {
                "id": child.name,
                "position": child.position_offset,
                "brick_type": brick_data["brick_type"],
                "brick_class": brick_data["brick_class"],
                "instance_name": brick_data["brick_instance"].get_instance_name(),
                "debug_enabled": brick_data["brick_instance"].debug_enabled,
                "debug_message": brick_data["brick_instance"].debug_message,
                "properties": brick_data["brick_instance"].get_properties()
            }
            graph_data["nodes"].append(node_data)
        elif child is GraphNode and child.has_meta("is_reroute"):
            var node_data = {
                "id": child.name,
                "position": child.position_offset,
                "is_reroute": true
            }
            graph_data["nodes"].append(node_data)
    
    # Save connections
    for conn in graph_edit.get_connection_list():
        graph_data["connections"].append({
            "from_node": conn["from_node"],
            "from_port": conn["from_port"],
            "to_node": conn["to_node"],
            "to_port": conn["to_port"]
        })
    
    #print("Logic Bricks: Saving %d nodes and %d connections to %s" % [graph_data["nodes"].size(), graph_data["connections"].size(), current_node.name])
    current_node.set_meta("logic_bricks_graph", graph_data)
    
    # Mark the scene as modified so changes are saved
    _mark_scene_modified()


func _on_popup_request(position: Vector2) -> void:
    pass  #print("Logic Bricks: Right-click popup at position: ", position)
    # Store the position accounting for scroll offset
    # position is in local graph coordinates, we need to add scroll offset
    last_mouse_position = (position + graph_edit.scroll_offset) / graph_edit.zoom
    # Position the menu at the click location in screen coordinates
    var screen_pos = graph_edit.get_screen_position() + position
    add_menu.position = screen_pos
    add_menu.popup()


func _on_main_menu_id_pressed(id: int) -> void:
    if id == 3:
        _create_reroute_node(last_mouse_position)


func _create_reroute_node(position: Vector2) -> void:
    var graph_node = GraphNode.new()
    graph_node.name = "reroute_%d" % next_node_id
    next_node_id += 1
    graph_node.title = ""
    graph_node.position_offset = position
    graph_node.custom_minimum_size = Vector2(30, 0)
    graph_node.size = Vector2(30, 30)
    graph_node.resizable = false
    graph_node.draggable = true
    
    # Add a minimal spacer child so the slot renders
    var spacer = Control.new()
    spacer.custom_minimum_size = Vector2(10, 4)
    graph_node.add_child(spacer)
    
    # Both input and output, type 0, white color (connects to both green and blue)
    graph_node.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)
    
    # Mark as reroute so chain extraction skips it
    graph_node.set_meta("is_reroute", true)
    
    graph_node.dragged.connect(_on_reroute_dragged.bind(graph_node))
    
    graph_edit.add_child(graph_node)
    _save_graph_to_metadata()


func _on_add_menu_item_selected(id: int) -> void:
    # Determine which menu was used based on ID range
    var metadata = null
    if id >= 100 and id < 200:
        # Sensors menu (100-199)
        var item_index = sensors_menu.get_item_index(id)
        metadata = sensors_menu.get_item_metadata(item_index)
    elif id >= 200 and id < 300:
        # Controllers menu (200-299)
        var item_index = controllers_menu.get_item_index(id)
        metadata = controllers_menu.get_item_metadata(item_index)
    elif id >= 300 and id < 400:
        # Actuators menu (300-399)
        var item_index = actuators_menu.get_item_index(id)
        metadata = actuators_menu.get_item_metadata(item_index)
    
    if metadata:
        var brick_type = metadata["type"]
        var brick_class = metadata["class"]
        _create_graph_node(brick_type, brick_class, last_mouse_position)


func _create_graph_node(brick_type: String, brick_class: String, position: Vector2) -> void:
    # Create the brick instance
    var brick_instance = _create_brick_instance(brick_class)
    if not brick_instance:
        push_error("Logic Bricks: Failed to create brick instance for: " + brick_class)
        return
    
    # Create the GraphNode
    var graph_node = BrickGraphNode.new()
    graph_node.name = "brick_node_%d" % next_node_id
    next_node_id += 1
    
    graph_node.position_offset = position
    graph_node.title = brick_class.replace("Sensor", "").replace("Controller", "").replace("Actuator", "")
    
    # Store brick data
    graph_node.set_meta("brick_data", {
        "brick_type": brick_type,
        "brick_class": brick_class,
        "brick_instance": brick_instance
    })
    
    # Set up ports based on brick type
    if brick_type == "sensor":
        graph_node.set_slot(0, false, 0, Color.WHITE, true, 0, Color.GREEN)
    elif brick_type == "controller":
        graph_node.set_slot(0, true, 0, Color.GREEN, true, 0, Color.BLUE)
    elif brick_type == "actuator":
        graph_node.set_slot(0, true, 0, Color.BLUE, false, 0, Color.WHITE)
    
    # Create UI for brick properties
    _create_brick_ui(graph_node, brick_instance)
    
    # Add "View Code" button to controller nodes
    if brick_type == "controller":
        var view_code_btn = Button.new()
        view_code_btn.text = "View Code"
        view_code_btn.tooltip_text = "Open the generated script and jump to this chain's code"
        view_code_btn.pressed.connect(_on_view_chain_code.bind(graph_node))
        graph_node.add_child(view_code_btn)
    
    # Add context menu for duplicate/delete
    _setup_graph_node_context_menu(graph_node)
    
    # Connect drag signal for frame detection
    graph_node.dragged.connect(_on_brick_node_dragged.bind(graph_node))
    
    graph_edit.add_child(graph_node)
    _save_graph_to_metadata()
    
    #print("Logic Bricks: Created graph node '%s' at %s" % [graph_node.name, position])


func _create_graph_node_from_data(node_data: Dictionary) -> void:
    # Handle reroute nodes
    if node_data.get("is_reroute", false):
        var graph_node = GraphNode.new()
        graph_node.name = node_data["id"]
        graph_node.title = ""
        graph_node.position_offset = node_data["position"]
        graph_node.custom_minimum_size = Vector2(30, 0)
        graph_node.size = Vector2(30, 30)
        graph_node.resizable = false
        graph_node.draggable = true
        var spacer = Control.new()
        spacer.custom_minimum_size = Vector2(10, 4)
        graph_node.add_child(spacer)
        graph_node.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)
        graph_node.set_meta("is_reroute", true)
        graph_node.dragged.connect(_on_reroute_dragged.bind(graph_node))
        graph_edit.add_child(graph_node)
        return
    
    var brick_type = node_data["brick_type"]
    var brick_class = node_data["brick_class"]
    var position = node_data["position"]
    var properties = node_data.get("properties", {})
    var instance_name = node_data.get("instance_name", "")
    var debug_enabled = node_data.get("debug_enabled", false)
    var debug_message = node_data.get("debug_message", "")
    
    # Create brick instance
    var brick_instance = _create_brick_instance(brick_class)
    if not brick_instance:
        return
    
    # Restore instance name
    if not instance_name.is_empty():
        brick_instance.set_instance_name(instance_name)
    
    # Restore debug fields
    brick_instance.debug_enabled = debug_enabled
    brick_instance.debug_message = debug_message
    
    # Restore properties
    for prop_name in properties:
        brick_instance.set_property(prop_name, properties[prop_name])
    
    # Create GraphNode
    var graph_node = BrickGraphNode.new()
    graph_node.name = node_data["id"]
    graph_node.position_offset = position
    graph_node.title = brick_class.replace("Sensor", "").replace("Controller", "").replace("Actuator", "")
    
    # Store brick data
    graph_node.set_meta("brick_data", {
        "brick_type": brick_type,
        "brick_class": brick_class,
        "brick_instance": brick_instance
    })
    
    # Set up ports
    if brick_type == "sensor":
        graph_node.set_slot(0, false, 0, Color.WHITE, true, 0, Color.GREEN)
    elif brick_type == "controller":
        graph_node.set_slot(0, true, 0, Color.GREEN, true, 0, Color.BLUE)
    elif brick_type == "actuator":
        graph_node.set_slot(0, true, 0, Color.BLUE, false, 0, Color.WHITE)
    
    # Create UI
    _create_brick_ui(graph_node, brick_instance)
    
    # Add "View Code" button to controller nodes
    if brick_type == "controller":
        var view_code_btn = Button.new()
        view_code_btn.text = "View Code"
        view_code_btn.tooltip_text = "Open the generated script and jump to this chain's code"
        view_code_btn.pressed.connect(_on_view_chain_code.bind(graph_node))
        graph_node.add_child(view_code_btn)
    
    # Add context menu for duplicate/delete
    _setup_graph_node_context_menu(graph_node)
    
    # Connect drag signal for frame detection
    graph_node.dragged.connect(_on_brick_node_dragged.bind(graph_node))
    
    graph_edit.add_child(graph_node)


func _create_brick_instance(brick_class: String):
    var script_path = ""
    
    match brick_class:
        "AlwaysSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/always_sensor.gd"
        "AnimationTreeSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/animation_tree_sensor.gd"
        "DelaySensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/delay_sensor.gd"
        "KeyboardSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/keyboard_sensor.gd"  # Legacy
        "InputMapSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/input_map_sensor.gd"
        "MessageSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/message_sensor.gd"
        "VariableSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/variable_sensor.gd"
        "ProximitySensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/proximity_sensor.gd"
        "RandomSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/random_sensor.gd"
        "RaycastSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/raycast_sensor.gd"
        "TimerSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/timer_sensor.gd"
        "MovementSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/movement_sensor.gd"
        "MouseSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/mouse_sensor.gd"
        "CollisionSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/collision_sensor.gd"
        "ANDController", "Controller":
            script_path = "res://addons/logic_bricks/bricks/controllers/controller.gd"
        "MotionActuator", "LocationActuator", "LinearVelocityActuator", "RotationActuator", "ForceActuator", "TorqueActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/motion_actuator.gd"
        "EditObjectActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/edit_object_actuator.gd"
        "CharacterActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/character_actuator.gd"
        "GravityActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/gravity_actuator.gd"  # Legacy
        "JumpActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/jump_actuator.gd"  # Legacy
        "MoveTowardsActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/move_towards_actuator.gd"
        "AnimationActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/animation_actuator.gd"
        "AnimationTreeActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/animation_tree_actuator.gd"
        "MessageActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/message_actuator.gd"
        "LookAtMovementActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/look_at_movement_actuator.gd"
        "VariableActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/variable_actuator.gd"
        "RandomActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/random_actuator.gd"
        "StateActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/state_actuator.gd"
        "TeleportActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/teleport_actuator.gd"
        "PropertyActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/property_actuator.gd"
        "TextActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/text_actuator.gd"
        "SoundActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/sound_actuator.gd"
        "SceneActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/scene_actuator.gd"
        "SaveGameActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/save_game_actuator.gd"
        "CameraActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/camera_actuator.gd"
        "CollisionActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/collision_actuator.gd"
        "ParentActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/parent_actuator.gd"
        "MouseActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/mouse_actuator.gd"
        "GameActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/game_actuator.gd"
        "PhysicsActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/physics_actuator.gd"
        "ANDController", "Controller":
            script_path = "res://addons/logic_bricks/bricks/controllers/controller.gd"
    
    if script_path.is_empty():
        return null
    
    var brick_script = load(script_path)
    if not brick_script:
        return null
    
    return brick_script.new()


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
        for prop_def in prop_definitions:
            var property_name = prop_def["name"]
            var property_value = properties.get(property_name, prop_def.get("default", null))
            var property_type = prop_def.get("type", TYPE_NIL)
            var hint = prop_def.get("hint", PROPERTY_HINT_NONE)
            var hint_string = prop_def.get("hint_string", "")
            
            var ui_element = null
            
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
                
                # Special case: Animation list from AnimationPlayer
                elif hint_string == "__ANIMATION_LIST__":
                    # Get animations from AnimationPlayer on the node specified by animation_node_path
                    var anim_node_path = properties.get("animation_node_path", "")
                    var animation_list = _get_animations_from_node_path(graph_node, anim_node_path)
                    
                    var selected_index = 0
                    for i in range(animation_list.size()):
                        var anim_name = animation_list[i]
                        option_button.add_item(anim_name, i)
                        option_button.set_item_metadata(i, anim_name)
                        
                        if anim_name == property_value:
                            selected_index = i
                    
                    # Add empty option if no selection
                    if animation_list.is_empty():
                        option_button.add_item("(No animations found)", 0)
                        option_button.disabled = true
                    
                    option_button.selected = selected_index
                
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
                spinbox.value = property_value
                spinbox.value_changed.connect(_on_property_changed.bind(graph_node, property_name))
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
                spinbox.step = 0.01
                spinbox.min_value = -10000
                spinbox.max_value = 10000
                spinbox.value = property_value
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
            
            if ui_element:
                # Store property name on the UI element for conditional visibility
                ui_element.set_meta("property_name", property_name)
                # Apply tooltip from brick's tooltip definitions
                if tooltips.has(property_name):
                    ui_element.tooltip_text = tooltips[property_name]
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
    # Convert property_name to Display Name
    return property_name.replace("_", " ").capitalize()


func _get_animations_from_player(graph_node: GraphNode, anim_player_name: String) -> Array[String]:
    # Get list of animation names from the AnimationPlayer on current_node
    var animations: Array[String] = []
    
    if not current_node:
        return animations
    
    # Try to find AnimationPlayer as child of current_node
    var anim_player = current_node.get_node_or_null(anim_player_name)
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
    
    if not current_node or node_path.is_empty():
        return animations
    
    # Find the node specified by the path
    var target_node = current_node.get_node_or_null(node_path)
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
    # Get list of AnimationPlayer node names that are children of current_node
    var players: Array[String] = []
    
    if not current_node:
        return players
    
    # Search all children for AnimationPlayer nodes
    for child in current_node.get_children():
        if child is AnimationPlayer:
            players.append(child.name)
    
    return players


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
    
    # Get the animation list based on current animation_node_path
    var anim_node_path = properties.get("animation_node_path", "")
    var animation_list = _get_animations_from_node_path(graph_node, anim_node_path)
    
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
            # Normalize to lowercase
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
        
        "motion_actuator":  # Motion Actuator
            var motion_type = properties.get("motion_type", "location")
            
            # Normalize
            if typeof(motion_type) == TYPE_STRING:
                motion_type = motion_type.to_lower().replace(" ", "_")
            
            # Show/hide fields based on motion type
            for child in graph_node.get_children():
                if child.has_meta("property_name"):
                    var prop_name = child.get_meta("property_name")
                    match prop_name:
                        "movement_method":
                            # Only show for location type
                            child.visible = (motion_type == "location")
                        "velocity_mode":
                            # Only show for linear_velocity type
                            child.visible = (motion_type == "linear_velocity")
        
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
            var collision_type = properties.get("collision_type", "area_child")
            
            # Normalize
            if typeof(collision_type) == TYPE_STRING:
                collision_type = collision_type.to_lower().replace(" ", "_")
            
            # Show area_node_name only for area_child type
            for child in graph_node.get_children():
                if child.has_meta("property_name"):
                    var prop_name = child.get_meta("property_name")
                    if prop_name == "area_node_name":
                        child.visible = (collision_type == "area_child")
        
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
        
        "camera_actuator":  # Camera Actuator
            var mode = properties.get("mode", "set_active")
            
            # Normalize mode
            if typeof(mode) == TYPE_STRING:
                mode = mode.to_lower().replace(" ", "_")
            
            # Show/hide fields based on mode
            for child in graph_node.get_children():
                if child.has_meta("property_name"):
                    var prop_name = child.get_meta("property_name")
                    match prop_name:
                        "camera_node":
                            child.visible = (mode == "set_active")
                        "target_node", "follow_speed", "follow_pos_x", "follow_pos_y", "follow_pos_z", "follow_rot_x", "follow_rot_y", "follow_rot_z":
                            child.visible = (mode == "smooth_follow")
        
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
                        "spawn_object", "spawn_point", "velocity_x", "velocity_y", "velocity_z", "lifespan":
                            child.visible = (edit_type == "add_object")
                        "end_mode":
                            child.visible = (edit_type == "end_object")
                        "mesh_path":
                            child.visible = (edit_type == "replace_mesh")
        
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
                        "negative_action", "positive_action", "invert", "store_in", "deadzone":
                            child.visible = is_axis



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
    if hint_string in ["__ANIMATION_LIST__", "__ANIMATION_PLAYER_LIST__"] and option_button:
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
            value = int(value)
        else:
            value = str(value)
    
    brick_instance.set_property(property_name, value)
    _save_graph_to_metadata()
    #print("Logic Bricks: Property '%s' changed to: '%s'" % [property_name, value])
    
    # Update conditional visibility for fields that depend on this enum
    _update_conditional_visibility(graph_node, brick_instance)


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
            
            _save_graph_to_metadata()
            #print("Logic Bricks: Property '%s' set to: %s" % [property_name, path])
        file_dialog.queue_free()
    )
    
    # Close dialog if cancelled
    file_dialog.canceled.connect(func():
        file_dialog.queue_free()
    )
    
    # Add to scene tree and show
    add_child(file_dialog)
    file_dialog.popup_centered_ratio(0.6)


func _on_lock_toggled() -> void:
    # Toggle the lock state to prevent/allow selection changes
    is_locked = not is_locked
    
    if is_locked:
        lock_button.text = "🔒"  # Locked icon
        lock_button.modulate = Color(1.0, 0.8, 0.8)  # Slight red tint
        if current_node:
            node_info_label.text = "🔒 Locked: " + current_node.name
    else:
        lock_button.text = "🔓"  # Unlocked icon
        lock_button.modulate = Color.WHITE
        if current_node:
            node_info_label.text = "Selected: " + current_node.name


func _setup_graph_node_context_menu(graph_node: GraphNode) -> void:
    # Set up right-click context menu for a graph node
    var popup_menu = PopupMenu.new()
    popup_menu.add_item("Duplicate", 0)
    popup_menu.add_separator()
    popup_menu.add_item("Delete", 1)
    
    popup_menu.id_pressed.connect(_on_graph_node_context_menu.bind(graph_node))
    graph_node.add_child(popup_menu)
    
    # Connect gui_input to show context menu on right-click
    graph_node.gui_input.connect(func(event: InputEvent):
        if event is InputEventMouseButton:
            if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
                popup_menu.position = graph_node.get_screen_position() + event.position
                popup_menu.popup()
    )


func _on_graph_node_context_menu(id: int, graph_node: GraphNode) -> void:
    # Handle context menu selection for a graph node
    match id:
        0:  # Duplicate
            await _duplicate_graph_node(graph_node)
        1:  # Delete
            graph_node.queue_free()
            _save_graph_to_metadata()


func _duplicate_graph_node(original_node: GraphNode) -> GraphNode:
    # Duplicate a graph node with automatic naming. Returns the new node.
    if not original_node.has_meta("brick_data"):
        return null
    
    var brick_data = original_node.get_meta("brick_data")
    var brick_instance = brick_data["brick_instance"]
    
    # Get the original instance name
    var original_name = brick_instance.instance_name
    if original_name.is_empty():
        original_name = brick_data["brick_class"].replace("Sensor", "").replace("Controller", "").replace("Actuator", "")
    
    # Generate new name with .001, .002, etc.
    var new_name = _generate_unique_brick_name(original_name)
    
    # Create new graph node at offset position
    var new_position = original_node.position_offset + Vector2(50, 50)
    _create_graph_node(brick_data["brick_type"], brick_data["brick_class"], new_position)
    
    # Get the newly created node (it's the last child)
    var new_node = graph_edit.get_child(graph_edit.get_child_count() - 1)
    if new_node and new_node.has_meta("brick_data"):
        var new_brick_data = new_node.get_meta("brick_data")
        var new_brick_instance = new_brick_data["brick_instance"]
        
        # Copy all properties
        var properties = brick_instance.get_properties()
        for key in properties:
            new_brick_instance.set_property(key, properties[key])
        
        # Set the new unique name
        new_brick_instance.set_instance_name(new_name)
        
        # Copy debug settings
        new_brick_instance.debug_enabled = brick_instance.debug_enabled
        new_brick_instance.debug_message = brick_instance.debug_message
        
        # Update the UI to reflect the new name
        var name_edit = new_node.get_node_or_null("InstanceNameEdit")
        if name_edit:
            name_edit.text = new_name
        
        # Rebuild the UI to reflect copied properties
        # Remove old UI children (except metadata)
        for child in new_node.get_children():
            if not child is PopupMenu:  # Keep the context menu
                child.queue_free()
        
        # Recreate UI with copied properties
        await get_tree().process_frame  # Wait for children to be freed
        _create_brick_ui(new_node, new_brick_instance)
        _setup_graph_node_context_menu(new_node)
        
        # Select the new node
        new_node.selected = true
        
        _save_graph_to_metadata()
        
        #print("Logic Bricks: Duplicated brick '%s' as '%s'" % [original_name, new_name])
        return new_node
    
    return null


func _generate_unique_brick_name(base_name: String) -> String:
    # Generate a unique brick name by appending .001, .002, etc.
    # Remove existing suffix if present
    var clean_name = base_name
    var regex = RegEx.new()
    regex.compile("_\\d{3}$")  # Matches _001, _002, etc. at end
    var result = regex.search(base_name)
    if result:
        clean_name = base_name.substr(0, result.get_start())
    
    # Find all existing names that match this pattern
    var existing_names = []
    for child in graph_edit.get_children():
        if child is GraphNode and child.has_meta("brick_data"):
            var brick_data = child.get_meta("brick_data")
            var brick_instance = brick_data["brick_instance"]
            existing_names.append(brick_instance.instance_name)
    
    # Find the next available number
    var suffix_num = 1
    var new_name = clean_name + "_%03d" % suffix_num
    
    while new_name in existing_names:
        suffix_num += 1
        new_name = clean_name + "_%03d" % suffix_num
        
        # Safety check to prevent infinite loop
        if suffix_num > 999:
            new_name = clean_name + "_%d" % Time.get_ticks_msec()
            break
    
    return new_name


func _on_connection_request(from_node: String, from_port: int, to_node: String, to_port: int) -> void:
    # Check if this is a sensor → actuator direct connection
    var from_graph_node = graph_edit.get_node_or_null(NodePath(from_node))
    var to_graph_node = graph_edit.get_node_or_null(NodePath(to_node))
    
    if from_graph_node and to_graph_node:
        var from_data = from_graph_node.get_meta("brick_data") if from_graph_node.has_meta("brick_data") else null
        var to_data = to_graph_node.get_meta("brick_data") if to_graph_node.has_meta("brick_data") else null
        
        if from_data and to_data:
            if from_data["brick_type"] == "sensor" and to_data["brick_type"] == "actuator":
                # Auto-insert a controller between them
                var mid_x = (from_graph_node.position_offset.x + to_graph_node.position_offset.x) / 2.0
                var mid_y = (from_graph_node.position_offset.y + to_graph_node.position_offset.y) / 2.0
                _create_graph_node("controller", "Controller", Vector2(mid_x, mid_y))
                
                # Find the controller we just created (it's the last child added)
                var controller_node: GraphNode = null
                for child in graph_edit.get_children():
                    if child is GraphNode and child.has_meta("brick_data"):
                        var data = child.get_meta("brick_data")
                        if data["brick_type"] == "controller":
                            controller_node = child
                
                if controller_node:
                    # Connect sensor → controller → actuator
                    graph_edit.connect_node(from_node, from_port, controller_node.name, 0)
                    graph_edit.connect_node(controller_node.name, 0, to_node, to_port)
                    _save_graph_to_metadata()
                return
    
    # Normal connection (sensor→controller or controller→actuator)
    graph_edit.connect_node(from_node, from_port, to_node, to_port)
    _save_graph_to_metadata()


func _on_graph_edit_input(event: InputEvent) -> void:
    # Handle keyboard shortcuts in the graph editor
    if event is InputEventKey and event.pressed and not event.echo:
        # Ctrl+D to duplicate selected nodes
        if event.keycode == KEY_D and event.ctrl_pressed:
            _duplicate_selected_nodes()
            graph_edit.accept_event()


func _duplicate_selected_nodes() -> void:
    # Duplicate all currently selected graph nodes and preserve their connections
    var selected_nodes = []
    
    # Find all selected nodes
    for child in graph_edit.get_children():
        if child is GraphNode and child.selected:
            selected_nodes.append(child)
    
    if selected_nodes.is_empty():
        pass  #print("Logic Bricks: No nodes selected to duplicate")
        return
    
    # Store connections between selected nodes
    var internal_connections = []  # Connections where both nodes are selected
    var connection_list = graph_edit.get_connection_list()
    
    for conn in connection_list:
        var from_node = graph_edit.get_node(NodePath(conn["from_node"]))
        var to_node = graph_edit.get_node(NodePath(conn["to_node"]))
        
        if from_node in selected_nodes and to_node in selected_nodes:
            internal_connections.append({
                "from": from_node,
                "from_port": conn["from_port"],
                "to": to_node,
                "to_port": conn["to_port"]
            })
    
    # Create mapping of old nodes to new nodes
    var node_mapping = {}
    
    # Duplicate each selected node
    for node in selected_nodes:
        # Deselect original before duplicating
        node.selected = false
        var new_node = await _duplicate_graph_node(node)
        if new_node:
            node_mapping[node] = new_node
    
    # Wait for UI to be fully created
    await get_tree().process_frame
    
    # Recreate connections between duplicated nodes
    for conn in internal_connections:
        var old_from = conn["from"]
        var old_to = conn["to"]
        
        if old_from in node_mapping and old_to in node_mapping:
            var new_from = node_mapping[old_from]
            var new_to = node_mapping[old_to]
            
            graph_edit.connect_node(
                new_from.name,
                conn["from_port"],
                new_to.name,
                conn["to_port"]
            )
    
    _save_graph_to_metadata()
    #print("Logic Bricks: Duplicated %d node(s) with connections preserved" % selected_nodes.size())


func _on_disconnection_request(from_node: String, from_port: int, to_node: String, to_port: int) -> void:
    pass  #print("Logic Bricks: Disconnection request: %s:%d -> %s:%d" % [from_node, from_port, to_node, to_port])
    graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
    _save_graph_to_metadata()


func _on_delete_nodes_request(nodes: Array) -> void:
    pass  #print("Logic Bricks: Delete nodes request: ", nodes)
    for node_name in nodes:
        var node = graph_edit.get_node(NodePath(node_name))
        if node:
            # Check if it's a frame and clean up frame data
            if node is GraphFrame:
                frame_node_mapping.erase(node.name)
                frame_titles.erase(node.name)
                if selected_frame == node:
                    selected_frame = null
                    frame_settings_container.visible = false
            # Remove from parent and free immediately (not queue_free)
            # This ensures the node is gone before we save metadata
            graph_edit.remove_child(node)
            node.free()
    
    # Update frames list if any frames were deleted
    _update_frames_list()
    _save_graph_to_metadata()
    _save_frames_to_metadata()


func _on_property_changed(value, graph_node: GraphNode, property_name: String) -> void:
    if graph_node.has_meta("brick_data"):
        var brick_data = graph_node.get_meta("brick_data")
        brick_data["brick_instance"].set_property(property_name, value)
        #print("Logic Bricks: Property '%s' changed to: '%s'" % [property_name, value])
        
        # Check if any properties depend on this one (for dynamic dropdowns like animation lists)
        if property_name == "animation_node_path":
            # Rebuild the animation_name dropdown
            _rebuild_dependent_property(graph_node, "animation_name")
        
        _save_graph_to_metadata()


func _on_instance_name_changed(new_name: String, graph_node: GraphNode, brick_instance) -> void:
    # Sanitize the name (remove spaces, special characters)
    var sanitized_name = new_name.strip_edges().to_lower().replace(" ", "_")
    sanitized_name = sanitized_name.replace("-", "_")
    # Remove any non-alphanumeric characters except underscore
    var regex = RegEx.new()
    regex.compile("[^a-z0-9_]")
    sanitized_name = regex.sub(sanitized_name, "", true)
    
    brick_instance.set_instance_name(sanitized_name)
    _save_graph_to_metadata()
    #print("Logic Bricks: Instance name changed to: ", sanitized_name)


func _on_debug_enabled_changed(enabled: bool, graph_node: GraphNode, brick_instance) -> void:
    brick_instance.debug_enabled = enabled
    _save_graph_to_metadata()
    #print("Logic Bricks: Debug %s for brick" % ("enabled" if enabled else "disabled"))


func _on_debug_message_changed(new_message: String, graph_node: GraphNode, brick_instance) -> void:
    brick_instance.debug_message = new_message
    _save_graph_to_metadata()
    #print("Logic Bricks: Debug message set to: ", new_message)


func _on_copy_bricks_pressed() -> void:
    if not current_node:
        push_warning("Logic Bricks: No node selected to copy from.")
        return
    
    if not current_node.has_meta("logic_bricks_graph"):
        push_warning("Logic Bricks: No logic bricks on this node to copy.")
        return
    
    # Deep copy graph data
    var graph_data = current_node.get_meta("logic_bricks_graph")
    _clipboard_graph = graph_data.duplicate(true)
    
    # Deep copy variables if they exist
    if current_node.has_meta("logic_bricks_variables"):
        var vars_data = current_node.get_meta("logic_bricks_variables")
        _clipboard_vars = vars_data.duplicate(true)
    else:
        _clipboard_vars = []
    
    print("Logic Bricks: Copied %d bricks and %d variables from '%s'" % [_clipboard_graph.get("nodes", []).size(), _clipboard_vars.size(), current_node.name])


func _on_paste_bricks_pressed() -> void:
    if not current_node:
        push_warning("Logic Bricks: No node selected to paste to.")
        return
    
    if _clipboard_graph.is_empty():
        push_warning("Logic Bricks: Nothing to paste. Copy bricks from a node first.")
        return
    
    # Never paste to instanced nodes
    if _is_part_of_instance(current_node):
        push_warning("Logic Bricks: Cannot paste to an instanced node.")
        return
    
    # Set the metadata on the target node
    current_node.set_meta("logic_bricks_graph", _clipboard_graph.duplicate(true))
    
    if _clipboard_vars.size() > 0:
        current_node.set_meta("logic_bricks_variables", _clipboard_vars.duplicate(true))
    
    # Mark scene as modified
    _mark_scene_modified()
    
    # Reload the graph to show the pasted bricks
    await _load_graph_from_metadata()
    
    # Reload variables
    if current_node.has_meta("logic_bricks_variables"):
        variables_data = current_node.get_meta("logic_bricks_variables").duplicate(true)
    else:
        variables_data = []
    _refresh_variables_ui()
    
    print("Logic Bricks: Pasted %d bricks and %d variables to '%s'" % [_clipboard_graph.get("nodes", []).size(), _clipboard_vars.size(), current_node.name])


func _on_view_chain_code(controller_node: GraphNode) -> void:
    # Open the generated script and jump to this chain's function
    if not current_node or not editor_interface:
        return
    
    var script = current_node.get_script()
    if not script:
        push_warning("Logic Bricks: No script on this node. Click 'Apply Code' first.")
        return
    
    # Get chain name from controller node
    var chain_name = _get_chain_name_for_controller(controller_node)
    var func_name = "_logic_brick__%s" % chain_name.split("_")[-1]
    
    # Read the script to find the line number
    var script_path = script.resource_path
    var file = FileAccess.open(script_path, FileAccess.READ)
    if not file:
        push_warning("Logic Bricks: Could not read script file.")
        return
    
    var line_number = 1
    var found = false
    while not file.eof_reached():
        var line = file.get_line()
        if line.strip_edges().begins_with("func " + func_name):
            found = true
            break
        line_number += 1
    file.close()
    
    if not found:
        push_warning("Logic Bricks: Chain function '%s' not found in script. Try 'Apply Code' first." % func_name)
        return
    
    # Open script editor at the line
    editor_interface.set_main_screen_editor("Script")
    editor_interface.edit_script(script, line_number)


func _on_apply_code_pressed() -> void:
    pass  #print("Logic Bricks: Applying code to script...")
    
    if not current_node:
        push_error("Logic Bricks: No node selected!")
        return
    
    if not manager:
        push_error("Logic Bricks: Manager not initialized!")
        return
    
    if not editor_interface:
        push_error("Logic Bricks: Editor interface not available!")
        return
    
    # Extract chains
    var chains = _extract_chains_from_graph()
    
    # Clear old metadata
    if current_node.has_meta("logic_bricks"):
        current_node.remove_meta("logic_bricks")
    
    # Get script path before regeneration
    var script_path = ""
    if current_node.get_script():
        script_path = current_node.get_script().resource_path
    
    # Get variables code
    var variables_code = get_variables_code()
    
    # Save and regenerate - this writes the file to disk
    manager.save_chains(current_node, chains)
    manager.regenerate_script(current_node, variables_code)
    
    # Get script path if we didn't have one
    if script_path.is_empty() and current_node.get_script():
        script_path = current_node.get_script().resource_path
    
    if script_path.is_empty():
        push_error("Logic Bricks: No script path available!")
        return
    
    #print("Logic Bricks: Script written to: " + script_path)
    
    # Force filesystem to update
    var filesystem = editor_interface.get_resource_filesystem()
    filesystem.update_file(script_path)
    
    # Wait a frame
    await get_tree().process_frame
    
    # Reload the script with cache bypass
    var reloaded_script = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE)
    
    if not reloaded_script:
        push_error("Logic Bricks: Failed to reload script from disk!")
        return
    
    # Apply the reloaded script to the node
    current_node.set_script(reloaded_script)
    
    # HACK: To force script editor to refresh, we'll:
    # 1. Switch to another editor temporarily
    # 2. Then switch back and open the script
    # This forces the script editor to re-read the file
    
    editor_interface.set_main_screen_editor("2D")  # Switch away
    await get_tree().process_frame
    
    editor_interface.set_main_screen_editor("Script")  # Switch to script editor
    await get_tree().process_frame
    
    # Now open the reloaded script
    editor_interface.edit_script(reloaded_script, 1)
    
    #print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    #print("✓ Code applied and script opened!")
    #print("  Script: " + script_path)
    #print("  The script editor should now show the updated code.")
    #print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

func _extract_chains_from_graph() -> Array:
    # Extract chains from the graph by finding controllers and collecting all their inputs/outputs.
    # This allows multiple sensors to feed into one controller.
    var chains = []
    var connections = graph_edit.get_connection_list()
    
    # Find all controller nodes (these are the "hubs" of chains)
    var controller_nodes = []
    for child in graph_edit.get_children():
        if child is GraphNode and child.has_meta("brick_data"):
            var brick_data = child.get_meta("brick_data")
            if brick_data["brick_type"] == "controller":
                controller_nodes.append(child)
    
    # For each controller, find all sensors feeding into it and all actuators it feeds
    for controller_node in controller_nodes:
        var chain = _build_chain_from_controller(controller_node, connections)
        if chain["sensors"].size() > 0 and chain["actuators"].size() > 0:
            # Generate chain name from controller
            var chain_name = _get_chain_name_for_controller(controller_node)
            chains.append({
                "name": chain_name,
                "sensors": chain["sensors"],
                "controllers": [chain["controller"]] if chain["controller"] else [],
                "actuators": chain["actuators"]
            })
    
    return chains


func _build_chain_from_controller(controller_node: GraphNode, connections: Array) -> Dictionary:
    # Build a chain by finding all sensors feeding into this controller,
    # and all actuators this controller feeds into.
    # Follows through reroute nodes transparently.
    var sensors = []
    var actuators = []
    var controller_brick = null
    
    # Get the controller brick
    if controller_node.has_meta("brick_data"):
        var brick_data = controller_node.get_meta("brick_data")
        controller_brick = brick_data["brick_instance"].serialize()
    
    # Find all sensors connected to this controller (inputs), following through reroutes
    var input_nodes = _trace_inputs(controller_node.name, connections)
    for from_node in input_nodes:
        if from_node.has_meta("brick_data"):
            var brick_data = from_node.get_meta("brick_data")
            if brick_data["brick_type"] == "sensor":
                var serialized_data = brick_data["brick_instance"].serialize()
                sensors.append(serialized_data)
    
    # Find all actuators connected from this controller (outputs), following through reroutes
    var output_nodes = _trace_outputs(controller_node.name, connections)
    for to_node in output_nodes:
        if to_node.has_meta("brick_data"):
            var brick_data = to_node.get_meta("brick_data")
            if brick_data["brick_type"] == "actuator":
                actuators.append(brick_data["brick_instance"].serialize())
    
    return {
        "sensors": sensors,
        "controller": controller_brick,
        "actuators": actuators
    }


func _trace_inputs(node_name: String, connections: Array) -> Array:
    # Follow connections backwards through reroute nodes to find real source bricks
    var results = []
    for conn in connections:
        if conn["to_node"] == node_name:
            var from_node = graph_edit.get_node_or_null(NodePath(conn["from_node"]))
            if from_node:
                if from_node.has_meta("is_reroute"):
                    # Follow through the reroute recursively
                    results.append_array(_trace_inputs(from_node.name, connections))
                else:
                    results.append(from_node)
    return results


func _trace_outputs(node_name: String, connections: Array) -> Array:
    # Follow connections forwards through reroute nodes to find real target bricks
    var results = []
    for conn in connections:
        if conn["from_node"] == node_name:
            var to_node = graph_edit.get_node_or_null(NodePath(conn["to_node"]))
            if to_node:
                if to_node.has_meta("is_reroute"):
                    # Follow through the reroute recursively
                    results.append_array(_trace_outputs(to_node.name, connections))
                else:
                    results.append(to_node)
    return results


func _get_chain_name_for_controller(controller_node: GraphNode) -> String:
    # Generate a unique chain name from the controller node.
    # Use a simple name based on the controller's position or ID
    if controller_node.has_meta("brick_data"):
        var brick_data = controller_node.get_meta("brick_data")
        var brick_class = brick_data["brick_class"]
        # Create name from class and node ID
        return brick_class.to_lower().replace("controller", "") + "_" + controller_node.name.replace("brick_node_", "")
    
    # Fallback: use node name
    return controller_node.name.replace("brick_node_", "chain_")



## ============================================================================
## VARIABLES PANEL FUNCTIONS
## ============================================================================

func _on_add_variable_pressed() -> void:
    # Add a new variable to the list
    var var_data = {
        "name": "new_variable",
        "type": "int",
        "value": "0",
        "exported": false,
        "global": false
    }
    variables_data.append(var_data)
    _refresh_variables_ui()
    _save_variables_to_metadata()


func _refresh_variables_ui() -> void:
    # Rebuild the variables list UI
    # Clear existing UI
    for child in variables_list.get_children():
        child.queue_free()
    
    # Create UI for each variable
    for i in range(variables_data.size()):
        var var_data = variables_data[i]
        _create_variable_ui(i, var_data)


func _create_variable_ui(index: int, var_data: Dictionary) -> void:
    # Create UI for a single variable (collapsible)
    var panel = PanelContainer.new()
    variables_list.add_child(panel)
    
    var vbox = VBoxContainer.new()
    panel.add_child(vbox)
    
    # Header row: Collapse button, Name display, Delete button
    var header = HBoxContainer.new()
    vbox.add_child(header)
    
    # Collapse/Expand button
    var collapse_btn = Button.new()
    collapse_btn.text = "▼"  # Down arrow = expanded
    collapse_btn.custom_minimum_size = Vector2(24, 0)
    collapse_btn.name = "CollapseBtn"
    header.add_child(collapse_btn)
    
    # Variable name display (when collapsed)
    var name_display = Label.new()
    name_display.text = "%s: %s" % [var_data["name"], var_data["type"]]
    name_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_display.name = "NameDisplay"
    header.add_child(name_display)
    
    # Delete button
    var delete_btn = Button.new()
    delete_btn.text = "×"
    delete_btn.custom_minimum_size = Vector2(24, 0)
    delete_btn.pressed.connect(_on_delete_variable_pressed.bind(index))
    header.add_child(delete_btn)
    
    # Details container (collapsible)
    var details = VBoxContainer.new()
    details.name = "Details"
    vbox.add_child(details)
    
    # Row 1: Name editor
    var row1 = HBoxContainer.new()
    details.add_child(row1)
    
    var name_label = Label.new()
    name_label.text = "Name:"
    row1.add_child(name_label)
    
    var name_edit = LineEdit.new()
    name_edit.name = "NameEdit"
    name_edit.text = var_data["name"]
    name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_edit.text_changed.connect(_on_variable_name_changed.bind(index, name_display))
    row1.add_child(name_edit)
    
    # Row 2: Type dropdown
    var row2 = HBoxContainer.new()
    details.add_child(row2)
    
    var type_label = Label.new()
    type_label.text = "Type:"
    row2.add_child(type_label)
    
    var type_option = OptionButton.new()
    type_option.name = "TypeOption"
    type_option.add_item("bool", 0)
    type_option.add_item("int", 1)
    type_option.add_item("float", 2)
    type_option.add_item("String", 3)
    type_option.add_item("Vector2", 4)
    type_option.add_item("Vector3", 5)
    
    # Set selected type
    var type_index = 1  # default to int
    match var_data["type"]:
        "bool": type_index = 0
        "int": type_index = 1
        "float": type_index = 2
        "String": type_index = 3
        "Vector2": type_index = 4
        "Vector3": type_index = 5
    type_option.selected = type_index
    type_option.item_selected.connect(_on_variable_type_changed.bind(index, name_display))
    row2.add_child(type_option)
    
    # Row 3: Initial value
    var row3 = HBoxContainer.new()
    details.add_child(row3)
    
    var value_label = Label.new()
    value_label.text = "Value:"
    row3.add_child(value_label)
    
    var value_edit = LineEdit.new()
    value_edit.text = var_data["value"]
    value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    value_edit.text_changed.connect(_on_variable_value_changed.bind(index))
    row3.add_child(value_edit)
    
    # Row 4: Export checkbox
    var row4 = HBoxContainer.new()
    details.add_child(row4)
    
    var export_check = CheckBox.new()
    export_check.text = "Export (visible in Inspector)"
    export_check.button_pressed = var_data["exported"]
    export_check.toggled.connect(_on_variable_exported_changed.bind(index))
    row4.add_child(export_check)
    
    # Row 5: Global checkbox
    var row5 = HBoxContainer.new()
    details.add_child(row5)
    
    var global_check = CheckBox.new()
    global_check.text = "Global (shared across all scenes)"
    global_check.button_pressed = var_data.get("global", false)
    global_check.toggled.connect(_on_variable_global_changed.bind(index))
    row5.add_child(global_check)
    
    # Connect collapse button
    collapse_btn.pressed.connect(_on_variable_collapse_toggled.bind(collapse_btn, details))


func _on_variable_name_changed(new_name: String, index: int, name_display: Label) -> void:
    # Handle variable name change
    if index < variables_data.size():
        variables_data[index]["name"] = new_name
        # Update the display label
        name_display.text = "%s: %s" % [new_name, variables_data[index]["type"]]
        _save_variables_to_metadata()


func _on_variable_type_changed(type_index: int, index: int, name_display: Label) -> void:
    # Handle variable type change
    if index < variables_data.size():
        var type_names = ["bool", "int", "float", "String", "Vector2", "Vector3"]
        variables_data[index]["type"] = type_names[type_index]
        # Update the display label
        name_display.text = "%s: %s" % [variables_data[index]["name"], type_names[type_index]]
        _save_variables_to_metadata()


func _on_variable_value_changed(new_value: String, index: int) -> void:
    # Handle variable value change
    if index < variables_data.size():
        variables_data[index]["value"] = new_value
        _save_variables_to_metadata()


func _on_variable_exported_changed(exported: bool, index: int) -> void:
    # Handle export checkbox change
    if index < variables_data.size():
        variables_data[index]["exported"] = exported
        _save_variables_to_metadata()


func _on_variable_global_changed(is_global: bool, index: int) -> void:
    # Handle global checkbox change
    if index < variables_data.size():
        variables_data[index]["global"] = is_global
        # Global variables cannot also be exported on the node (they live in the autoload)
        if is_global:
            variables_data[index]["exported"] = false
            _refresh_variables_ui()
        _save_variables_to_metadata()
        _update_global_vars_script()


func _on_variable_collapse_toggled(collapse_btn: Button, details: VBoxContainer) -> void:
    # Toggle variable details visibility
    details.visible = !details.visible
    if details.visible:
        collapse_btn.text = "▼"  # Down arrow = expanded
    else:
        collapse_btn.text = "▶"  # Right arrow = collapsed


func _on_delete_variable_pressed(index: int) -> void:
    # Delete a variable
    if index < variables_data.size():
        variables_data.remove_at(index)
        _refresh_variables_ui()
        _save_variables_to_metadata()


func _save_variables_to_metadata() -> void:
    # Save ALL variables from this node to metadata
    # (includes both local and global variables defined here)
    
    if not current_node:
        return
    
    # Never save to instanced nodes
    if _is_part_of_instance(current_node):
        return
    
    # Save all variables (both local and global defined on this node)
    current_node.set_meta("logic_bricks_variables", variables_data.duplicate())
    
    # Mark the scene as modified so changes are saved
    _mark_scene_modified()
    
    # Update global vars script if any globals exist
    _update_global_vars_script()


func _update_global_vars_script() -> void:
    # Collect ALL global variables across ALL nodes in the scene
    # This ensures the global_vars.gd stays in sync
    var global_vars: Array[Dictionary] = []
    var seen_names: Dictionary = {}
    
    # Collect from current node's variables
    for var_data in variables_data:
        if var_data.get("global", false):
            var var_name = var_data["name"]
            if var_name not in seen_names:
                seen_names[var_name] = true
                global_vars.append(var_data.duplicate())
    
    # Also scan other nodes in the scene for global vars
    if editor_interface:
        var edited_scene = editor_interface.get_edited_scene_root()
        if edited_scene:
            _collect_global_vars_recursive(edited_scene, global_vars, seen_names)
    
    var script_path = "res://addons/logic_bricks/global_vars.gd"
    
    if global_vars.is_empty():
        # No globals — write an empty script to clean up old variables
        var empty_lines: Array[String] = []
        empty_lines.append("extends Node")
        empty_lines.append("")
        empty_lines.append("## Auto-generated by Logic Bricks plugin")
        empty_lines.append("## Global variables shared across all scenes")
        empty_lines.append("")
        empty_lines.append("# === LOGIC BRICKS GLOBALS START ===")
        empty_lines.append("# (no global variables)")
        empty_lines.append("# === LOGIC BRICKS GLOBALS END ===")
        empty_lines.append("")
        var file = FileAccess.open(script_path, FileAccess.WRITE)
        if file:
            file.store_string("\n".join(empty_lines))
            file.close()
            if editor_interface:
                editor_interface.get_resource_filesystem().scan()
        return
    
    # Generate the global vars script
    var lines: Array[String] = []
    lines.append("extends Node")
    lines.append("")
    lines.append("## Auto-generated by Logic Bricks plugin")
    lines.append("## Global variables shared across all scenes")
    lines.append("## Do not edit between the markers")
    lines.append("")
    lines.append("# === LOGIC BRICKS GLOBALS START ===")
    
    for var_data in global_vars:
        var var_name = var_data["name"]
        var var_type = var_data.get("type", "float")
        var var_value = var_data.get("value", "0")
        lines.append("var %s: %s = %s" % [var_name, var_type, var_value])
    
    lines.append("# === LOGIC BRICKS GLOBALS END ===")
    lines.append("")
    
    # Write the file
    var file = FileAccess.open(script_path, FileAccess.WRITE)
    if file:
        file.store_string("\n".join(lines))
        file.close()
    else:
        push_error("Logic Bricks: Could not write global vars script at: " + script_path)
        return
    
    # Tell the editor to scan for the new file
    if editor_interface:
        editor_interface.get_resource_filesystem().scan()
    
    # Register autoload if not already registered
    _ensure_global_vars_autoload(script_path)


func _collect_global_vars_recursive(node: Node, global_vars: Array[Dictionary], seen_names: Dictionary) -> void:
    # Skip the current_node (already collected above)
    if node != current_node and node.has_meta("logic_bricks_variables"):
        var node_vars = node.get_meta("logic_bricks_variables")
        if node_vars is Array:
            for var_data in node_vars:
                if var_data.get("global", false):
                    var var_name = var_data.get("name", "")
                    if not var_name.is_empty() and var_name not in seen_names:
                        seen_names[var_name] = true
                        global_vars.append(var_data.duplicate())
    
    for child in node.get_children():
        _collect_global_vars_recursive(child, global_vars, seen_names)


func _ensure_global_vars_autoload(script_path: String) -> void:
    # Use the EditorPlugin API to register autoload (takes effect immediately)
    if not ProjectSettings.has_setting("autoload/GlobalVars"):
        if plugin:
            plugin.ensure_global_vars_autoload(script_path)
        else:
            # Fallback: write to ProjectSettings directly (needs editor restart)
            ProjectSettings.set_setting("autoload/GlobalVars", "*" + script_path)
            ProjectSettings.save()
            print("Logic Bricks: Registered GlobalVars autoload (restart editor to activate)")


func _load_variables_from_metadata() -> void:
    # Load variables from node metadata
    # This loads both:
    # 1. Local variables for this node
    # 2. Global variables from ALL nodes in the scene (shared)
    
    variables_data.clear()
    
    if not current_node:
        return
    
    # Step 1: Load local variables from current node
    if current_node.has_meta("logic_bricks_variables"):
        var saved_vars = current_node.get_meta("logic_bricks_variables")
        if saved_vars is Array:
            # Only add non-global variables (local to this node)
            for var_data in saved_vars:
                if not var_data.get("global", false):
                    variables_data.append(var_data.duplicate())
    
    # Step 2: Collect all global variables from ALL nodes in the scene
    var global_vars: Array[Dictionary] = []
    var seen_names: Dictionary = {}
    
    if editor_interface:
        var edited_scene = editor_interface.get_edited_scene_root()
        if edited_scene:
            _collect_global_vars_recursive(edited_scene, global_vars, seen_names)
    
    # Step 3: Add global variables to the list
    for global_var in global_vars:
        variables_data.append(global_var)
    
    _refresh_variables_ui()


func get_variables_code() -> String:
    # Generate variable declarations code
    if variables_data.is_empty():
        return ""
    
    var lines: Array[String] = []
    lines.append("# Variables")
    
    for var_data in variables_data:
        var var_name = var_data["name"]
        var var_type = var_data["type"]
        var var_value = var_data["value"]
        var exported = var_data["exported"]
        var is_global = var_data.get("global", false)
        
        if is_global:
            # Global variable: create a property that proxies to the GlobalVars autoload
            lines.append("var %s: %s:" % [var_name, var_type])
            lines.append("\tget: return GlobalVars.%s" % var_name)
            lines.append("\tset(val): GlobalVars.%s = val" % var_name)
        else:
            # Local variable: declare normally
            var declaration = ""
            if exported:
                declaration += "@export "
            declaration += "var %s: %s = %s" % [var_name, var_type, var_value]
            lines.append(declaration)
    
    lines.append("")  # Empty line after variables
    return "\n".join(lines)


## Add a new frame to the graph

## Frame tracking: maps frame names to arrays of node names
var frame_node_mapping: Dictionary = {}  # {"frame_name": ["node1", "node2", ...]}
var frame_titles: Dictionary = {}  # {"frame_name": "Custom Title"}


## Add a new frame to the graph
func _on_add_frame_pressed() -> void:
    if not current_node:
        return
    
    # Get all selected nodes
    var selected_nodes: Array[Node] = []
    for child in graph_edit.get_children():
        if child is GraphNode and child.selected:
            selected_nodes.append(child)
    
    var frame = GraphFrame.new()
    var frame_id = Time.get_ticks_msec()  # Unique ID
    frame.name = "Frame_%d" % frame_id
    frame.resizable = true
    frame.draggable = true
    frame.tint_color_enabled = true
    frame.tint_color = Color(0.3, 0.5, 0.7, 0.5)
    
    # Store title
    frame_titles[frame.name] = "New Frame"
    
    # If nodes are selected, position frame around them
    if selected_nodes.size() > 0:
        _fit_frame_to_nodes(frame, selected_nodes)
        
        # Add selected nodes to frame
        var node_names: Array[String] = []
        for node in selected_nodes:
            node_names.append(node.name)
        frame_node_mapping[frame.name] = node_names
    else:
        # Default position and size
        frame.position_offset = graph_edit.scroll_offset + Vector2(100, 100)
        frame.size = Vector2(400, 300)
        frame_node_mapping[frame.name] = []
    
    # Add interactive UI to frame
    _create_frame_ui(frame)
    
    # Connect signals
    frame.dragged.connect(_on_frame_dragged.bind(frame))
    frame.resize_request.connect(_on_frame_resize_request.bind(frame))
    
    graph_edit.add_child(frame)
    _update_frames_list()
    _save_frames_to_metadata()


## Create interactive UI elements on the frame
func _create_frame_ui(frame: GraphFrame) -> void:
    # Use GraphFrame's built-in title property
    frame.title = frame_titles.get(frame.name, "New Frame")
    
    # Don't connect gui_input as it blocks editor interaction


## Handle frame click to select it in side panel (DISABLED - was blocking editor input)
#func _on_frame_gui_input(event: InputEvent, frame: GraphFrame) -> void:
#    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
#        _select_frame_in_side_panel(frame)



## Fit frame to contain given nodes with padding
func _fit_frame_to_nodes(frame: GraphFrame, nodes: Array[Node]) -> void:
    if nodes.is_empty():
        return
    
    var min_pos = Vector2(INF, INF)
    var max_pos = Vector2(-INF, -INF)
    
    for node in nodes:
        if not node is GraphNode:
            continue
        var node_pos = node.position_offset
        var node_size = node.size
        min_pos.x = min(min_pos.x, node_pos.x)
        min_pos.y = min(min_pos.y, node_pos.y)
        max_pos.x = max(max_pos.x, node_pos.x + node_size.x)
        max_pos.y = max(max_pos.y, node_pos.y + node_size.y)
    
    # Add padding
    var padding = Vector2(40, 60)
    frame.position_offset = min_pos - padding
    frame.size = (max_pos - min_pos) + padding * 2


## Auto-resize frame to fit its nodes
func _auto_resize_frame(frame: GraphFrame) -> void:
    if not frame_node_mapping.has(frame.name):
        return
    
    var nodes_to_fit: Array[Node] = []
    for node_name in frame_node_mapping[frame.name]:
        var node = graph_edit.get_node_or_null(NodePath(node_name))
        if node and node is GraphNode:
            nodes_to_fit.append(node)
    
    if nodes_to_fit.is_empty():
        return
    
    _fit_frame_to_nodes(frame, nodes_to_fit)
    _save_frames_to_metadata()


## Handle brick node being dragged
func _on_brick_node_dragged(from: Vector2, to: Vector2, node: GraphNode) -> void:
    # Check if node entered/left any frames
    _check_node_frame_membership(node)
    
    # Auto-resize frames that contain this node
    for frame_name in frame_node_mapping.keys():
        if node.name in frame_node_mapping[frame_name]:
            var frame = graph_edit.get_node_or_null(NodePath(frame_name))
            if frame and frame is GraphFrame:
                _auto_resize_frame(frame)
    
    # Save node positions
    _save_graph_to_metadata()


func _on_reroute_dragged(from: Vector2, to: Vector2, reroute: GraphNode) -> void:
    # Skip if the reroute already has connections
    var connections = graph_edit.get_connection_list()
    for conn in connections:
        if conn["from_node"] == reroute.name or conn["to_node"] == reroute.name:
            _save_graph_to_metadata()
            return
    
    # Check if the reroute landed on top of an existing connection
    var reroute_center = reroute.position_offset + reroute.size / 2.0
    var best_conn = null
    var best_dist = 40.0  # Max distance in graph units to snap
    
    for conn in connections:
        var from_node = graph_edit.get_node_or_null(NodePath(conn["from_node"]))
        var to_node = graph_edit.get_node_or_null(NodePath(conn["to_node"]))
        if not from_node or not to_node:
            continue
        
        # Get approximate port positions (output port on right side, input port on left side)
        var from_pos = from_node.position_offset + Vector2(from_node.size.x, from_node.size.y / 2.0)
        var to_pos = to_node.position_offset + Vector2(0, to_node.size.y / 2.0)
        
        # Distance from reroute center to the line segment
        var dist = _point_to_segment_distance(reroute_center, from_pos, to_pos)
        if dist < best_dist:
            best_dist = dist
            best_conn = conn
    
    if best_conn:
        # Remove the original connection
        graph_edit.disconnect_node(best_conn["from_node"], best_conn["from_port"], best_conn["to_node"], best_conn["to_port"])
        # Insert reroute: original_from → reroute → original_to
        graph_edit.connect_node(best_conn["from_node"], best_conn["from_port"], reroute.name, 0)
        graph_edit.connect_node(reroute.name, 0, best_conn["to_node"], best_conn["to_port"])
    
    _save_graph_to_metadata()


func _point_to_segment_distance(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
    var ab = seg_b - seg_a
    var ap = point - seg_a
    var ab_len_sq = ab.length_squared()
    if ab_len_sq == 0.0:
        return ap.length()
    var t = clampf(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
    var closest = seg_a + ab * t
    return point.distance_to(closest)


## Handle frame being dragged
func _on_frame_dragged(from: Vector2, to: Vector2, frame: GraphFrame) -> void:
    var delta = to - from
    
    # Move all nodes inside the frame
    if frame_node_mapping.has(frame.name):
        for node_name in frame_node_mapping[frame.name]:
            var node = graph_edit.get_node_or_null(NodePath(node_name))
            if node and node is GraphNode:
                node.position_offset += delta
    
    _save_graph_to_metadata()
    _save_frames_to_metadata()


## Handle frame resize
func _on_frame_resize_request(new_size: Vector2, frame: GraphFrame) -> void:
    frame.size = new_size
    _save_frames_to_metadata()


## Auto-detect nodes entering/leaving frames when nodes are moved
func _check_node_frame_membership(moved_node: GraphNode) -> void:
    if not moved_node:
        return
    
    var node_pos = moved_node.position_offset
    var node_center = node_pos + moved_node.size / 2
    
    # Check all frames
    for child in graph_edit.get_children():
        if not child is GraphFrame:
            continue
        
        var frame = child as GraphFrame
        var current_members = frame_node_mapping.get(frame.name, [])
        var is_member = moved_node.name in current_members
        
        # If node is a member of this frame, auto-resize frame to keep it contained
        if is_member:
            _auto_resize_frame(frame)
            _save_frames_to_metadata()
        else:
            # Not a member - check if we should add it
            var frame_rect = Rect2(frame.position_offset, frame.size)
            var is_inside = frame_rect.has_point(node_center)
            
            if is_inside:
                # Add to frame if center is inside
                current_members.append(moved_node.name)
                frame_node_mapping[frame.name] = current_members
                _auto_resize_frame(frame)
                _save_frames_to_metadata()
                #print("Logic Bricks: Added node '%s' to frame '%s'" % [moved_node.name, frame.name])


## Save frame data to node metadata
func _save_frames_to_metadata() -> void:
    if not current_node:
        return
    
    # Never save to instanced nodes
    if _is_part_of_instance(current_node):
        return
    
    var frames_data = []
    
    for child in graph_edit.get_children():
        if child is GraphFrame:
            frames_data.append({
                "name": child.name,
                "title": frame_titles.get(child.name, "Frame"),
                "position": child.position_offset,
                "size": child.size,
                "color": child.tint_color,
                "nodes": frame_node_mapping.get(child.name, [])
            })
    
    current_node.set_meta("logic_bricks_frames", frames_data)
    
    # Mark the scene as modified so changes are saved
    _mark_scene_modified()


## Load frames from node metadata
func _load_frames_from_metadata() -> void:
    if not current_node:
        return
    
    # Clear existing frames immediately (not queue_free)
    var frames_to_remove = []
    for child in graph_edit.get_children():
        if child is GraphFrame:
            frames_to_remove.append(child)
    for frame in frames_to_remove:
        graph_edit.remove_child(frame)
        frame.free()
    
    frame_node_mapping.clear()
    frame_titles.clear()
    
    # Load saved frames
    if current_node.has_meta("logic_bricks_frames"):
        var frames_data = current_node.get_meta("logic_bricks_frames")
        
        for frame_data in frames_data:
            var frame = GraphFrame.new()
            frame.name = frame_data.get("name", "Frame")
            frame.position_offset = frame_data.get("position", Vector2.ZERO)
            frame.size = frame_data.get("size", Vector2(400, 300))
            frame.tint_color = frame_data.get("color", Color(0.3, 0.5, 0.7, 0.5))
            frame.tint_color_enabled = true
            frame.resizable = true
            frame.draggable = true
            
            # Store title and node mapping
            frame_titles[frame.name] = frame_data.get("title", "Frame")
            frame_node_mapping[frame.name] = frame_data.get("nodes", [])
            
            # Create interactive UI
            _create_frame_ui(frame)
            
            # Connect signals
            frame.dragged.connect(_on_frame_dragged.bind(frame))
            frame.resize_request.connect(_on_frame_resize_request.bind(frame))
            
            graph_edit.add_child(frame)
    
    # Update frames list
    _update_frames_list()


## Frame Panel Callbacks

func _on_frame_list_item_selected(index: int) -> void:
    # Handle frame selection from the list
    var frame_name = frames_list.get_item_metadata(index)
    selected_frame = graph_edit.get_node_or_null(NodePath(frame_name))
    
    if selected_frame:
        _update_frame_settings_ui()
        frame_settings_container.visible = true
        
        # Update the color wheel button in the list
        var color_wheel = frames_panel.find_child("FrameListColorPicker", true, false)
        if color_wheel:
            color_wheel.color = selected_frame.tint_color
    else:
        frame_settings_container.visible = false


func _update_frame_settings_ui() -> void:
    # Update the frame settings UI with the selected frame's values
    if not selected_frame:
        return
    
    var name_edit = frame_settings_container.find_child("FrameNameEdit", true, false)
    var color_picker = frame_settings_container.find_child("FrameColorPicker", true, false)
    var width_spin = frame_settings_container.find_child("FrameWidthSpin", true, false)
    var height_spin = frame_settings_container.find_child("FrameHeightSpin", true, false)
    
    if name_edit:
        name_edit.text = frame_titles.get(selected_frame.name, selected_frame.name)
    
    if color_picker:
        color_picker.color = selected_frame.tint_color
    
    if width_spin:
        width_spin.value = selected_frame.size.x
    
    if height_spin:
        height_spin.value = selected_frame.size.y


func _on_frame_name_changed(new_name: String) -> void:
    # Handle frame name change from settings panel
    if not selected_frame:
        return
    
    frame_titles[selected_frame.name] = new_name
    
    # Update the frame's built-in title
    selected_frame.title = new_name
    
    _update_frames_list()
    _save_frames_to_metadata()


func _on_frame_color_changed(new_color: Color) -> void:
    # Handle frame color change from settings panel
    if not selected_frame:
        return
    
    selected_frame.tint_color = new_color
    selected_frame.tint_color_enabled = true
    selected_frame.queue_redraw()
    
    # Sync the list color picker
    var color_wheel = frames_panel.find_child("FrameListColorPicker", true, false)
    if color_wheel:
        color_wheel.color = new_color
    
    _save_frames_to_metadata()


func _on_frame_resize_pressed() -> void:
    # Handle auto-resize button press
    if selected_frame:
        _auto_resize_frame(selected_frame)


func _on_frame_width_changed(new_width: float) -> void:
    # Handle manual width change
    if selected_frame:
        selected_frame.size.x = new_width
        _save_frames_to_metadata()


func _on_frame_height_changed(new_height: float) -> void:
    # Handle manual height change
    if selected_frame:
        selected_frame.size.y = new_height
        _save_frames_to_metadata()


func _on_frame_delete_pressed() -> void:
    # Handle delete frame button press
    if not selected_frame:
        return
    
    frame_node_mapping.erase(selected_frame.name)
    frame_titles.erase(selected_frame.name)
    selected_frame.queue_free()
    selected_frame = null
    
    frame_settings_container.visible = false
    _update_frames_list()
    _save_frames_to_metadata()


func _update_frames_list() -> void:
    # Update the frames list in the side panel
    frames_list.clear()
    
    for child in graph_edit.get_children():
        if child is GraphFrame and not child.is_queued_for_deletion():
            var display_name = frame_titles.get(child.name, child.name)
            frames_list.add_item(display_name)
            frames_list.set_item_metadata(frames_list.get_item_count() - 1, child.name)


func _select_frame_in_side_panel(frame: GraphFrame) -> void:
    # Select a frame in the side panel list
    if not frame:
        return
    
    # Switch to Frames tab
    side_panel.current_tab = 1  # Frames is tab index 1
    
    # Find and select the frame in the list
    for i in range(frames_list.get_item_count()):
        if frames_list.get_item_metadata(i) == frame.name:
            frames_list.select(i)
            _on_frame_list_item_selected(i)
            break


func _on_frame_list_item_activated(index: int) -> void:
    # Handle double-click on frame list item to rename
    _on_frame_rename_button_pressed()


func _on_frame_rename_button_pressed() -> void:
    # Show inline rename dialog for selected frame
    if not selected_frame:
        return
    
    var selected_index = -1
    for i in range(frames_list.get_item_count()):
        if frames_list.is_selected(i):
            selected_index = i
            break
    
    if selected_index < 0:
        return
    
    # Create a popup dialog for renaming
    var dialog = AcceptDialog.new()
    dialog.title = "Rename Frame"
    dialog.dialog_autowrap = true
    
    var vbox = VBoxContainer.new()
    dialog.add_child(vbox)
    
    var label = Label.new()
    label.text = "New frame name:"
    vbox.add_child(label)
    
    var line_edit = LineEdit.new()
    line_edit.text = frame_titles.get(selected_frame.name, selected_frame.name)
    line_edit.custom_minimum_size = Vector2(200, 0)
    line_edit.select_all()
    vbox.add_child(line_edit)
    
    # Handle confirm
    dialog.confirmed.connect(_on_rename_dialog_confirmed.bind(dialog, line_edit))
    
    # Handle cancel/close
    dialog.canceled.connect(_on_rename_dialog_canceled.bind(dialog))
    
    add_child(dialog)
    dialog.popup_centered()
    line_edit.grab_focus()


func _on_rename_dialog_confirmed(dialog: AcceptDialog, line_edit: LineEdit) -> void:
    # Handle the rename confirmation
    var new_name = line_edit.text.strip_edges()
    if not new_name.is_empty():
        frame_titles[selected_frame.name] = new_name
        
        # Update the frame's built-in title
        selected_frame.title = new_name
        
        # Update frame settings if visible
        var name_edit = frame_settings_container.get_node_or_null("FrameNameEdit")
        if name_edit:
            name_edit.text = new_name
        
        _update_frames_list()
        _save_frames_to_metadata()
    dialog.queue_free()


func _on_rename_dialog_canceled(dialog: AcceptDialog) -> void:
    # Handle dialog cancellation
    dialog.queue_free()


func _on_frame_list_color_changed(new_color: Color) -> void:
    # Handle color change from the list color wheel button
    if not selected_frame:
        return
    
    selected_frame.tint_color = new_color
    selected_frame.tint_color_enabled = true
    selected_frame.queue_redraw()
    
    # Update the color picker in frame settings if visible
    var settings_color_picker = frame_settings_container.find_child("FrameColorPicker", true, false)
    if settings_color_picker:
        settings_color_picker.color = new_color
    
    _save_frames_to_metadata()


## Mark the scene as modified so changes are saved
func _mark_scene_modified() -> void:
    if not editor_interface:
        return
    
    # Mark the currently edited scene as unsaved
    # This is the correct way to tell Godot the scene needs saving
    editor_interface.mark_scene_as_unsaved()
