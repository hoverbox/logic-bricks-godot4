@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"


func get_brick_info()->Dictionary: return {"class":"Force2DActuator","name":"Force","type":"actuator","category":"Physics","domain":"2d","menu_order":400}
func _init()->void: super._init(); brick_type=BrickType.ACTUATOR; brick_name="Force"
func _initialize_properties()->void: properties={"x":"0.0","y":"-100.0","space":"global","apply_at_point":false,"point_x":"0.0","point_y":"0.0"}
func get_property_definitions()->Array: return [{"name":"x","type":TYPE_STRING,"default":"0.0"},{"name":"y","type":TYPE_STRING,"default":"-100.0"},{"name":"space","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Global,Local","default":"global"},{"name":"apply_at_point","type":TYPE_BOOL,"default":false},{"name":"point_x","type":TYPE_STRING,"default":"0.0"},{"name":"point_y","type":TYPE_STRING,"default":"0.0"}]
func generate_code(node:Node,chain_name:String)->Dictionary:
 var f="Vector2(%s, %s)"%[_to_expr(properties.get("x","0.0")),_to_expr(properties.get("y","-100.0"))]
 if str(properties.get("space","global")).to_lower()=="local":
  f="global_transform.basis_xform(%s)"%f
 var call="apply_force(%s, Vector2(%s, %s))"%[f,_to_expr(properties.get("point_x","0.0")),_to_expr(properties.get("point_y","0.0"))] if properties.get("apply_at_point",false) else "apply_central_force(%s)"%f
 return {"actuator_code":"if self is RigidBody2D:\n\t%s\nelse:\n\tpush_warning(\"Force requires RigidBody2D\")"%call}
func _to_expr(v)->String: var s=str(v).strip_edges(); return "0.0" if s.is_empty() else s
