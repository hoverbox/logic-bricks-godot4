@tool
extends VBoxContainer

## Main panel UI for the Logic Bricks plugin (bottom panel)
## Visual node graph editor for connecting logic bricks

const BrickGraphNode = preload("res://addons/logic_bricks/ui/brick_graph_node.gd")

var manager = null
var editor_interface = null
var plugin = null  # Reference to the EditorPlugin (for autoload registration)
var current_node: Node = null
var _clipboard_graph: Dictionary = {}  # Stored graph data for copy/paste (whole node)
var _clipboard_vars: Array = []  # Stored variables for copy/paste (whole node)
var _selection_clipboard: Dictionary = {}  # Selected bricks only — survives node switching
var is_locked: bool = false  # Lock to prevent losing current_node on selection change
var _instance_override: bool = false  # Allow editing instanced nodes when true
var _instance_panel: PanelContainer = null  # The instance warning/choice panel

var node_info_label: Label
var lock_button: Button
var _copy_button: Button
var _paste_button: Button
var _popout_button: Button         # Toggles floating window
var _popout_window: Window = null  # The detached floating window (null when docked)
var _main_hsplit: HSplitContainer  # The bottom-panel hsplit (kept as member for re-docking)
var _toolbar_separator: HSeparator  # Separator above the toolbar (moved with toolbar)
var _toolbar: HBoxContainer         # Bottom toolbar with Add Frame / Apply Code (moved on popout)
var _instructions_label: Label      # "Select a node" label (moved with graph area)
var graph_edit: GraphEdit
var add_menu: PopupMenu
var sensors_menu: PopupMenu
var controllers_menu: PopupMenu
var actuators_menu: PopupMenu
var actuator_submenus: Dictionary = {}  # name -> PopupMenu, for sub-submenu ID lookup
var next_node_id: int = 0
var last_mouse_position: Vector2 = Vector2.ZERO

# Side panel (tabbed: Variables, Frames)
var side_panel: TabContainer
var variables_panel: VBoxContainer
var variables_list: VBoxContainer
var variables_data: Array[Dictionary] = []  # Local variables for this node
var global_vars_data: Array[Dictionary] = []  # Global variables (scene-wide, stored on scene root)
var global_vars_panel: VBoxContainer  # Tab panel for global variables
var global_vars_list: VBoxContainer  # UI container for the globals section
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
    _copy_button.tooltip_text = "Copy selected bricks (Ctrl+C)\nIf nothing is selected, copies the entire node setup."
    _copy_button.pressed.connect(_on_copy_bricks_pressed)
    header_hbox.add_child(_copy_button)
    
    _paste_button = Button.new()
    _paste_button.text = "P"
    _paste_button.tooltip_text = "Paste copied bricks into this node (Ctrl+V)\nIf bricks were copied, pastes those. Otherwise pastes the whole node setup."
    _paste_button.pressed.connect(_on_paste_bricks_pressed)
    header_hbox.add_child(_paste_button)
    
    _popout_button = Button.new()
    _popout_button.text = "⧉"
    _popout_button.tooltip_text = "Pop out into a floating window (useful for 2nd screen)"
    _popout_button.pressed.connect(_on_popout_pressed)
    header_hbox.add_child(_popout_button)
    
    # Separator
    var separator1 = HSeparator.new()
    add_child(separator1)
    
    # Create horizontal split: graph on left, variables on right
    _main_hsplit = HSplitContainer.new()
    _main_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _main_hsplit.split_offset = -300  # Variables panel takes 300px from the right
    add_child(_main_hsplit)
    
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
    _main_hsplit.add_child(graph_edit)
    
    # Side Panel (RIGHT SIDE) - Tabbed: Variables, Globals, Frames
    _create_side_panel()
    _main_hsplit.add_child(side_panel)
    
    # Create add node menu
    _create_add_menu()
    
    # Instructions label (shown when graph is hidden)
    _instructions_label = Label.new()
    _instructions_label.name = "InstructionsLabel"
    _instructions_label.text = "👆 Select a 3D node in your scene tree to start creating logic bricks"
    _instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _instructions_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _instructions_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _instructions_label.add_theme_font_size_override("font_size", 16)
    add_child(_instructions_label)
    
    # Toolbar
    _toolbar_separator = HSeparator.new()
    add_child(_toolbar_separator)
    
    _toolbar = HBoxContainer.new()
    add_child(_toolbar)
    
    var help_label = Label.new()
    help_label.text = "  Right-click: Add nodes | Drag nodes: Move | Middle-click drag: Pan | Scroll: Zoom | Select + Delete: Remove"
    help_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _toolbar.add_child(help_label)
    
    var add_frame_button = Button.new()
    add_frame_button.text = "Add Frame"
    add_frame_button.pressed.connect(_on_add_frame_pressed)
    _toolbar.add_child(add_frame_button)
    
    var apply_code_button = Button.new()
    apply_code_button.text = "Apply Code"
    apply_code_button.pressed.connect(_on_apply_code_pressed)
    _toolbar.add_child(apply_code_button)


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
    sensors_menu.add_item("Actuator", 112)
    sensors_menu.set_item_metadata(0, {"type": "sensor", "class": "ActuatorSensor"})
    sensors_menu.set_item_tooltip(0, "Fires TRUE when a named actuator on this node is running.\nThe actuator must have an instance name set.")
    
    sensors_menu.add_item("Always", 100)
    sensors_menu.set_item_metadata(1, {"type": "sensor", "class": "AlwaysSensor"})
    sensors_menu.set_item_tooltip(1, "Always active. Fires every frame.\nUse for continuous actions like gravity or idle animations.")
    
    sensors_menu.add_item("Animation Tree", 101)
    sensors_menu.set_item_metadata(2, {"type": "sensor", "class": "AnimationTreeSensor"})
    sensors_menu.set_item_tooltip(2, "Detects animation tree state changes and conditions.")
    
    sensors_menu.add_item("Collision", 102)
    sensors_menu.set_item_metadata(3, {"type": "sensor", "class": "CollisionSensor"})
    sensors_menu.set_item_tooltip(3, "Detects collisions using an Area3D node.\nRequires an Area3D child or reference.\n⚠ Adds @export in Inspector — assign your Area3D.")
    
    sensors_menu.add_item("Compare Variable", 103)
    sensors_menu.set_item_metadata(4, {"type": "sensor", "class": "VariableSensor"})
    sensors_menu.set_item_tooltip(4, "Compares a logic brick variable against a value.\nTriggers when the comparison is true.")
    
    sensors_menu.add_item("Delay", 104)
    sensors_menu.set_item_metadata(5, {"type": "sensor", "class": "DelaySensor"})
    sensors_menu.set_item_tooltip(5, "Adds a delay before activating.\nStays active for a set duration, can repeat.")
    
    sensors_menu.add_item("InputMap", 105)
    sensors_menu.set_item_metadata(6, {"type": "sensor", "class": "InputMapSensor"})
    sensors_menu.set_item_tooltip(6, "Detects input actions from Project > Input Map.\nWorks with keyboard, gamepad, etc.")
    
    sensors_menu.add_item("Message", 106)
    sensors_menu.set_item_metadata(7, {"type": "sensor", "class": "MessageSensor"})
    sensors_menu.set_item_tooltip(7, "Listens for messages sent by a Message Actuator.\nFilters by subject.")
    
    sensors_menu.add_item("Mouse", 107)
    sensors_menu.set_item_metadata(8, {"type": "sensor", "class": "MouseSensor"})
    sensors_menu.set_item_tooltip(8, "Detects mouse button presses and releases.")
    
    sensors_menu.add_item("Movement", 108)
    sensors_menu.set_item_metadata(9, {"type": "sensor", "class": "MovementSensor"})
    sensors_menu.set_item_tooltip(9, "Detects if the node is moving or stationary.")
    
    sensors_menu.add_item("Proximity", 109)
    sensors_menu.set_item_metadata(10, {"type": "sensor", "class": "ProximitySensor"})
    sensors_menu.set_item_tooltip(10, "Detects nodes within a certain distance.\nChecks against nodes in a specified group.")
    
    sensors_menu.add_item("Random", 110)
    sensors_menu.set_item_metadata(11, {"type": "sensor", "class": "RandomSensor"})
    sensors_menu.set_item_tooltip(11, "Activates randomly based on a probability.\nUseful for random behaviors or AI variation.")
    
    sensors_menu.add_item("Raycast", 111)
    sensors_menu.set_item_metadata(12, {"type": "sensor", "class": "RaycastSensor"})
    sensors_menu.set_item_tooltip(12, "Casts a ray to detect objects in a direction.\nUseful for line-of-sight or ground detection.")
    
    
    # Populate Controllers submenu
    controllers_menu.add_item("Controller", 200)
    controllers_menu.set_item_metadata(0, {"type": "controller", "class": "Controller"})
    controllers_menu.set_item_tooltip(0, "Logic gate that combines sensor inputs.\nAND, OR, NAND, NOR, XOR modes.")
    
    # Populate Actuators submenu — grouped into categories
    var _actuator_groups = [
        {
            "label": "Animation",
            "items": [
                ["Animation", 300, "AnimationActuator", "Play, stop, pause, queue, ping-pong, or flipper animations.\nAutomatically finds the AnimationPlayer that owns the animation.\n⚠ No @export needed — AnimationPlayer is found automatically."],
                ["Animation Tree", 301, "AnimationTreeActuator", "Controls AnimationTree: travel states, set parameters/conditions.\n⚠ Adds @export in Inspector — assign your AnimationTree."],
            ]
        },
        {
            "label": "Movement",
            "items": [
                ["Motion", 309, "MotionActuator", "Move or rotate a node.\\nCharacter Velocity, Translate, or Position modes."],
                ["Character", 303, "CharacterActuator", "All-in-one: gravity, jumping, and ground detection."],
                ["Look At Movement", 306, "LookAtMovementActuator", "Rotates a node to face the direction of movement.\n⚠ Adds @export in Inspector — assign the mesh/Node3D to rotate."],
                ["Rotate Towards", 342, "RotateTowardsActuator", "Rotates to face a target node found by name or group.\nUseful for turrets and enemies tracking the player."],
                ["Waypoint Path", 343, "WaypointPathActuator", "Moves a node through a series of waypoints placed in the 3D viewport.\nDrag the handles to position each point. Supports Loop, Ping Pong, and Once."],
                ["Move Towards", 311, "MoveTowardsActuator", "Seek, flee, or path-follow toward a target node.\n⚠ Path Follow adds @export in Inspector — assign your NavigationAgent3D."],
                ["Teleport", 320, "TeleportActuator", "Instantly move to a target node or coordinates.\n⚠ Target Node mode adds @export in Inspector — assign the destination."],
                ["Mouse", 310, "MouseActuator", "Mouse-based camera rotation with sensitivity and clamping."],
            ]
        },
        {
            "label": "Physics",
            "items": [
                ["Physics", 313, "PhysicsActuator", "Modify physics properties: gravity scale, mass, friction."],
                ["Force", 339, "ForceActuator", "Apply a continuous force to a RigidBody3D.\nUse for gravity-like effects or constant pushes."],
                ["Torque", 340, "TorqueActuator", "Apply a rotational force to a RigidBody3D.\nUse for spinning or angular acceleration."],
                ["Linear Velocity", 341, "LinearVelocityActuator", "Set, add, or average the linear velocity of a RigidBody3D."],
                ["Impulse", 329, "ImpulseActuator", "Apply a one-shot impulse to a RigidBody3D."],
                ["Collision", 322, "CollisionActuator", "Modify collision properties: enable/disable shapes, layers, masks."],
            ]
        },
        {
            "label": "Object",
            "items": [
                ["Edit Object", 304, "EditObjectActuator", "Add, remove, or replace objects in the scene at runtime."],
                ["Object Pool", 330, "ObjectPoolActuator", "Spawn/recycle objects from a pre-allocated pool for better performance."],
                ["Parent", 312, "ParentActuator", "Change the node's parent in the scene tree."],
                ["Property", 314, "PropertyActuator", "Set any property on a target node (visible, modulate, etc).\n⚠ Adds @export in Inspector — assign the target node."],
                ["Visibility", 328, "VisibilityActuator", "Show, hide, or toggle visibility of this node or an assigned node.\nWorks with Node3D, Control, Sprite2D, and any node with a visible property."],
            ]
        },
        {
            "label": "Environment",
            "items": [
                ["Environment", 323, "EnvironmentActuator", "Modify WorldEnvironment properties at runtime: fog, glow, SSAO, tone mapping, color correction."],
                ["Light", 337, "LightActuator", "Control OmniLight3D, SpotLight3D, or DirectionalLight3D properties.\nSupports FX presets: Flicker, Strobe, Pulse, Fade In/Out."],
            ]
        },
        {
            "label": "Camera",
            "items": [
                ["Set Camera", 302, "SetCameraActuator", "Makes the assigned Camera3D the active camera for the viewport.\n⚠ Adds @export in Inspector — assign your Camera3D."],
                ["Smooth Follow Camera", 345, "SmoothFollowCameraActuator", "Camera smoothly follows this node, maintaining its initial offset.\nSupports per-axis position/rotation follow, dead zones, and independent speeds.\n⚠ Adds @export in Inspector — assign your Camera3D."],
                ["Camera Zoom", 332, "CameraZoomActuator", "Change camera FOV (3D) or zoom (2D) with optional lerp.\n⚠ Adds @export in Inspector — assign your camera."],
                ["Screen Shake", 333, "ScreenShakeActuator", "Trauma-based camera shake. Attach to your Camera3D node."],
                ["3rd Person Camera", 338, "ThirdPersonCameraActuator", "Mouse and/or joystick orbit camera for third-person games.\nAssign a SpringArm3D or pivot node as the camera mount."],
                ["Split Screen", 344, "SplitScreenActuator", "Positions SubViewportContainers for 2-4 player split screen.\n⚠ Adds @export slots in Inspector — assign your SubViewportContainers."],
            ]
        },
        {
            "label": "Audio",
            "items": [
                ["Audio 3D", 318, "SoundActuator", "Play 3D audio with random pitch, buses, and play modes.\n⚠ Adds @export in Inspector — assign your AudioStreamPlayer3D."],
                ["Audio 2D", 324, "Audio2DActuator", "Control an AudioStreamPlayer or AudioStreamPlayer2D.\n⚠ Adds @export in Inspector — assign your audio node."],
                ["Music", 334, "MusicActuator", "Control background music with crossfade support.\n⚠ Adds @export in Inspector — assign AudioStreamPlayer node(s)."],
            ]
        },
        {
            "label": "Game Feel",
            "items": [
                ["Screen Flash", 335, "ScreenFlashActuator", "Flash a color over the screen.\n⚠ Adds @export in Inspector — assign a full-screen ColorRect."],
                ["Rumble", 336, "RumbleActuator", "Trigger controller haptic vibration."],
            ]
        },
        {
            "label": "UI",
            "items": [
                ["Text", 321, "TextActuator", "Display text or variable values on a UI Label.\n⚠ Adds @export in Inspector — assign your text node."],
                ["Modulate", 325, "ModulateActuator", "Set or smoothly transition the color/alpha of this node.\nUseful for fades, flashes, and tints."],
                ["Progress Bar", 326, "ProgressBarActuator", "Set the value, min, or max of a ProgressBar, HSlider, or VSlider.\n⚠ Adds @export in Inspector — assign your Range node."],
                ["Tween", 327, "TweenActuator", "Animate any property on a node using Godot's Tween system."],
            ]
        },
        {
            "label": "Logic",
            "items": [
                ["State", 319, "StateActuator", "Change the logic brick state (1-30)."],
                ["Random", 315, "RandomActuator", "Set a variable to a random value within a range."],
                ["Message", 307, "MessageActuator", "Sends a message to all nodes in a target group."],
                ["Modify Variable", 308, "VariableActuator", "Modify a logic brick variable (assign, add, subtract, etc)."],
            ]
        },
        {
            "label": "Game",
            "items": [
                ["Game", 305, "GameActuator", "Game-level actions: quit, restart, screenshot."],
                ["Scene", 317, "SceneActuator", "Change or reload scenes."],
                ["Save / Load", 316, "SaveLoadActuator", "Save/load game state to a file.\nThis Node: saves the node the brick is on.\nTarget Node: saves a specific node by name.\nGroup: saves every node in a named group automatically."],
            ]
        },
    ]
    
    for group in _actuator_groups:
        var group_label: String = group["label"]
        var group_items: Array = group["items"]
        
        # Single-item groups go directly into the actuators menu, no submenu needed
        if group_items.size() == 1:
            var item = group_items[0]
            actuators_menu.add_item(item[0], item[1])
            var idx = actuators_menu.get_item_index(item[1])
            actuators_menu.set_item_metadata(idx, {"type": "actuator", "class": item[2]})
            actuators_menu.set_item_tooltip(idx, item[3])
        else:
            # Create a submenu for this group
            var submenu = PopupMenu.new()
            var submenu_name = "ActuatorSub_" + group_label.replace(" ", "_")
            submenu.name = submenu_name
            actuators_menu.add_child(submenu)
            submenu.id_pressed.connect(_on_add_menu_item_selected)
            actuator_submenus[submenu_name] = submenu
            
            for item in group_items:
                submenu.add_item(item[0], item[1])
                var idx = submenu.get_item_index(item[1])
                submenu.set_item_metadata(idx, {"type": "actuator", "class": item[2]})
                submenu.set_item_tooltip(idx, item[3])
            
            actuators_menu.add_submenu_item(group_label, submenu_name)


func _create_side_panel() -> void:
    # Create the tabbed side panel with Variables, Global Variables, and Frames tabs
    side_panel = TabContainer.new()
    side_panel.custom_minimum_size = Vector2(300, 0)
    side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    side_panel.visible = false  # Hidden until node selected
    
    # Variables Tab (local, per-node)
    _create_variables_tab()
    side_panel.add_child(variables_panel)
    
    # Global Variables Tab (scene-wide)
    _create_global_variables_tab()
    side_panel.add_child(global_vars_panel)
    
    # Frames Tab
    _create_frames_tab()
    side_panel.add_child(frames_panel)


func _create_variables_tab() -> void:
    # Create the variables management tab
    variables_panel = VBoxContainer.new()
    variables_panel.name = "Variables"
    variables_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    
    # ── Local Variables header ──
    var header = HBoxContainer.new()
    variables_panel.add_child(header)
    
    var title = Label.new()
    title.text = "Node Variables"
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
    
    var sep = HSeparator.new()
    variables_panel.add_child(sep)
    
    # Scrollable list of local variables
    var scroll = ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    variables_panel.add_child(scroll)
    
    variables_list = VBoxContainer.new()
    variables_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(variables_list)


func _create_global_variables_tab() -> void:
    # Create the global variables management tab (scene-wide, stored on scene root)
    global_vars_panel = VBoxContainer.new()
    global_vars_panel.name = "Globals"
    global_vars_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    
    var header = HBoxContainer.new()
    global_vars_panel.add_child(header)
    
    var title = Label.new()
    title.text = "Global Variables"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var title_font = title.get_theme_font("bold", "EditorFonts")
    if title_font:
        title.add_theme_font_override("font", title_font)
    header.add_child(title)
    
    var add_global_button = Button.new()
    add_global_button.text = "+ Add"
    add_global_button.pressed.connect(_on_add_global_variable_pressed)
    header.add_child(add_global_button)
    
    var sep = HSeparator.new()
    global_vars_panel.add_child(sep)
    
    var hint = Label.new()
    hint.text = "Shared across all nodes in the scene"
    hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    hint.add_theme_font_size_override("font_size", 10)
    global_vars_panel.add_child(hint)
    
    var global_scroll = ScrollContainer.new()
    global_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    global_vars_panel.add_child(global_scroll)
    
    global_vars_list = VBoxContainer.new()
    global_vars_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    global_scroll.add_child(global_vars_list)


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
    
    # Reset instance override when switching nodes
    _instance_override = false
    _hide_instance_panel()
    
    # Save current state before switching (but NOT if current node is an instance)
    if current_node and not _is_part_of_instance(current_node):
        _save_graph_to_metadata()
        _save_frames_to_metadata()
    
    current_node = node
    _update_ui()


func _update_ui() -> void:
    if not current_node:
        node_info_label.text = "No node selected - Select a 3D node in the scene tree"
        graph_edit.visible = false
        side_panel.visible = false
        if _instructions_label:
            _instructions_label.visible = true
        return
    
    # Check if node is supported
    if not _is_supported_node(current_node):
        node_info_label.text = "Unsupported node type: %s - Use Node3D, CharacterBody3D, or RigidBody3D" % current_node.get_class()
        graph_edit.visible = false
        side_panel.visible = false
        if _instructions_label:
            _instructions_label.visible = true
        return
    
    # Check if node is part of an instanced scene
    if _is_part_of_instance(current_node) and not _instance_override:
        node_info_label.text = "⚠ Instanced Node: %s" % current_node.name
        node_info_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
        graph_edit.visible = false
        side_panel.visible = false
        if _instructions_label:
            _instructions_label.visible = false
        _show_instance_panel()
        return
    
    # Hide instance panel if showing
    _hide_instance_panel()
    
    # Reset label color to normal
    node_info_label.remove_theme_color_override("font_color")
    
    # Update header
    node_info_label.text = "✓ Node: %s (%s) - Right-click to add bricks" % [current_node.name, current_node.get_class()]
    graph_edit.visible = true
    side_panel.visible = true
    if _instructions_label:
        _instructions_label.visible = false
    
    # Load graph, frames, and variables from metadata
    await _load_graph_from_metadata()
    _load_frames_from_metadata()
    _load_variables_from_metadata()


func _is_supported_node(node: Node) -> bool:
    return node is Node3D or node is CharacterBody3D or node is RigidBody3D



## ── Pop-out / dock ────────────────────────────────────────────────────────────

func _on_popout_pressed() -> void:
    if _popout_window:
        _dock_window()
    else:
        _popout_window_open()


func _popout_window_open() -> void:
    # Create the floating window
    _popout_window = Window.new()
    _popout_window.title = "Logic Bricks"
    _popout_window.size = Vector2i(1280, 720)
    _popout_window.wrap_controls = true
    _popout_window.min_size = Vector2i(640, 400)
    _popout_window.close_requested.connect(_dock_window)
    
    # Root container inside the window (mirrors the bottom panel VBox structure)
    var win_root = VBoxContainer.new()
    win_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _popout_window.add_child(win_root)
    
    # Move instructions label into the window root
    remove_child(_instructions_label)
    win_root.add_child(_instructions_label)
    
    # Re-create the hsplit inside the window
    var win_hsplit = HSplitContainer.new()
    win_hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
    win_hsplit.split_offset = _main_hsplit.split_offset
    win_root.add_child(win_hsplit)
    
    # Move graph_edit and side_panel into the window hsplit
    _main_hsplit.remove_child(graph_edit)
    _main_hsplit.remove_child(side_panel)
    win_hsplit.add_child(graph_edit)
    win_hsplit.add_child(side_panel)
    
    # Move toolbar separator and toolbar into the window root
    remove_child(_toolbar_separator)
    remove_child(_toolbar)
    win_root.add_child(_toolbar_separator)
    win_root.add_child(_toolbar)
    
    # Re-parent add_menu into the floating window so right-click popups
    # appear on the correct monitor (popups always follow their owner window)
    remove_child(add_menu)
    _popout_window.add_child(add_menu)
    
    # Hide the now-empty bottom panel hsplit
    _main_hsplit.visible = false
    
    # Update button
    _popout_button.text = "⬅"
    _popout_button.tooltip_text = "Dock back into the bottom panel"
    
    # Add the window to the editor
    get_tree().root.add_child(_popout_window)
    _popout_window.popup_centered()


func _dock_window() -> void:
    if not _popout_window:
        return
    
    # Retrieve the window's hsplit so we can restore split_offset
    var win_root = _popout_window.get_child(0) if _popout_window.get_child_count() > 0 else null
    var win_hsplit: HSplitContainer = null
    if win_root:
        for child in win_root.get_children():
            if child is HSplitContainer:
                win_hsplit = child
                break
    
    # Restore split offset from window if available
    if win_hsplit:
        _main_hsplit.split_offset = win_hsplit.split_offset
        win_hsplit.remove_child(graph_edit)
        win_hsplit.remove_child(side_panel)
    
    # Move instructions label back
    if win_root:
        win_root.remove_child(_instructions_label)
    add_child(_instructions_label)
    move_child(_instructions_label, get_child_count() - 1)
    
    # Re-parent back into the bottom panel hsplit
    _main_hsplit.add_child(graph_edit)
    _main_hsplit.add_child(side_panel)
    _main_hsplit.visible = true
    
    # Move toolbar separator and toolbar back
    if win_root:
        win_root.remove_child(_toolbar_separator)
        win_root.remove_child(_toolbar)
    add_child(_toolbar_separator)
    add_child(_toolbar)
    
    # Move add_menu back to the main panel
    _popout_window.remove_child(add_menu)
    add_child(add_menu)
    
    # Close and free the window
    _popout_window.close_requested.disconnect(_dock_window)
    _popout_window.queue_free()
    _popout_window = null
    
    # Restore button
    _popout_button.text = "⧉"
    _popout_button.tooltip_text = "Pop out into a floating window (useful for 2nd screen)"


func _show_instance_panel() -> void:
    if _instance_panel:
        _instance_panel.visible = true
        return
    
    # Build the panel
    _instance_panel = PanelContainer.new()
    _instance_panel.name = "InstancePanel"
    _instance_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    _instance_panel.add_child(vbox)
    
    # Warning icon + title
    var title = Label.new()
    title.text = "⚠  Instanced Scene"
    title.add_theme_font_size_override("font_size", 15)
    title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vbox.add_child(title)
    
    # Description
    var desc = Label.new()
    desc.text = "This node belongs to an instanced scene.\nChanges made here will only affect this instance.\nTo change all instances, edit the original scene."
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
    vbox.add_child(desc)
    
    var sep = HSeparator.new()
    vbox.add_child(sep)
    
    # Buttons
    var btn_box = HBoxContainer.new()
    btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
    btn_box.add_theme_constant_override("separation", 12)
    vbox.add_child(btn_box)
    
    var open_btn = Button.new()
    open_btn.text = "📂  Open Original Scene"
    open_btn.tooltip_text = "Open the original scene file for this instance"
    open_btn.pressed.connect(_on_open_original_pressed)
    btn_box.add_child(open_btn)
    
    var override_btn = Button.new()
    override_btn.text = "✏  Edit This Instance"
    override_btn.tooltip_text = "Add Logic Bricks to this instance only.\nWarning: these bricks will not appear in the original scene."
    override_btn.pressed.connect(_on_edit_instance_pressed)
    btn_box.add_child(override_btn)
    
    # Insert above the graph_edit in the layout
    var parent = graph_edit.get_parent()
    var graph_index = graph_edit.get_index()
    parent.add_child(_instance_panel)
    parent.move_child(_instance_panel, graph_index)


func _hide_instance_panel() -> void:
    if _instance_panel:
        _instance_panel.visible = false


func _on_open_original_pressed() -> void:
    if not current_node or not editor_interface:
        return
    # Walk up to find the instanced scene root
    var target = current_node
    var edited_root = editor_interface.get_edited_scene_root()
    while target:
        if target.scene_file_path != "" and target != edited_root:
            editor_interface.open_scene_from_path(target.scene_file_path)
            return
        target = target.get_parent()


func _on_edit_instance_pressed() -> void:
    _instance_override = true
    _hide_instance_panel()
    _update_ui()


func _is_part_of_instance(node: Node) -> bool:
    # Check if the node is part of an instanced scene (not the root scene)
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


## Take a deep copy of the current graph metadata for undo/redo snapshots
func _take_graph_snapshot() -> Dictionary:
    if not current_node or not current_node.has_meta("logic_bricks_graph"):
        return {}
    return current_node.get_meta("logic_bricks_graph").duplicate(true)


## Restore a graph snapshot: write it back to metadata and rebuild the visual graph.
## The metadata write is synchronous; the visual rebuild is deferred one frame.
func _restore_graph_snapshot(snapshot: Dictionary) -> void:
    if not current_node:
        return
    if snapshot.is_empty():
        if current_node.has_meta("logic_bricks_graph"):
            current_node.remove_meta("logic_bricks_graph")
    else:
        current_node.set_meta("logic_bricks_graph", snapshot.duplicate(true))
    _mark_scene_modified()
    # Defer the visual rebuild so the undo manager call returns cleanly
    _reload_graph_deferred.call_deferred()


## Called deferred after a snapshot restore so the visual graph rebuilds cleanly
func _reload_graph_deferred() -> void:
    await _load_graph_from_metadata()


## Record an undoable graph action.
## Call BEFORE making changes (before_snapshot) and AFTER (after_snapshot).
func _record_undo(action_name: String, before_snapshot: Dictionary, after_snapshot: Dictionary) -> void:
    if not plugin:
        return
    var ur = plugin.get_undo_redo()
    ur.create_action(action_name)
    ur.add_do_method(self, "_restore_graph_snapshot", after_snapshot)
    ur.add_undo_method(self, "_restore_graph_snapshot", before_snapshot)
    ur.commit_action(false)  # false = don't execute do_method immediately (we already applied it)


func _save_graph_to_metadata() -> void:
    if not current_node:
        return
    
    # Never save to instanced nodes (unless user explicitly chose to edit the instance)
    if _is_part_of_instance(current_node) and not _instance_override:
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
        # Actuators — check direct items first, then sub-submenus
        var item_index = actuators_menu.get_item_index(id)
        if item_index >= 0:
            metadata = actuators_menu.get_item_metadata(item_index)
        else:
            for submenu in actuator_submenus.values():
                var sub_index = submenu.get_item_index(id)
                if sub_index >= 0:
                    metadata = submenu.get_item_metadata(sub_index)
                    break
    
    if metadata:
        var brick_type = metadata["type"]
        var brick_class = metadata["class"]
        var before_snapshot = _take_graph_snapshot()
        _create_graph_node(brick_type, brick_class, last_mouse_position)
        _record_undo("Add Logic Brick", before_snapshot, _take_graph_snapshot())


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
    graph_node.title = brick_instance.get_brick_name()
    
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
        _update_controller_title(graph_node, brick_instance)
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


func _create_graph_node_from_data(node_data: Dictionary) -> GraphNode:
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
        return graph_node
    
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
        return null
    
    # Restore instance name
    if not instance_name.is_empty():
        brick_instance.set_instance_name(instance_name)
    
    # Restore debug fields
    brick_instance.debug_enabled = debug_enabled
    brick_instance.debug_message = debug_message
    
    # Restore properties
    for prop_name in properties:
        brick_instance.set_property(prop_name, properties[prop_name])
    
    # If this is a WaypointPathActuator, restore pos_# Node3D children
    if brick_class == "WaypointPathActuator" and current_node is Node3D:
        var WaypointPathActuator = load("res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd")
        if WaypointPathActuator:
            WaypointPathActuator.sync_waypoint_nodes(current_node, brick_instance)
    
    # Create GraphNode
    var graph_node = BrickGraphNode.new()
    graph_node.name = node_data["id"]
    graph_node.position_offset = position
    graph_node.title = brick_instance.get_brick_name()
    
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
        _update_controller_title(graph_node, brick_instance)
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
    return graph_node


func _create_brick_instance(brick_class: String):
    var script_path = ""
    
    match brick_class:
        "ActuatorSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/actuator_sensor.gd"
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
        "MovementSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/movement_sensor.gd"
        "MouseSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/mouse_sensor.gd"
        "CollisionSensor":
            script_path = "res://addons/logic_bricks/bricks/sensors/3d/collision_sensor.gd"
        "ANDController", "Controller":
            script_path = "res://addons/logic_bricks/bricks/controllers/controller.gd"
        "MotionActuator", "LocationActuator", "RotationActuator":
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
        "RotateTowardsActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/rotate_towards_actuator.gd"
        "WaypointPathActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd"
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
        "SaveLoadActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/save_load_actuator.gd"
        "SetCameraActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/set_camera_actuator.gd"
        "SmoothFollowCameraActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/smooth_follow_camera_actuator.gd"
        "CollisionActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/collision_actuator.gd"
        "ParentActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/parent_actuator.gd"
        "MouseActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/mouse_actuator.gd"
        "GameActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/game_actuator.gd"
        "EnvironmentActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/environment_actuator.gd"
        "Audio2DActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/audio_2d_actuator.gd"
        "ModulateActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/modulate_actuator.gd"
        "VisibilityActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/visibility_actuator.gd"
        "ProgressBarActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/progress_bar_actuator.gd"
        "TweenActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/tween_actuator.gd"
        "ImpulseActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/impulse_actuator.gd"
        "ForceActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/force_actuator.gd"
        "TorqueActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/torque_actuator.gd"
        "LinearVelocityActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/linear_velocity_actuator.gd"
        "MusicActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/music_actuator.gd"
        "ScreenShakeActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/screen_shake_actuator.gd"
        "ScreenFlashActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/screen_flash_actuator.gd"
        "RumbleActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/rumble_actuator.gd"
        "ShaderParamActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/shader_param_actuator.gd"
        "LightActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/light_actuator.gd"
        "ThirdPersonCameraActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/third_person_camera_actuator.gd"
        "SplitScreenActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/split_screen_actuator.gd"
        "CameraZoomActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/camera_zoom_actuator.gd"
        "ObjectPoolActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/object_pool_actuator.gd"
        "PhysicsActuator":
            script_path = "res://addons/logic_bricks/bricks/actuators/3d/physics_actuator.gd"
        "ANDController", "Controller":
            script_path = "res://addons/logic_bricks/bricks/controllers/controller.gd"
    
    if script_path.is_empty():
        return null

    # Ensure the base class is resident in the resource cache before loading
    # the brick script. Scripts that use extends "res://..." fail to instantiate
    # with .new() if their base class hasn't been loaded yet.
    var _base = load("res://addons/logic_bricks/core/logic_brick.gd")
    if not _base:
        push_error("Logic Bricks: could not load base class logic_brick.gd")
        return null

    var brick_script = load(script_path)
    if not brick_script:
        push_error("Logic Bricks: Failed to load script: " + script_path)
        return null

    if not brick_script.can_instantiate():
        push_error("Logic Bricks: Script cannot be instantiated (check for parse errors): " + script_path)
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
                    if property_name == "waypoints" and current_node is Node3D:
                        var WaypointPathActuator = load("res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd")
                        if WaypointPathActuator:
                            WaypointPathActuator.sync_waypoint_nodes(current_node, brick_instance)
                    _save_graph_to_metadata()
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
                add_child(dialog)
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
                    _save_graph_to_metadata()
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
                    _save_graph_to_metadata()
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
            if property_name == "waypoints" and current_node is Node3D:
                var WaypointPathActuator = load("res://addons/logic_bricks/bricks/actuators/3d/waypoint_path_actuator.gd")
                if WaypointPathActuator:
                    WaypointPathActuator.sync_waypoint_nodes(current_node, brick_instance)
            _save_graph_to_metadata()
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
    # Recursively search current_node's entire subtree for AnimationPlayer nodes
    # and collect all unique animation names across all of them
    var animations: Array[String] = []
    
    if not current_node:
        return animations
    
    var players: Array[AnimationPlayer] = []
    _find_animation_players_recursive(current_node, players)
    
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
        
        "controller":  # Controller
            var all_states = properties.get("all_states", false)
            
            # Hide the state spinbox when "All States" is checked
            for child in graph_node.get_children():
                if child.has_meta("property_name"):
                    var prop_name = child.get_meta("property_name")
                    if prop_name == "state":
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
            # Use the raw index directly — converting the enum label string to int
            # (e.g. int("enable_monitoring")) always returns 0, which is wrong.
            value = index
        else:
            value = str(value)
    
    brick_instance.set_property(property_name, value)
    
    # Update controller title to reflect state changes
    var brick_class = brick_data.get("brick_class", "")
    if brick_data.get("brick_type", "") == "controller" and property_name in ["state", "all_states", "logic_mode"]:
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
            var before_snapshot = _take_graph_snapshot()
            graph_node.queue_free()
            await get_tree().process_frame  # Wait for queue_free to complete
            _save_graph_to_metadata()
            _record_undo("Delete Logic Brick", before_snapshot, _take_graph_snapshot())


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
    var before_snapshot = _take_graph_snapshot()
    
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
                    _record_undo("Connect Logic Bricks", before_snapshot, _take_graph_snapshot())
                return
    
    # Normal connection (sensor→controller or controller→actuator)
    graph_edit.connect_node(from_node, from_port, to_node, to_port)
    _save_graph_to_metadata()
    _record_undo("Connect Logic Bricks", before_snapshot, _take_graph_snapshot())


func _on_graph_edit_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        # Ctrl+D to duplicate selected nodes
        if event.keycode == KEY_D and event.ctrl_pressed:
            _duplicate_selected_nodes()
            graph_edit.accept_event()
        # Ctrl+C — copy selected bricks, or whole node if nothing selected
        elif event.keycode == KEY_C and event.ctrl_pressed:
            _on_copy_bricks_pressed()
            graph_edit.accept_event()
        # Ctrl+V — paste selection clipboard if available, else whole-node clipboard
        elif event.keycode == KEY_V and event.ctrl_pressed:
            _on_paste_bricks_pressed()
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
    var before_snapshot = _take_graph_snapshot()
    graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
    _save_graph_to_metadata()
    _record_undo("Disconnect Logic Bricks", before_snapshot, _take_graph_snapshot())


func _on_delete_nodes_request(nodes: Array) -> void:
    var before_snapshot = _take_graph_snapshot()
    
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
    
    _record_undo("Delete Logic Brick(s)", before_snapshot, _take_graph_snapshot())


func _on_property_changed(value, graph_node: GraphNode, property_name: String) -> void:
    if graph_node.has_meta("brick_data"):
        var brick_data = graph_node.get_meta("brick_data")
        var brick_instance = brick_data["brick_instance"]
        brick_instance.set_property(property_name, value)
        
        if brick_data.get("brick_type", "") == "controller" and property_name in ["state", "all_states"]:
            _update_controller_title(graph_node, brick_instance)
        
        _update_conditional_visibility(graph_node, brick_instance)
        _save_graph_to_metadata()


func _update_controller_title(graph_node: GraphNode, brick_instance) -> void:
    var props     = brick_instance.properties
    var all_states = props.get("all_states", false)
    var state      = props.get("state", 1)
    if all_states:
        graph_node.title = "Controller [ALL]"
    else:
        graph_node.title = "Controller [S%d]" % int(state)


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
    
    # Gather selected graph nodes
    var selected_nodes: Array = []
    for child in graph_edit.get_children():
        if child is GraphNode and child.selected:
            selected_nodes.append(child)
    
    # ── Selection copy ─────────────────────────────────────────
    if not selected_nodes.is_empty():
        _selection_clipboard = _capture_selection(selected_nodes)
        # Clear whole-node clipboard so paste knows which to use
        _clipboard_graph = {}
        return
    
    # ── Whole-node copy (nothing selected) ────────────────────
    if not current_node.has_meta("logic_bricks_graph"):
        push_warning("Logic Bricks: No logic bricks on this node to copy.")
        return
    
    _clipboard_graph = current_node.get_meta("logic_bricks_graph").duplicate(true)
    
    if current_node.has_meta("logic_bricks_variables"):
        _clipboard_vars = current_node.get_meta("logic_bricks_variables").duplicate(true)
    else:
        _clipboard_vars = []
    
    var clipboard_globals: Array = []
    if editor_interface:
        var scene_root = editor_interface.get_edited_scene_root()
        if scene_root and scene_root.has_meta("logic_bricks_global_vars"):
            clipboard_globals = scene_root.get_meta("logic_bricks_global_vars").duplicate(true)
    _clipboard_graph["_global_vars"] = clipboard_globals
    
    # Clear selection clipboard so paste uses the whole-node one
    _selection_clipboard = {}


## Capture selected graph nodes and their internal connections
## into a portable dictionary that can be pasted onto any node.
func _capture_selection(selected_nodes: Array) -> Dictionary:
    var selected_names: Dictionary = {}
    for node in selected_nodes:
        selected_names[node.name] = true
    
    var node_data_list: Array = []
    for node in selected_nodes:
        if not node.has_meta("brick_data"):
            continue
        var bd = node.get_meta("brick_data")
        var bi = bd["brick_instance"]
        node_data_list.append({
            "id":           node.name,
            "position":     node.position_offset,
            "brick_type":   bd["brick_type"],
            "brick_class":  bd["brick_class"],
            "instance_name": bi.get_instance_name(),
            "debug_enabled": bi.debug_enabled,
            "debug_message": bi.debug_message,
            "properties":   bi.get_properties().duplicate(true)
        })
    
    # Only keep connections where both endpoints are in the selection
    var internal_conns: Array = []
    for conn in graph_edit.get_connection_list():
        if conn["from_node"] in selected_names and conn["to_node"] in selected_names:
            internal_conns.append(conn.duplicate())
    
    return {"nodes": node_data_list, "connections": internal_conns}


func _on_paste_bricks_pressed() -> void:
    if not current_node:
        push_warning("Logic Bricks: No node selected to paste to.")
        return
    
    if _is_part_of_instance(current_node):
        push_warning("Logic Bricks: Cannot paste to an instanced node.")
        return
    
    # ── Selection paste ─────────────────────────────────────────
    if not _selection_clipboard.is_empty():
        await _paste_selection(_selection_clipboard)
        return
    
    # ── Whole-node paste ────────────────────────────────────────
    if _clipboard_graph.is_empty():
        push_warning("Logic Bricks: Nothing to paste. Copy bricks from a node first.")
        return
    
    var paste_graph = _clipboard_graph.duplicate(true)
    var pasted_globals: Array = paste_graph.get("_global_vars", [])
    paste_graph.erase("_global_vars")
    
    current_node.set_meta("logic_bricks_graph", paste_graph)
    
    if _clipboard_vars.size() > 0:
        current_node.set_meta("logic_bricks_variables", _clipboard_vars.duplicate(true))
    
    if pasted_globals.size() > 0 and editor_interface:
        var scene_root = editor_interface.get_edited_scene_root()
        if scene_root:
            var existing: Array = []
            if scene_root.has_meta("logic_bricks_global_vars"):
                existing = scene_root.get_meta("logic_bricks_global_vars").duplicate(true)
            var existing_names: Dictionary = {}
            for v in existing:
                existing_names[v.get("name", "")] = true
            for v in pasted_globals:
                if not existing_names.get(v.get("name", ""), false):
                    existing.append(v.duplicate())
            scene_root.set_meta("logic_bricks_global_vars", existing)
    
    _mark_scene_modified()
    await _load_graph_from_metadata()
    _load_variables_from_metadata()


## Paste the selection clipboard into the current graph.
## Pasted nodes are offset slightly so they don't land on top of existing bricks.
## Internal connections are recreated. The clipboard is not cleared so the user
## can paste the same set multiple times or switch nodes and paste again.
func _paste_selection(clipboard: Dictionary) -> void:
    var node_list: Array = clipboard.get("nodes", [])
    if node_list.is_empty():
        return
    
    # Deselect everything currently in the graph
    for child in graph_edit.get_children():
        if child is GraphNode:
            child.selected = false
    
    var paste_offset = Vector2(40, 40)
    
    # Map old node ID -> new GraphNode instance (captured directly from add_child)
    var node_map: Dictionary = {}
    
    for node_data in node_list:
        var new_id = "brick_node_%d" % next_node_id
        next_node_id += 1
        
        var new_data = node_data.duplicate(true)
        new_data["id"] = new_id
        new_data["position"] = Vector2(node_data["position"]) + paste_offset
        
        var new_node = _create_graph_node_from_data(new_data)
        if new_node:
            node_map[node_data["id"]] = new_node
    
    # Wait a frame so all nodes are fully initialised before wiring
    await get_tree().process_frame
    
    # Select pasted nodes and recreate internal connections using actual node names
    for new_node in node_map.values():
        if is_instance_valid(new_node):
            new_node.selected = true
    
    for conn in clipboard.get("connections", []):
        var from_node = node_map.get(conn["from_node"])
        var to_node   = node_map.get(conn["to_node"])
        if from_node and to_node and is_instance_valid(from_node) and is_instance_valid(to_node):
            graph_edit.connect_node(from_node.name, conn["from_port"], to_node.name, conn["to_port"])
    
    _save_graph_to_metadata()


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
    
    # Phase 1: create any required scene nodes (CanvasLayer, ColorRect, etc.)
    # @export var assignment happens in Phase 2 AFTER set_script() below,
    # because set_script() resets all properties to their defaults.
    _apply_scene_setup_create(current_node, chains)
    
    # Get script path if we didn't have one
    if script_path.is_empty() and current_node.get_script():
        script_path = current_node.get_script().resource_path
    
    if script_path.is_empty():
        push_error("Logic Bricks: No script path available!")
        return
    
    # Save the scene before hot-reload only when ScreenFlashActuator is present,
    # because it creates nodes that reference SubViewport NodePaths — Godot can
    # hit "common_parent is null" in get_path_to() if those paths aren't on disk
    # before the script reloads. All other actuator types are safe without a save.
    var needs_pre_save := false
    for chain in chains:
        for actuator in chain.get("actuators", []):
            if actuator.get("type", "") == "ScreenFlashActuator":
                needs_pre_save = true
                break
        if needs_pre_save:
            break
    if needs_pre_save:
        editor_interface.save_scene()
    
    # Force filesystem to update
    var filesystem = editor_interface.get_resource_filesystem()
    filesystem.update_file(script_path)
    
    # Snapshot current_node before awaiting — the user may click away during the
    # yield, setting current_node to null or a different node.
    var _apply_node = current_node
    
    # Wait a frame
    await get_tree().process_frame
    
    # Guard: node must still be valid after the yield
    if not is_instance_valid(_apply_node):
        push_error("Logic Bricks: Node was freed during Apply Code — try again.")
        return
    
    # Reload the script with cache bypass
    var reloaded_script = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE)
    
    if not reloaded_script:
        push_error("Logic Bricks: Failed to reload script from disk!")
        return
    
    # Apply the reloaded script to the node
    _apply_node.set_script(reloaded_script)
    
    # Phase 2: assign @export vars now that the new script is live.
    # This MUST come after set_script() or the assignments get wiped.
    await get_tree().process_frame
    if is_instance_valid(_apply_node):
        _apply_scene_setup_assign(_apply_node, chains)
    
    # Minimize/restore is the only reliable way to force Godot to rebuild
    # the inspector's @export slots after a script reload.
    # Hide all secondary Window nodes first — any visible child Window (including
    # the addon pop-out or other editor sub-windows) can prevent the OS-level
    # focus loss that makes the hack work, and can also steal the restore signal
    # leaving the main window stuck minimized.
    var was_popout_open = _popout_window != null
    if was_popout_open:
        _popout_window.hide()
    
    # Also hide any other top-level Windows that are currently visible.
    var other_windows: Array[Window] = []
    for child in get_tree().root.get_children():
        if child is Window and child.visible and child != get_tree().root:
            other_windows.append(child)
            child.hide()
    
    # Capture the restore mode *before* minimizing.
    # Always restore to WINDOWED or MAXIMIZED — never back to MINIMIZED — so
    # that a pre-existing minimized state (e.g. caused by another window) does
    # not leave us stuck.
    var prev_window_mode = DisplayServer.window_get_mode()
    var restore_mode = DisplayServer.WINDOW_MODE_WINDOWED
    if prev_window_mode == DisplayServer.WINDOW_MODE_MAXIMIZED or \
       prev_window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or \
       prev_window_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
        restore_mode = prev_window_mode
    
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
    # A single process frame is enough for the OS to register the minimize.
    await get_tree().process_frame
    DisplayServer.window_set_mode(restore_mode)
    
    # Restore all secondary windows that were hidden above.
    for w in other_windows:
        if is_instance_valid(w):
            w.show()
    
    if was_popout_open and _popout_window:
        _popout_window.show()
    
    # Open the script in the script editor
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
    var var_data = {
        "name": "new_variable",
        "type": "int",
        "value": "0",
        "exported": false,
        "use_min": false,
        "min_val": "0",
        "use_max": false,
        "max_val": "100"
    }
    variables_data.append(var_data)
    _refresh_variables_ui()
    _save_variables_to_metadata()


func _on_add_global_variable_pressed() -> void:
    var var_data = {
        "name": "new_global",
        "type": "int",
        "value": "0",
        "use_min": false,
        "min_val": "0",
        "use_max": false,
        "max_val": "100"
    }
    global_vars_data.append(var_data)
    _refresh_global_vars_ui()
    _save_global_vars_to_metadata()


func _refresh_variables_ui() -> void:
    for child in variables_list.get_children():
        child.queue_free()
    for i in range(variables_data.size()):
        _create_variable_ui(i, variables_data[i])


func _refresh_global_vars_ui() -> void:
    if not global_vars_list:
        return
    for child in global_vars_list.get_children():
        child.queue_free()
    for i in range(global_vars_data.size()):
        _create_global_variable_ui(i, global_vars_data[i])


func _create_variable_ui(index: int, var_data: Dictionary) -> void:
    var panel = PanelContainer.new()
    variables_list.add_child(panel)
    
    var vbox = VBoxContainer.new()
    panel.add_child(vbox)
    
    var header = HBoxContainer.new()
    vbox.add_child(header)
    
    var collapse_btn = Button.new()
    collapse_btn.text = "▼"
    collapse_btn.custom_minimum_size = Vector2(24, 0)
    collapse_btn.name = "CollapseBtn"
    header.add_child(collapse_btn)
    
    var name_display = Label.new()
    name_display.text = "%s: %s" % [var_data["name"], var_data["type"]]
    name_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_display.name = "NameDisplay"
    header.add_child(name_display)
    
    var delete_btn = Button.new()
    delete_btn.text = "×"
    delete_btn.custom_minimum_size = Vector2(24, 0)
    delete_btn.pressed.connect(_on_delete_variable_pressed.bind(index))
    header.add_child(delete_btn)
    
    var details = VBoxContainer.new()
    details.name = "Details"
    vbox.add_child(details)
    
    # Name
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
    
    # Type
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
    var type_index = 1
    match var_data["type"]:
        "bool": type_index = 0
        "int":  type_index = 1
        "float": type_index = 2
        "String": type_index = 3
        "Vector2": type_index = 4
        "Vector3": type_index = 5
    type_option.selected = type_index
    type_option.item_selected.connect(_on_variable_type_changed.bind(index, name_display))
    row2.add_child(type_option)
    
    # Value
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
    
    # Export
    var row4 = HBoxContainer.new()
    details.add_child(row4)
    var export_check = CheckBox.new()
    export_check.text = "Export (visible in Inspector)"
    export_check.button_pressed = var_data.get("exported", false)
    export_check.toggled.connect(_on_variable_exported_changed.bind(index))
    row4.add_child(export_check)
    
    # Min / Max (numeric types only)
    var is_numeric = var_data["type"] in ["int", "float"]
    
    var row_min = HBoxContainer.new()
    row_min.name = "RowMin"
    row_min.visible = is_numeric
    details.add_child(row_min)
    var min_check = CheckBox.new()
    min_check.text = "Min"
    min_check.button_pressed = var_data.get("use_min", false)
    row_min.add_child(min_check)
    var min_edit = LineEdit.new()
    min_edit.text = var_data.get("min_val", "0")
    min_edit.custom_minimum_size = Vector2(60, 0)
    min_edit.editable = var_data.get("use_min", false)
    min_edit.modulate.a = 1.0 if var_data.get("use_min", false) else 0.4
    min_edit.text_changed.connect(_on_variable_min_val_changed.bind(index))
    row_min.add_child(min_edit)
    min_check.toggled.connect(_on_variable_min_toggled.bind(index, min_edit))
    
    var row_max = HBoxContainer.new()
    row_max.name = "RowMax"
    row_max.visible = is_numeric
    details.add_child(row_max)
    var max_check = CheckBox.new()
    max_check.text = "Max"
    max_check.button_pressed = var_data.get("use_max", false)
    row_max.add_child(max_check)
    var max_edit = LineEdit.new()
    max_edit.text = var_data.get("max_val", "100")
    max_edit.custom_minimum_size = Vector2(60, 0)
    max_edit.editable = var_data.get("use_max", false)
    max_edit.modulate.a = 1.0 if var_data.get("use_max", false) else 0.4
    max_edit.text_changed.connect(_on_variable_max_val_changed.bind(index))
    row_max.add_child(max_edit)
    max_check.toggled.connect(_on_variable_max_toggled.bind(index, max_edit))
    
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
        # Refresh so min/max rows show/hide correctly for the new type
        _refresh_variables_ui()


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


func _create_global_variable_ui(index: int, var_data: Dictionary) -> void:
    var panel = PanelContainer.new()
    global_vars_list.add_child(panel)
    
    var vbox = VBoxContainer.new()
    panel.add_child(vbox)
    
    var header = HBoxContainer.new()
    vbox.add_child(header)
    
    var collapse_btn = Button.new()
    collapse_btn.text = "▼"
    collapse_btn.custom_minimum_size = Vector2(24, 0)
    header.add_child(collapse_btn)
    
    var name_display = Label.new()
    name_display.text = "%s: %s" % [var_data.get("name", ""), var_data.get("type", "int")]
    name_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(name_display)
    
    var delete_btn = Button.new()
    delete_btn.text = "×"
    delete_btn.custom_minimum_size = Vector2(24, 0)
    delete_btn.pressed.connect(_on_delete_global_variable_pressed.bind(index))
    header.add_child(delete_btn)
    
    var details = VBoxContainer.new()
    details.name = "Details"
    vbox.add_child(details)
    
    # Name
    var row1 = HBoxContainer.new()
    details.add_child(row1)
    var name_label = Label.new()
    name_label.text = "Name:"
    row1.add_child(name_label)
    var name_edit = LineEdit.new()
    name_edit.text = var_data.get("name", "")
    name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_edit.text_changed.connect(_on_global_variable_name_changed.bind(index, name_display))
    row1.add_child(name_edit)
    
    # Type
    var row2 = HBoxContainer.new()
    details.add_child(row2)
    var type_label = Label.new()
    type_label.text = "Type:"
    row2.add_child(type_label)
    var type_option = OptionButton.new()
    type_option.add_item("bool", 0)
    type_option.add_item("int", 1)
    type_option.add_item("float", 2)
    type_option.add_item("String", 3)
    type_option.add_item("Vector2", 4)
    type_option.add_item("Vector3", 5)
    var type_index = 1
    match var_data.get("type", "int"):
        "bool":   type_index = 0
        "int":    type_index = 1
        "float":  type_index = 2
        "String": type_index = 3
        "Vector2": type_index = 4
        "Vector3": type_index = 5
    type_option.selected = type_index
    type_option.item_selected.connect(_on_global_variable_type_changed.bind(index, name_display))
    row2.add_child(type_option)
    
    # Value
    var row3 = HBoxContainer.new()
    details.add_child(row3)
    var value_label = Label.new()
    value_label.text = "Value:"
    row3.add_child(value_label)
    var value_edit = LineEdit.new()
    value_edit.text = var_data.get("value", "0")
    value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    value_edit.text_changed.connect(_on_global_variable_value_changed.bind(index))
    row3.add_child(value_edit)
    
    # Min / Max (numeric types only)
    var is_numeric = var_data.get("type", "int") in ["int", "float"]
    
    var row_min = HBoxContainer.new()
    row_min.visible = is_numeric
    details.add_child(row_min)
    var min_check = CheckBox.new()
    min_check.text = "Min"
    min_check.button_pressed = var_data.get("use_min", false)
    row_min.add_child(min_check)
    var min_edit = LineEdit.new()
    min_edit.text = var_data.get("min_val", "0")
    min_edit.custom_minimum_size = Vector2(60, 0)
    min_edit.editable = var_data.get("use_min", false)
    min_edit.modulate.a = 1.0 if var_data.get("use_min", false) else 0.4
    min_edit.text_changed.connect(_on_global_variable_min_val_changed.bind(index))
    row_min.add_child(min_edit)
    min_check.toggled.connect(_on_global_variable_min_toggled.bind(index, min_edit))
    
    var row_max = HBoxContainer.new()
    row_max.visible = is_numeric
    details.add_child(row_max)
    var max_check = CheckBox.new()
    max_check.text = "Max"
    max_check.button_pressed = var_data.get("use_max", false)
    row_max.add_child(max_check)
    var max_edit = LineEdit.new()
    max_edit.text = var_data.get("max_val", "100")
    max_edit.custom_minimum_size = Vector2(60, 0)
    max_edit.editable = var_data.get("use_max", false)
    max_edit.modulate.a = 1.0 if var_data.get("use_max", false) else 0.4
    max_edit.text_changed.connect(_on_global_variable_max_val_changed.bind(index))
    row_max.add_child(max_edit)
    max_check.toggled.connect(_on_global_variable_max_toggled.bind(index, max_edit))
    
    collapse_btn.pressed.connect(_on_variable_collapse_toggled.bind(collapse_btn, details))


func _on_global_variable_name_changed(new_name: String, index: int, name_display: Label) -> void:
    if index < global_vars_data.size():
        global_vars_data[index]["name"] = new_name
        name_display.text = "%s: %s" % [new_name, global_vars_data[index].get("type", "int")]
        _save_global_vars_to_metadata()


func _on_global_variable_type_changed(type_index: int, index: int, name_display: Label) -> void:
    if index < global_vars_data.size():
        var type_names = ["bool", "int", "float", "String", "Vector2", "Vector3"]
        global_vars_data[index]["type"] = type_names[type_index]
        name_display.text = "%s: %s" % [global_vars_data[index].get("name", ""), type_names[type_index]]
        _save_global_vars_to_metadata()
        _refresh_global_vars_ui()


func _on_global_variable_value_changed(new_value: String, index: int) -> void:
    if index < global_vars_data.size():
        global_vars_data[index]["value"] = new_value
        _save_global_vars_to_metadata()


func _on_global_variable_min_toggled(enabled: bool, index: int, min_edit: LineEdit) -> void:
    min_edit.editable = enabled
    min_edit.modulate.a = 1.0 if enabled else 0.4
    if index < global_vars_data.size():
        global_vars_data[index]["use_min"] = enabled
        _save_global_vars_to_metadata()


func _on_global_variable_min_val_changed(new_val: String, index: int) -> void:
    if index < global_vars_data.size():
        global_vars_data[index]["min_val"] = new_val
        _save_global_vars_to_metadata()


func _on_global_variable_max_toggled(enabled: bool, index: int, max_edit: LineEdit) -> void:
    max_edit.editable = enabled
    max_edit.modulate.a = 1.0 if enabled else 0.4
    if index < global_vars_data.size():
        global_vars_data[index]["use_max"] = enabled
        _save_global_vars_to_metadata()


func _on_global_variable_max_val_changed(new_val: String, index: int) -> void:
    if index < global_vars_data.size():
        global_vars_data[index]["max_val"] = new_val
        _save_global_vars_to_metadata()


func _on_delete_global_variable_pressed(index: int) -> void:
    if index < global_vars_data.size():
        global_vars_data.remove_at(index)
        _refresh_global_vars_ui()
        _save_global_vars_to_metadata()


func _on_variable_min_toggled(enabled: bool, index: int, min_edit: LineEdit) -> void:
    min_edit.editable = enabled
    min_edit.modulate.a = 1.0 if enabled else 0.4
    if index < variables_data.size():
        variables_data[index]["use_min"] = enabled
        _save_variables_to_metadata()


func _on_variable_min_val_changed(new_val: String, index: int) -> void:
    if index < variables_data.size():
        variables_data[index]["min_val"] = new_val
        _save_variables_to_metadata()


func _on_variable_max_toggled(enabled: bool, index: int, max_edit: LineEdit) -> void:
    max_edit.editable = enabled
    max_edit.modulate.a = 1.0 if enabled else 0.4
    if index < variables_data.size():
        variables_data[index]["use_max"] = enabled
        _save_variables_to_metadata()


func _on_variable_max_val_changed(new_val: String, index: int) -> void:
    if index < variables_data.size():
        variables_data[index]["max_val"] = new_val
        _save_variables_to_metadata()


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
    if not current_node:
        return
    if _is_part_of_instance(current_node) and not _instance_override:
        return
    
    # Save only local (non-global) variables on this node
    current_node.set_meta("logic_bricks_variables", variables_data.duplicate())
    _mark_scene_modified()
    _update_global_vars_script()


func _save_global_vars_to_metadata() -> void:
    if not editor_interface:
        return
    
    # Global variables live on the scene root — single source of truth, no duplication
    var scene_root = editor_interface.get_edited_scene_root()
    if not scene_root:
        return
    
    scene_root.set_meta("logic_bricks_global_vars", global_vars_data.duplicate())
    _mark_scene_modified()
    _update_global_vars_script()


func _update_global_vars_script() -> void:
    var script_path = "res://addons/logic_bricks/global_vars.gd"
    
    if global_vars_data.is_empty():
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
        var empty_file = FileAccess.open(script_path, FileAccess.WRITE)
        if empty_file:
            empty_file.store_string("\n".join(empty_lines))
            empty_file.close()
            if editor_interface:
                editor_interface.get_resource_filesystem().scan()
        return
    
    var lines: Array[String] = []
    lines.append("extends Node")
    lines.append("")
    lines.append("## Auto-generated by Logic Bricks plugin")
    lines.append("## Global variables shared across all scenes")
    lines.append("## Do not edit between the markers")
    lines.append("")
    lines.append("# === LOGIC BRICKS GLOBALS START ===")
    
    for var_data in global_vars_data:
        var var_name  = var_data.get("name", "")
        var var_type  = var_data.get("type", "float")
        var var_value = var_data.get("value", "0")
        if not var_name.is_empty():
            lines.append("var %s: %s = %s" % [var_name, var_type, var_value])
    
    lines.append("# === LOGIC BRICKS GLOBALS END ===")
    lines.append("")
    
    var file = FileAccess.open(script_path, FileAccess.WRITE)
    if file:
        file.store_string("\n".join(lines))
        file.close()
    else:
        push_error("Logic Bricks: Could not write global vars script at: " + script_path)
        return
    
    if editor_interface:
        editor_interface.get_resource_filesystem().scan()
    
    _ensure_global_vars_autoload(script_path)


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
    variables_data.clear()
    global_vars_data.clear()
    
    if not current_node:
        return
    
    # Load local variables from this node's metadata (non-global only)
    if current_node.has_meta("logic_bricks_variables"):
        var saved_vars = current_node.get_meta("logic_bricks_variables")
        if saved_vars is Array:
            for var_data in saved_vars:
                if not var_data.get("global", false):
                    variables_data.append(var_data.duplicate())
    
    # Load global variables from the scene root's metadata (single source of truth)
    if editor_interface:
        var scene_root = editor_interface.get_edited_scene_root()
        if scene_root and scene_root.has_meta("logic_bricks_global_vars"):
            var saved_globals = scene_root.get_meta("logic_bricks_global_vars")
            if saved_globals is Array:
                for var_data in saved_globals:
                    global_vars_data.append(var_data.duplicate())
    
    _refresh_variables_ui()
    _refresh_global_vars_ui()


func _build_export_range_str(var_type: String, use_min: bool, min_val: String, use_max: bool, max_val: String) -> String:
    var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
    var hi = max_val if use_max else ("9999999"  if var_type == "int" else "9999999.0")
    return "%s, %s" % [lo, hi]


func _build_clamp_expr(val_var: String, var_type: String, use_min: bool, min_val: String, use_max: bool, max_val: String) -> String:
    var fn = "clampi" if var_type == "int" else "clampf"
    var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
    var hi = max_val if use_max else ("9999999"  if var_type == "int" else "9999999.0")
    return "%s(%s, %s, %s)" % [fn, val_var, lo, hi]


func get_variables_code() -> String:
    var lines: Array[String] = []
    
    if not variables_data.is_empty() or not global_vars_data.is_empty():
        lines.append("# Variables")
    
    # Local variables
    for var_data in variables_data:
        var var_name  = var_data.get("name", "")
        var var_type  = var_data.get("type", "int")
        var var_value = var_data.get("value", "0")
        var exported  = var_data.get("exported", false)
        var use_min   = var_data.get("use_min", false)
        var min_val   = var_data.get("min_val", "0")
        var use_max   = var_data.get("use_max", false)
        var max_val   = var_data.get("max_val", "100")
        var has_range = (var_type in ["int", "float"]) and (use_min or use_max)
        
        if has_range and exported:
            var range_str = _build_export_range_str(var_type, use_min, min_val, use_max, max_val)
            lines.append("@export_range(%s) var %s: %s = %s" % [range_str, var_name, var_type, var_value])
        elif has_range and not exported:
            var clamp_expr = _build_clamp_expr("val", var_type, use_min, min_val, use_max, max_val)
            lines.append("var _%s_raw: %s = %s" % [var_name, var_type, var_value])
            lines.append("var %s: %s:" % [var_name, var_type])
            lines.append("\tget: return _%s_raw" % var_name)
            lines.append("\tset(val): _%s_raw = %s" % [var_name, clamp_expr])
        else:
            var declaration = ""
            if exported:
                declaration += "@export "
            declaration += "var %s: %s = %s" % [var_name, var_type, var_value]
            lines.append(declaration)
    
    # Global variables — proxy properties that read/write through GlobalVars autoload
    for var_data in global_vars_data:
        var var_name  = var_data.get("name", "")
        var var_type  = var_data.get("type", "int")
        var use_min   = var_data.get("use_min", false)
        var min_val   = var_data.get("min_val", "0")
        var use_max   = var_data.get("use_max", false)
        var max_val   = var_data.get("max_val", "100")
        var has_range = (var_type in ["int", "float"]) and (use_min or use_max)
        if var_name.is_empty():
            continue
        lines.append("var %s: %s:" % [var_name, var_type])
        lines.append("\tget: return GlobalVars.%s" % var_name)
        if has_range:
            var clamp_expr = _build_clamp_expr("val", var_type, use_min, min_val, use_max, max_val)
            lines.append("\tset(val): GlobalVars.%s = %s" % [var_name, clamp_expr])
        else:
            lines.append("\tset(val): GlobalVars.%s = val" % var_name)
    
    if lines.is_empty():
        return ""
    lines.append("")
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
    
    # Never save to instanced nodes (unless user explicitly chose to edit the instance)
    if _is_part_of_instance(current_node) and not _instance_override:
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
    side_panel.current_tab = 2  # Frames is tab index 2 (Variables=0, Globals=1, Frames=2)
    
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


## Build, update, or remove scene nodes required by special actuators.
## Called after Apply Code so nodes exist in the scene before the script runs.
func _apply_scene_setup_create(node: Node, chains: Array) -> void:
    # Phase 1 of Apply Code scene setup: create scene nodes and clean up stale ones.
    # @export var assignments are done separately in _apply_scene_setup_assign(),
    # which must run AFTER set_script() so the assignments aren't wiped.
    var scene_root = node.get_tree().edited_scene_root if node.get_tree() else null
    if not scene_root:
        return

    # ── SplitScreen: free stale _ss_canvas_* nodes if the actuator was removed ──
    var has_split_screen := false
    for chain in chains:
        for actuator in chain.get("actuators", []):
            if actuator.get("type", "") == "SplitScreenActuator":
                has_split_screen = true
                break
        if has_split_screen:
            break

    if not has_split_screen:
        var stale_ss: Array = []
        for child in scene_root.get_children():
            if child is CanvasLayer and child.name.begins_with("_ss_canvas_"):
                stale_ss.append(child)
        for cl in stale_ss:
            cl.free()

    # ── ScreenFlash: create/update CanvasLayer + ColorRect nodes ────────────
    var active_flash_layers: Array = []

    for chain in chains:
        for actuator_data in chain.get("actuators", []):
            if actuator_data.get("type", "") != "ScreenFlashActuator":
                continue

            var brick_script = load("res://addons/logic_bricks/bricks/actuators/3d/screen_flash_actuator.gd")
            if not brick_script:
                push_warning("Logic Bricks: Could not load screen_flash_actuator.gd")
                continue
            var brick = brick_script.new()
            brick.deserialize(actuator_data)
            var gen = brick.generate_code(node, chain.get("name", "chain"))
            var setup = gen.get("scene_setup", {})
            if setup.get("type", "") != "ScreenFlash":
                continue

            var flash_var: String  = setup.get("flash_var", "")
            var cam_name: String   = setup.get("camera_name", "").strip_edges()
            if flash_var.is_empty():
                continue

            var layer_name := "__FlashLayer_%s" % flash_var
            active_flash_layers.append(layer_name)

            # Determine size to match the target camera's viewport
            var flash_size := Vector2(
                ProjectSettings.get_setting("display/window/size/viewport_width",  1280),
                ProjectSettings.get_setting("display/window/size/viewport_height", 720)
            )

            if not cam_name.is_empty():
                var cam := _find_camera_by_name(scene_root, cam_name)
                if is_instance_valid(cam):
                    var p := cam.get_parent()
                    while is_instance_valid(p):
                        if p is SubViewportContainer:
                            flash_size = (p as SubViewportContainer).size
                            break
                        elif p is SubViewport:
                            flash_size = Vector2((p as SubViewport).size)
                            break
                        p = p.get_parent()
                else:
                    push_warning("Screen Flash Actuator: Camera '%s' not found — using full window size" % cam_name)

            # Find or create the CanvasLayer
            var canvas_layer: CanvasLayer = null
            for child in scene_root.get_children():
                if child is CanvasLayer and child.name == layer_name:
                    canvas_layer = child as CanvasLayer
                    break
            if not is_instance_valid(canvas_layer):
                canvas_layer = CanvasLayer.new()
                canvas_layer.name = layer_name
                canvas_layer.layer = 128
                scene_root.add_child(canvas_layer)
                canvas_layer.owner = scene_root

            # Find or create the ColorRect inside the CanvasLayer
            var color_rect: ColorRect = canvas_layer.get_node_or_null("ColorRect") as ColorRect
            if not is_instance_valid(color_rect):
                color_rect = ColorRect.new()
                color_rect.name = "ColorRect"
                canvas_layer.add_child(color_rect)
                color_rect.owner = scene_root

            # Size it to match the camera viewport; use anchors=0 so size is literal
            color_rect.anchor_left   = 0.0
            color_rect.anchor_top    = 0.0
            color_rect.anchor_right  = 0.0
            color_rect.anchor_bottom = 0.0
            color_rect.position      = Vector2.ZERO
            color_rect.size          = flash_size
            color_rect.color         = Color(0, 0, 0, 0)
            color_rect.visible       = false
            color_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE

    # Free stale flash layers from removed ScreenFlashActuator bricks
    var stale_flash: Array = []
    for child in scene_root.get_children():
        if child is CanvasLayer and child.name.begins_with("__FlashLayer_")                 and child.name not in active_flash_layers:
            stale_flash.append(child)
    for cl in stale_flash:
        cl.free()


func _apply_scene_setup_assign(node: Node, chains: Array) -> void:
    # Phase 2 of Apply Code scene setup: assign @export vars to the pre-created nodes.
    # Must run AFTER set_script() — set_script() resets all properties, so any
    # assignment done before it would be silently discarded.
    #
    # NOTE: ScreenFlash no longer uses @export vars. The generated actuator code
    # resolves the ColorRect by node path at runtime via get_tree().root.get_node_or_null().
    # No assignment is needed here for that actuator type.
    pass

func _find_camera_by_name(root: Node, cam_name: String) -> Camera3D:
    if not is_instance_valid(root): return null
    for child in root.get_children():
        if not is_instance_valid(child): continue
        if child is Camera3D and child.name == cam_name:
            return child
        elif not child is SubViewport:
            var found = _find_camera_by_name(child, cam_name)
            if found:
                return found
    return null


## Recursively collect all Camera3D nodes under a root node
func _collect_cameras(root: Node, result: Array) -> void:
    for child in root.get_children():
        if child is Camera3D:
            result.append(child)
        elif not child is SubViewport:
            _collect_cameras(child, result)