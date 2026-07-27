@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"


func get_brick_info()->Dictionary: return {"class":"WaypointPath2DActuator","name":"Waypoint Path","type":"actuator","category":"Motion","domain":"2d","menu_order":160}
func _init()->void: super._init(); brick_type=BrickType.ACTUATOR; brick_name="Waypoint Path"
func _initialize_properties()->void: properties={"path_node_name":"Path2D","speed":"150.0","loop":true,"face_direction":false}
func get_property_definitions()->Array: return [{"name":"path_node_name","type":TYPE_STRING,"default":"Path2D"},{"name":"speed","type":TYPE_STRING,"default":"150.0"},{"name":"loop","type":TYPE_BOOL,"default":true},{"name":"face_direction","type":TYPE_BOOL,"default":false}]
func generate_code(node:Node,chain_name:String)->Dictionary:
 var name=_gd(str(properties.get("path_node_name","Path2D"))); var speed=_to_expr(properties.get("speed","150.0")); var loop=str(bool(properties.get("loop",true))).to_lower(); var face=bool(properties.get("face_direction",false)); var id=_id(chain_name); var mv=["var _wp2_distance_%s: float = 0.0"%id]; var l=["var _wp2_path = get_tree().current_scene.find_child(\"%s\", true, false) if get_tree().current_scene else null"%name,"if _wp2_path is Path2D and _wp2_path.curve and _wp2_path.curve.get_baked_length() > 0.0:","\tvar _wp2_old = global_position","\t_wp2_distance_%s += (%s) * _delta"%[id,speed],"\tvar _wp2_len = _wp2_path.curve.get_baked_length()","\t_wp2_distance_%s = fmod(_wp2_distance_%s, _wp2_len) if %s else min(_wp2_distance_%s, _wp2_len)"%[id,id,loop,id],"\tglobal_position = _wp2_path.to_global(_wp2_path.curve.sample_baked(_wp2_distance_%s))"%id]
 if face: l += ["\tvar _wp2_motion = global_position - _wp2_old","\tif _wp2_motion.length_squared() > 0.0001: rotation = _wp2_motion.angle()"]
 return {"actuator_code":"\n".join(l),"member_vars":mv}
func _id(s:String)->String: return (instance_name if not instance_name.is_empty() else s).to_lower().replace(" ","_").validate_node_name().replace(".","_")
func _to_expr(v)->String: var s=str(v).strip_edges(); return "0.0" if s.is_empty() else s
func _gd(s:String)->String: return s.replace("\\","\\\\").replace("\"","\\\"")
