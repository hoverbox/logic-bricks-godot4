@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"


func get_brick_info()->Dictionary: return {"class":"Collision2DActuator","name":"Collisions","type":"actuator","category":"Physics","domain":"2d","menu_order":430}
func _init()->void: super._init(); brick_type=BrickType.ACTUATOR; brick_name="Collisions"
func _initialize_properties()->void: properties={"action":"disable_shape","target_node":"CollisionShape2D","layer_value":1,"bit_enabled":true}
func get_property_definitions()->Array: return [{"name":"action","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Disable Shape,Enable Shape,Set Layer Bit,Set Mask Bit,Enable Monitoring,Disable Monitoring","default":"disable_shape"},{"name":"target_node","type":TYPE_STRING,"default":"CollisionShape2D"},{"name":"layer_value","type":TYPE_INT,"hint":PROPERTY_HINT_RANGE,"hint_string":"1,32,1","default":1},{"name":"bit_enabled","type":TYPE_BOOL,"default":true}]
func generate_code(node:Node,chain_name:String)->Dictionary:
 var a=str(properties.get("action","disable_shape")).to_lower().replace(" ","_"); var n=_gd(str(properties.get("target_node","CollisionShape2D"))); var bit=int(properties.get("layer_value",1)); var en=str(bool(properties.get("bit_enabled",true))).to_lower(); var l=["var _c2 = get_tree().current_scene.find_child(\"%s\", true, false) if get_tree().current_scene else null"%n,"if _c2:"]
 match a:
  "disable_shape": l.append("\tif _c2 is CollisionShape2D or _c2 is CollisionPolygon2D: _c2.set_deferred(\"disabled\", true)")
  "enable_shape": l.append("\tif _c2 is CollisionShape2D or _c2 is CollisionPolygon2D: _c2.set_deferred(\"disabled\", false)")
  "set_layer_bit": l.append("\tif _c2 is CollisionObject2D: _c2.set_collision_layer_value(%d, %s)"%[bit,en])
  "set_mask_bit": l.append("\tif _c2 is CollisionObject2D: _c2.set_collision_mask_value(%d, %s)"%[bit,en])
  "enable_monitoring": l.append("\tif _c2 is Area2D: _c2.set_deferred(\"monitoring\", true)")
  "disable_monitoring": l.append("\tif _c2 is Area2D: _c2.set_deferred(\"monitoring\", false)")
 l += ["else:","\tpush_warning(\"Collisions: target not found\")"]
 return {"actuator_code":"\n".join(l)}
func _gd(s:String)->String: return s.replace("\\","\\\\").replace("\"","\\\"")
