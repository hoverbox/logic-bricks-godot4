@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"
func get_brick_info() -> Dictionary: return {"class":"LinearVelocity2DActuator","name":"Linear Velocity 2D","type":"actuator","category":"Physics","domain":"2d","menu_order":420}
func _init()->void: super._init(); brick_type=BrickType.ACTUATOR; brick_name="Linear Velocity 2D"
func _initialize_properties()->void: properties={"x":"0.0","y":"0.0"}
func get_property_definitions()->Array: return [{"name":"x","type":TYPE_STRING,"default":"0.0"},{"name":"y","type":TYPE_STRING,"default":"0.0"}]
func _to_expr(v)->String: var s=str(v).strip_edges(); return "0.0" if s.is_empty() else ("%.3f"%float(s) if s.is_valid_float() or s.is_valid_int() else s)
func generate_code(node:Node, chain_name:String)->Dictionary:
	var v="Vector2(%s, %s)"%[_to_expr(properties.get("x","0.0")),_to_expr(properties.get("y","0.0"))]
	var code = "var _lv_current = get(\"linear_velocity\")\nvar _vel_current = get(\"velocity\")\nif _lv_current is Vector2:\n\tset(\"linear_velocity\", %s)\nelif _vel_current is Vector2:\n\tset(\"velocity\", %s)\nelse:\n\tpush_warning(\"Linear Velocity 2D requires RigidBody2D or CharacterBody2D\")" % [v, v]
	return {"actuator_code": code}
