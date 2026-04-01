@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Property Actuator - Set properties on a target node
## Choose a node type, then all its properties are shown in collapsible sections
## Each property has a value field that accepts a literal or variable name
## Assign the target node via @export (drag and drop in inspector)


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Property"


func _initialize_properties() -> void:
	properties = {
		"node_type":    "node_3d",
		"target_node":  "self",  # "self" or a node name to search for in the scene tree

		# --- NODE 3D ---
		"n3d_visible":    "true",
		"n3d_pos_x":      "",
		"n3d_pos_y":      "",
		"n3d_pos_z":      "",
		"n3d_rot_x":      "",
		"n3d_rot_y":      "",
		"n3d_rot_z":      "",
		"n3d_scale_x":    "",
		"n3d_scale_y":    "",
		"n3d_scale_z":    "",

		# --- MESH INSTANCE 3D ---
		"mesh_visible":     "true",
		"mesh_cast_shadow": "",

		# --- COLLISION SHAPE 3D ---
		"col_disabled": "false",

		# --- LIGHT 3D ---
		"light_visible":  "true",
		"light_energy":   "",
		"light_color":    Color(1, 1, 1, 1),
		"light_shadow":   "",

		# --- RIGID BODY 3D ---
		"rb_freeze":        "",
		"rb_gravity_scale": "",
		"rb_linear_damp":   "",
		"rb_angular_damp":  "",
		"rb_mass":          "",

		# --- CHARACTER BODY 3D ---
		"cb_up_dir_y":           "",
		"cb_floor_max_angle":    "",
		"cb_max_slides":         "",
		"cb_stop_on_slope":      "",
		"cb_block_on_wall":      "",
		"cb_slide_on_ceiling":   "",

		# --- ANIMATION PLAYER ---
		"anim_speed_scale": "",

		# --- CONTROL ---
		"ctrl_visible":    "true",
		"ctrl_modulate":   Color(1, 1, 1, 1),
		"ctrl_size_x":     "",
		"ctrl_size_y":     "",
		"ctrl_pos_x":      "",
		"ctrl_pos_y":      "",
		"ctrl_rotation":   "",
		"ctrl_scale_x":    "",
		"ctrl_scale_y":    "",

		# --- LABEL ---
		"lbl_text":     "",
		"lbl_visible":  "true",
		"lbl_modulate": Color(1, 1, 1, 1),

		# --- BUTTON ---
		"btn_disabled": "false",
		"btn_text":     "",
		"btn_visible":  "true",

		# --- CAMERA 3D ---
		"cam_fov":     "",
		"cam_near":    "",
		"cam_far":     "",
		"cam_current": "",

		# --- SPRITE 3D ---
		"spr_visible":      "true",
		"spr_modulate":     Color(1, 1, 1, 1),
		"spr_flip_h":       "",
		"spr_flip_v":       "",
		"spr_pixel_size":   "",
		"spr_billboard":    "",
		"spr_transparent":  "",
		"spr_shaded":       "",
		"spr_double_sided": "",
		"spr_frame":        "",
		"spr_hframes":      "",
		"spr_vframes":      "",

		# --- CUSTOM ---
		"custom_property": "",
		"custom_value":    "",
	}


## All property definitions — groups use hint 999 (collapsible)
## Properties prefixed with the node type key
func get_property_definitions() -> Array:
	return [
		# Node type selector — always visible
		{
			"name": "node_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Node 3D,Mesh Instance 3D,Collision Shape 3D,Light 3D,Rigid Body 3D,Character Body 3D,Animation Player,Control,Label,Button,Camera 3D,Sprite 3D,Custom",
			"default": "node_3d"
		},
		# Target node path — always visible
		{
			"name": "target_node",
			"type": TYPE_STRING,
			"default": "self"
		},

		# === NODE 3D ===
		{ "name": "_group_n3d_visibility", "type": TYPE_NIL, "hint": 999, "hint_string": "Visibility" },
		{ "name": "n3d_visible", "type": TYPE_STRING, "default": "true" },

		{ "name": "_group_n3d_transform", "type": TYPE_NIL, "hint": 999, "hint_string": "Transform", "collapsed": true },
		{ "name": "n3d_pos_x",   "type": TYPE_STRING, "default": "" },
		{ "name": "n3d_pos_y",   "type": TYPE_STRING, "default": "" },
		{ "name": "n3d_pos_z",   "type": TYPE_STRING, "default": "" },
		{ "name": "n3d_rot_x",   "type": TYPE_STRING, "default": "" },
		{ "name": "n3d_rot_y",   "type": TYPE_STRING, "default": "" },
		{ "name": "n3d_rot_z",   "type": TYPE_STRING, "default": "" },
		{ "name": "n3d_scale_x", "type": TYPE_STRING, "default": "" },
		{ "name": "n3d_scale_y", "type": TYPE_STRING, "default": "" },
		{ "name": "n3d_scale_z", "type": TYPE_STRING, "default": "" },

		# === MESH INSTANCE 3D ===
		{ "name": "_group_mesh_basic", "type": TYPE_NIL, "hint": 999, "hint_string": "Mesh Instance 3D" },
		{ "name": "mesh_visible",     "type": TYPE_STRING, "default": "true" },
		{ "name": "mesh_cast_shadow", "type": TYPE_STRING, "default": "" },

		# === COLLISION SHAPE 3D ===
		{ "name": "_group_col_basic", "type": TYPE_NIL, "hint": 999, "hint_string": "Collision Shape 3D" },
		{ "name": "col_disabled", "type": TYPE_STRING, "default": "false" },

		# === LIGHT 3D ===
		{ "name": "_group_light_basic", "type": TYPE_NIL, "hint": 999, "hint_string": "Basic" },
		{ "name": "light_visible", "type": TYPE_STRING, "default": "true" },
		{ "name": "light_energy",  "type": TYPE_STRING, "default": "" },
		{ "name": "_group_light_color", "type": TYPE_NIL, "hint": 999, "hint_string": "Color", "collapsed": true },
		{ "name": "light_color",   "type": TYPE_COLOR, "default": Color(1, 1, 1, 1) },
		{ "name": "_group_light_shadow", "type": TYPE_NIL, "hint": 999, "hint_string": "Shadow", "collapsed": true },
		{ "name": "light_shadow",  "type": TYPE_STRING, "default": "" },

		# === RIGID BODY 3D ===
		{ "name": "_group_rb_basic", "type": TYPE_NIL, "hint": 999, "hint_string": "Basic" },
		{ "name": "rb_freeze",        "type": TYPE_STRING, "default": "" },
		{ "name": "rb_mass",          "type": TYPE_STRING, "default": "" },
		{ "name": "_group_rb_damping", "type": TYPE_NIL, "hint": 999, "hint_string": "Damping", "collapsed": true },
		{ "name": "rb_gravity_scale", "type": TYPE_STRING, "default": "" },
		{ "name": "rb_linear_damp",   "type": TYPE_STRING, "default": "" },
		{ "name": "rb_angular_damp",  "type": TYPE_STRING, "default": "" },

		# === CHARACTER BODY 3D ===
		{ "name": "_group_cb_basic", "type": TYPE_NIL, "hint": 999, "hint_string": "Basic" },
		{ "name": "cb_up_dir_y",        "type": TYPE_STRING, "default": "" },
		{ "name": "cb_max_slides",      "type": TYPE_STRING, "default": "" },
		{ "name": "_group_cb_floor", "type": TYPE_NIL, "hint": 999, "hint_string": "Floor", "collapsed": true },
		{ "name": "cb_floor_max_angle",  "type": TYPE_STRING, "default": "" },
		{ "name": "cb_stop_on_slope",    "type": TYPE_STRING, "default": "" },
		{ "name": "cb_block_on_wall",    "type": TYPE_STRING, "default": "" },
		{ "name": "cb_slide_on_ceiling", "type": TYPE_STRING, "default": "" },

		# === ANIMATION PLAYER ===
		{ "name": "_group_anim_basic", "type": TYPE_NIL, "hint": 999, "hint_string": "Animation Player" },
		{ "name": "anim_speed_scale", "type": TYPE_STRING, "default": "" },

		# === CONTROL ===
		{ "name": "_group_ctrl_basic", "type": TYPE_NIL, "hint": 999, "hint_string": "Basic" },
		{ "name": "ctrl_visible",  "type": TYPE_STRING, "default": "true" },
		{ "name": "ctrl_modulate", "type": TYPE_COLOR,  "default": Color(1, 1, 1, 1) },
		{ "name": "_group_ctrl_transform", "type": TYPE_NIL, "hint": 999, "hint_string": "Transform", "collapsed": true },
		{ "name": "ctrl_size_x",   "type": TYPE_STRING, "default": "" },
		{ "name": "ctrl_size_y",   "type": TYPE_STRING, "default": "" },
		{ "name": "ctrl_pos_x",    "type": TYPE_STRING, "default": "" },
		{ "name": "ctrl_pos_y",    "type": TYPE_STRING, "default": "" },
		{ "name": "ctrl_rotation", "type": TYPE_STRING, "default": "" },
		{ "name": "ctrl_scale_x",  "type": TYPE_STRING, "default": "" },
		{ "name": "ctrl_scale_y",  "type": TYPE_STRING, "default": "" },

		# === LABEL ===
		{ "name": "_group_lbl_basic", "type": TYPE_NIL, "hint": 999, "hint_string": "Label" },
		{ "name": "lbl_text",     "type": TYPE_STRING, "default": "" },
		{ "name": "lbl_visible",  "type": TYPE_STRING, "default": "true" },
		{ "name": "lbl_modulate", "type": TYPE_COLOR,  "default": Color(1, 1, 1, 1) },

		# === BUTTON ===
		{ "name": "_group_btn_basic", "type": TYPE_NIL, "hint": 999, "hint_string": "Button" },
		{ "name": "btn_disabled", "type": TYPE_STRING, "default": "false" },
		{ "name": "btn_text",     "type": TYPE_STRING, "default": "" },
		{ "name": "btn_visible",  "type": TYPE_STRING, "default": "true" },

		# === CAMERA 3D ===
		{ "name": "_group_cam_basic", "type": TYPE_NIL, "hint": 999, "hint_string": "Camera 3D" },
		{ "name": "cam_fov",     "type": TYPE_STRING, "default": "" },
		{ "name": "cam_near",    "type": TYPE_STRING, "default": "" },
		{ "name": "cam_far",     "type": TYPE_STRING, "default": "" },
		{ "name": "cam_current", "type": TYPE_STRING, "default": "" },

		# === SPRITE 3D ===
		{ "name": "_group_spr_basic", "type": TYPE_NIL, "hint": 999, "hint_string": "Basic" },
		{ "name": "spr_visible",      "type": TYPE_STRING, "default": "true" },
		{ "name": "spr_modulate",     "type": TYPE_COLOR,  "default": Color(1, 1, 1, 1) },
		{ "name": "spr_flip_h",       "type": TYPE_STRING, "default": "" },
		{ "name": "spr_flip_v",       "type": TYPE_STRING, "default": "" },
		{ "name": "spr_pixel_size",   "type": TYPE_STRING, "default": "" },
		{ "name": "_group_spr_display", "type": TYPE_NIL, "hint": 999, "hint_string": "Display", "collapsed": true },
		{ "name": "spr_billboard",    "type": TYPE_STRING, "default": "" },
		{ "name": "spr_transparent",  "type": TYPE_STRING, "default": "" },
		{ "name": "spr_shaded",       "type": TYPE_STRING, "default": "" },
		{ "name": "spr_double_sided", "type": TYPE_STRING, "default": "" },
		{ "name": "_group_spr_frames", "type": TYPE_NIL, "hint": 999, "hint_string": "Frames", "collapsed": true },
		{ "name": "spr_frame",        "type": TYPE_STRING, "default": "" },
		{ "name": "spr_hframes",      "type": TYPE_STRING, "default": "" },
		{ "name": "spr_vframes",      "type": TYPE_STRING, "default": "" },

		# === CUSTOM ===
		{ "name": "_group_custom", "type": TYPE_NIL, "hint": 999, "hint_string": "Custom Property" },
		{ "name": "custom_property", "type": TYPE_STRING, "default": "" },
		{ "name": "custom_value",    "type": TYPE_STRING, "default": "" },
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Sets properties on a target node.\nChoose the node type to see its available properties.\nLeave a field empty to skip setting that property.\n⚠ Adds @export in Inspector — assign the target node.",
		"node_type":    "The type of node you are targeting.",
		"target_node":  "Which node to affect.\n\"self\" = this node.\nOr type a node name to search for anywhere in the scene tree:\n  Sprite3D\n  PlayerMesh\n  HUD",
		"n3d_visible":      "true / false, or a variable name.",
		"n3d_pos_x":        "Position X. Leave empty to skip.",
		"n3d_pos_y":        "Position Y. Leave empty to skip.",
		"n3d_pos_z":        "Position Z. Leave empty to skip.",
		"n3d_rot_x":        "Rotation degrees X. Leave empty to skip.",
		"n3d_rot_y":        "Rotation degrees Y. Leave empty to skip.",
		"n3d_rot_z":        "Rotation degrees Z. Leave empty to skip.",
		"n3d_scale_x":      "Scale X. Leave empty to skip.",
		"n3d_scale_y":      "Scale Y. Leave empty to skip.",
		"n3d_scale_z":      "Scale Z. Leave empty to skip.",
		"mesh_visible":     "true / false, or a variable name.",
		"mesh_cast_shadow": "0=Off 1=On 2=DoubleSided 3=ShadowsOnly. Leave empty to skip.",
		"col_disabled":     "true / false. Leave empty to skip.",
		"light_visible":    "true / false, or a variable name.",
		"light_energy":     "Light energy multiplier. Leave empty to skip.",
		"light_color":      "Color of the light.",
		"light_shadow":     "true / false. Leave empty to skip.",
		"rb_freeze":        "true / false. Leave empty to skip.",
		"rb_mass":          "Mass in kg. Leave empty to skip.",
		"rb_gravity_scale": "Gravity multiplier. 0 = no gravity. Leave empty to skip.",
		"rb_linear_damp":   "Linear velocity damping. Leave empty to skip.",
		"rb_angular_damp":  "Angular velocity damping. Leave empty to skip.",
		"cb_up_dir_y":      "Up direction Y component (usually 1.0). Leave empty to skip.",
		"cb_max_slides":    "Max collision slides per frame. Leave empty to skip.",
		"cb_floor_max_angle": "Max slope angle in radians. Leave empty to skip.",
		"cb_stop_on_slope": "true / false. Leave empty to skip.",
		"cb_block_on_wall": "true / false. Leave empty to skip.",
		"cb_slide_on_ceiling": "true / false. Leave empty to skip.",
		"anim_speed_scale": "Playback speed. 1.0 = normal. Leave empty to skip.",
		"ctrl_visible":     "true / false, or a variable name.",
		"ctrl_modulate":    "Color tint including alpha.",
		"ctrl_size_x":      "Control width. Leave empty to skip.",
		"ctrl_size_y":      "Control height. Leave empty to skip.",
		"ctrl_pos_x":       "Position X (anchored). Leave empty to skip.",
		"ctrl_pos_y":       "Position Y (anchored). Leave empty to skip.",
		"ctrl_rotation":    "Rotation in radians. Leave empty to skip.",
		"ctrl_scale_x":     "Scale X. Leave empty to skip.",
		"ctrl_scale_y":     "Scale Y. Leave empty to skip.",
		"lbl_text":         "Label text. Leave empty to skip.",
		"lbl_visible":      "true / false, or a variable name.",
		"lbl_modulate":     "Color tint including alpha.",
		"btn_disabled":     "true / false. Leave empty to skip.",
		"btn_text":         "Button label text. Leave empty to skip.",
		"btn_visible":      "true / false, or a variable name.",
		"cam_fov":          "Field of view in degrees. Leave empty to skip.",
		"cam_near":         "Near clip distance. Leave empty to skip.",
		"cam_far":          "Far clip distance. Leave empty to skip.",
		"cam_current":      "true / false — make this the active camera. Leave empty to skip.",
		"spr_visible":      "true / false, or a variable name.",
		"spr_modulate":     "Color tint including alpha.",
		"spr_flip_h":       "true / false. Leave empty to skip.",
		"spr_flip_v":       "true / false. Leave empty to skip.",
		"spr_pixel_size":   "Size of one pixel in 3D units. Default 0.01. Leave empty to skip.",
		"spr_billboard":    "0=Disabled 1=Enabled 2=Y-Billboard. Leave empty to skip.",
		"spr_transparent":  "true / false — enable transparency. Leave empty to skip.",
		"spr_shaded":       "true / false — receive scene lighting. Leave empty to skip.",
		"spr_double_sided": "true / false — visible from back face. Leave empty to skip.",
		"spr_frame":        "Current animation frame index. Leave empty to skip.",
		"spr_hframes":      "Number of horizontal frames in spritesheet. Leave empty to skip.",
		"spr_vframes":      "Number of vertical frames in spritesheet. Leave empty to skip.",
		"custom_property":  "Any Godot property path.\nExamples: visible  scale:x  modulate:a  position:y",
		"custom_value":     "Value to set. Accepts any GDScript expression.",
	}


## Map of prop key -> [gdscript_path, is_color]
## is_color = true means use set_indexed with a Color value
const PROP_MAP = {
	"n3d_visible":    ["visible", false],
	"n3d_pos_x":      ["position:x", false],
	"n3d_pos_y":      ["position:y", false],
	"n3d_pos_z":      ["position:z", false],
	"n3d_rot_x":      ["rotation_degrees:x", false],
	"n3d_rot_y":      ["rotation_degrees:y", false],
	"n3d_rot_z":      ["rotation_degrees:z", false],
	"n3d_scale_x":    ["scale:x", false],
	"n3d_scale_y":    ["scale:y", false],
	"n3d_scale_z":    ["scale:z", false],
	"mesh_visible":     ["visible", false],
	"mesh_cast_shadow": ["cast_shadow", false],
	"col_disabled":     ["disabled", false],
	"light_visible":    ["visible", false],
	"light_energy":     ["light_energy", false],
	"light_color":      ["light_color", true],
	"light_shadow":     ["shadow_enabled", false],
	"rb_freeze":        ["freeze", false],
	"rb_gravity_scale": ["gravity_scale", false],
	"rb_linear_damp":   ["linear_damp", false],
	"rb_angular_damp":  ["angular_damp", false],
	"rb_mass":          ["mass", false],
	"cb_up_dir_y":          ["up_direction:y", false],
	"cb_floor_max_angle":   ["floor_max_angle", false],
	"cb_max_slides":        ["max_slides", false],
	"cb_stop_on_slope":     ["floor_stop_on_slope", false],
	"cb_block_on_wall":     ["floor_block_on_wall", false],
	"cb_slide_on_ceiling":  ["slide_on_ceiling", false],
	"anim_speed_scale": ["speed_scale", false],
	"ctrl_visible":     ["visible", false],
	"ctrl_modulate":    ["modulate", true],
	"ctrl_size_x":      ["size:x", false],
	"ctrl_size_y":      ["size:y", false],
	"ctrl_pos_x":       ["position:x", false],
	"ctrl_pos_y":       ["position:y", false],
	"ctrl_rotation":    ["rotation", false],
	"ctrl_scale_x":     ["scale:x", false],
	"ctrl_scale_y":     ["scale:y", false],
	"lbl_text":     ["text", false],
	"lbl_visible":  ["visible", false],
	"lbl_modulate": ["modulate", true],
	"btn_disabled": ["disabled", false],
	"btn_text":     ["text", false],
	"btn_visible":  ["visible", false],
	"cam_fov":     ["fov", false],
	"cam_near":    ["near", false],
	"cam_far":     ["far", false],
	"cam_current": ["current", false],
	"spr_visible":      ["visible", false],
	"spr_modulate":     ["modulate", true],
	"spr_flip_h":       ["flip_h", false],
	"spr_flip_v":       ["flip_v", false],
	"spr_pixel_size":   ["pixel_size", false],
	"spr_billboard":    ["billboard", false],
	"spr_transparent":  ["transparent", false],
	"spr_shaded":       ["shaded", false],
	"spr_double_sided": ["double_sided", false],
	"spr_frame":        ["frame", false],
	"spr_hframes":      ["hframes", false],
	"spr_vframes":      ["vframes", false],
}


## Which property keys belong to each node type
const TYPE_PROPS = {
	"node_3d":            ["n3d_visible", "n3d_pos_x", "n3d_pos_y", "n3d_pos_z", "n3d_rot_x", "n3d_rot_y", "n3d_rot_z", "n3d_scale_x", "n3d_scale_y", "n3d_scale_z"],
	"mesh_instance_3d":   ["mesh_visible", "mesh_cast_shadow"],
	"collision_shape_3d": ["col_disabled"],
	"light_3d":           ["light_visible", "light_energy", "light_color", "light_shadow"],
	"rigid_body_3d":      ["rb_freeze", "rb_gravity_scale", "rb_linear_damp", "rb_angular_damp", "rb_mass"],
	"character_body_3d":  ["cb_up_dir_y", "cb_floor_max_angle", "cb_max_slides", "cb_stop_on_slope", "cb_block_on_wall", "cb_slide_on_ceiling"],
	"animation_player":   ["anim_speed_scale"],
	"control":            ["ctrl_visible", "ctrl_modulate", "ctrl_size_x", "ctrl_size_y", "ctrl_pos_x", "ctrl_pos_y", "ctrl_rotation", "ctrl_scale_x", "ctrl_scale_y"],
	"label":              ["lbl_text", "lbl_visible", "lbl_modulate"],
	"button":             ["btn_disabled", "btn_text", "btn_visible"],
	"camera_3d":          ["cam_fov", "cam_near", "cam_far", "cam_current"],
	"sprite_3d":          ["spr_visible", "spr_modulate", "spr_flip_h", "spr_flip_v", "spr_pixel_size", "spr_billboard", "spr_transparent", "spr_shaded", "spr_double_sided", "spr_frame", "spr_hframes", "spr_vframes"],
	"custom":             ["custom_property", "custom_value"],
}


## Which group headers belong to each node type
const TYPE_GROUPS = {
	"node_3d":            ["_group_n3d_visibility", "_group_n3d_transform"],
	"mesh_instance_3d":   ["_group_mesh_basic"],
	"collision_shape_3d": ["_group_col_basic"],
	"light_3d":           ["_group_light_basic", "_group_light_color", "_group_light_shadow"],
	"rigid_body_3d":      ["_group_rb_basic", "_group_rb_damping"],
	"character_body_3d":  ["_group_cb_basic", "_group_cb_floor"],
	"animation_player":   ["_group_anim_basic"],
	"control":            ["_group_ctrl_basic", "_group_ctrl_transform"],
	"label":              ["_group_lbl_basic"],
	"button":             ["_group_btn_basic"],
	"camera_3d":          ["_group_cam_basic"],
	"sprite_3d":          ["_group_spr_basic", "_group_spr_display", "_group_spr_frames"],
	"custom":             ["_group_custom"],
}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var node_type   = properties.get("node_type", "node_3d")
	var target_node = str(properties.get("target_node", "self")).strip_edges()
	if typeof(node_type) == TYPE_STRING:
		node_type = node_type.to_lower().replace(" ", "_")
	if target_node.is_empty():
		target_node = "self"

	var code_lines: Array[String] = []

	# Build the target reference — self is direct, anything else uses get_node_or_null
	var use_self    = (target_node == "self")
	var target_ref  = "_prop_node_%s" % chain_name if not use_self else "self"
	var indent      = "\t" if not use_self else ""

	# Get the list of property keys for this node type
	var prop_keys: Array = TYPE_PROPS.get(node_type, [])

	# Special case: custom
	if node_type == "custom":
		var gdprop = str(properties.get("custom_property", "")).strip_edges()
		var val    = str(properties.get("custom_value", "")).strip_edges()
		if gdprop.is_empty() or val.is_empty():
			return {"actuator_code": "push_warning(\"Property Actuator: Custom property or value not set — open the brick and fill in both fields\")"}
		code_lines.append("# Property Actuator (custom): %s" % gdprop)
		if not use_self:
			code_lines.append("# Search for node by name: %s" % target_node)
			code_lines.append("var %s = get_tree().root.find_child(\"%s\", true, false)" % [target_ref, target_node])
			code_lines.append("if %s:" % target_ref)
			code_lines.append("\t%s.set_indexed(\"%s\", %s)" % [target_ref, gdprop, val])
			code_lines.append("else:")
			code_lines.append("\tpush_warning(\"Property Actuator: Node named '%s' not found\")" % target_node)
		else:
			code_lines.append("set_indexed(\"%s\", %s)" % [gdprop, val])
		return {"actuator_code": "\n".join(code_lines)}

	# Build assignments for all non-empty properties
	var assignments: Array[String] = []
	for key in prop_keys:
		var val = properties.get(key, "")
		if val == null:
			continue

		var mapped = PROP_MAP.get(key, [])
		if mapped.is_empty():
			continue

		var gdprop:   String = mapped[0]
		var is_color: bool   = mapped[1]

		var val_str: String
		if is_color:
			var c = val
			if typeof(c) == TYPE_COLOR:
				val_str = "Color(%.4f, %.4f, %.4f, %.4f)" % [c.r, c.g, c.b, c.a]
			else:
				continue
		else:
			val_str = str(val).strip_edges()
			if val_str.is_empty():
				continue

		if use_self:
			assignments.append("set_indexed(\"%s\", %s)" % [gdprop, val_str])
		else:
			assignments.append("\t%s.set_indexed(\"%s\", %s)" % [target_ref, gdprop, val_str])

	if assignments.is_empty():
		return {"actuator_code": "push_warning(\"Property Actuator: No values set — open the brick and fill in at least one property\")"}

	code_lines.append("# Property Actuator (%s)" % node_type)
	if not use_self:
		code_lines.append("# Search for node by name: %s" % target_node)
		code_lines.append("var %s = get_tree().root.find_child(\"%s\", true, false)" % [target_ref, target_node])
		code_lines.append("if %s:" % target_ref)
		code_lines.append_array(assignments)
		code_lines.append("else:")
		code_lines.append("\tpush_warning(\"Property Actuator: Node named '%s' not found\")" % target_node)
	else:
		code_lines.append_array(assignments)

	return {"actuator_code": "\n".join(code_lines)}
