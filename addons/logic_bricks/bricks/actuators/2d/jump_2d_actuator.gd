@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"
func get_brick_info() -> Dictionary: return {"class":"Jump2DActuator","name":"Character Jump 2D","type":"actuator","category":"Motion","domain":"2d","menu_order":20}
func _init()->void: super._init(); brick_type=BrickType.ACTUATOR; brick_name="Character Jump 2D"
func get_compatibility_error(node: Node) -> String:
	return "" if node is CharacterBody2D else "Requires CharacterBody2D"
func _initialize_properties()->void: properties={"jump_height":"80.0","gravity_strength":"980.0","max_jumps":"1","inherit_platform_velocity":true,"ignore_jump_limit":false}
func get_property_definitions()->Array: return [{"name":"jump_height","type":TYPE_STRING,"default":"80.0"},{"name":"gravity_strength","type":TYPE_STRING,"default":"980.0"},{"name":"max_jumps","type":TYPE_STRING,"default":"1"},{"name":"inherit_platform_velocity","type":TYPE_BOOL,"default":true},{"name":"ignore_jump_limit","type":TYPE_BOOL,"default":false}]
func _to_expr(v)->String: var s=str(v).strip_edges(); return "0.0" if s.is_empty() else ("%.3f"%float(s) if s.is_valid_float() or s.is_valid_int() else s)
func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Applies a jump to a CharacterBody2D. Pair with Character Physics for gravity and grounded behavior.",
		"jump_height": "Approximate jump height in pixels.",
		"gravity_strength": "Gravity used to calculate the launch speed.",
		"max_jumps": "Number of jumps allowed before touching the floor again.",
		"inherit_platform_velocity": "Carry horizontal moving-platform velocity when jumping from a platform.",
		"ignore_jump_limit": "Jump even when no normal jumps remain. Useful for enemy stomps, bounce pads, knockback launches, and other forced jumps. Does not consume the normal jump counter.",
	}

func generate_code(node:Node, chain_name:String)->Dictionary:
	var h=_to_expr(properties.get("jump_height","80.0")); var g=_to_expr(properties.get("gravity_strength","980.0")); var m=_to_expr(properties.get("max_jumps","1")); var inherit_platform_velocity:bool=properties.get("inherit_platform_velocity",true); var ignore_limit:bool=properties.get("ignore_jump_limit",false); var l:Array[String]=[]; l.append("if not (self is CharacterBody2D):"); l.append("\tpush_warning(\"Character Jump 2D requires CharacterBody2D\")"); l.append("else:"); l.append("\tvar _jumps_remaining = int(get_meta('_logic_brick_jumps_remaining', int(%s)))"%m); l.append("\tif is_on_floor(): _jumps_remaining = int(%s)"%m);
	if ignore_limit:
		if inherit_platform_velocity:
			l.append("\tif is_on_floor(): _inherited_platform_velocity_2d = Vector2(get_platform_velocity().x, 0.0)")
		l.append("\tvelocity.y = -sqrt(2.0 * float(%s) * float(%s))"%[g,h])
	else:
		l.append("\tif _jumps_remaining > 0:")
		if inherit_platform_velocity:
			l.append("\t\tif is_on_floor(): _inherited_platform_velocity_2d = Vector2(get_platform_velocity().x, 0.0)")
		l.append("\t\tvelocity.y = -sqrt(2.0 * float(%s) * float(%s))"%[g,h]); l.append("\t\t_jumps_remaining -= 1")
	l.append("\tset_meta('_logic_brick_jumps_remaining', _jumps_remaining)"); return {"actuator_code":"\n".join(l),"member_vars":["var _inherited_platform_velocity_2d: Vector2 = Vector2.ZERO"]}
