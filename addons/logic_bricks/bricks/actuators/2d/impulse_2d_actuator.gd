@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"
func get_brick_info() -> Dictionary: return {"class":"Impulse2DActuator","name":"Impulse 2D","type":"actuator","category":"Physics","domain":"2d","menu_order":410}
func _init()->void: super._init(); brick_type=BrickType.ACTUATOR; brick_name="Impulse 2D"
func get_compatibility_error(node: Node) -> String:
	return "" if node is RigidBody2D else "Requires RigidBody2D"
func _initialize_properties()->void: properties={"x":"0.0","y":"0.0"}
func get_property_definitions()->Array: return [{"name":"x","type":TYPE_STRING,"default":"0.0"},{"name":"y","type":TYPE_STRING,"default":"0.0"}]
func _to_expr(v)->String: var s=str(v).strip_edges(); return "0.0" if s.is_empty() else ("%.3f"%float(s) if s.is_valid_float() or s.is_valid_int() else s)

func get_configuration_warnings(node: Node = null) -> Array[String]:
	var warnings := super.get_configuration_warnings(node)
	if _validation_all_numeric_zero(["x", "y"]):
		warnings.append("Put a Value or Variable in X or Y")
	return warnings

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Applies an instant push to a RigidBody2D. Use Force when the push should continue over time.",
		"x": "Horizontal impulse. Accepts a number, variable, or expression.",
		"y": "Vertical impulse. Accepts a number, variable, or expression.",
	}

func generate_code(node:Node, chain_name:String)->Dictionary: var l=["if self is RigidBody2D:","\tapply_central_impulse(Vector2(%s, %s))"%[_to_expr(properties.get("x","0.0")),_to_expr(properties.get("y","0.0"))],"else: push_warning(\"Impulse 2D requires RigidBody2D\")"]; return {"actuator_code":"\n".join(l)}
