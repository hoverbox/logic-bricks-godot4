@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"
func get_brick_info() -> Dictionary: return {"class":"Jump2DActuator","name":"Character Jump 2D","type":"actuator","category":"Motion","domain":"2d","menu_order":120}
func _init()->void: super._init(); brick_type=BrickType.ACTUATOR; brick_name="Character Jump 2D"
func _initialize_properties()->void: properties={"jump_height":"80.0","gravity_strength":"980.0","max_jumps":"1"}
func get_property_definitions()->Array: return [{"name":"jump_height","type":TYPE_STRING,"default":"80.0"},{"name":"gravity_strength","type":TYPE_STRING,"default":"980.0"},{"name":"max_jumps","type":TYPE_STRING,"default":"1"}]
func _to_expr(v)->String: var s=str(v).strip_edges(); return "0.0" if s.is_empty() else ("%.3f"%float(s) if s.is_valid_float() or s.is_valid_int() else s)
func generate_code(node:Node, chain_name:String)->Dictionary:
	var h=_to_expr(properties.get("jump_height","80.0")); var g=_to_expr(properties.get("gravity_strength","980.0")); var m=_to_expr(properties.get("max_jumps","1")); var l:Array[String]=[]; l.append("if not (self is CharacterBody2D):"); l.append("\tpush_warning(\"Character Jump 2D requires CharacterBody2D\")"); l.append("else:"); l.append("\tvar _jumps_remaining = int(get_meta('_logic_brick_jumps_remaining', int(%s)))"%m); l.append("\tif is_on_floor(): _jumps_remaining = int(%s)"%m); l.append("\tif _jumps_remaining > 0:"); l.append("\t\tvelocity.y = -sqrt(2.0 * float(%s) * float(%s))"%[g,h]); l.append("\t\t_jumps_remaining -= 1"); l.append("\tset_meta('_logic_brick_jumps_remaining', _jumps_remaining)"); return {"actuator_code":"\n".join(l)}
