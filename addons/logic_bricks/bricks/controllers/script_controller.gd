@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Script Controller - Calls a function in a custom .gd script when sensors fire.
##
## Works like UPBGE's Python Controller (module mode):
##   - Point to a .gd file
##   - That file defines a top-level function: func run(node: Node) -> void:
##   - When the sensor fires, run(node) is called — node is the scene object
##
## Example script (my_script.gd):
##   func run(node: Node) -> void:
##       node.health -= 10
##       print("Health: ", node.health)
##
## The script does NOT need extends — it is called as a module, not instantiated.


func _init() -> void:
	super._init()
	brick_type = BrickType.CONTROLLER
	brick_name = "Script Controller"


func _initialize_properties() -> void:
	properties = {
		"logic_mode": "and",
		"script_path": "",
		"all_states": false,
		"state": 1
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "logic_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "AND,OR,NAND,NOR,XOR",
			"default": "and"
		},
		{
			"name": "script_path",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_FILE,
			"hint_string": "*.gd",
			"default": ""
		},
		{
			"name": "all_states",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "state",
			"type": TYPE_INT,
			"default": 1,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "1,30,1"
		}
	]


## Returns the sensor-combination condition string respecting logic_mode.
func get_condition(sensor_vars: Array) -> String:
	if sensor_vars.is_empty():
		return "false"

	var logic_mode: String = properties.get("logic_mode", "and")
	if typeof(logic_mode) == TYPE_STRING:
		logic_mode = logic_mode.to_lower()

	match logic_mode:
		"or":
			return " or ".join(sensor_vars)
		"nand":
			return "not (" + " and ".join(sensor_vars) + ")"
		"nor":
			return "not (" + " or ".join(sensor_vars) + ")"
		"xor":
			var int_vars: Array[String] = []
			for sv in sensor_vars:
				int_vars.append("int(%s)" % sv)
			return "(" + " + ".join(int_vars) + ") == 1"
		_:
			return " and ".join(sensor_vars)


## Returns indented code (two tabs = inside `if controller_active:`) that calls
## the user's script as a module — loading it as a GDScript resource and calling
## run(node) where node is the scene object (self in the generated script context).
func get_script_body() -> String:
	var path: String = properties.get("script_path", "").strip_edges()
	if path.is_empty():
		return "\t\tpass  # Script Controller: no script file set"

	var lines: Array[String] = []
	lines.append("\t\tvar _sc_res = load(\"%s\")" % path)
	lines.append("\t\tif _sc_res and _sc_res is GDScript:")
	lines.append("\t\t\tvar _sc_obj = _sc_res.new()")
	lines.append("\t\t\tif _sc_obj.has_method(\"run\"):")
	lines.append("\t\t\t\t_sc_obj.run(self)")
	lines.append("\t\t\telse:")
	lines.append("\t\t\t\tpush_warning(\"Script Controller: '%s' has no run(node) function\")" % path)
	lines.append("\t\telse:")
	lines.append("\t\t\tpush_warning(\"Script Controller: could not load '%s'\")" % path)
	return "\n".join(lines)


func generate_code(node: Node, chain_name: String) -> Dictionary:
	return {}
