extends RefCounted

const SEARCH_BRICKS: Array = [
    ["Actuator", "sensor", "ActuatorSensor"],
    ["Always", "sensor", "AlwaysSensor"],
    ["Animation Tree", "sensor", "AnimationTreeSensor"],
    ["Collision", "sensor", "CollisionSensor"],
    ["Compare Variable", "sensor", "VariableSensor"],
    ["Delay", "sensor", "DelaySensor"],
    ["InputMap", "sensor", "InputMapSensor"],
    ["Message", "sensor", "MessageSensor"],
    ["Mouse", "sensor", "MouseSensor"],
    ["Movement", "sensor", "MovementSensor"],
    ["Proximity", "sensor", "ProximitySensor"],
    ["Random", "sensor", "RandomSensor"],
    ["Raycast", "sensor", "RaycastSensor"],
    ["Controller", "controller", "Controller"],
    ["Animation", "actuator", "AnimationActuator"],
    ["Animation Tree", "actuator", "AnimationTreeActuator"],
    ["Sprite Frames", "actuator", "SpriteFramesActuator"],
    ["Motion", "actuator", "MotionActuator"],
    ["Character", "actuator", "CharacterActuator"],
    ["Look At Movement", "actuator", "LookAtMovementActuator"],
    ["Rotate Towards", "actuator", "RotateTowardsActuator"],
    ["Waypoint Path", "actuator", "WaypointPathActuator"],
    ["Move Towards", "actuator", "MoveTowardsActuator"],
    ["Teleport", "actuator", "TeleportActuator"],
    ["Mouse", "actuator", "MouseActuator"],
    ["Physics", "actuator", "PhysicsActuator"],
    ["Force", "actuator", "ForceActuator"],
    ["Torque", "actuator", "TorqueActuator"],
    ["Linear Velocity", "actuator", "LinearVelocityActuator"],
    ["Impulse", "actuator", "ImpulseActuator"],
    ["Collision", "actuator", "CollisionActuator"],
    ["Edit Object", "actuator", "EditObjectActuator"],
    ["Object Pool", "actuator", "ObjectPoolActuator"],
    ["Parent", "actuator", "ParentActuator"],
    ["Property", "actuator", "PropertyActuator"],
    ["Visibility", "actuator", "VisibilityActuator"],
    ["Environment", "actuator", "EnvironmentActuator"],
    ["Light", "actuator", "LightActuator"],
    ["Set Camera", "actuator", "SetCameraActuator"],
    ["Smooth Follow Camera", "actuator", "SmoothFollowCameraActuator"],
    ["Camera Zoom", "actuator", "CameraZoomActuator"],
    ["Screen Shake", "actuator", "ScreenShakeActuator"],
    ["3rd Person Camera", "actuator", "ThirdPersonCameraActuator"],
    ["Split Screen", "actuator", "SplitScreenActuator"],
    ["Audio 3D", "actuator", "SoundActuator"],
    ["Audio 2D", "actuator", "Audio2DActuator"],
    ["Music", "actuator", "MusicActuator"],
    ["Screen Flash", "actuator", "ScreenFlashActuator"],
    ["Object Flash", "actuator", "ObjectFlashActuator"],
    ["Rumble", "actuator", "RumbleActuator"],
    ["Text", "actuator", "TextActuator"],
    ["Modulate", "actuator", "ModulateActuator"],
    ["Progress Bar", "actuator", "ProgressBarActuator"],
    ["Tween", "actuator", "TweenActuator"],
    ["State", "actuator", "StateActuator"],
    ["Random", "actuator", "RandomActuator"],
    ["Message", "actuator", "MessageActuator"],
    ["Modify Variable", "actuator", "VariableActuator"],
    ["Game", "actuator", "GameActuator"],
    ["Scene", "actuator", "SceneActuator"],
    ["Save / Load", "actuator", "SaveLoadActuator"],
    ["Preload", "actuator", "PreloadActuator"],
]

const SEARCH_TYPE_COLORS: Dictionary = {
    "sensor":     Color(0.2, 0.55, 0.2,  0.9),
    "controller": Color(0.2, 0.3,  0.75, 0.9),
    "actuator":   Color(0.6, 0.3,  0.1,  0.9),
}

var panel = null
var search_popup: PopupPanel = null
var search_selected_index: int = -1
var search_result_buttons: Array = []
var search_edit_ref: LineEdit = null
var search_results_ref: VBoxContainer = null
var search_scroll_ref: ScrollContainer = null
var search_no_results_ref: Label = null

func setup(target_panel) -> void:
    panel = target_panel

func open_search_popup(screen_pos: Vector2, initial_text: String = "") -> void:
    if not is_instance_valid(search_popup):
        _build_search_popup()

    if is_instance_valid(search_edit_ref):
        search_edit_ref.text = initial_text
        search_edit_ref.caret_column = initial_text.length()

    _search_update_results(initial_text)

    var screen_size = DisplayServer.screen_get_size()
    search_popup.reset_size()
    var pop_size = Vector2(search_popup.size)
    if pop_size == Vector2.ZERO:
        pop_size = Vector2(456, 300)
    var pos = screen_pos
    if pos.x + pop_size.x > screen_size.x:
        pos.x = screen_size.x - pop_size.x - 8
    if pos.y + pop_size.y > screen_size.y:
        pos.y = screen_size.y - pop_size.y - 8
    search_popup.position = Vector2i(pos)
    search_popup.popup()

    if is_instance_valid(search_edit_ref):
        search_edit_ref.call_deferred("grab_focus")

func _build_search_popup() -> void:
    search_popup = PopupPanel.new()
    search_popup.name = "BrickSearchPopup"
    search_popup.exclusive = false
    search_popup.unresizable = true

    var vbox = VBoxContainer.new()
    vbox.name = "VBox"
    vbox.add_theme_constant_override("separation", 4)
    vbox.custom_minimum_size = Vector2(440, 0)
    search_popup.add_child(vbox)

    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    vbox.add_child(row)

    var icon_lbl = Label.new()
    icon_lbl.text = "🔍"
    row.add_child(icon_lbl)

    var edit = LineEdit.new()
    edit.name = "SearchEdit"
    edit.placeholder_text = "Search bricks…"
    edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    edit.clear_button_enabled = true
    edit.text_changed.connect(_search_on_text_changed)
    edit.gui_input.connect(_search_on_key)
    row.add_child(edit)
    search_edit_ref = edit

    var scroll = ScrollContainer.new()
    scroll.name = "Scroll"
    scroll.custom_minimum_size = Vector2(440, 0)
    scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vbox.add_child(scroll)
    search_scroll_ref = scroll

    var results = VBoxContainer.new()
    results.name = "Results"
    results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    results.add_theme_constant_override("separation", 2)
    scroll.add_child(results)
    search_results_ref = results

    var no_results = Label.new()
    no_results.name = "NoResults"
    no_results.text = "No matching bricks found."
    no_results.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    no_results.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
    no_results.visible = false
    vbox.add_child(no_results)
    search_no_results_ref = no_results

    panel.add_child(search_popup)

func _search_on_text_changed(text: String) -> void:
    _search_update_results(text)

func _search_on_key(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed:
        return
    var n = search_result_buttons.size()
    if n == 0:
        if event.keycode == KEY_ESCAPE and is_instance_valid(search_popup):
            search_popup.hide()
        return
    match event.keycode:
        KEY_DOWN:
            _search_set_selected((search_selected_index + 1) % n)
            if is_instance_valid(search_edit_ref):
                search_edit_ref.accept_event()
        KEY_UP:
            _search_set_selected((search_selected_index - 1 + n) % n)
            if is_instance_valid(search_edit_ref):
                search_edit_ref.accept_event()
        KEY_ENTER, KEY_KP_ENTER:
            if search_selected_index >= 0 and search_selected_index < n:
                search_result_buttons[search_selected_index].pressed.emit()
            if is_instance_valid(search_edit_ref):
                search_edit_ref.accept_event()
        KEY_ESCAPE:
            if is_instance_valid(search_popup):
                search_popup.hide()
            if is_instance_valid(search_edit_ref):
                search_edit_ref.accept_event()

func _search_update_results(query: String) -> void:
    if not is_instance_valid(search_popup) or not is_instance_valid(search_results_ref):
        return

    for child in search_results_ref.get_children():
        child.queue_free()
    search_result_buttons.clear()
    search_selected_index = -1

    var scored: Array = []
    for brick in SEARCH_BRICKS:
        var s = _search_score(query, brick[0], brick[1])
        if s > 0.0:
            scored.append([s, brick])
    scored.sort_custom(func(a, b): return a[0] > b[0])

    var show_count = mini(scored.size(), 12)
    for i in range(show_count):
        var btn = _search_make_button(scored[i][1], i)
        search_results_ref.add_child(btn)
        search_result_buttons.append(btn)

    if is_instance_valid(search_no_results_ref):
        search_no_results_ref.visible = (show_count == 0 and not query.is_empty())

    if is_instance_valid(search_scroll_ref):
        search_scroll_ref.custom_minimum_size = Vector2(440, mini(show_count, 12) * 36 + 4)

    search_popup.reset_size()

    if search_result_buttons.size() > 0:
        _search_set_selected(0)

func _search_make_button(brick: Array, index: int) -> Button:
    var display_name: String = brick[0]
    var brick_type: String = brick[1]
    var brick_class: String = brick[2]

    var btn = Button.new()
    btn.flat = true
    btn.custom_minimum_size = Vector2(440, 34)
    btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
    btn.focus_mode = Control.FOCUS_NONE
    btn.pressed.connect(_on_search_brick_selected.bind(brick_type, brick_class))
    btn.mouse_entered.connect(_search_set_selected.bind(index))

    var hbox = HBoxContainer.new()
    hbox.add_theme_constant_override("separation", 8)
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    btn.add_child(hbox)

    var sp = Control.new()
    sp.custom_minimum_size = Vector2(4, 0)
    sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.add_child(sp)

    var badge = Label.new()
    badge.text = brick_type.capitalize()
    badge.custom_minimum_size = Vector2(72, 20)
    badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    badge.add_theme_font_size_override("font_size", 10)
    var sbox = StyleBoxFlat.new()
    sbox.bg_color = SEARCH_TYPE_COLORS.get(brick_type, Color.GRAY)
    sbox.corner_radius_top_left = 4
    sbox.corner_radius_top_right = 4
    sbox.corner_radius_bottom_left = 4
    sbox.corner_radius_bottom_right = 4
    sbox.content_margin_left = 4
    sbox.content_margin_right = 4
    badge.add_theme_stylebox_override("normal", sbox)
    badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.add_child(badge)

    var lbl = Label.new()
    lbl.text = display_name
    lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.add_child(lbl)

    return btn

func _search_set_selected(index: int) -> void:
    if search_selected_index >= 0 and search_selected_index < search_result_buttons.size():
        search_result_buttons[search_selected_index].remove_theme_stylebox_override("normal")
    search_selected_index = index
    if index >= 0 and index < search_result_buttons.size():
        var hl = StyleBoxFlat.new()
        hl.bg_color = Color(0.3, 0.5, 0.8, 0.35)
        hl.corner_radius_top_left = 3
        hl.corner_radius_top_right = 3
        hl.corner_radius_bottom_left = 3
        hl.corner_radius_bottom_right = 3
        search_result_buttons[index].add_theme_stylebox_override("normal", hl)
        if is_instance_valid(search_scroll_ref):
            search_scroll_ref.ensure_control_visible(search_result_buttons[index])

func _search_score(query: String, name: String, type: String) -> float:
    if query.is_empty():
        return 1.0
    var q = query.to_lower().strip_edges()
    var t = name.to_lower()
    var y = type.to_lower()
    if t == q:
        return 100.0
    if t.begins_with(q):
        return 80.0
    if t.contains(q):
        return 60.0
    if y.contains(q):
        return 30.0
    var q_words = q.split(" ", false)
    var t_words = t.split(" ", false)
    var total := 0.0
    for qw in q_words:
        if qw.is_empty():
            continue
        var best := 0.0
        for tw in t_words:
            var s = _search_word_score(qw, tw)
            if s > best:
                best = s
        total += best
    return total / max(q_words.size(), 1)

func _search_word_score(qw: String, tw: String) -> float:
    if tw == qw:
        return 40.0
    if tw.begins_with(qw):
        return 30.0
    if tw.contains(qw):
        return 20.0
    var dist = _search_levenshtein(qw, tw)
    var max_len = max(qw.length(), tw.length())
    if max_len == 0:
        return 0.0
    var tolerance = max(1, max_len / 3)
    if dist <= tolerance:
        return float(tolerance - dist + 1) * 5.0
    return 0.0

func _search_levenshtein(a: String, b: String) -> int:
    var la = a.length()
    var lb = b.length()
    if la == 0:
        return lb
    if lb == 0:
        return la
    if abs(la - lb) > 5:
        return 10
    var prev: Array = []
    prev.resize(lb + 1)
    for j in range(lb + 1):
        prev[j] = j
    for i in range(1, la + 1):
        var curr: Array = []
        curr.resize(lb + 1)
        curr[0] = i
        for j in range(1, lb + 1):
            var cost = 0 if a[i - 1] == b[j - 1] else 1
            curr[j] = mini(mini(curr[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost)
        prev = curr
    return prev[lb]

func _on_search_brick_selected(brick_type: String, brick_class: String) -> void:
    if is_instance_valid(search_popup):
        search_popup.hide()
    var before_snapshot = panel._take_graph_snapshot()
    panel._create_graph_node(brick_type, brick_class, panel.last_mouse_position)
    panel._record_undo("Add Logic Brick", before_snapshot, panel._take_graph_snapshot())
