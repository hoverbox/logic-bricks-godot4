@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"


func get_brick_info()->Dictionary: return {"class":"RotateTowards2DActuator","name":"Rotate Towards","type":"actuator","category":"Motion","domain":"2d","menu_order":150}
func _init()->void: super._init(); brick_type=BrickType.ACTUATOR; brick_name="Rotate Towards"
func _initialize_properties()->void: properties={"target_mode":"node_name","target_name":"","speed":"180.0","angle_offset":"0.0"}
func get_property_definitions()->Array: return [{"name":"target_mode","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Node Name,Group","default":"node_name"},{"name":"target_name","type":TYPE_STRING,"default":""},{"name":"speed","type":TYPE_STRING,"default":"180.0"},{"name":"angle_offset","type":TYPE_STRING,"default":"0.0"}]
func generate_code(node:Node,chain_name:String)->Dictionary:
 var mode=str(properties.get("target_mode","node_name")).to_lower().replace(" ","_"); var name=_gd(str(properties.get("target_name",""))); var speed=_to_expr(properties.get("speed","180.0")); var off=_to_expr(properties.get("angle_offset","0.0")); var l=[]
 if mode=="group": l=["var _rt2: Node2D = null","var _rt2d := INF","for _n in get_tree().get_nodes_in_group(\"%s\"):"%name,"\tif _n is Node2D and _n != self:","\t\tvar _d = global_position.distance_squared_to(_n.global_position)","\t\tif _d < _rt2d: _rt2d = _d; _rt2 = _n"]
 else: l=["var _rt2 = get_tree().current_scene.find_child(\"%s\", true, false) if get_tree().current_scene else null"%name]
 l += ["if _rt2 is Node2D:","\tvar _angle = global_position.angle_to_point(_rt2.global_position) + deg_to_rad(%s)"%off,"\tvar _step = deg_to_rad(%s) * _delta"%speed,"\tglobal_rotation = _angle if (%s) <= 0.0 else rotate_toward(global_rotation, _angle, _step)"%speed]
 return {"actuator_code":"\n".join(l)}
func _to_expr(v)->String: var s=str(v).strip_edges(); return "0.0" if s.is_empty() else s
func _gd(s:String)->String: return s.replace("\\","\\\\").replace("\"","\\\"")
