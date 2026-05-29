@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Rotates a node to face the direction of movement
## Target node is found by typed node name at runtime
## Forward axis setting corrects for meshes whose front isn't -Z


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Look At Movement"


func _initialize_properties() -> void:
	properties = {
		"target_node_name": "MeshInstance3D",
		"forward_axis": "-z",  # Which direction the mesh considers "forward"
		"smoothing": 0.1,  # How smoothly to rotate (0 = instant, higher = smoother)
		"ignore_platform_motion": true,  # Ignore moving platform carry/inherited velocity when choosing look direction
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "target_node_name",
			"type": TYPE_STRING,
			"default": "MeshInstance3D",
			"placeholder": "Node3D node name"
		},
		{
			"name": "forward_axis",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "-Z (Godot Default),+Z,+X,-X",
			"default": "-z"
		},
		{
			"name": "smoothing",
			"type": TYPE_FLOAT,
			"default": 0.1
		},
		{
			"name": "ignore_platform_motion",
			"type": TYPE_BOOL,
			"default": true
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Rotates a Node3D to face the direction of movement. Type the node name; the generated script finds it in the current scene at runtime.",
		"target_node_name": "The name of the Node3D to rotate, such as PlayerMesh or CharacterModel. Searches the whole current scene tree by node name.",
		"forward_axis": "Which direction the mesh considers 'forward'.\n-Z is Godot's default forward direction.",
		"smoothing": "How smoothly to rotate.\n0 = instant, higher = smoother.",
		"ignore_platform_motion": "When enabled, moving-platform carry and inherited platform velocity are removed before choosing the look direction. This keeps the character facing the player's input movement instead of the platform's movement.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var target_node_name = str(properties.get("target_node_name", "MeshInstance3D")).strip_edges()
	var forward_axis = properties.get("forward_axis", "-z")
	var smoothing = properties.get("smoothing", 0.1)
	var ignore_platform_motion = properties.get("ignore_platform_motion", true)

	# Normalize
	if typeof(forward_axis) == TYPE_STRING:
		forward_axis = forward_axis.to_lower().replace(" ", "_")

	# Y rotation offset to correct for mesh forward direction
	# look_at() makes -Z point at the target, so we offset based on where the mesh's front actually is
	var y_offset = "0.0"
	match forward_axis:
		"-z", "-z_(godot_default)":
			y_offset = "0.0"          # No correction needed
		"+z":
			y_offset = "PI"           # 180 degrees
		"+x":
			y_offset = "-PI / 2.0"   # -90 degrees
		"-x":
			y_offset = "PI / 2.0"    # 90 degrees

	var label = _unique_label(chain_name)
	var target_var = "_%s_target_node" % label
	var last_pos_var = "_look_at_last_pos_%s" % chain_name

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	# Runtime Node3D reference — resolved by typed node name
	member_vars.append("var %s: Node3D = null" % target_var)
	_append_find_node_helpers(member_vars)
	member_vars.append("var %s: Vector3 = Vector3.INF" % last_pos_var)
	if ignore_platform_motion:
		# Character/Gravity actuators write this after movement so next frame can ignore external carry.
		# When no platform actuator is present it remains zero.
		member_vars.append("var _logic_brick_external_motion_delta: Vector3 = Vector3.ZERO")

	code_lines.append("# Rotate target node to face movement direction")
	code_lines.append("var _target_name_%s = \"%s\"" % [label, _gd_string(target_node_name)])
	code_lines.append("if _target_name_%s.is_empty():" % label)
	code_lines.append("\tpush_warning(\"Look At Movement: No target node name set\")")
	code_lines.append("\t%s = null" % target_var)
	code_lines.append("elif %s == null or %s.name != _target_name_%s:" % [target_var, target_var, label])
	code_lines.append("\tvar _found_target_%s = _lb_find_node_in_current_scene(_target_name_%s)" % [label, label])
	code_lines.append("\tif _found_target_%s is Node3D:" % label)
	code_lines.append("\t\t%s = _found_target_%s" % [target_var, label])
	code_lines.append("\telif _found_target_%s:" % label)
	code_lines.append("\t\tpush_warning(\"Look At Movement: node '\" + str(_target_name_%s) + \"' is not a Node3D\")" % label)
	code_lines.append("if not %s:" % target_var)
	code_lines.append("\tpush_warning(\"Look At Movement: could not find Node3D named '\" + str(_target_name_%s) + \"'\")" % label)
	code_lines.append("else:")

	# Track position change
	code_lines.append("\t# Track position change for movement direction")
	code_lines.append("\tif %s == Vector3.INF:" % last_pos_var)
	code_lines.append("\t\t%s = global_position" % last_pos_var)
	code_lines.append("\tvar _movement_dir = global_position - %s" % last_pos_var)
	if ignore_platform_motion:
		code_lines.append("\t# Remove last frame's platform-carried/inherited motion so facing follows player movement")
		code_lines.append("\t_movement_dir -= _logic_brick_external_motion_delta")
	code_lines.append("\t%s = global_position" % last_pos_var)

	code_lines.append("\t")
	code_lines.append("\t# Flatten to horizontal plane")
	code_lines.append("\t_movement_dir.y = 0.0")
	code_lines.append("\t")
	code_lines.append("\t# Only rotate if actually moving")
	code_lines.append("\tif _movement_dir.length_squared() > 0.0001:")
	code_lines.append("\t\tvar _look_target = global_position + _movement_dir.normalized()")
	code_lines.append("\t\t")

	if smoothing > 0.001:
		code_lines.append("\t\t# Smooth Y-axis rotation only")
		code_lines.append("\t\tvar _target_angle = atan2(_movement_dir.x, _movement_dir.z) + %s" % y_offset)
		code_lines.append("\t\tvar _current_y = %s.global_rotation.y" % target_var)
		code_lines.append("\t\t%s.global_rotation.y = lerp_angle(_current_y, _target_angle, %f)" % [target_var, smoothing])
	else:
		code_lines.append("\t\t# Instant Y-axis rotation")
		code_lines.append("\t\t%s.global_rotation.y = atan2(_movement_dir.x, _movement_dir.z) + %s" % [target_var, y_offset])

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}

func _append_find_node_helpers(member_vars: Array[String]) -> void:
	member_vars.append("")
	member_vars.append("func _lb_find_node_by_name_recursive(node: Node, target_name: String) -> Node:")
	member_vars.append("\tif node == null or target_name.is_empty():")
	member_vars.append("\t\treturn null")
	member_vars.append("\tif node.name == target_name:")
	member_vars.append("\t\treturn node")
	member_vars.append("\tfor child in node.get_children():")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(child, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn null")
	member_vars.append("")
	member_vars.append("func _lb_find_node_in_current_scene(target_name: String) -> Node:")
	member_vars.append("\tvar scene_root = get_tree().current_scene")
	member_vars.append("\tif scene_root:")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(scene_root, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn _lb_find_node_by_name_recursive(get_tree().root, target_name)")

func _unique_label(chain_name: String) -> String:
	var label = instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	label = label.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	return label if not label.is_empty() else chain_name

func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")
