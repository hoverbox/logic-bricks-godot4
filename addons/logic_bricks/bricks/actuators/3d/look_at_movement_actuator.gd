@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"

## Rotates a node to face the direction of movement
## Target node is assigned via @export variable in the inspector (drag and drop)
## Forward axis setting corrects for meshes whose front isn't -Z


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Look At Movement"


func _initialize_properties() -> void:
	properties = {
		"forward_axis": "-z",  # Which direction the mesh considers "forward"
		"smoothing": 0.1,  # How smoothly to rotate (0 = instant, higher = smoother)
	}


func get_property_definitions() -> Array:
	return [
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
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Rotates a node to face the direction of movement.\n\n⚠ Adds an @export in the Inspector — assign the mesh/Node3D to rotate there.",
		"forward_axis": "Which direction the mesh considers 'forward'.\n-Z is Godot's default forward direction.",
		"smoothing": "How smoothly to rotate.\n0 = instant, higher = smoother.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var forward_axis = properties.get("forward_axis", "-z")
	var smoothing = properties.get("smoothing", 0.1)

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

	var target_var = "_look_at_target_%s" % chain_name
	var last_pos_var = "_look_at_last_pos_%s" % chain_name

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	# Exported Node3D variable — user assigns via inspector drag-and-drop
	member_vars.append("@export var %s: Node3D" % target_var)
	member_vars.append("var %s: Vector3 = Vector3.INF" % last_pos_var)

	code_lines.append("# Rotate target node to face movement direction")
	code_lines.append("if not %s:" % target_var)
	code_lines.append("\tpush_warning(\"Look At Movement: No Node3D assigned to '%s' — drag one into the inspector\")" % target_var)
	code_lines.append("else:")

	# Track position change
	code_lines.append("\t# Track position change for movement direction")
	code_lines.append("\tif %s == Vector3.INF:" % last_pos_var)
	code_lines.append("\t\t%s = global_position" % last_pos_var)
	code_lines.append("\tvar _movement_dir = global_position - %s" % last_pos_var)
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
		code_lines.append("\t\t# Smooth rotation using look_at")
		code_lines.append("\t\tvar _current_y = %s.global_rotation.y" % target_var)
		code_lines.append("\t\t%s.look_at(_look_target, Vector3.UP)" % target_var)
		code_lines.append("\t\tvar _target_y = %s.global_rotation.y + %s" % [target_var, y_offset])
		code_lines.append("\t\t%s.global_rotation.y = lerp_angle(_current_y, _target_y, %f)" % [target_var, smoothing])
	else:
		code_lines.append("\t\t# Instant rotation")
		code_lines.append("\t\t%s.look_at(_look_target, Vector3.UP)" % target_var)
		if y_offset != "0.0":
			code_lines.append("\t\t%s.global_rotation.y += %s" % [target_var, y_offset])

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
