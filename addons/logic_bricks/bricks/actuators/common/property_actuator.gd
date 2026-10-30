@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Node Properties - set one Inspector property on the selected target node.
## The editor populates the Property dropdown from the actual target node, so
## this works with built-in nodes and custom script properties without a
## hand-maintained node-type list.

func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Node Properties"


func _initialize_properties() -> void:
	properties = {
		"target_node": "self",
		"property_name": "",
		"value": "",
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_node",
			"type": TYPE_STRING,
			"default": "self",
			"node_reference": true,
			"placeholder": "self or node name",
		},
		{
			"name": "property_name",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "__TARGET_NODE_PROPERTY_LIST__",
			"default": "",
		},
		{
			"name": "value",
			"type": TYPE_STRING,
			"default": "",
			"placeholder": "Value, variable, or expression",
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Sets an Inspector property on Self or another node. The Property list updates to match the selected Target Node.",
		"target_node": "Self uses the node that owns these Logic Bricks. Type a node name or Ctrl-drag a node from the Scene dock.",
		"property_name": "Properties are read directly from the selected target node's Inspector property list.",
		"value": "Value to assign. Numbers, booleans, vectors, colors, variables, and expressions can be entered directly. Plain text is automatically quoted for String properties.",
	}


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var node_type = properties.get("node_type", "node_3d")
	if typeof(node_type) == TYPE_STRING:
		node_type = node_type.to_lower().replace(" ", "_")
		var node_type_aliases := {
			"node": "node_3d",
			"mesh_instance": "mesh_instance_3d",
			"collision_shape": "collision_shape_3d",
			"light": "light_3d",
			"rigid_body": "rigid_body_3d",
			"character_body": "character_body_3d",
			"camera": "camera_3d",
			"sprite": "sprite_3d",
		}
		node_type = node_type_aliases.get(node_type, node_type)

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

	for child in _get_field_names():
		if true:
			var prop_name = child
			if prop_name in group_type_map:
				shown[child] = (group_type_map[prop_name] == node_type)
			elif prop_name in prop_type_map:
				shown[child] = (prop_type_map[prop_name] == node_type)
	return shown


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_name := str(properties.get("target_node", "self")).strip_edges()
	var property_name := str(properties.get("property_name", "")).strip_edges()
	var raw_value := str(properties.get("value", "")).strip_edges()
	if target_name.is_empty():
		target_name = "self"
	if property_name.is_empty():
		return {"actuator_code": "push_warning(\"Node Properties: No property selected\")"}
	if raw_value.is_empty():
		return {"actuator_code": "push_warning(\"Node Properties: No value set for property '%s'\")" % _gd_string(property_name)}

	var target := _resolve_editor_target(node, target_name)
	var property_type := _property_type(target, property_name)
	var value_expr := _value_expression(node, raw_value, property_type)
	var safe_property := _gd_string(property_name)
	var code_lines: Array[String] = []

	if target_name.to_lower() == "self":
		code_lines.append("set_indexed(\"%s\", %s)" % [safe_property, value_expr])
		return {"actuator_code": "\n".join(code_lines)}

	var target_var := "_property_target_%s" % chain_name
	code_lines.append("var %s = get_tree().root.find_child(\"%s\", true, false)" % [target_var, _gd_string(target_name)])
	code_lines.append("if %s:" % target_var)
	code_lines.append("\t%s.set_indexed(\"%s\", %s)" % [target_var, safe_property, value_expr])
	code_lines.append("else:")
	code_lines.append("\tpush_warning(\"Node Properties: Node named '%s' not found\")" % _gd_string(target_name))
	return {"actuator_code": "\n".join(code_lines)}


func _resolve_editor_target(owner_node: Node, target_name: String) -> Node:
	if owner_node == null:
		return null
	if target_name.is_empty() or target_name.to_lower() == "self":
		return owner_node
	var tree := owner_node.get_tree()
	if tree != null and tree.root != null:
		return tree.root.find_child(target_name, true, false)
	return owner_node.find_child(target_name, true, false)


func _property_type(target: Node, property_name: String) -> int:
	if target == null:
		return TYPE_NIL
	for info in target.get_property_list():
		if str(info.get("name", "")) == property_name:
			return int(info.get("type", TYPE_NIL))
	return TYPE_NIL


func _value_expression(owner_node: Node, raw_value: String, property_type: int) -> String:
	# Exact Logic Bricks variable names stay as variable references, including
	# String variables. Everything else follows the target property's type.
	if _is_logic_brick_variable(owner_node, raw_value):
		return raw_value
	match property_type:
		TYPE_STRING:
			return "\"%s\"" % _gd_string(raw_value)
		TYPE_STRING_NAME:
			return "StringName(\"%s\")" % _gd_string(raw_value)
		TYPE_NODE_PATH:
			return "NodePath(\"%s\")" % _gd_string(raw_value)
		_:
			return raw_value


func _is_logic_brick_variable(owner_node: Node, candidate: String) -> bool:
	if owner_node == null or candidate.is_empty():
		return false
	var variables = owner_node.get_meta("logic_bricks_variables", [])
	if not variables is Array:
		return false
	for variable in variables:
		if variable is Dictionary and str(variable.get("name", "")) == candidate:
			return true
	return false
