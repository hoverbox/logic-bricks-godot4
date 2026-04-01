@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Collision Actuator - Modify collision properties at runtime
## Can enable/disable CollisionShape3D nodes, set collision layer/mask bits,
## and toggle Area3D monitoring. Target node is assigned via @export (drag and drop in inspector).
##
## NOTE: Area3D can detect PhysicsBody3D nodes (CharacterBody3D, RigidBody3D, etc.)
## without requiring an Area3D on the other object. Ensure the Area3D's collision
## MASK includes the layer the player's body is on.


# Maps enum index -> internal action key.
# Must match the order of hint_string in get_property_definitions().
const ACTION_KEYS := [
	"disable_shape",
	"enable_shape",
	"set_layer_bit",
	"set_mask_bit",
	"enable_monitoring",
	"disable_monitoring",
]


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Collision"


func _initialize_properties() -> void:
	properties = {
		# Stored as an int index matching ACTION_KEYS / hint_string order.
		"action": 0,
		# Layer/mask number (1-32) for set_layer_bit / set_mask_bit
		"layer_value": 1,
		# Whether to enable or disable the layer/mask bit
		"bit_enabled": true,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "action",
			"type": TYPE_INT,
			"hint": PROPERTY_HINT_ENUM,
			# Order must match ACTION_KEYS above.
			"hint_string": "Disable Shape,Enable Shape,Set Layer Bit,Set Mask Bit,Enable Monitoring,Disable Monitoring",
			"default": 0
		},
		{
			"name": "layer_value",
			"type": TYPE_INT,
			"default": 1
		},
		{
			"name": "bit_enabled",
			"type": TYPE_BOOL,
			"default": true
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var action_raw = properties.get("action", 0)
	var layer_value = properties.get("layer_value", 1)
	var bit_enabled: bool = properties.get("bit_enabled", true)

	# Resolve action key whether stored as int index or legacy string.
	var action: String
	if typeof(action_raw) == TYPE_INT:
		action = ACTION_KEYS[clampi(action_raw, 0, ACTION_KEYS.size() - 1)]
	else:
		# Legacy: normalise old string values so existing scenes keep working.
		action = str(action_raw).to_lower().replace(" ", "_")
		if action not in ACTION_KEYS:
			action = "disable_shape"

	# Coerce layer_value to int in case it was serialised as a string.
	if typeof(layer_value) == TYPE_STRING:
		layer_value = int(layer_value) if str(layer_value).is_valid_int() else 1

	# Build a sanitized export label from the instance/brick name (same pattern as collision sensor)
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name

	var node_var := "_%s" % _export_label
	var temp_var := "_col_tgt_%s" % chain_name

	var member_vars: Array[String] = []
	var code_lines: Array[String] = []

	# Exported node reference — type is narrowed to match the action so the
	# inspector only allows dragging in a compatible node.
	var export_type: String
	match action:
		"disable_shape", "enable_shape":
			export_type = "CollisionShape3D"
		"enable_monitoring", "disable_monitoring":
			export_type = "Area3D"
		_:  # set_layer_bit, set_mask_bit — base class, fall back to Node
			export_type = "Node"
	member_vars.append("@export var %s: %s" % [node_var, export_type])

	code_lines.append("var %s = %s" % [temp_var, node_var])
	code_lines.append("if %s == null:" % temp_var)
	code_lines.append('\tpush_warning("CollisionActuator: no node assigned to \'%s\' — drag one into the Inspector")' % node_var)
	code_lines.append("else:")

	match action:
		"disable_shape":
			code_lines.append("\tif %s is CollisionShape3D or %s is CollisionShape2D:" % [temp_var, temp_var])
			code_lines.append("\t\t%s.disabled = true" % temp_var)
			code_lines.append("\telse:")
			code_lines.append('\t\tpush_warning("CollisionActuator: disable_shape target is not a CollisionShape: " + str(%s))' % temp_var)

		"enable_shape":
			code_lines.append("\tif %s is CollisionShape3D or %s is CollisionShape2D:" % [temp_var, temp_var])
			code_lines.append("\t\t%s.disabled = false" % temp_var)
			code_lines.append("\telse:")
			code_lines.append('\t\tpush_warning("CollisionActuator: enable_shape target is not a CollisionShape: " + str(%s))' % temp_var)

		"set_layer_bit":
			code_lines.append("\tif %s is CollisionObject3D or %s is CollisionObject2D:" % [temp_var, temp_var])
			code_lines.append("\t\t%s.set_collision_layer_value(%d, %s)" % [temp_var, layer_value, str(bit_enabled).to_lower()])
			code_lines.append("\telse:")
			code_lines.append('\t\tpush_warning("CollisionActuator: set_layer_bit target is not a CollisionObject: " + str(%s))' % temp_var)

		"set_mask_bit":
			# Reminder: for an Area3D to detect a CharacterBody3D without the player
			# having its own Area3D, the Area3D's MASK must include the player's LAYER.
			code_lines.append("\tif %s is CollisionObject3D or %s is CollisionObject2D:" % [temp_var, temp_var])
			code_lines.append("\t\t%s.set_collision_mask_value(%d, %s)" % [temp_var, layer_value, str(bit_enabled).to_lower()])
			code_lines.append("\telse:")
			code_lines.append('\t\tpush_warning("CollisionActuator: set_mask_bit target is not a CollisionObject: " + str(%s))' % temp_var)

		"enable_monitoring":
			code_lines.append("\tif %s is Area3D or %s is Area2D:" % [temp_var, temp_var])
			code_lines.append("\t\t%s.monitoring = true" % temp_var)
			code_lines.append("\t\t%s.monitorable = true" % temp_var)
			code_lines.append("\telse:")
			code_lines.append('\t\tpush_warning("CollisionActuator: enable_monitoring target is not an Area: " + str(%s))' % temp_var)

		"disable_monitoring":
			code_lines.append("\tif %s is Area3D or %s is Area2D:" % [temp_var, temp_var])
			code_lines.append("\t\t%s.monitoring = false" % temp_var)
			code_lines.append("\t\t%s.monitorable = false" % temp_var)
			code_lines.append("\telse:")
			code_lines.append('\t\tpush_warning("CollisionActuator: disable_monitoring target is not an Area: " + str(%s))' % temp_var)

		_:
			code_lines.append('\tpush_warning("CollisionActuator: unknown action: %s")' % action)

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
