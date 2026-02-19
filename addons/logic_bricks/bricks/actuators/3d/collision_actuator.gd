@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Collision Actuator - Modify collision properties at runtime
## Can enable/disable CollisionShape3D nodes, set collision layer/mask bits,
## and toggle Area3D monitoring. Target node is specified by name (child path).


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Collision"


func _initialize_properties() -> void:
	properties = {
		"action": "disable_shape",  # disable_shape, enable_shape, set_layer, set_mask, enable_monitoring, disable_monitoring
		"target_node": "",  # Name or path of the target node (child of the logic brick owner)
		"layer_value": 1,  # Layer/mask number (1-32) for set_layer/set_mask
		"bit_enabled": true,  # Whether to enable or disable the layer/mask bit
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Disable Shape,Enable Shape,Set Layer Bit,Set Mask Bit,Enable Monitoring,Disable Monitoring",
			"default": "disable_shape"
		},
		{
			"name": "target_node",
			"type": TYPE_STRING,
			"default": ""
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
	var action = properties.get("action", "disable_shape")
	var target_node = properties.get("target_node", "")
	var layer_value = properties.get("layer_value", 1)
	var bit_enabled = properties.get("bit_enabled", true)
	
	# Normalize
	if typeof(action) == TYPE_STRING:
		action = action.to_lower().replace(" ", "_")
	if typeof(layer_value) == TYPE_STRING:
		layer_value = int(layer_value) if str(layer_value).is_valid_int() else 1
	
	var code_lines: Array[String] = []
	
	if target_node.is_empty():
		code_lines.append("pass  # No target node specified for collision actuator")
		return {"actuator_code": "\n".join(code_lines)}
	
	var node_ref = 'get_node_or_null("%s")' % target_node
	var temp_var = "_collision_target_%s" % chain_name
	
	code_lines.append("var %s = %s" % [temp_var, node_ref])
	code_lines.append("if %s:" % temp_var)
	
	match action:
		"disable_shape":
			code_lines.append("\tif %s is CollisionShape3D or %s is CollisionShape2D:" % [temp_var, temp_var])
			code_lines.append("\t\t%s.disabled = true" % temp_var)
		
		"enable_shape":
			code_lines.append("\tif %s is CollisionShape3D or %s is CollisionShape2D:" % [temp_var, temp_var])
			code_lines.append("\t\t%s.disabled = false" % temp_var)
		
		"set_layer_bit":
			# Layer bits are 0-indexed internally but 1-indexed for users
			var bit_index = clamp(layer_value - 1, 0, 31)
			code_lines.append("\tif %s is CollisionObject3D or %s is CollisionObject2D:" % [temp_var, temp_var])
			code_lines.append("\t\t%s.set_collision_layer_value(%d, %s)" % [temp_var, layer_value, "true" if bit_enabled else "false"])
		
		"set_mask_bit":
			var bit_index = clamp(layer_value - 1, 0, 31)
			code_lines.append("\tif %s is CollisionObject3D or %s is CollisionObject2D:" % [temp_var, temp_var])
			code_lines.append("\t\t%s.set_collision_mask_value(%d, %s)" % [temp_var, layer_value, "true" if bit_enabled else "false"])
		
		"enable_monitoring":
			code_lines.append("\tif %s is Area3D or %s is Area2D:" % [temp_var, temp_var])
			code_lines.append("\t\t%s.monitoring = true" % temp_var)
			code_lines.append("\t\t%s.monitorable = true" % temp_var)
		
		"disable_monitoring":
			code_lines.append("\tif %s is Area3D or %s is Area2D:" % [temp_var, temp_var])
			code_lines.append("\t\t%s.monitoring = false" % temp_var)
			code_lines.append("\t\t%s.monitorable = false" % temp_var)
	
	return {"actuator_code": "\n".join(code_lines)}
