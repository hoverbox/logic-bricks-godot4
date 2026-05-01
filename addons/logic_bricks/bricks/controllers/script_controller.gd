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
		"state_id": ""
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
			"name": "state_id",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "__STATE_LIST__",
			"default": ""
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


## Returns the member variable name used to cache the script instance for this chain.
func _get_cache_var_name(chain_name: String) -> String:
	return "_sc_obj_%s" % chain_name


## Returns indented code (two tabs = inside `if controller_active:`) that calls
## run(self) on the pre-cached script instance. The instance is loaded once in
## _ready() via the member_vars / ready_code returned by generate_code(), so
## there is no load() or new() call at all during _process().
func get_script_body(chain_name: String) -> String:
	var path: String = properties.get("script_path", "").strip_edges()
	if path.is_empty():
		return "\t\tpass  # Script Controller: no script file set"

	var cache_var = _get_cache_var_name(chain_name)
	var lines: Array[String] = []
	lines.append("\t\tif %s:" % cache_var)
	lines.append("\t\t\t%s.run(self)" % cache_var)
	return "\n".join(lines)


## Emits the member variable declaration and _ready() initialisation so the
## script is loaded and instantiated exactly once, not on every process frame.
func generate_code(node: Node, chain_name: String) -> Dictionary:
	var path: String = properties.get("script_path", "").strip_edges()
	if path.is_empty():
		return {}

	var cache_var = _get_cache_var_name(chain_name)

	var member_vars: Array[String] = [
		"var %s = null  # Script Controller cache for chain '%s'" % [cache_var, chain_name]
	]

	var ready_code: Array[String] = [
		"# Script Controller (%s): load and cache instance" % chain_name,
		"var _sc_res_%s = load(\"%s\")" % [chain_name, path],
		"if _sc_res_%s and _sc_res_%s is GDScript:" % [chain_name, chain_name],
		"\t%s = _sc_res_%s.new()" % [cache_var, chain_name],
		"\tif not %s.has_method(\"run\"):" % cache_var,
		"\t\tpush_warning(\"Script Controller: '%s' has no run(node) function\")" % path,
		"\t\t%s = null" % cache_var,
		"else:",
		"\tpush_warning(\"Script Controller: could not load '%s'\")" % path,
	]

	return {
		"member_vars": member_vars,
		"ready_code": ready_code,
	}
