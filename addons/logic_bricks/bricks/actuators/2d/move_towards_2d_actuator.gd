@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"


func get_brick_info()->Dictionary: return {"class":"MoveTowards2DActuator","name":"Move Towards","type":"actuator","category":"Motion","domain":"2d","menu_order":140}
func _init()->void: super._init(); brick_type=BrickType.ACTUATOR; brick_name="Move Towards"
func _initialize_properties()->void: properties={"behavior":"seek","target_mode":"node_name","target_name":"","coordinate_x":"0.0","coordinate_y":"0.0","speed":"200.0","arrival_distance":"4.0","face_target":false,"use_navigation":false}
func get_property_definitions()->Array: return [{"name":"behavior","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Seek,Flee","default":"seek"},{"name":"target_mode","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Node Name,Group,Coordinates","default":"node_name"},{"name":"target_name","type":TYPE_STRING,"default":""},{"name":"coordinate_x","type":TYPE_STRING,"default":"0.0"},{"name":"coordinate_y","type":TYPE_STRING,"default":"0.0"},{"name":"speed","type":TYPE_STRING,"default":"200.0"},{"name":"arrival_distance","type":TYPE_STRING,"default":"4.0"},{"name":"face_target","type":TYPE_BOOL,"default":false},{"name":"use_navigation","type":TYPE_BOOL,"default":false}]
func generate_code(node:Node,chain_name:String)->Dictionary:
 var mode=str(properties.get("target_mode","node_name")).to_lower().replace(" ","_"); var behavior=str(properties.get("behavior","seek")).to_lower(); var name=_gd(str(properties.get("target_name",""))); var x=_to_expr(properties.get("coordinate_x","0.0")); var y=_to_expr(properties.get("coordinate_y","0.0")); var sp=_to_expr(properties.get("speed","200.0")); var ar=_to_expr(properties.get("arrival_distance","4.0")); var face=bool(properties.get("face_target",false)); var nav=bool(properties.get("use_navigation",false)); var l=[]
 if mode=="coordinates": l=["var _mt2_pos = Vector2(%s, %s)"%[x,y]]
 elif mode=="group": l=["var _mt2_node: Node2D = null","var _mt2_best := INF","for _n in get_tree().get_nodes_in_group(\"%s\"):"%name,"\tif _n is Node2D and _n != self:","\t\tvar _d=global_position.distance_squared_to(_n.global_position)","\t\tif _d < _mt2_best: _mt2_best=_d; _mt2_node=_n","var _mt2_pos = _mt2_node.global_position if _mt2_node else global_position"]
 else: l=["var _mt2_node = get_tree().current_scene.find_child(\"%s\", true, false) if get_tree().current_scene else null"%name,"var _mt2_pos = _mt2_node.global_position if _mt2_node is Node2D else global_position"]
 l += ["var _mt2_dir = (_mt2_pos - global_position)","if _mt2_dir.length() > (%s):"%ar]
 if behavior=="flee": l.append("\t_mt2_dir = -_mt2_dir")
 if nav: l += ["\tvar _agent = get_node_or_null(\"NavigationAgent2D\")","\tif _agent is NavigationAgent2D:","\t\t_agent.target_position = _mt2_pos","\t\t_mt2_dir = (_agent.get_next_path_position() - global_position)"]
 l += ["\tvar _mt2_velocity = _mt2_dir.normalized() * (%s)"%sp,"\tif self is CharacterBody2D:","\t\tvelocity = _mt2_velocity","\t\tmove_and_slide()","\telse:","\t\tglobal_position += _mt2_velocity * _delta"]
 if face: l.append("\trotation = _mt2_dir.angle()")
 return {"actuator_code":"\n".join(l)}
func _to_expr(v)->String: var s=str(v).strip_edges(); return "0.0" if s.is_empty() else s
func _gd(s:String)->String: return s.replace("\\","\\\\").replace("\"","\\\"")
