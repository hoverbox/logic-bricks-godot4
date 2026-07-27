@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

const SPLIT_SCREEN_DISPLAY_LAYER: int = 1 << 19


func get_brick_info() -> Dictionary:
	return {
		"class": "SplitScreen2DActuator",
		"name": "Split Screen",
		"type": "actuator",
		"category": "Camera",
		"domain": "2d",
		"menu_order": 330,
	}


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Split Screen"


func _initialize_properties() -> void:
	properties = {
		"camera_1_node_name": "Camera2D",
		"camera_2_node_name": "Camera2D2",
		"layout": "vertical",
	}


func get_property_definitions() -> Array:
	return [
		{"name": "camera_1_node_name", "type": TYPE_STRING, "default": "Camera2D"},
		{"name": "camera_2_node_name", "type": TYPE_STRING, "default": "Camera2D2"},
		{
			"name": "layout",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Vertical,Horizontal",
			"default": "vertical",
		},
	]


func generate_code(_node: Node, chain_name: String) -> Dictionary:
	var camera_1_name := _gd(str(properties.get("camera_1_node_name", "Camera2D")))
	var camera_2_name := _gd(str(properties.get("camera_2_node_name", "Camera2D2")))
	var vertical := str(properties.get("layout", "vertical")).to_lower().begins_with("vertical")
	var stable_id := _id(chain_name)

	var root_var := "_ss2_root_%s" % stable_id
	var layer_var := "_ss2_canvas_%s" % stable_id
	var containers_var := "_ss2_containers_%s" % stable_id
	var viewports_var := "_ss2_viewports_%s" % stable_id
	var sources_var := "_ss2_sources_%s" % stable_id
	var proxies_var := "_ss2_proxies_%s" % stable_id
	var setup_func := "_lb_setup_split_screen_2d_%s" % stable_id
	var sync_func := "_lb_sync_split_screen_2d_camera_%s" % stable_id

	var members: Array[String] = [
		"var %s: CanvasLayer = null" % layer_var,
		"var %s: Control = null" % root_var,
		"var %s: Array[SubViewportContainer] = []" % containers_var,
		"var %s: Array[SubViewport] = []" % viewports_var,
		"var %s: Array[Camera2D] = []" % sources_var,
		"var %s: Array[Camera2D] = []" % proxies_var,
		"",
		"func %s(source: Camera2D, proxy: Camera2D) -> void:" % sync_func,
		"\tif source == null or proxy == null:",
		"\t\treturn",
		"\tproxy.global_transform = source.global_transform",
		"\tproxy.offset = source.offset",
		"\tproxy.zoom = source.zoom",
		"\tproxy.anchor_mode = source.anchor_mode",
		"\tproxy.position_smoothing_enabled = false",
		"\tproxy.rotation_smoothing_enabled = false",
		"\tproxy.ignore_rotation = source.ignore_rotation",
		"\tproxy.enabled = true",
		"",
		"func %s() -> void:" % setup_func,
		"\tawait get_tree().process_frame",
		"\tif %s != null and is_instance_valid(%s):" % [layer_var, layer_var],
		"\t\t%s.queue_free()" % layer_var,
		"\t%s = CanvasLayer.new()" % layer_var,
		"\t%s.name = \"LogicBricksSplitScreen2D_%s\"" % [layer_var, stable_id],
		"\t%s.layer = 100" % layer_var,
		"\tget_tree().root.add_child(%s)" % layer_var,
		"\t%s = Control.new()" % root_var,
		"\t%s.name = \"SplitScreenRoot\"" % root_var,
		"\t%s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)" % root_var,
		"\t%s.mouse_filter = Control.MOUSE_FILTER_IGNORE" % root_var,
		"\t%s.visibility_layer = %d" % [root_var, SPLIT_SCREEN_DISPLAY_LAYER],
		"\t%s.add_child(%s)" % [layer_var, root_var],
		"\t%s.clear()" % containers_var,
		"\t%s.clear()" % viewports_var,
		"\t%s.clear()" % sources_var,
		"\t%s.clear()" % proxies_var,
		"\tvar _ss2_shared_world: World2D = get_viewport().world_2d",
	]

	var camera_names := [camera_1_name, camera_2_name]
	for index in range(2):
		members.append("\tvar _ss2_box_%d := SubViewportContainer.new()" % index)
		members.append("\t_ss2_box_%d.name = \"Player%dViewport\"" % [index, index + 1])
		members.append("\t_ss2_box_%d.stretch = true" % index)
		members.append("\t_ss2_box_%d.mouse_filter = Control.MOUSE_FILTER_IGNORE" % index)
		members.append("\t_ss2_box_%d.visibility_layer = %d" % [index, SPLIT_SCREEN_DISPLAY_LAYER])
		members.append("\t%s.add_child(_ss2_box_%d)" % [root_var, index])
		members.append("\t%s.append(_ss2_box_%d)" % [containers_var, index])
		members.append("\tvar _ss2_vp_%d := SubViewport.new()" % index)
		members.append("\t_ss2_vp_%d.name = \"Player%dRenderTarget\"" % [index, index + 1])
		members.append("\t_ss2_vp_%d.world_2d = _ss2_shared_world" % index)
		members.append("\t_ss2_vp_%d.canvas_cull_mask = 0xFFFFFFFF & ~%d" % [index, SPLIT_SCREEN_DISPLAY_LAYER])
		members.append("\t_ss2_vp_%d.transparent_bg = false" % index)
		members.append("\t_ss2_vp_%d.handle_input_locally = false" % index)
		members.append("\t_ss2_vp_%d.render_target_update_mode = SubViewport.UPDATE_DISABLED" % index)
		members.append("\t_ss2_box_%d.add_child(_ss2_vp_%d)" % [index, index])
		members.append("\t%s.append(_ss2_vp_%d)" % [viewports_var, index])
		members.append("\tvar _ss2_source_%d: Camera2D = null" % index)
		members.append("\tvar _ss2_found_%d = get_tree().current_scene.find_child(\"%s\", true, false) if get_tree().current_scene else null" % [index, camera_names[index]])
		members.append("\tif _ss2_found_%d is Camera2D:" % index)
		members.append("\t\t_ss2_source_%d = _ss2_found_%d as Camera2D" % [index, index])
		members.append("\t%s.append(_ss2_source_%d)" % [sources_var, index])
		members.append("\tvar _ss2_proxy_%d := Camera2D.new()" % index)
		members.append("\t_ss2_proxy_%d.name = \"Player%dProxyCamera\"" % [index, index + 1])
		members.append("\t_ss2_vp_%d.add_child(_ss2_proxy_%d)" % [index, index])
		members.append("\t%s.append(_ss2_proxy_%d)" % [proxies_var, index])
		members.append("\tif _ss2_source_%d:" % index)
		members.append("\t\t%s(_ss2_source_%d, _ss2_proxy_%d)" % [sync_func, index, index])

	members += [
		"\tawait get_tree().process_frame",
		"\tfor _ss2_vp in %s:" % viewports_var,
		"\t\t_ss2_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS",
	]

	var ready_code: Array[String] = [
		"call_deferred(\"%s\")" % setup_func,
	]

	var actuator_code: Array[String] = [
		"if %s == null or not is_instance_valid(%s):" % [root_var, root_var],
		"\tpass",
		"else:",
		"\tvar _ss2_screen_size := get_viewport().get_visible_rect().size",
		"\tvar _ss2_half_size := Vector2(_ss2_screen_size.x * %s, _ss2_screen_size.y * %s)" % ["0.5" if vertical else "1.0", "1.0" if vertical else "0.5"],
		"\tfor _ss2_i in range(min(%s.size(), %s.size())):" % [sources_var, proxies_var],
		"\t\tif %s[_ss2_i] != null and is_instance_valid(%s[_ss2_i]):" % [sources_var, sources_var],
		"\t\t\t%s(%s[_ss2_i], %s[_ss2_i])" % [sync_func, sources_var, proxies_var],
		"\tfor _ss2_i in range(min(%s.size(), %s.size())):" % [containers_var, viewports_var],
		"\t\tvar _ss2_box := %s[_ss2_i]" % containers_var,
		"\t\t_ss2_box.set_anchor(SIDE_LEFT, 0.0)",
		"\t\t_ss2_box.set_anchor(SIDE_TOP, 0.0)",
		"\t\t_ss2_box.set_anchor(SIDE_RIGHT, 0.0)",
		"\t\t_ss2_box.set_anchor(SIDE_BOTTOM, 0.0)",
		"\t\t_ss2_box.position = Vector2(_ss2_half_size.x * _ss2_i, 0.0)" if vertical else "\t\t_ss2_box.position = Vector2(0.0, _ss2_half_size.y * _ss2_i)",
		"\t\t_ss2_box.size = _ss2_half_size",
	]

	return {
		"actuator_code": "\n".join(actuator_code),
		"member_vars": members,
		"ready_code": ready_code,
	}


func _id(value: String) -> String:
	return (instance_name if not instance_name.is_empty() else value).to_lower().replace(" ", "_").validate_node_name().replace(".", "_")


func _gd(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")
