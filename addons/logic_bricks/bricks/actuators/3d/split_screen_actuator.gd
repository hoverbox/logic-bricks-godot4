@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Split Screen Actuator
## Apply Code always builds 4 SubViewportContainers (one per possible player).
## Slots beyond the active player count are hidden each frame — no rebuild needed
## when the player count changes at runtime.
##
## Each player count has its own independent layout setting:
##   layout_2 — used when split_screen_players == 2 (default: Vertical)
##   layout_3 — used when split_screen_players == 3 (default: Top Wide)
##   layout_4 — used when split_screen_players == 4 (default: 2x2 Grid)
##
## The generated @export var split_screen_players lets you change player count
## from 1->2->3->4 (or back) at runtime without re-applying code.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Split Screen"


func _initialize_properties() -> void:
	properties = {
		"player_count": "2",
		"layout_2": "vertical",
		"layout_3": "top_wide",
		"layout_4": "grid_2x2",
	}


func get_property_definitions() -> Array:
	var layouts = "Vertical,Horizontal,2x2 Grid,Top Wide,Bottom Wide"
	return [
		{
			"name": "player_count",
			"type": TYPE_STRING,
			"default": "2",
			"placeholder": "2  or  player_count"
		},
		{
			"name": "layout_2",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": layouts,
			"default": "vertical"
		},
		{
			"name": "layout_3",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": layouts,
			"default": "top_wide"
		},
		{
			"name": "layout_4",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": layouts,
			"default": "grid_2x2"
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Creates a split screen layout.\nApply Code always builds all 4 SubViewportContainers.\nEach player count has its own independent layout.\nChange split_screen_players at runtime to switch counts\nwithout re-applying code.\n** Use an Always sensor so the layout updates every frame.",
		"player_count": "Default number of active players (1-4).\nSets the initial value of @export var split_screen_players on the node.\nChange that variable at runtime to switch player count dynamically.\n1 = single player fullscreen (no split).",
		"layout_2": "Layout used when exactly 2 players are active.",
		"layout_3": "Layout used when exactly 3 players are active.",
		"layout_4": "Layout used when exactly 4 players are active.",
	}


func _parse_layout(raw: String) -> String:
	var l = raw.to_lower().replace(" ", "_")
	if l == "2x2_grid": l = "grid_2x2"
	return l


func generate_code(node: Node, chain_name: String) -> Dictionary:
	# player_count can be a literal ("2") or a variable/expression ("player_count")
	var _pc_raw = str(properties.get("player_count", "2")).strip_edges()
	var _pc_is_literal = _pc_raw.is_valid_int()
	var default_player_count = int(_pc_raw) if _pc_is_literal else 2

	# Per-count layouts — each independently configurable
	var layout2 = _parse_layout(str(properties.get("layout_2", "vertical")))
	var layout3 = _parse_layout(str(properties.get("layout_3", "top_wide")))
	var layout4 = _parse_layout(str(properties.get("layout_4", "grid_2x2")))
	var layouts = {2: layout2, 3: layout3, 4: layout4}

	var cn = chain_name
	var stable_name = instance_name.to_lower().replace(" ", "_") if not instance_name.is_empty() else "ss"
	var canvas_name = "_ss_canvas_%s" % stable_name

	# --- Member vars ---
	var member_vars: Array[String] = []
	var containers_var = "_%s_containers" % cn
	var viewports_var  = "_%s_viewports"  % cn
	var canvas_var     = "_%s_canvas"     % cn
	member_vars.append("var %s: Array" % containers_var)
	member_vars.append("var %s: Array"  % viewports_var)
	member_vars.append("var %s: CanvasLayer" % canvas_var)
	member_vars.append("var split_screen_players: int = %d" % default_player_count)
	for i in range(4):
		member_vars.append("@export var camera_%d: Camera3D" % (i + 1))
	if not _pc_is_literal:
		member_vars.append("# split_screen_players is driven by: %s" % _pc_raw)

	# --- _ready: create SubViewports at runtime, never in the editor scene ---
	# SubViewports created by Apply Code and saved into .tscn cause Godot to
	# emit "common_parent is null" on every scene save — a known engine issue
	# with SubViewport serialization. Creating them in _ready() means they
	# never exist in the .tscn file, so the serializer never touches them.
	var ready_lines: Array[String] = []
	ready_lines.append("# Split Screen: create SubViewports at runtime (not stored in .tscn)")
	ready_lines.append("%s.clear()" % containers_var)
	ready_lines.append("%s.clear()"  % viewports_var)
	ready_lines.append("if %s:" % canvas_var)
	ready_lines.append("\t%s.queue_free()" % canvas_var)
	ready_lines.append("\t%s = null" % canvas_var)
	ready_lines.append("var _ss_root = get_tree().current_scene if get_tree().current_scene else get_tree().root")
	ready_lines.append("var _ss_sw = DisplayServer.window_get_size().x")
	ready_lines.append("var _ss_sh = DisplayServer.window_get_size().y")
	ready_lines.append("var _ss_cl = CanvasLayer.new()")
	ready_lines.append("_ss_cl.name = \"%s\"" % canvas_name)
	ready_lines.append("_ss_cl.layer = 0")
	ready_lines.append("_ss_root.add_child(_ss_cl)")
	ready_lines.append("%s = _ss_cl" % canvas_var)
	for i in range(4):
		var svc_name = "_ss_svc_%s_%d" % [stable_name, i + 1]
		var vp_name  = "_ss_vp_%s_%d"  % [stable_name, i + 1]
		var is_visible = str(i < default_player_count).to_lower()
		ready_lines.append("var _ss_svc_%d = SubViewportContainer.new()" % i)
		ready_lines.append("_ss_svc_%d.name = \"%s\"" % [i, svc_name])
		ready_lines.append("_ss_svc_%d.stretch = false" % i)
		ready_lines.append("_ss_svc_%d.set_anchor(SIDE_LEFT,   0.0)" % i)
		ready_lines.append("_ss_svc_%d.set_anchor(SIDE_TOP,    0.0)" % i)
		ready_lines.append("_ss_svc_%d.set_anchor(SIDE_RIGHT,  0.0)" % i)
		ready_lines.append("_ss_svc_%d.set_anchor(SIDE_BOTTOM, 0.0)" % i)
		ready_lines.append("_ss_svc_%d.visible = %s" % [i, is_visible])
		ready_lines.append("_ss_cl.add_child(_ss_svc_%d)" % i)
		ready_lines.append("%s.append(_ss_svc_%d)" % [containers_var, i])
		ready_lines.append("var _ss_svp_%d = SubViewport.new()" % i)
		ready_lines.append("_ss_svp_%d.name = \"%s\"" % [i, vp_name])
		ready_lines.append("_ss_svp_%d.size = Vector2i(max(1, _ss_sw / 2), max(1, _ss_sh / 2))" % i)
		ready_lines.append("_ss_svp_%d.render_target_update_mode = SubViewport.UPDATE_DISABLED" % i)
		ready_lines.append("_ss_svc_%d.add_child(_ss_svp_%d)" % [i, i])
		ready_lines.append("%s.append(_ss_svp_%d)" % [viewports_var, i])
		# Reparent user-assigned camera into this SubViewport
		ready_lines.append("if camera_%d:" % (i + 1))
		ready_lines.append("\tvar _ss_cam_parent_%d = camera_%d.get_parent()" % [i, i + 1])
		ready_lines.append("\tif _ss_cam_parent_%d:" % i)
		ready_lines.append("\t\t_ss_cam_parent_%d.remove_child(camera_%d)" % [i, i + 1])
		ready_lines.append("\t_ss_svp_%d.add_child(camera_%d)" % [i, i + 1])
	ready_lines.append("await get_tree().process_frame")
	ready_lines.append("for _ss_vp in %s:" % viewports_var)
	ready_lines.append("\t_ss_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS")

	# --- Actuator code (runs every frame) ---
	var code_lines: Array[String] = []
	var _pc_expr = _pc_raw
	code_lines.append("# Split Screen: apply layout for current player count")
	code_lines.append("var _ss_active = clampi(%s, 1, 4)" % _pc_expr)
	code_lines.append("if %s: %s.visible = true" % [canvas_var, canvas_var])

	# 1-player: slot 0 fills the screen, all others hidden
	code_lines.append("if _ss_active == 1:")
	code_lines.append("\tvar _ss_size_1 = get_tree().root.get_viewport().get_visible_rect().size")
	code_lines.append("\tif %s.size() > 0:" % containers_var)
	code_lines.append("\t\t%s[0].set_anchor(SIDE_LEFT,   0.0)" % containers_var)
	code_lines.append("\t\t%s[0].set_anchor(SIDE_TOP,    0.0)" % containers_var)
	code_lines.append("\t\t%s[0].set_anchor(SIDE_RIGHT,  0.0)" % containers_var)
	code_lines.append("\t\t%s[0].set_anchor(SIDE_BOTTOM, 0.0)" % containers_var)
	code_lines.append("\t\t%s[0].position = Vector2.ZERO" % containers_var)
	code_lines.append("\t\t%s[0].size = _ss_size_1" % containers_var)
	code_lines.append("\t\t%s[0].visible = true" % containers_var)
	code_lines.append("\t\tif %s.size() > 0: %s[0].size = Vector2i(int(_ss_size_1.x), int(_ss_size_1.y))" % [viewports_var, viewports_var])
	code_lines.append("\tfor _ss_i in range(1, %s.size()):" % containers_var)
	code_lines.append("\t\t%s[_ss_i].visible = false" % containers_var)
	code_lines.append("\treturn")

	# 2-4 players: show/hide slots then apply the correct layout for this count
	code_lines.append("var _ss_size = get_tree().root.get_viewport().get_visible_rect().size")
	code_lines.append("var _ss_w = _ss_size.x")
	code_lines.append("var _ss_h = _ss_size.y")
	code_lines.append("var _svc_list = %s" % containers_var)
	code_lines.append("var _svp_list = %s"  % viewports_var)
	code_lines.append("for _ss_i in _svc_list.size():")
	code_lines.append("\t_svc_list[_ss_i].visible = (_ss_i < _ss_active)")
	code_lines.append("\tif _ss_i < _svp_list.size():")
	code_lines.append("\t\t_svp_list[_ss_i].render_target_update_mode = SubViewport.UPDATE_ALWAYS if (_ss_i < _ss_active) else SubViewport.UPDATE_DISABLED")

	# match block: each arm uses its own independently chosen layout
	code_lines.append("if _svc_list.size() == 4:")
	code_lines.append("\tmatch _ss_active:")
	for count in [2, 3, 4]:
		var arm_lines: Array[String] = []
		var lay = layouts[count]
		match lay:
			"vertical":    _emit_vertical(arm_lines, count)
			"horizontal":  _emit_horizontal(arm_lines, count)
			"grid_2x2":    _emit_grid_2x2(arm_lines, count)
			"top_wide":    _emit_top_wide(arm_lines, count)
			"bottom_wide": _emit_bottom_wide(arm_lines, count)
			_:             _emit_vertical(arm_lines, count)
		code_lines.append("\t\t%d:" % count)
		for al in arm_lines:
			code_lines.append("\t\t" + al)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars":   member_vars,
		"ready_code":    ready_lines,
	}


func _set_slot(lines: Array[String], index: int, x: String, y: String, w: String, h: String) -> void:
	var i = str(index)
	lines.append("\t_svc_list[%s].set_anchor(SIDE_LEFT,   0.0)" % i)
	lines.append("\t_svc_list[%s].set_anchor(SIDE_TOP,    0.0)" % i)
	lines.append("\t_svc_list[%s].set_anchor(SIDE_RIGHT,  0.0)" % i)
	lines.append("\t_svc_list[%s].set_anchor(SIDE_BOTTOM, 0.0)" % i)
	lines.append("\t_svc_list[%s].position = Vector2(%s, %s)" % [i, x, y])
	lines.append("\t_svc_list[%s].size = Vector2(%s, %s)" % [i, w, h])
	lines.append("\tif _svp_list.size() > %s:" % i)
	lines.append("\t\t_svp_list[%s].size = Vector2i(int(%s), int(%s))" % [i, w, h])


func _emit_vertical(lines: Array[String], count: int) -> void:
	for i in range(count):
		_set_slot(lines, i,
			"(_ss_w / %d.0) * %d" % [count, i], "0",
			"_ss_w / %d.0" % count, "_ss_h")


func _emit_horizontal(lines: Array[String], count: int) -> void:
	for i in range(count):
		_set_slot(lines, i,
			"0", "(_ss_h / %d.0) * %d" % [count, i],
			"_ss_w", "_ss_h / %d.0" % count)


func _emit_grid_2x2(lines: Array[String], count: int) -> void:
	var positions = [
		["0", "0"], ["_ss_w / 2.0", "0"],
		["0", "_ss_h / 2.0"], ["_ss_w / 2.0", "_ss_h / 2.0"],
	]
	for i in range(count):
		_set_slot(lines, i, positions[i][0], positions[i][1], "_ss_w / 2.0", "_ss_h / 2.0")


func _emit_top_wide(lines: Array[String], count: int) -> void:
	_set_slot(lines, 0, "0", "0", "_ss_w", "_ss_h / 2.0")
	var bc = count - 1
	for i in range(bc):
		_set_slot(lines, i + 1,
			"(_ss_w / %d.0) * %d" % [bc, i], "_ss_h / 2.0",
			"_ss_w / %d.0" % bc, "_ss_h / 2.0")


func _emit_bottom_wide(lines: Array[String], count: int) -> void:
	var tc = count - 1
	for i in range(tc):
		_set_slot(lines, i,
			"(_ss_w / %d.0) * %d" % [tc, i], "0",
			"_ss_w / %d.0" % tc, "_ss_h / 2.0")
	_set_slot(lines, count - 1, "0", "_ss_h / 2.0", "_ss_w", "_ss_h / 2.0")
