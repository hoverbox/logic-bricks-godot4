@tool
extends VBoxContainer

## Main panel UI for the Logic Bricks plugin (bottom panel)
## Visual node graph editor for connecting logic bricks

const BrickGraphNode    = preload("res://addons/logic_bricks/ui/brick_graph_node.gd")
const VariableUtils = preload("res://addons/logic_bricks/core/logic_brick_variable_utils.gd")

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

# Search popup (lazy-created)

# Side panel (vertical nav: Variables, Globals, Frames, States)
var side_panel: PanelContainer          # Outer wrapper added to _main_hsplit
var _side_hbox: HBoxContainer           # nav buttons | content stack
var _side_nav_panel: PanelContainer      # wrapper for the nav rail
var _side_nav: VBoxContainer            # left column of nav buttons
var _side_content_scroll: ScrollContainer # right content column
var _side_stack: VBoxContainer          # right column — only one child visible at a time
var _collapse_button: Button            # collapses to icon rail only
var _side_collapsed: bool = false
var _expanded_side_width: int = 300
var _active_tab_index: int = 0          # 0=Variables, 1=Globals, 2=Frames, 3=States
var _nav_buttons: Array[Button] = []    # Kept so we can update active highlight
var variables_panel: VBoxContainer
var variables_list: VBoxContainer
var variables_data: Array[Dictionary] = []  # Local variables for this node
var global_vars_data: Array[Dictionary] = []  # Global variables (scene-wide, stored on scene root)
var global_vars_panel: VBoxContainer  # Tab panel for global variables
var global_vars_list: VBoxContainer  # UI container for the globals section
var frames_panel: VBoxContainer
var frames_list: ItemList
var states_panel: VBoxContainer
var states_data: Array[Dictionary] = []
var states_list: VBoxContainer
var frame_settings_container: VBoxContainer
var selected_frame: GraphFrame = null
var _frames_helper = preload("res://addons/logic_bricks/ui/panel_frames_helper.gd").new()
var _search_helper = preload("res://addons/logic_bricks/ui/panel_search_helper.gd").new()
var _clipboard_helper = preload("res://addons/logic_bricks/ui/panel_clipboard_helper.gd").new()
var _graph_helper = preload("res://addons/logic_bricks/ui/panel_graph_helper.gd").new()
var _property_helper = preload("res://addons/logic_bricks/ui/panel_property_helper.gd").new()
var _script_rebuild_helper = preload("res://addons/logic_bricks/ui/panel_script_rebuild_helper.gd").new()


func _init() -> void:
	# Set minimum size for the bottom panel
	custom_minimum_size = Vector2(0, 300)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	_search_helper.setup(self)
	_clipboard_helper.setup(self)
	_graph_helper.setup(self)
	_property_helper.setup(self)
	_script_rebuild_helper.setup(self)

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
	add_menu.add_item("🔍 Search…", 4)
	add_menu.add_item("Reroute", 3)
	add_menu.add_separator()
	add_menu.add_item("Rebuild from Script", 5)
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
	
	controllers_menu.add_item("Script Controller", 201)
	controllers_menu.set_item_metadata(1, {"type": "controller", "class": "ScriptController"})
	controllers_menu.set_item_tooltip(1, "Run custom GDScript or C# code when sensors fire.\nWrite your code directly in the brick's Script Body property.")
	
	# Populate Actuators submenu — grouped into categories
	var _actuator_groups = [
		{
			"label": "Animation",
			"items": [
				["Animation", 300, "AnimationActuator", "Play, stop, pause, queue, ping-pong, or flipper animations.\nAutomatically finds the AnimationPlayer that owns the animation.\n⚠ No @export needed — AnimationPlayer is found automatically."],
				["Animation Tree", 301, "AnimationTreeActuator", "Controls AnimationTree: travel states, set parameters/conditions.\n⚠ Adds @export in Inspector — assign your AnimationTree."],
				["Sprite Frames", 346, "SpriteFramesActuator", "Play, stop, or pause Sprite3D / AnimatedSprite3D frame animations.\nLeave Target Node empty to target self.\n⚠ No @export needed — node is found by name automatically."],
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
				["Object Flash", 348, "ObjectFlashActuator", "Flash a named object or mesh with a color overlay.\nType a node name, not a path. Use self to flash the current object."],
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
				["Preload", 347, "PreloadActuator", "Preloads materials, scenes, textures, audio, and meshes into memory before they are needed.\nPrevents runtime hitches and frame drops during gameplay."],
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
	# Outer container — replaces the old TabContainer
	side_panel = PanelContainer.new()
	side_panel.custom_minimum_size = Vector2.ZERO
	side_panel.size_flags_horizontal = Control.SIZE_FILL
	side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.visible = false  # Hidden until node selected

	# Horizontal split: Blender-like icon rail | content column
	_side_hbox = HBoxContainer.new()
	_side_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_child(_side_hbox)

	# Left nav column
	_side_nav_panel = PanelContainer.new()
	_side_nav_panel.custom_minimum_size = Vector2.ZERO
	_side_nav_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_hbox.add_child(_side_nav_panel)

	_side_nav = VBoxContainer.new()
	_side_nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_nav.alignment = BoxContainer.ALIGNMENT_BEGIN
	_side_nav_panel.add_child(_side_nav)

	_collapse_button = Button.new()
	_collapse_button.flat = true
	_collapse_button.focus_mode = Control.FOCUS_NONE
	_collapse_button.custom_minimum_size = Vector2(32, 32)
	_collapse_button.tooltip_text = "Collapse to icon rail"
	_collapse_button.expand_icon = false
	_collapse_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapse_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_collapse_button.text = "<"
	_collapse_button.pressed.connect(_toggle_side_panel_collapsed)
	_side_nav.add_child(_collapse_button)

	# Right content stack (inside a scroll container so the split can get very thin)
	_side_content_scroll = ScrollContainer.new()
	_side_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_side_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_side_hbox.add_child(_side_content_scroll)

	_side_stack = VBoxContainer.new()
	_side_stack.custom_minimum_size = Vector2.ZERO
	_side_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side_content_scroll.add_child(_side_stack)

	# Build the three content panels
	_create_variables_tab()
	_create_global_variables_tab()
	_create_frames_tab()
	_create_states_tab()

	_side_stack.add_child(variables_panel)
	_side_stack.add_child(global_vars_panel)
	_side_stack.add_child(frames_panel)
	_side_stack.add_child(states_panel)

	# Build nav buttons (one per panel)
	var tab_defs = [
		{"tooltip": "Variables", "icon": "LocalVariable", "fallback": "V"},
		{"tooltip": "Globals", "icon": "WorldEnvironment", "fallback": "G"},
		{"tooltip": "Frames", "icon": "KeyEasedSelected", "fallback": "F"},
		{"tooltip": "States", "icon": "StateMachine", "fallback": "S"}
	]
	for i in range(tab_defs.size()):
		var btn = Button.new()
		btn.flat = true
		btn.toggle_mode = false
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size = Vector2(32, 32)
		btn.tooltip_text = str(tab_defs[i]["tooltip"])
		btn.text = str(tab_defs[i]["fallback"])
		btn.expand_icon = false
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.theme_type_variation = "FlatButton"
		btn.set_meta("icon_name", str(tab_defs[i]["icon"]))
		btn.set_meta("fallback_text", str(tab_defs[i]["fallback"]))
		var idx = i  # capture for closure
		btn.pressed.connect(func(): _on_side_tab_pressed(idx))
		_side_nav.add_child(btn)
		_nav_buttons.append(btn)

	_apply_side_tab_icons()
	_update_collapse_button_icon()

	# Show first tab by default
	_select_side_tab(0)


func _on_side_tab_pressed(index: int) -> void:
	if _side_collapsed:
		_set_side_panel_collapsed(false)
	_select_side_tab(index)


func _select_side_tab(index: int) -> void:
	_active_tab_index = index
	for i in range(_side_stack.get_child_count()):
		_side_stack.get_child(i).visible = (i == index)
	# Update button highlight
	for i in range(_nav_buttons.size()):
		var btn = _nav_buttons[i]
		if i == index:
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			var active_sb = _make_active_nav_stylebox()
			btn.add_theme_stylebox_override("normal", active_sb)
			btn.add_theme_stylebox_override("hover", active_sb)
			btn.add_theme_stylebox_override("pressed", active_sb)
			btn.add_theme_stylebox_override("focus", active_sb)
		else:
			btn.remove_theme_color_override("font_color")
			var inactive_sb = _make_inactive_nav_stylebox()
			btn.add_theme_stylebox_override("normal", inactive_sb)
			btn.add_theme_stylebox_override("hover", _make_hover_nav_stylebox())
			btn.add_theme_stylebox_override("pressed", inactive_sb)
			btn.add_theme_stylebox_override("focus", inactive_sb)


func _toggle_side_panel_collapsed() -> void:
	_set_side_panel_collapsed(not _side_collapsed)


func _set_side_panel_collapsed(collapsed: bool) -> void:
	if _side_collapsed == collapsed:
		return
	if collapsed:
		_expanded_side_width = maxi(_expanded_side_width, int(side_panel.size.x))
	_side_collapsed = collapsed
	if _side_content_scroll:
		_side_content_scroll.visible = not collapsed
	_update_collapse_button_icon()
	call_deferred("_apply_side_collapse_split")


func _apply_side_collapse_split() -> void:
	if not _main_hsplit or not side_panel or not _side_nav_panel:
		return
	if _side_collapsed:
		var rail_width := maxi(int(_side_nav_panel.size.x), 40)
		_main_hsplit.split_offset = -rail_width
	else:
		var target_width := maxi(_expanded_side_width, 140)
		_main_hsplit.split_offset = -target_width


func _update_collapse_button_icon() -> void:
	if not _collapse_button:
		return
	var icon_name := "Forward" if _side_collapsed else "Back"
	var fallback := ">" if _side_collapsed else "<"
	var icon = null
	if has_theme_icon(icon_name, "EditorIcons"):
		icon = get_theme_icon(icon_name, "EditorIcons")
	_collapse_button.icon = icon
	_collapse_button.text = "" if icon != null else fallback
	_collapse_button.tooltip_text = "Expand panel" if _side_collapsed else "Collapse to icon rail"


func _make_active_nav_stylebox() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.45, 0.75, 0.85)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


func _make_inactive_nav_stylebox() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	return sb


func _make_hover_nav_stylebox() -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


func _apply_side_tab_icons() -> void:
	if _nav_buttons.is_empty():
		return
	for btn in _nav_buttons:
		if not is_instance_valid(btn):
			continue
		var icon_name = str(btn.get_meta("icon_name", ""))
		var fallback_text = str(btn.get_meta("fallback_text", ""))
		var icon = null
		if has_theme_icon(icon_name, "EditorIcons"):
			icon = get_theme_icon(icon_name, "EditorIcons")
		btn.icon = icon
		btn.text = "" if icon != null else fallback_text


func _apply_side_panel_visibility() -> void:
	if not side_panel:
		return
	side_panel.visible = graph_edit.visible
	if graph_edit.visible:
		call_deferred("_apply_side_collapse_split")


func _generate_global_var_id() -> String:
	return "lb_global_%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]


func _ensure_global_var_ids() -> void:
	var used_ids: Dictionary = {}
	for i in range(global_vars_data.size()):
		var var_data = global_vars_data[i]
		var gid = str(var_data.get("id", ""))
		if gid.is_empty() or used_ids.has(gid):
			gid = _generate_global_var_id() + "_%d" % i
			global_vars_data[i]["id"] = gid
		used_ids[gid] = true


func _get_global_usage_map() -> Dictionary:
	if not current_node or not current_node.has_meta("logic_bricks_global_usage"):
		return {}
	var usage = current_node.get_meta("logic_bricks_global_usage")
	return usage.duplicate(true) if usage is Dictionary else {}


func _is_global_used_in_current_script(var_data: Dictionary) -> bool:
	var gid = str(var_data.get("id", ""))
	if gid.is_empty():
		return false
	return bool(_get_global_usage_map().get(gid, false))


func _set_global_used_in_current_script(index: int, enabled: bool) -> void:
	if not current_node or index < 0 or index >= global_vars_data.size():
		return
	_ensure_global_var_ids()
	var gid = str(global_vars_data[index].get("id", ""))
	if gid.is_empty():
		return
	var usage = _get_global_usage_map()
	usage[gid] = enabled
	current_node.set_meta("logic_bricks_global_usage", usage)
	_mark_scene_modified()


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
	hint.text = "Shared across all nodes and all scenes (via GlobalVars autoload)"
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




func _create_states_tab() -> void:
	states_panel = VBoxContainer.new()
	states_panel.name = "States"
	states_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header = HBoxContainer.new()
	states_panel.add_child(header)

	var title = Label.new()
	title.text = "States"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title_font = title.get_theme_font("bold", "EditorFonts")
	if title_font:
		title.add_theme_font_override("font", title_font)
	header.add_child(title)

	var add_state_button = Button.new()
	add_state_button.text = "+ Add"
	add_state_button.pressed.connect(_on_add_state_pressed)
	header.add_child(add_state_button)

	states_panel.add_child(HSeparator.new())

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	states_panel.add_child(scroll)

	states_list = VBoxContainer.new()
	states_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(states_list)

	_refresh_states_ui()


func _sanitize_state_id(text_value: String) -> String:
	var sanitized_name = text_value.strip_edges().to_lower().replace(" ", "_")
	sanitized_name = sanitized_name.replace("-", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	sanitized_name = regex.sub(sanitized_name, "", true)
	if sanitized_name.is_empty():
		sanitized_name = "state"
	return sanitized_name


func _generate_unique_state_id(base_name: String) -> String:
	var candidate = _sanitize_state_id(base_name)
	var suffix = 1
	var existing: Dictionary = {}
	for state_data in states_data:
		existing[str(state_data.get("id", ""))] = true
	while existing.has(candidate):
		candidate = "%s_%d" % [_sanitize_state_id(base_name), suffix]
		suffix += 1
	return candidate


func _get_default_states() -> Array[Dictionary]:
	return [
		{
			"id": "state_1",
			"name": "State 1"
		}
	]


func _load_states_from_metadata() -> void:
	states_data.clear()
	if current_node and current_node.has_meta("logic_bricks_states"):
		var saved = current_node.get_meta("logic_bricks_states")
		if saved is Array:
			for state_data in saved:
				states_data.append(state_data.duplicate(true))
	if states_data.is_empty():
		states_data = _get_default_states()
		_save_states_to_metadata()
	_refresh_states_ui()
	_refresh_brick_state_ui()


func _save_states_to_metadata() -> void:
	if not current_node or not is_instance_valid(current_node):
		return
	current_node.set_meta("logic_bricks_states", states_data.duplicate(true))
	_mark_scene_modified()
	_save_graph_to_metadata()


func _refresh_states_ui() -> void:
	if not states_list:
		return
	for child in states_list.get_children():
		child.queue_free()
	for i in range(states_data.size()):
		_create_state_item_ui(i, states_data[i])


func _create_state_item_ui(index: int, state_data: Dictionary) -> void:
	var item_panel = PanelContainer.new()
	states_list.add_child(item_panel)

	var vbox = VBoxContainer.new()
	item_panel.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)

	var name_edit = LineEdit.new()
	name_edit.text = str(state_data.get("name", "State"))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_state_name_changed.bind(index))
	header.add_child(name_edit)

	var delete_btn = Button.new()
	delete_btn.text = "×"
	delete_btn.custom_minimum_size = Vector2(24, 0)
	delete_btn.tooltip_text = "Delete state"
	delete_btn.pressed.connect(_on_delete_state_pressed.bind(index))
	header.add_child(delete_btn)


func _on_add_state_pressed() -> void:
	var state_name = "State %d" % (states_data.size() + 1)
	var state_id = _generate_unique_state_id(state_name)
	states_data.append({
		"id": state_id,
		"name": state_name
	})
	_refresh_states_ui()
	_save_states_to_metadata()
	_refresh_brick_state_ui()


func _on_delete_state_pressed(index: int) -> void:
	if index < 0 or index >= states_data.size():
		return
	states_data.remove_at(index)
	if states_data.is_empty():
		states_data = _get_default_states()
	_refresh_states_ui()
	_save_states_to_metadata()
	_refresh_brick_state_ui()


func _on_state_name_changed(new_text: String, index: int) -> void:
	if index < 0 or index >= states_data.size():
		return
	states_data[index]["name"] = new_text
	_save_states_to_metadata()
	_refresh_brick_state_ui()


func get_state_options() -> Array:
	var result: Array = []
	for state_data in states_data:
		result.append({"id": str(state_data.get("id", "")), "name": str(state_data.get("name", ""))})
	return result


func get_state_display_name(state_id: String) -> String:
	for state_data in states_data:
		if str(state_data.get("id", "")) == state_id:
			return str(state_data.get("name", state_id))
	return state_id

func _enter_tree() -> void:
	# Set editor icons now that the theme is available
	if _copy_button:
		_copy_button.icon = get_theme_icon("ActionCopy", "EditorIcons")
		_copy_button.text = ""
	if _paste_button:
		_paste_button.icon = get_theme_icon("ActionPaste", "EditorIcons")
		_paste_button.text = ""
	_apply_side_tab_icons()


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
		_frames_helper.save_frames_to_metadata(self)
	
	current_node = node
	_update_ui()


func _update_ui() -> void:
	if not current_node:
		node_info_label.text = "No node selected - Select a 3D node in the scene tree"
		graph_edit.visible = false
		_apply_side_panel_visibility()
		if _instructions_label:
			_instructions_label.visible = true
		return
	
	# Check if node is supported
	if not _is_supported_node(current_node):
		node_info_label.text = "Unsupported node type: %s - Use Node3D, CharacterBody3D, or RigidBody3D" % current_node.get_class()
		graph_edit.visible = false
		_apply_side_panel_visibility()
		if _instructions_label:
			_instructions_label.visible = true
		return
	
	# Check if node is part of an instanced scene
	if _is_part_of_instance(current_node) and not _instance_override:
		node_info_label.text = "⚠ Instanced Node: %s" % current_node.name
		node_info_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
		graph_edit.visible = false
		_apply_side_panel_visibility()
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
	_apply_side_panel_visibility()
	if _instructions_label:
		_instructions_label.visible = false
	
	# Load states before building graph UI so state dropdowns have options immediately
	_load_states_from_metadata()
	await _load_graph_from_metadata()
	_frames_helper.load_frames_from_metadata(self)
	_load_variables_from_metadata()
	_refresh_brick_state_ui()


func _refresh_brick_state_ui() -> void:
	if not graph_edit or not _property_helper:
		return
	for child in graph_edit.get_children():
		if child is GraphNode and child.has_meta("brick_data"):
			var brick_data = child.get_meta("brick_data")
			var brick_instance = brick_data.get("brick_instance")
			if not brick_instance:
				continue
			var brick_type = str(brick_data.get("brick_type", ""))
			if brick_type in ["controller", "actuator"]:
				_property_helper._refresh_state_dropdown(child, brick_instance)
				if brick_type == "controller":
					_property_helper._update_controller_title(child, brick_instance)


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
	return _clipboard_helper.take_graph_snapshot()


## Restore a graph snapshot: write it back to metadata and rebuild the visual graph.
## The metadata write is synchronous; the visual rebuild is deferred one frame.
func _restore_graph_snapshot(snapshot: Dictionary) -> void:
	_clipboard_helper.restore_graph_snapshot(snapshot)


## Called deferred after a snapshot restore so the visual graph rebuilds cleanly
func _reload_graph_deferred() -> void:
	await _clipboard_helper.reload_graph_deferred()


## Record an undoable graph action.
## Call BEFORE making changes (before_snapshot) and AFTER (after_snapshot).
func _record_undo(action_name: String, before_snapshot: Dictionary, after_snapshot: Dictionary) -> void:
	_clipboard_helper.record_undo(action_name, before_snapshot, after_snapshot)


func _save_graph_to_metadata() -> void:
	_clipboard_helper.save_graph_to_metadata()


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
	elif id == 4:
		_open_search_popup(add_menu.position)
	elif id == 5:
		_on_rebuild_from_script_pressed()


func _open_search_popup(screen_pos: Vector2, initial_text: String = "") -> void:
	_search_helper.open_search_popup(screen_pos, initial_text)


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
		"ScriptController":
			script_path = "res://addons/logic_bricks/bricks/controllers/script_controller.gd"
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
		"SpriteFramesActuator":
			script_path = "res://addons/logic_bricks/bricks/actuators/3d/sprite_frames_actuator.gd"
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
		"PreloadActuator":
			script_path = "res://addons/logic_bricks/bricks/actuators/3d/preload_actuator.gd"
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
		"ObjectFlashActuator":
			script_path = "res://addons/logic_bricks/bricks/actuators/3d/object_flash_actuator.gd"
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
	_property_helper._create_brick_ui(graph_node, brick_instance)


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
	await _clipboard_helper.on_graph_node_context_menu(id, graph_node)


func _duplicate_graph_node(original_node: GraphNode) -> GraphNode:
	return await _clipboard_helper.duplicate_graph_node(original_node)


func _generate_unique_brick_name(base_name: String) -> String:
	return _clipboard_helper.generate_unique_brick_name(base_name)


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
		# Type-to-search: any printable character (no modifiers except Shift) opens the search popup
		elif not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
			var ch = event.as_text()
			# as_text() returns the printable character(s); skip special key names (len > 1 means it's e.g. "Escape", "F1", etc.)
			if ch.length() == 1 and ch.unicode_at(0) >= 32:
				# Store position under mouse for placing the new brick
				last_mouse_position = (graph_edit.get_local_mouse_position() + graph_edit.scroll_offset) / graph_edit.zoom
				var screen_pos = graph_edit.get_screen_position() + graph_edit.get_local_mouse_position()
				_open_search_popup(screen_pos, ch)
				graph_edit.accept_event()


func _duplicate_selected_nodes() -> void:
	await _clipboard_helper.duplicate_selected_nodes()


func _on_disconnection_request(from_node: String, from_port: int, to_node: String, to_port: int) -> void:
	var before_snapshot = _take_graph_snapshot()
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	_save_graph_to_metadata()
	_record_undo("Disconnect Logic Bricks", before_snapshot, _take_graph_snapshot())


func _on_delete_nodes_request(nodes: Array) -> void:
	_clipboard_helper.on_delete_nodes_request(nodes)


func _on_property_changed(value, graph_node: GraphNode, property_name: String) -> void:
	_property_helper._on_property_changed(value, graph_node, property_name)


func _update_controller_title(graph_node: GraphNode, brick_instance) -> void:
	_property_helper._update_controller_title(graph_node, brick_instance)


func _on_instance_name_changed(new_name: String, graph_node: GraphNode, brick_instance) -> void:
	_property_helper._on_instance_name_changed(new_name, graph_node, brick_instance)


func _on_debug_enabled_changed(enabled: bool, graph_node: GraphNode, brick_instance) -> void:
	_property_helper._on_debug_enabled_changed(enabled, graph_node, brick_instance)


func _on_debug_message_changed(new_message: String, graph_node: GraphNode, brick_instance) -> void:
	_property_helper._on_debug_message_changed(new_message, graph_node, brick_instance)


func _on_copy_bricks_pressed() -> void:
	_clipboard_helper.on_copy_bricks_pressed()


## Capture selected graph nodes and their internal connections
## into a portable dictionary that can be pasted onto any node.
func _capture_selection(selected_nodes: Array) -> Dictionary:
	return _clipboard_helper.capture_selection(selected_nodes)


func _on_paste_bricks_pressed() -> void:
	await _clipboard_helper.on_paste_bricks_pressed()


## Paste the selection clipboard into the current graph.
## Pasted nodes are offset slightly so they don't land on top of existing bricks.
## Internal connections are recreated. The clipboard is not cleared so the user
## can paste the same set multiple times or switch nodes and paste again.
func _paste_selection(clipboard: Dictionary) -> void:
	await _clipboard_helper.paste_selection(clipboard)


func _on_view_chain_code(controller_node: GraphNode) -> void:
	# Open the generated script and jump to this chain's function
	if not current_node or not editor_interface:
		return
	
	var script = current_node.get_script()
	if not script:
		push_warning("Logic Bricks: No script on this node. Click 'Apply Code' first.")
		return
	
	# Get chain name from controller node
	var chain_name = _graph_helper.get_chain_name_for_controller(controller_node)
	var func_name = "_logic_brick_%s" % chain_name
	
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


func _on_rebuild_metadata_pressed() -> void:
	if not current_node:
		push_error("Logic Bricks: No node selected!")
		return

	if not manager:
		push_error("Logic Bricks: Manager not initialized!")
		return

	if not current_node.has_meta("logic_bricks_graph"):
		push_warning("Logic Bricks: No saved graph metadata found on this node.")
		return

	await _load_graph_from_metadata()
	await get_tree().process_frame
	_graph_helper.sync_graph_ui_to_bricks()

	var chains = _graph_helper.extract_chains_from_graph(true)
	if chains.is_empty():
		push_warning("Logic Bricks: Could not rebuild metadata because no controller-rooted chains were found in the saved graph.")
		return

	manager.save_chains(current_node, chains)

	var complete_count := 0
	for chain in chains:
		var controllers = chain.get("controllers", [])
		var is_script_controller = controllers.size() > 0 and controllers[0].get("type", "") == "ScriptController"
		var has_sensors = chain.get("sensors", []).size() > 0
		var has_actuators = chain.get("actuators", []).size() > 0
		if has_sensors and (has_actuators or is_script_controller):
			complete_count += 1

	if complete_count < chains.size():
		push_warning("Logic Bricks: Rebuilt %d chain(s) from graph data, but %d are incomplete and will not generate code until their connections are restored." % [chains.size(), chains.size() - complete_count])
	else:
		print("Logic Bricks: Rebuilt logic_bricks metadata for %s from saved graph data." % current_node.name)


func _on_rebuild_from_script_pressed() -> void:
	if not current_node:
		push_error("Logic Bricks: No node selected!")
		return
	if not manager:
		push_error("Logic Bricks: Manager not initialized!")
		return
	await _script_rebuild_helper.rebuild_from_script()


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
	
	_graph_helper.sync_graph_ui_to_bricks()
	_save_graph_to_metadata()
	
	# Extract chains
	var chains = _graph_helper.extract_chains_from_graph()
	
	# Clear old metadata
	if current_node.has_meta("logic_bricks"):
		current_node.remove_meta("logic_bricks")
	
	if not current_node.get_script():
		push_error("Logic Bricks: Selected node has no script. Add a script manually before applying Logic Bricks code.")
		return
	
	# Get script path before regeneration
	var script_path = current_node.get_script().resource_path
	
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
		"id": _generate_global_var_id(),
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
	_ensure_global_var_ids()
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
	var type_index = 1
	match var_data["type"]:
		"bool": type_index = 0
		"int":  type_index = 1
		"float": type_index = 2
		"String": type_index = 3
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
	value_edit.text = _value_to_line_edit_text(var_data.get("value", _get_default_value_for_variable_type(var_data.get("type", "int"))))
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
		var type_names = ["bool", "int", "float", "String"]
		var new_type = type_names[type_index]
		variables_data[index]["type"] = new_type
		variables_data[index]["value"] = _coerce_variable_value_for_type(variables_data[index].get("value", _get_default_value_for_variable_type(new_type)), new_type)
		# Update the display label
		name_display.text = "%s: %s" % [variables_data[index]["name"], new_type]
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
	var type_index = 1
	match var_data.get("type", "int"):
		"bool":   type_index = 0
		"int":    type_index = 1
		"float":  type_index = 2
		"String": type_index = 3
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
	value_edit.text = _value_to_line_edit_text(var_data.get("value", _get_default_value_for_variable_type(var_data.get("type", "int"))))
	value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_edit.text_changed.connect(_on_global_variable_value_changed.bind(index))
	row3.add_child(value_edit)

	# Per-script usage
	var row_use = HBoxContainer.new()
	details.add_child(row_use)
	var use_check = CheckBox.new()
	use_check.text = "Use in this script"
	use_check.button_pressed = _is_global_used_in_current_script(var_data)
	use_check.toggled.connect(_on_global_variable_use_in_script_toggled.bind(index))
	row_use.add_child(use_check)
	
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
		var type_names = ["bool", "int", "float", "String"]
		var new_type = type_names[type_index]
		global_vars_data[index]["type"] = new_type
		global_vars_data[index]["value"] = _coerce_variable_value_for_type(global_vars_data[index].get("value", _get_default_value_for_variable_type(new_type)), new_type)
		name_display.text = "%s: %s" % [global_vars_data[index].get("name", ""), new_type]
		_save_global_vars_to_metadata()
		_refresh_global_vars_ui()


func _on_global_variable_value_changed(new_value: String, index: int) -> void:
	if index < global_vars_data.size():
		global_vars_data[index]["value"] = new_value
		_save_global_vars_to_metadata()


func _on_global_variable_use_in_script_toggled(enabled: bool, index: int) -> void:
	_set_global_used_in_current_script(index, enabled)


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
		var removed_id = str(global_vars_data[index].get("id", ""))
		global_vars_data.remove_at(index)
		if current_node and not removed_id.is_empty():
			var usage = _get_global_usage_map()
			if usage.has(removed_id):
				usage.erase(removed_id)
				current_node.set_meta("logic_bricks_global_usage", usage)
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
	
	_ensure_global_var_ids()
	# Global variables live on the scene root — single source of truth, no duplication
	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	
	scene_root.set_meta("logic_bricks_global_vars", global_vars_data.duplicate())
	_mark_scene_modified()
	_update_global_vars_script()


func _update_global_vars_script() -> void:
	var script_path = "res://addons/logic_bricks/global_vars.gd"
	
	# Merge global_vars_data with whatever is already on disk.
	# This prevents a scene that has no globals metadata from wiping variables
	# that were defined in other scenes.
	var merged: Array[Dictionary] = []
	var merged_names: Array[String] = []
	
	# Start with current scene's data (highest priority — newest edit wins)
	for var_data in global_vars_data:
		var vname = var_data.get("name", "")
		if not vname.is_empty() and vname not in merged_names:
			merged.append(var_data.duplicate())
			merged_names.append(vname)
	
	# Fill in any variables from disk that this scene doesn't define
	for disk_var in _read_global_vars_from_script():
		var vname = disk_var.get("name", "")
		if not vname.is_empty() and vname not in merged_names:
			merged.append(disk_var)
			merged_names.append(vname)
	
	if merged.is_empty():
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
	
	for var_data in merged:
		var var_name  = var_data.get("name", "")
		var var_type  = VariableUtils.normalize_type(str(var_data.get("type", "int")))
		var var_value = _to_gdscript_value_literal(var_data.get("value", _get_default_value_for_variable_type(var_type)), var_type)
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


func _read_global_vars_from_script() -> Array[Dictionary]:
	# Parse global_vars.gd from disk and return its declared variables as an Array of Dictionaries.
	# This is used to seed scenes that have no globals metadata yet, and to merge on save,
	# so that globals defined in one scene are never lost when editing another scene.
	var result: Array[Dictionary] = []
	var script_path = "res://addons/logic_bricks/global_vars.gd"
	var file = FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return result
	var text = file.get_as_text()
	file.close()
	
	var in_block = false
	for raw_line in text.split("\n"):
		var line = raw_line.strip_edges()
		if line == "# === LOGIC BRICKS GLOBALS START ===":
			in_block = true
			continue
		if line == "# === LOGIC BRICKS GLOBALS END ===":
			break
		if not in_block:
			continue
		if not line.begins_with("var "):
			continue
		# Parse:  var <name>: <type> = <value>
		var after_var = line.substr(4)  # strip "var "
		var colon = after_var.find(":")
		var eq    = after_var.find("=")
		if colon == -1 or eq == -1:
			continue
		var vname = after_var.substr(0, colon).strip_edges()
		var vtype = after_var.substr(colon + 1, eq - colon - 1).strip_edges()
		var vval  = after_var.substr(eq + 1).strip_edges()
		if vname.is_empty():
			continue
		var normalized_type = VariableUtils.normalize_type(vtype)
		var parsed_value = VariableUtils.parse_gdscript_value_literal(vval, normalized_type)
		result.append({"name": vname, "type": normalized_type, "value": parsed_value})
	return result


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
	
	# Load global variables — prefer scene root metadata, fall back to global_vars.gd on disk.
	# This ensures scenes that have never had their Globals tab opened still see all globals
	# defined in other scenes, so variables persist correctly across scene transitions.
	if editor_interface:
		var scene_root = editor_interface.get_edited_scene_root()
		if scene_root and scene_root.has_meta("logic_bricks_global_vars"):
			var saved_globals = scene_root.get_meta("logic_bricks_global_vars")
			if saved_globals is Array:
				for var_data in saved_globals:
					global_vars_data.append(var_data.duplicate())
		else:
			# This scene has no globals metadata yet — read whatever is already in global_vars.gd
			# so the tab shows (and preserves) variables created in other scenes.
			var disk_globals = _read_global_vars_from_script()
			for var_data in disk_globals:
				global_vars_data.append(var_data)
			# If we loaded anything from disk, seed this scene root's metadata so future
			# saves from this scene don't accidentally wipe variables set elsewhere.
			if not global_vars_data.is_empty() and scene_root:
				scene_root.set_meta("logic_bricks_global_vars", global_vars_data.duplicate())

	_ensure_global_var_ids()

	# Backward compatibility: migrate any legacy globals stored on the node into the usage map.
	if current_node.has_meta("logic_bricks_variables"):
		var legacy_vars = current_node.get_meta("logic_bricks_variables")
		if legacy_vars is Array:
			var usage_map = _get_global_usage_map()
			var usage_changed = false
			for legacy_var in legacy_vars:
				if not legacy_var.get("global", false):
					continue
				var legacy_name = str(legacy_var.get("name", ""))
				if legacy_name.is_empty():
					continue
				for global_var in global_vars_data:
					if str(global_var.get("name", "")) == legacy_name:
						var gid = str(global_var.get("id", ""))
						if not gid.is_empty() and not usage_map.has(gid):
							usage_map[gid] = true
							usage_changed = true
						break
			if usage_changed:
				current_node.set_meta("logic_bricks_global_usage", usage_map)

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


func _get_default_value_for_variable_type(var_type: String) -> String:
	return VariableUtils.get_default_value_for_variable_type(var_type)


func _coerce_variable_value_for_type(value, var_type: String) -> String:
	return VariableUtils.coerce_variable_value_for_type(value, var_type)


func _value_to_line_edit_text(value) -> String:
	return VariableUtils.value_to_line_edit_text(value)


func _to_gdscript_value_literal(value, var_type: String) -> String:
	return VariableUtils.to_gdscript_value_literal(value, var_type)


func get_variables_code() -> String:
	var lines: Array[String] = []
	var used_globals: Array[Dictionary] = []
	for var_data in global_vars_data:
		if _is_global_used_in_current_script(var_data):
			used_globals.append(var_data)

	if not variables_data.is_empty() or not used_globals.is_empty():
		lines.append("# Variables")
	
	# Local variables only
	for var_data in variables_data:
		var var_name  = var_data.get("name", "")
		var var_type  = var_data.get("type", "int")
		var var_value = _to_gdscript_value_literal(var_data.get("value", _get_default_value_for_variable_type(var_type)), var_type)
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
	
	for var_data in used_globals:
		var var_name = var_data.get("name", "")
		var var_type = var_data.get("type", "int")
		var use_min = var_data.get("use_min", false)
		var min_val = var_data.get("min_val", "0")
		var use_max = var_data.get("use_max", false)
		var max_val = var_data.get("max_val", "100")
		if var_name.is_empty():
			continue
		lines.append("var %s: %s:" % [var_name, var_type])
		lines.append("	get:")
		lines.append("		var _gv = get_node_or_null(\"/root/GlobalVars\")")
		lines.append("		return _gv.%s if _gv else null" % var_name)
		lines.append("	set(val):")
		lines.append("		var _gv = get_node_or_null(\"/root/GlobalVars\")")
		if var_type in ["int", "float"] and (use_min or use_max):
			var clamp_expr = _build_clamp_expr("val", var_type, use_min, min_val, use_max, max_val)
			lines.append("		if _gv: _gv.%s = %s" % [var_name, clamp_expr])
		else:
			lines.append("		if _gv: _gv.%s = val" % var_name)

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
	_frames_helper.on_add_frame_pressed(self)


## Handle frame click to select it in side panel (DISABLED - was blocking editor input)
#func _on_frame_gui_input(event: InputEvent, frame: GraphFrame) -> void:
#    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
#        _select_frame_in_side_panel(frame)





## Handle brick node being dragged
func _on_brick_node_dragged(from: Vector2, to: Vector2, node: GraphNode) -> void:
	# Check if node entered/left any frames
	_frames_helper.check_node_frame_membership(self, node)
	
	# Auto-resize frames that contain this node
	for frame_name in frame_node_mapping.keys():
		if node.name in frame_node_mapping[frame_name]:
			var frame = graph_edit.get_node_or_null(NodePath(frame_name))
			if frame and frame is GraphFrame:
				_frames_helper.auto_resize_frame(self, frame)
	
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
	_frames_helper.on_frame_dragged(self, from, to, frame)

## Handle frame resize
func _on_frame_resize_request(new_size: Vector2, frame: GraphFrame) -> void:
	_frames_helper.on_frame_resize_request(self, new_size, frame)




## Frame Panel Callbacks

func _update_frames_list() -> void:
	_frames_helper.update_frames_list(self)


func _save_frames_to_metadata() -> void:
	_frames_helper.save_frames_to_metadata(self)


func _update_frame_settings_ui() -> void:
	_frames_helper.update_frame_settings_ui(self)


func _select_frame_in_side_panel(frame: GraphFrame) -> void:
	_frames_helper.select_frame_in_side_panel(self, frame)


func _on_frame_list_item_selected(index: int) -> void:
	_frames_helper.on_frame_list_item_selected(self, index)


func _on_frame_name_changed(new_name: String) -> void:
	_frames_helper.on_frame_name_changed(self, new_name)

func _on_frame_color_changed(new_color: Color) -> void:
	_frames_helper.on_frame_color_changed(self, new_color)

func _on_frame_resize_pressed() -> void:
	_frames_helper.on_frame_resize_pressed(self)

func _on_frame_width_changed(new_width: float) -> void:
	_frames_helper.on_frame_width_changed(self, new_width)

func _on_frame_height_changed(new_height: float) -> void:
	_frames_helper.on_frame_height_changed(self, new_height)

func _on_frame_delete_pressed() -> void:
	_frames_helper.on_frame_delete_pressed(self)



func _on_frame_list_item_activated(index: int) -> void:
	_frames_helper.on_frame_list_item_activated(self, index)

func _on_frame_rename_button_pressed() -> void:
	_frames_helper.on_frame_rename_button_pressed(self)

func _on_rename_dialog_confirmed(dialog: AcceptDialog, line_edit: LineEdit) -> void:
	_frames_helper.on_rename_dialog_confirmed(self, dialog, line_edit)

func _on_rename_dialog_canceled(dialog: AcceptDialog) -> void:
	_frames_helper.on_rename_dialog_canceled(self, dialog)

func _on_frame_list_color_changed(new_color: Color) -> void:
	_frames_helper.on_frame_list_color_changed(self, new_color)

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

			# Full-screen flash layers should stretch with the viewport instead of
			# relying on a one-time editor size snapshot.
			color_rect.anchor_left   = 0.0
			color_rect.anchor_top    = 0.0
			color_rect.anchor_right  = 1.0
			color_rect.anchor_bottom = 1.0
			color_rect.offset_left   = 0.0
			color_rect.offset_top    = 0.0
			color_rect.offset_right  = 0.0
			color_rect.offset_bottom = 0.0
			color_rect.position      = Vector2.ZERO
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
