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
			"name": "script_path", "required": true, "required_label": "a script file",
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
## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var all_states = properties.get("all_states", false)
	for child in _get_field_names():
		if true:
			var prop_name = child
			if prop_name == "state_id":
				shown[child] = not all_states
	return shown


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
		"var _sc_res_%s = load(\"%s\")" % [chain_name, _gd_string(str(path))],
		"if _sc_res_%s and _sc_res_%s is GDScript:" % [chain_name, chain_name],
		"\t%s = _sc_res_%s.new()" % [cache_var, chain_name],
		"\tif not %s.has_method(\"run\"):" % cache_var,
		"\t\tpush_warning(\"Script Controller: '%s' has no run(node) function\")" % _gd_string(str(path)),
		"\t\t%s = null" % cache_var,
		"else:",
		"\tpush_warning(\"Script Controller: could not load '%s'\")" % _gd_string(str(path)),
	]

	return {
		"member_vars": member_vars,
		"ready_code": ready_code,
	}

func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Calls a function in a custom .gd script when triggers fire.\nRuns a custom GDScript module function:\nno separate Action is needed — the script performs the action.",
		"logic_mode": "Logic gate type:\n• AND: All connected Triggers must be active\n• OR: At least one Trigger must be active\n• NAND: NOT AND — active when not all Triggers are active\n• NOR: NOT OR — active only when no Triggers are active\n• XOR: Exclusive OR — active when exactly one Trigger is active",
		"script_path": "Path to the .gd script file to run.\nThe script must define: func run(node: Node) -> void:\n\'node\' is the scene object this brick is attached to.\nDo NOT add \'extends\' to the script — it is called as a module.",
	}
