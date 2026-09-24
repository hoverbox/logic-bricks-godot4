@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"


func get_brick_info()->Dictionary: return {"class":"Collision2DActuator","name":"Collisions","type":"actuator","category":"Physics","domain":"2d","menu_order":430}
func _init()->void: super._init(); brick_type=BrickType.ACTUATOR; brick_name="Collisions"
func _initialize_properties()->void: properties={"action":"disable_shape","target_node":"CollisionShape2D","layer_value":1,"bit_enabled":true}
func get_property_definitions()->Array: return [{"name":"action","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Disable Shape,Enable Shape,Set Layer Bit,Set Mask Bit,Enable Monitoring,Disable Monitoring","default":"disable_shape"},{"name":"target_node", "required": true, "required_label": "a collision target node name","type":TYPE_STRING,"default":"CollisionShape2D","node_reference":true,"node_picker_scope":"scene","accepted_node_types":["CollisionShape2D","CollisionPolygon2D","CollisionObject2D","Area2D"]},{"name":"layer_value","type":TYPE_INT,"hint":PROPERTY_HINT_RANGE,"hint_string":"1,32,1","default":1},{"name":"bit_enabled","type":TYPE_BOOL,"default":true}]
func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Enables, disables, or edits 2D collision settings on a target node.",
		"action": "Choose which collision setting to change.",
		"target_node": "CollisionShape2D, CollisionPolygon2D, CollisionObject2D, or Area2D node name.",
		"layer_value": "Collision layer or mask bit from 1 to 32.",
		"bit_enabled": "Turn the selected layer or mask bit on or off.",
	}

func generate_code(node:Node,chain_name:String)->Dictionary:
	var a=str(properties.get("action","disable_shape")).to_lower().replace(" ","_"); var n=_gd_string(str(properties.get("target_node","CollisionShape2D"))); var bit=int(properties.get("layer_value",1)); var en=str(bool(properties.get("bit_enabled",true))).to_lower(); var l=["var _c2 = get_tree().current_scene.find_child(\"%s\", true, false) if get_tree().current_scene else null"%n,"if _c2:"]
	match a:
		"disable_shape": l.append("\tif _c2 is CollisionShape2D or _c2 is CollisionPolygon2D: _c2.set_deferred(\"disabled\", true)")
		"enable_shape": l.append("\tif _c2 is CollisionShape2D or _c2 is CollisionPolygon2D: _c2.set_deferred(\"disabled\", false)")
		"set_layer_bit": l.append("\tif _c2 is CollisionObject2D: _c2.set_collision_layer_value(%d, %s)"%[bit,en])
		"set_mask_bit": l.append("\tif _c2 is CollisionObject2D: _c2.set_collision_mask_value(%d, %s)"%[bit,en])
		"enable_monitoring": l.append("\tif _c2 is Area2D: _c2.set_deferred(\"monitoring\", true)")
		"disable_monitoring": l.append("\tif _c2 is Area2D: _c2.set_deferred(\"monitoring\", false)")
	l += ["else:","\tpush_warning(\"Collisions: target not found\")"]
	return {"actuator_code":"\n".join(l)}
