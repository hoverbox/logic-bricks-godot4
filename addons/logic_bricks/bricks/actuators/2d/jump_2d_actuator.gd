@tool
extends "res://addons/logic_bricks/core/logic_brick.gd"
func get_brick_info() -> Dictionary: return {"class":"Jump2DActuator","name":"Character Jump 2D","type":"actuator","category":"Motion","domain":"2d","menu_order":20}
func _init()->void: super._init(); brick_type=BrickType.ACTUATOR; brick_name="Character Jump 2D"
func get_compatibility_error(node: Node) -> String:
	return "" if node is CharacterBody2D else "Requires CharacterBody2D"
func _initialize_properties()->void: properties={"mode":"jump","jump_height":"80.0","gravity_strength":"980.0","max_jumps":"1","inherit_platform_velocity":true,"ignore_jump_limit":false}
func get_property_definitions()->Array: return [{"name":"mode","type":TYPE_STRING,"hint":PROPERTY_HINT_ENUM,"hint_string":"Jump:jump,Reset Jump Count:reset","default":"jump"},{"name":"jump_height","type":TYPE_STRING,"default":"80.0"},{"name":"gravity_strength","type":TYPE_STRING,"default":"980.0"},{"name":"max_jumps","type":TYPE_STRING,"default":"1"},{"name":"inherit_platform_velocity","type":TYPE_BOOL,"default":true},{"name":"ignore_jump_limit","type":TYPE_BOOL,"default":false}]
func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Applies a jump to a CharacterBody2D. Pair with Character Physics for gravity and grounded behavior.",
		"mode": "Jump launches the character. Reset Jump Count restores Max Jumps without changing velocity. Trigger reset when attaching to a wall or reaching a checkpoint.",
		"jump_height": "Approximate jump height in pixels.",
		"gravity_strength": "Gravity used to calculate the launch speed.",
		"max_jumps": "Jump: jumps allowed before landing. Reset Jump Count: jumps to restore; use the same value as your normal Jump action.",
		"inherit_platform_velocity": "Carry horizontal moving-platform velocity when jumping from a platform.",
		"ignore_jump_limit": "Jump even when no normal jumps remain. Useful for enemy stomps, bounce pads, knockback launches, and other forced jumps. Does not consume the normal jump counter.",
	}

## Member variables this brick declares that keep their value when the node
## changes state (other state-specific variables are reset on state entry).
## Platform velocity is shared with the Character 2D brick.
func get_kept_member_vars() -> PackedStringArray:
	return PackedStringArray(["_inherited_platform_velocity*"])


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var jumping = str(properties.get("mode", "jump")) != "reset"
	for child in _get_field_names():
		if str(child) in ["jump_height", "gravity_strength", "inherit_platform_velocity", "ignore_jump_limit"]:
			shown[child] = jumping
	return shown


func generate_code(node:Node, chain_name:String)->Dictionary:
	if str(properties.get("mode", "jump")) == "reset":
		return {"actuator_code": "# Jump 2D — reset jump count without launching\nset_meta('_logic_brick_jumps_remaining', maxi(0, int(%s)))" % _gd_string(str(_numeric_expr(properties.get("max_jumps", "1"))))}
	var h=_numeric_expr(properties.get("jump_height","80.0")); var g=_numeric_expr(properties.get("gravity_strength","980.0")); var m=_numeric_expr(properties.get("max_jumps","1")); var inherit_platform_velocity:bool=properties.get("inherit_platform_velocity",true); var ignore_limit:bool=properties.get("ignore_jump_limit",false); var l:Array[String]=[]; l.append("if not (self is CharacterBody2D):"); l.append("\tpush_warning(\"Character Jump 2D requires CharacterBody2D\")"); l.append("else:"); l.append("\tvar _jumps_remaining = int(get_meta('_logic_brick_jumps_remaining', int(%s)))"%m); l.append("\tif is_on_floor(): _jumps_remaining = int(%s)"%m);
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
