@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"


func get_brick_info()->Dictionary: return {"class":"ScreenShake2DActuator","name":"Camera Shake","type":"actuator","category":"Game Feel","domain":"2d","menu_order":500}
func _init()->void: super._init(); brick_type=BrickType.ACTUATOR; brick_name="Camera Shake"
func _initialize_properties()->void: properties={"camera_node_name":"Camera2D","intensity":"10.0","duration":"0.3","rotation_intensity":"1.5"}
func get_property_definitions()->Array: return [{"name":"camera_node_name","type":TYPE_STRING,"default":"Camera2D"},{"name":"intensity","type":TYPE_STRING,"default":"10.0"},{"name":"duration","type":TYPE_STRING,"default":"0.3"},{"name":"rotation_intensity","type":TYPE_STRING,"default":"1.5"}]
func generate_code(node:Node,chain_name:String)->Dictionary:
 var n=_gd(str(properties.get("camera_node_name","Camera2D"))); var i=_to_expr(properties.get("intensity","10.0")); var d=_to_expr(properties.get("duration","0.3")); var r=_to_expr(properties.get("rotation_intensity","1.5")); var l=["var _ss2 = get_tree().current_scene.find_child(\"%s\", true, false) if get_tree().current_scene else null"%n,"if _ss2 is Camera2D:","\tvar _ss2_offset = _ss2.offset","\tvar _ss2_rot = _ss2.rotation","\tvar _ss2_t = create_tween()","\tvar _ss2_steps = max(1, int((%s) / 0.04))"%d,"\tfor _j in range(_ss2_steps):","\t\t_ss2_t.tween_property(_ss2, \"offset\", _ss2_offset + Vector2(randf_range(-(%s), (%s)), randf_range(-(%s), (%s))), 0.02)"%[i,i,i,i],"\t\t_ss2_t.parallel().tween_property(_ss2, \"rotation\", _ss2_rot + deg_to_rad(randf_range(-(%s), (%s))), 0.02)"%[r,r],"\t_ss2_t.tween_property(_ss2, \"offset\", _ss2_offset, 0.03)","\t_ss2_t.parallel().tween_property(_ss2, \"rotation\", _ss2_rot, 0.03)"]
 return {"actuator_code":"\n".join(l)}
func _to_expr(v)->String: var s=str(v).strip_edges(); return "0.0" if s.is_empty() else s
func _gd(s:String)->String: return s.replace("\\","\\\\").replace("\"","\\\"")
