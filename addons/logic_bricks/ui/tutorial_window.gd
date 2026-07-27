@tool
extends Window

const IMAGE_DIR := "res://addons/logic_bricks/tutorial/images/"

var _lesson_list: ItemList
var _title_label: Label
var _image: TextureRect
var _video: VideoStreamPlayer
var _body: RichTextLabel
var _progress: Label
var _previous_button: Button
var _next_button: Button
var _lesson_index := 0
var _image_error: Label

var _lessons: Array[Dictionary] = [
	{
		"title": "Welcome to Logic Bricks",
		"image": "01_welcome.png",
		"body": "[font_size=18]Logic Bricks is a visual scripting system for Godot. It lets you create game behavior by connecting sensors, controllers, and actuators instead of writing every line of code yourself.[/font_size]\n\nUse this tutorial to learn the basic workflow and the ideas that appear in nearly every Logic Bricks graph."
	},
	{
		"title": "Before You Begin: Attach a Script",
		"image": "02_attach_script.png",
		"body": "[font_size=18][b]A node must have a script attached before Logic Bricks can be used on it.[/b][/font_size]\n\n1. Select a 3D, 2D, or UI node in the Scene tree.\n2. Click Godot's [b]Attach Script[/b] button.\n3. Create or attach a GDScript file.\n4. Open the Logic Bricks bottom panel and begin adding bricks.\n\nThe script is where Logic Bricks stores the generated game logic. If the selected node has no script, attach one first."
	},
	{
		"title": "The Logic Bricks Window",
		"image": "03_window_overview.png",
		"body": "The large center area is the graph where you place and connect bricks. Right-click the graph to add a brick.\n\nThe side panel contains variables, global variables, states, and frames. The toolbar includes graph organization and code-generation tools."
	},
	{
		"title": "The Four Building Blocks",
		"image": "04_brick_types.png",
		"body": "[b]Sensors[/b] detect events or conditions, such as a key press, a timer, or a collision.\n\n[b]Controllers[/b] decide whether connected sensor results should allow the chain to continue.\n\n[b]Actuators[/b] perform actions, such as moving a character, changing a property, playing audio, or sending a signal.\n\n[b]Variables[/b] store information such as health, speed, names, positions, and true/false values."
	},
	{
		"title": "Controllers and Logic Gates",
		"image": "05_controller_and.png",
		"body": "Controllers sit between sensors and actuators. Their gate determines how multiple sensor results are combined.\n\n[b]AND[/b] — Every connected sensor must be true. Example: Space is pressed [i]and[/i] the character is on the floor.\n\n[b]OR[/b] — At least one connected sensor must be true. Example: keyboard input [i]or[/i] controller input can open a menu.\n\n[b]NAND[/b] — Fires unless every connected sensor is true. It is the opposite of AND.\n\n[b]NOR[/b] — Fires only when none of the connected sensors are true. It is the opposite of OR.\n\n[b]XOR[/b] — Exactly one connected sensor must be true. If two or more are true at the same time, the chain does not fire.\n\nMost beginner chains use AND. Choose another gate when the relationship between multiple sensors requires it."
	},
	{
		"title": "Create Your First Graph",
		"image": "10_first_graph.png",
		"body": "Start with one sensor, one controller, and one actuator.\n\nExample: connect a Ready sensor to an AND controller, then connect the controller to a Print actuator. Apply the code and run the scene.\n\nThis simple chain teaches the full pattern: [b]detect → decide → act[/b]."
	},
	{
		"title": "Connecting Bricks",
		"image": "11_connections.png",
		"body": "Drag from an output port to a compatible input port. A typical chain flows from sensors into a controller and then into one or more actuators.\n\nConnections describe execution flow. Keep graphs moving in a consistent direction so they are easy to read."
	},
	{
		"title": "Choosing Target Nodes",
		"image": "12_target_nodes.png",
		"body": "Many actuators need to know which node should be affected.\n\n[b]Self[/b] targets the node that owns the Logic Bricks graph.\n\n[b]Node[/b] targets a specific node path.\n\n[b]Group[/b] targets nodes assigned to a Godot group.\n\nAlways verify the target when a brick appears to run but nothing changes."
	},
	{
		"title": "Variables",
		"image": "13_variables.png",
		"body": "Variables store values that can be reused or changed while the game runs.\n\nUse [b]int[/b] for whole numbers, [b]float[/b] for decimal values, [b]bool[/b] for true/false states, [b]String[/b] for text, and [b]Vector2/Vector3[/b] for positions, directions, rotations, and scales.\n\nLocal variables belong to one node. Global variables can be shared across the scene."
	},
	{
		"title": "Getting and Reusing Data",
		"image": "14_get_transform.png",
		"body": "Some actuators read information and store it in variables. For example, Get Transform can capture a node's position, rotation, or scale.\n\nThat stored vector can then be used by another actuator, such as Move Towards or Set Transforms. This is how separate bricks share changing game data."
	},
	{
		"title": "Signals Between Nodes",
		"image": "15_signals.png",
		"body": "Signals let one object announce that something happened without directly controlling every other object.\n\nFor example, a button can send a signal and a door can react to it. This keeps each object's graph focused on its own job and makes scenes easier to reuse."
	},
	{
		"title": "2D, 3D, and UI Nodes",
		"image": "16_2d_3d_ui.png",
		"body": "Logic Bricks supports 3D nodes, 2D nodes, and UI Control nodes. The available bricks change to match the selected node type.\n\nChoose bricks designed for the current domain—for example, CharacterBody2D movement for a 2D character and UI actuators for Control nodes."
	},
	{
		"title": "Organizing Graphs",
		"image": "17_graph_organization.png",
		"body": "Use frames to group related chains and label what they do. Keep related sensors, controllers, and actuators close together.\n\nA readable graph is easier to debug, teach, and change later. Split unrelated behavior into separate chains rather than building one enormous chain."
	},
	{
		"title": "Debugging Common Problems",
		"image": "18_debugging.png",
		"body": "When something does not work, check these items first:\n\n• Does the node have a script attached?\n• Is the correct node selected?\n• Is the sensor able to become true?\n• Are the bricks connected in the correct order?\n• Is the controller gate appropriate?\n• Does the actuator target the intended node?\n• Are variable names and types correct?\n• Did you click Apply Code after making changes?"
	},
	{
		"title": "What to Build Next",
		"image": "19_next_steps.png",
		"body": "Practice by building small systems:\n\n• A key that opens a door\n• A character that jumps\n• A moving platform\n• A health pickup\n• An enemy patrol\n• A UI button that changes scenes\n\nBuild one behavior at a time, test it, and then combine working chains into a larger game."
	}
]

func _init() -> void:
	title = "Logic Bricks — Getting Started"
	size = Vector2i(1050, 720)
	min_size = Vector2i(800, 560)
	transient = true
	close_requested.connect(_on_close_requested)
	_build_ui()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	margin.add_child(root)

	var heading := Label.new()
	heading.text = "Getting Started with Logic Bricks"
	heading.add_theme_font_size_override("font_size", 24)
	root.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "Learn the core workflow, controller gates, variables, signals, and common troubleshooting steps."
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(subtitle)
	root.add_child(HSeparator.new())

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 250
	root.add_child(split)

	_lesson_list = ItemList.new()
	_lesson_list.custom_minimum_size.x = 240
	_lesson_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for lesson in _lessons:
		_lesson_list.add_item(lesson["title"])
	_lesson_list.item_selected.connect(_on_lesson_selected)
	split.add_child(_lesson_list)

	var content_scroll := ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(content_scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(content)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_title_label)

	var media_container := Control.new()
	media_container.custom_minimum_size = Vector2(0, 280)
	media_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(media_container)

	_image = TextureRect.new()
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	media_container.add_child(_image)

	_video = VideoStreamPlayer.new()
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_video.expand = true
	_video.autoplay = false
	_video.loop = true
	_video.volume_db = -80.0
	_video.visible = false
	media_container.add_child(_video)

	_image_error = Label.new()
	_image_error.visible = false
	_image_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_image_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_image_error)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.custom_minimum_size.y = 240
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_font_size_override("normal_font_size", 16)
	content.add_child(_body)

	root.add_child(HSeparator.new())
	var nav := HBoxContainer.new()
	root.add_child(nav)

	_progress = Label.new()
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_progress)

	_previous_button = Button.new()
	_previous_button.text = "Previous"
	_previous_button.pressed.connect(_on_previous_pressed)
	nav.add_child(_previous_button)

	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.pressed.connect(_on_next_pressed)
	nav.add_child(_next_button)

	_lesson_list.select(0)
	_show_lesson(0)

func open_tutorial() -> void:
	popup_centered()
	_show_lesson(_lesson_index)
	grab_focus()

func _on_close_requested() -> void:
	_stop_media()
	hide()

func _on_lesson_selected(index: int) -> void:
	_show_lesson(index)

func _on_previous_pressed() -> void:
	_show_lesson(maxi(0, _lesson_index - 1))

func _on_next_pressed() -> void:
	_show_lesson(mini(_lessons.size() - 1, _lesson_index + 1))

func _show_lesson(index: int) -> void:
	_lesson_index = clampi(index, 0, _lessons.size() - 1)
	var lesson := _lessons[_lesson_index]
	_title_label.text = lesson["title"]
	_body.text = lesson["body"]
	_progress.text = "Lesson %d of %d" % [_lesson_index + 1, _lessons.size()]
	_previous_button.disabled = _lesson_index == 0
	_next_button.disabled = _lesson_index == _lessons.size() - 1
	_lesson_list.select(_lesson_index)

	_load_lesson_image(str(lesson["image"]))

func _load_lesson_image(configured_filename: String) -> void:
	_stop_media()
	_image_error.visible = false
	_image_error.text = ""

	var base_name := configured_filename.get_basename()
	# Prefer a native Godot Ogg Theora video, then fall back to a still image.
	# A WebM candidate is also accepted when the project has a compatible importer.
	var video_candidates := PackedStringArray([
		IMAGE_DIR + base_name + ".ogv",
		IMAGE_DIR + base_name + ".webm"
	])
	for path in video_candidates:
		if not ResourceLoader.exists(path):
			continue
		var stream := ResourceLoader.load(path)
		if stream is VideoStream:
			_video.stream = stream
			_video.visible = true
			_video.play()
			return

	var image_candidates := PackedStringArray([
		IMAGE_DIR + base_name + ".png",
		IMAGE_DIR + base_name + ".webp",
		IMAGE_DIR + base_name + ".jpg",
		IMAGE_DIR + base_name + ".jpeg"
	])
	for path in image_candidates:
		if not ResourceLoader.exists(path):
			continue
		var texture := ResourceLoader.load(path)
		if texture is Texture2D:
			_image.texture = texture
			_image.visible = true
			return

	_image_error.text = "Tutorial media not found. Add %s.ogv or keep the PNG placeholder." % base_name
	_image_error.visible = true

func _stop_media() -> void:
	if _video != null:
		_video.stop()
		_video.stream = null
		_video.visible = false
	if _image != null:
		_image.texture = null
		_image.visible = false

