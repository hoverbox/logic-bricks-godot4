@tool
extends RefCounted

## Base class for all Logic Bricks (Sensors, Controllers, Actuators)

enum BrickType {
	SENSOR,
	CONTROLLER,
	ACTUATOR
}

## The type of this brick
var brick_type: BrickType

## The display name of this brick (type name like "Keyboard Sensor")
var brick_name: String = "Logic Brick"

## The instance name of this brick (user-customizable, used in code generation)
var instance_name: String = ""

## Debug mode flag
var debug_enabled: bool = false

## Debug message to print
var debug_message: String = ""

## Properties specific to this brick type
var properties: Dictionary = {}


## Initialize the brick with default properties
func _init() -> void:
	_initialize_properties()


## Override this to set default properties for the brick
func _initialize_properties() -> void:
	pass


## Get the brick type (SENSOR, CONTROLLER, or ACTUATOR)
func get_brick_type() -> BrickType:
	return brick_type


## Get the display name for this brick
func get_brick_name() -> String:
	return brick_name


## Set the instance name (user-editable)
func set_instance_name(name: String) -> void:
	instance_name = name


## Get the instance name (used in code generation)
func get_instance_name() -> String:
	return instance_name


## Get all properties as a dictionary
func get_properties() -> Dictionary:
	return properties.duplicate()


## Set a property value
func set_property(property_name: String, value: Variant) -> void:
	properties[property_name] = value


## Get a property value
func get_property(property_name: String, default_value: Variant = null) -> Variant:
	return properties.get(property_name, default_value)


## Serialize this brick to a dictionary for storage
func serialize() -> Dictionary:
	# Prefer the explicit registry class from get_brick_info() when a brick
	# provides one. This prevents UI wrapper bricks such as UISliderActuator
	# from being saved as their plain filename-derived class SliderActuator.
	var class_name_str = ""
	if has_method("get_brick_info"):
		var info = call("get_brick_info")
		if typeof(info) == TYPE_DICTIONARY:
			class_name_str = str(info.get("class", ""))

	if class_name_str.is_empty():
		# Get the script filename as the type identifier
		var script_path = get_script().resource_path
		var type_name = script_path.get_file().get_basename()

		# Convert snake_case to PascalCase for consistency
		# keyboard_sensor -> KeyboardSensor
		# and_controller -> ANDController (special case)
		var parts = type_name.split("_")
		for part in parts:
			# Special handling for acronyms
			if part == "2d":
				class_name_str += "2D"
			elif part == "3d":
				class_name_str += "3D"
			else:
				class_name_str += part.capitalize()

	return {
		"type": class_name_str,
		"instance_name": instance_name,
		"debug_enabled": debug_enabled,
		"debug_message": debug_message,
		"properties": properties.duplicate()
	}


## Deserialize from a dictionary
func deserialize(data: Dictionary) -> void:
	if data.has("instance_name"):
		instance_name = data["instance_name"]
	if data.has("debug_enabled"):
		debug_enabled = data["debug_enabled"]
	if data.has("debug_message"):
		debug_message = data["debug_message"]
	if data.has("properties"):
		# Merge saved properties over the initialized defaults rather than replacing
		# the whole dict. This prevents stale saved data (e.g. a scene file that was
		# written before a new property was added) from silently discarding keys that
		# _initialize_properties() just set — most critically, it stops an old saved
		# mode = "restart" from overwriting a freshly-set mode = "set_scene".
		var renamed := renamed_properties()
		for key in data["properties"]:
			var target_key: String = renamed.get(key, key)
			if target_key != key and data["properties"].has(target_key):
				continue  # the current name wins over an old one
			properties[target_key] = data["properties"][key]


## Old property name -> current name, for properties renamed so the editor
## label matches the name used in code. Saved data under an old name loads
## into the new one (scene metadata is also migrated, see logic_brick_migrations.gd).
func renamed_properties() -> Dictionary:
	return {}


## What a number field stores for typed text: a number for a plain number
## (an int for int fields), otherwise the text itself (a variable or math).
static func numeric_value_from_text(text: String, property_type: int) -> Variant:
	var t := text.strip_edges()
	if t.is_valid_int() or t.is_valid_float():
		return int(float(t)) if property_type == TYPE_INT else float(t)
	return t


## True when a number field holds a variable or math instead of a number.
func _is_number_expression(key: String) -> bool:
	var value = properties.get(key, 0)
	if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return false
	var text := str(value).strip_edges()
	return not (text.is_empty() or text.is_valid_float() or text.is_valid_int())


## The field's number, or null when it holds a variable or math. For choices
## made while generating code (for example "skip the cone when Angle is 360").
func _literal_number(key: String, fallback: float = 0.0) -> Variant:
	if _is_number_expression(key):
		return null
	var text := str(properties.get(key, fallback)).strip_edges()
	return fallback if text.is_empty() else float(text)


## The field's number as generated code: a formatted number, or the typed
## variable/math (already in parentheses when needed, see wrap_numeric_expressions()).
func _num(key: String, fallback: float = 0.0, decimals: int = 3) -> String:
	if _is_number_expression(key):
		return "float(%s)" % str(properties[key]).strip_edges()
	var number = _literal_number(key, fallback)
	return ("%." + str(decimals) + "f") % float(number)


## Like _num() for whole numbers: a literal int, or int(expression).
func _int_num(key: String, fallback: int = 0) -> String:
	if _is_number_expression(key):
		return "int(%s)" % str(properties[key]).strip_edges()
	return str(int(_literal_number(key, float(fallback))))


## Wrap math typed into numeric fields in parentheses before code generation,
## so "speed + 1" stays one value wherever a brick places it
## (Vector2.ONE * (speed + 1), not Vector2.ONE * speed + 1). Only fields whose
## default is a number are touched; plain numbers, single names, text that is
## already wrapped, and comma lists (such as collision layers) are left as is.
func wrap_numeric_expressions() -> void:
	var defaults: Dictionary = get_script().new().get_properties()
	for key in properties:
		var value = properties[key]
		if typeof(value) != TYPE_STRING or not defaults.has(key):
			continue
		var default_value = defaults[key]
		var default_is_number: bool = typeof(default_value) in [TYPE_INT, TYPE_FLOAT] \
			or (typeof(default_value) == TYPE_STRING and (str(default_value).is_valid_float() or str(default_value).is_valid_int()))
		if not default_is_number:
			continue
		var text := str(value).strip_edges()
		if _expression_needs_parentheses(text):
			properties[key] = "(%s)" % text


static func _expression_needs_parentheses(text: String) -> bool:
	if text.is_empty() or text.is_valid_float() or text.is_valid_int() or text.is_valid_identifier():
		return false
	if text.begins_with("\"") or text.begins_with("'"):
		return false
	# Already one bracketed group, a call like max(a, b), or a.b member access
	var depth := 0
	var top_level_operator := false
	for i in text.length():
		var c := text[i]
		if c in "([{":
			depth += 1
		elif c in ")]}":
			depth -= 1
		elif depth == 0:
			if c == ",":
				return false  # a list (e.g. "1, 2, Player"), not one value
			if c in "+-*/%<>=!&|^~ ":
				top_level_operator = true
	return top_level_operator


## Generate the GDScript code for this brick in a chain
## Returns a dictionary with 'sensor_code', 'controller_code', or 'actuator_code'
func generate_code(node: Node, chain_name: String) -> Dictionary:
	return {}


## What the manager calls: generate_code() followed by settling every
## `self is Type` check in the result at generation time.
##
## The node is known while code is generated, so a check like
## `if self is CharacterBody2D:` does not need to run every frame. It is also
## unsafe to leave in: GDScript decides `self is Type` when it parses the
## script, and a script whose node can never be that type fails to load
## entirely ("can't be of type"). Resolving here keeps the branch that will
## actually run and drops the others (usually leaving just the brick's
## push_warning when the node is the wrong type).
##
## Bricks keep writing their checks the simple way; only `self is <EngineClass>`
## forms are resolved (see _resolve_self_type_checks()). Checks on other
## variables, compound conditions and checks against class_name scripts are
## left as they are.
func generate_code_for_node(node: Node, chain_name: String) -> Dictionary:
	var generated = generate_code(node, chain_name)
	if node == null or typeof(generated) != TYPE_DICTIONARY:
		return generated
	var self_class := _self_native_class(node)
	for key in ["sensor_code", "controller_code", "actuator_code"]:
		if generated.has(key) and typeof(generated[key]) == TYPE_STRING and _has_self_type_check(generated[key]):
			var resolved := _resolve_self_type_checks(generated[key], self_class)
			generated[key] = resolved if _has_statement(Array(resolved.split("\n"))) else resolved + ("\n" if not resolved.is_empty() else "") + "pass"
	for key in ["member_vars", "ready_code", "pre_process_code", "post_process_code"]:
		if not generated.has(key) or typeof(generated[key]) != TYPE_ARRAY:
			continue
		var text := "\n".join(PackedStringArray(generated[key].map(func(item): return str(item))))
		if not _has_self_type_check(text):
			continue
		# These lists hold one line per item; keep that shape.
		var lines: Array[String] = []
		for line in _resolve_self_type_checks(text, self_class).split("\n"):
			lines.append(line)
		generated[key] = lines
	return generated


## The engine class the generated script will extend: the node's existing
## script base when it has a script (the manager keeps that extends line),
## otherwise the node's own class (what the manager writes for a new script).
static func _self_native_class(node: Node) -> StringName:
	var script = node.get_script()
	if script is Script:
		var base: StringName = script.get_instance_base_type()
		if base != &"":
			return base
	return StringName(node.get_class())


static func _has_self_type_check(code: String) -> bool:
	return code.contains("self is ")


## Rewrites if/elif/else chains whose conditions are exactly
## `self is T` or `not (self is T)` (T an engine class), at any depth.
## A branch known to be false is removed; a branch known to be true becomes
## the last branch (or, if it comes first, its body replaces the chain).
## Lines that are not part of such a chain are returned unchanged.
static func _resolve_self_type_checks(code: String, self_class: StringName) -> String:
	var lines: Array[String] = []
	for line in code.split("\n"):
		lines.append(line)
	return "\n".join(PackedStringArray(_resolve_self_type_block(lines, self_class)))


static func _resolve_self_type_block(lines: Array[String], self_class: StringName) -> Array[String]:
	var out: Array[String] = []
	var i := 0
	while i < lines.size():
		var line := lines[i]
		var indent := _tab_depth(line)
		var content := line.substr(indent)
		if not content.begins_with("if "):
			out.append(line)
			i += 1
			continue

		# Collect the chain: if / elif ... / else at this indent.
		var branches: Array = []  # [{keyword, condition, body: Array[String]}]
		var j := i
		while j < lines.size():
			var branch_content := lines[j].substr(indent) if _tab_depth(lines[j]) == indent else ""
			var keyword := ""
			for kw in ["if ", "elif ", "else:"]:
				if branch_content.begins_with(kw):
					keyword = kw.strip_edges().trim_suffix(":")
					break
			if keyword.is_empty() or (keyword == "if" and j != i):
				break
			var header := _split_branch_header(branch_content, keyword)
			if header.is_empty():
				break
			var body: Array[String] = []
			if not header["inline"].is_empty():
				body.append("\t".repeat(indent + 1) + header["inline"])
			j += 1
			while j < lines.size() and (lines[j].strip_edges().is_empty() or _tab_depth(lines[j]) > indent):
				body.append(lines[j])
				j += 1
			var trailing_blanks := 0
			while not body.is_empty() and body.back().strip_edges().is_empty():
				body.pop_back()
				trailing_blanks += 1
			j -= trailing_blanks  # blank lines after the chain belong outside it
			branches.append({"keyword": keyword, "condition": header["condition"], "body": body})
			if keyword == "else":
				break

		var known_any := false
		var kept: Array = []
		for branch in branches:
			var verdict := 0 if branch["keyword"] == "else" else _self_type_verdict(branch["condition"], self_class)
			if verdict == -1:
				known_any = true
				continue
			if verdict == 1:
				known_any = true
				kept.append({"keyword": "else", "condition": "", "body": branch["body"]})
				break
			kept.append(branch)

		if not known_any:
			var chain_lines: Array[String] = lines.slice(i, j)
			if not _has_self_type_check("\n".join(PackedStringArray(chain_lines))):
				out.append_array(chain_lines)  # untouched, byte for byte
			else:
				# A check is nested deeper: keep this chain, resolve inside it.
				for branch in branches:
					out.append(_rebuild_header(branch, indent))
					var body: Array[String] = _resolve_self_type_block(branch["body"], self_class)
					if not _has_statement(body):
						body.append("\t".repeat(indent + 1) + "pass")
					out.append_array(body)
			i = j
			continue

		if kept.is_empty():
			pass  # Every branch was impossible: the chain disappears.
		elif kept[0]["keyword"] == "else":
			out.append_array(_resolve_self_type_block(_dedent(kept[0]["body"]), self_class))
		else:
			for b in kept.size():
				var branch: Dictionary = kept[b]
				var keyword: String = "if" if b == 0 else branch["keyword"]
				if keyword == "else":
					out.append("\t".repeat(indent) + "else:")
				else:
					out.append("\t".repeat(indent) + "%s %s:" % [keyword, branch["condition"]])
				var body: Array[String] = _resolve_self_type_block(branch["body"], self_class)
				if not _has_statement(body):
					body.append("\t".repeat(indent + 1) + "pass")
				out.append_array(body)
		i = j
	return out


## Splits "if cond: stmt" / "elif cond:" / "else: stmt" into its condition and
## an optional statement written on the same line. Returns {} if the colon
## that ends the condition can't be found safely.
static func _split_branch_header(content: String, keyword: String) -> Dictionary:
	if keyword == "else":
		return {"condition": "", "inline": content.substr(5).strip_edges()}
	var rest := content.substr(keyword.length() + 1)
	var depth := 0
	var quote := ""
	for k in rest.length():
		var ch := rest[k]
		if not quote.is_empty():
			if ch == "\\":
				continue
			if ch == quote:
				quote = ""
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch in "([{":
			depth += 1
		elif ch in ")]}":
			depth -= 1
		elif ch == ":" and depth == 0:
			return {"condition": rest.substr(0, k).strip_edges(), "inline": rest.substr(k + 1).strip_edges()}
	return {}


## 1 = always true for this node, -1 = never true, 0 = not a self type check.
static func _self_type_verdict(condition: String, self_class: StringName) -> int:
	var negated := false
	var type_name := ""
	var rx := RegEx.new()
	rx.compile("^(not\\s*\\(\\s*)?self\\s+is\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(\\))?$")
	var m := rx.search(condition.strip_edges())
	if m == null:
		return 0
	negated = not m.get_string(1).is_empty()
	if negated != not m.get_string(3).is_empty():
		return 0  # unbalanced parentheses: leave it alone
	type_name = m.get_string(2)
	if not ClassDB.class_exists(type_name):
		return 0  # a class_name script or unknown type: decide at runtime
	var is_type := ClassDB.is_parent_class(self_class, type_name)
	return 1 if is_type != negated else -1


## True when the lines contain code, not just blank lines and comments
## (a block holding only comments is a parse error).
static func _has_statement(lines: Array) -> bool:
	for line in lines:
		var text := str(line).strip_edges()
		if not text.is_empty() and not text.begins_with("#"):
			return true
	return false


static func _tab_depth(line: String) -> int:
	var n := 0
	while n < line.length() and line[n] == "\t":
		n += 1
	return n


static func _dedent(body: Array) -> Array[String]:
	var result: Array[String] = []
	for line in body:
		var text := str(line)
		result.append(text.substr(1) if text.begins_with("\t") else text)
	return result


static func _rebuild_header(branch: Dictionary, indent: int) -> String:
	if branch["keyword"] == "else":
		return "\t".repeat(indent) + "else:"
	return "\t".repeat(indent) + "%s %s:" % [branch["keyword"], branch["condition"]]


## Get property definitions for UI generation
## Returns array of dictionaries with 'name', 'type', 'default', 'hint', etc.
func get_property_definitions() -> Array:
	return []


## Editor-time validation shown only after the user presses Apply Code.
## Bricks opt in by adding required=true to a property definition.
func get_configuration_warnings(_node: Node = null) -> Array[String]:
	var warnings: Array[String] = []
	for prop_def in get_property_definitions():
		if not prop_def.get("required", false):
			continue
		if prop_def.has("required_if") and not _validation_conditions_match(prop_def["required_if"]):
			continue
		if prop_def.has("required_unless") and _validation_conditions_match(prop_def["required_unless"]):
			continue
		var prop_name = str(prop_def.get("name", ""))
		var value = get_property(prop_name, prop_def.get("default", null))
		if _validation_value_is_empty(value):
			var label = str(prop_def.get("required_label", prop_name.replace("_", " ").capitalize()))
			warnings.append("Select or enter %s." % label)
	return warnings


func _validation_conditions_match(conditions: Dictionary) -> bool:
	for property_name in conditions:
		var actual = get_property(str(property_name), null)
		var expected = conditions[property_name]
		if expected is Array:
			var matched := false
			for option in expected:
				if _validation_values_match(actual, option):
					matched = true
					break
			if not matched:
				return false
		elif not _validation_values_match(actual, expected):
			return false
	return true


func _validation_values_match(actual, expected) -> bool:
	if typeof(actual) == TYPE_STRING or typeof(expected) == TYPE_STRING:
		var a = str(actual).strip_edges().to_lower().replace(" ", "_")
		var e = str(expected).strip_edges().to_lower().replace(" ", "_")
		return a == e
	return actual == expected


func _validation_value_is_empty(value) -> bool:
	if value == null:
		return true
	if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH]:
		return str(value).strip_edges().is_empty()
	if value is Array:
		return value.is_empty()
	return false


## Treat blank or literal numeric zero as zero, while variables/expressions count as values.
func _validation_value_is_numeric_zero(value) -> bool:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value) == 0.0
	var text := str(value).strip_edges()
	if text.is_empty():
		return true
	if text.is_valid_float() or text.is_valid_int():
		return float(text) == 0.0
	return false


func _validation_all_numeric_zero(property_names: Array[String]) -> bool:
	for property_name in property_names:
		if not _validation_value_is_numeric_zero(properties.get(property_name, "0.0")):
			return false
	return true


## Project settings this brick needs, applied by Apply Code:
## {"physics/common/physics_interpolation": true}. Use this instead of
## changing engine settings from generated code at runtime: turning physics
## interpolation on while the game runs leaves already-loaded scenery drawn
## at the world origin.
func get_required_project_settings() -> Dictionary:
	return {}


## Which fields the editor shows for the brick's current settings:
## {property_name: visible}. Combines the brick's own
## get_field_visibility_rules() with "visible_if" entries in its property
## definitions ({"visible_if": {"scope": "group"}} shows a field only while
## scope is Group; a list of values matches any of them).
func get_field_visibility(context_node: Node) -> Dictionary:
	var shown: Dictionary = get_field_visibility_rules(context_node)
	for definition in get_property_definitions():
		if definition is Dictionary and definition.get("visible_if") is Dictionary:
			shown[str(definition.get("name", ""))] = _settings_match(definition["visible_if"])
	return shown


## Override to show or hide fields depending on other settings or on the node
## the brick is on (context_node). Return {property_name: visible}; fields not
## listed stay visible.
func get_field_visibility_rules(_context_node: Node) -> Dictionary:
	return {}


## Names of all fields, including group headers and fields inside groups.
func _get_field_names() -> Array:
	var names: Array = []
	var pending: Array = get_property_definitions().duplicate()
	while not pending.is_empty():
		var definition = pending.pop_front()
		if not (definition is Dictionary):
			continue
		var field_name := str(definition.get("name", ""))
		if not field_name.is_empty() and not names.has(field_name):
			names.append(field_name)
		for key in ["properties", "children", "items"]:
			if definition.get(key) is Array:
				pending.append_array(definition[key])
	for key in properties:
		if not names.has(str(key)):
			names.append(str(key))
	return names


## True when every {property: value or [values]} in condition matches the
## brick's settings (case and spaces ignored, "Target Node" == "target_node").
func _settings_match(condition: Dictionary) -> bool:
	for property_name in condition:
		var actual := str(get_property(str(property_name), "")).to_lower().replace(" ", "_")
		var expected = condition[property_name]
		var options: Array = expected if expected is Array else [expected]
		var matched := false
		for option in options:
			if actual == str(option).to_lower().replace(" ", "_"):
				matched = true
				break
		if not matched:
			return false
	return true


## Member variables this brick declares that must keep their value when the
## node changes state. Variables declared by bricks in state-specific chains
## are normally reset to their default on state entry; return glob patterns
## (String.match) for the ones that hold long-lived runtime state, e.g.
## ["_pools_*"] for pools built once in _ready(). A variable is kept if any
## brick on the node lists it.
func get_kept_member_vars() -> PackedStringArray:
	return PackedStringArray()


## Get tooltip definitions for UI hover hints.
## Returns a dictionary mapping property names to tooltip strings.
## Include "_description" key for the overall brick description.
## Example: {"_description": "Plays animations", "speed": "Playback speed multiplier"}
func get_tooltip_definitions() -> Dictionary:
	return {}


## Shared code-generation helpers used by many bricks. Keeping these in the base
## class avoids dozens of brick-local copies drifting out of sync.
func _append_find_node_helpers(member_vars: Array[String]) -> void:
	_append_standard_find_node_helpers(member_vars)


# Non-virtual implementation used by shared helpers that must not dispatch back
# into a brick override of _append_find_node_helpers().
func _append_standard_find_node_helpers(member_vars: Array[String]) -> void:
	member_vars.append("")
	member_vars.append("func _lb_find_node_by_name_recursive(node: Node, target_name: String) -> Node:")
	member_vars.append("\tif node == null or target_name.is_empty():")
	member_vars.append("\t\treturn null")
	member_vars.append("\tif node.name == target_name:")
	member_vars.append("\t\treturn node")
	member_vars.append("\tfor child in node.get_children():")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(child, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn null")
	member_vars.append("")
	member_vars.append("func _lb_find_node_in_current_scene(target_name: String) -> Node:")
	member_vars.append("\tvar scene_root = get_tree().current_scene")
	member_vars.append("\tif scene_root:")
	member_vars.append("\t\tvar found = _lb_find_node_by_name_recursive(scene_root, target_name)")
	member_vars.append("\t\tif found:")
	member_vars.append("\t\t\treturn found")
	member_vars.append("\treturn _lb_find_node_by_name_recursive(get_tree().root, target_name)")



## Normalize a user-facing name into a safe generated GDScript identifier.
func _sanitize_identifier(value: String) -> String:
	var sanitized := value.strip_edges().replace(" ", "_")
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	sanitized = regex.sub(sanitized, "", true)
	if sanitized.is_empty():
		return ""
	if sanitized.substr(0, 1).is_valid_int():
		sanitized = "var_" + sanitized
	return sanitized


## Check whether an editor/runtime node exposes a Logic Bricks variable by name.
func _node_has_logic_variable(node: Node, variable_name: String) -> bool:
	if node == null or variable_name.is_empty() or not node.has_meta("logic_bricks_variables"):
		return false
	var variables_data = node.get_meta("logic_bricks_variables")
	if not (variables_data is Array):
		return false
	for var_data in variables_data:
		if var_data is Dictionary and str(var_data.get("name", "")).strip_edges() == variable_name:
			return true
	return false


## Shared collision-area lookup helper used by the 2D and 3D collision sensors.
## area_type must be "Area2D" or "Area3D"; keeping the emitted helper identical
## preserves generated-code behavior while removing duplicate brick implementations.
func _append_collision_area_helpers(member_vars: Array[String], area_type: String) -> void:
	_append_standard_find_node_helpers(member_vars)
	member_vars.append("")
	member_vars.append("func _lb_find_collision_area_for_sensor(owner_node: Node, target_name: String) -> %s:" % area_type)
	member_vars.append("\tif target_name.is_empty():")
	member_vars.append("\t\treturn owner_node as %s" % area_type)
	member_vars.append("\tif owner_node is %s and owner_node.name == target_name:" % area_type)
	member_vars.append("\t\treturn owner_node as %s" % area_type)
	member_vars.append("\tvar found = _lb_find_node_by_name_recursive(owner_node, target_name)")
	member_vars.append("\tif found is %s:" % area_type)
	member_vars.append("\t\treturn found as %s" % area_type)
	member_vars.append("\tvar owner_root = owner_node.get_owner() if is_instance_valid(owner_node) else null")
	member_vars.append("\tif owner_root and owner_root != owner_node:")
	member_vars.append("\t\tfound = _lb_find_node_by_name_recursive(owner_root, target_name)")
	member_vars.append("\t\tif found is %s:" % area_type)
	member_vars.append("\t\t\treturn found as %s" % area_type)
	member_vars.append("\tvar scene_root = get_tree().current_scene")
	member_vars.append("\tif scene_root and scene_root != owner_root and scene_root != owner_node:")
	member_vars.append("\t\tfound = _lb_find_node_by_name_recursive(scene_root, target_name)")
	member_vars.append("\t\tif found is %s:" % area_type)
	member_vars.append("\t\t\treturn found as %s" % area_type)
	member_vars.append("\tfound = _lb_find_node_by_name_recursive(get_tree().root, target_name)")
	member_vars.append("\treturn found as %s" % area_type)


## Append the standard generated-code lookup for a named target node.
## Used by UI actuators that accept Self or a node name.
func _append_target_lookup(code_lines: Array[String], label: String, target_node_name: String, var_name: String) -> void:
	code_lines.append("var _target_name_%s = \"%s\"" % [label, _gd_string(target_node_name)])
	code_lines.append("if _target_name_%s.strip_edges().to_lower() == \"self\":" % label)
	code_lines.append("\t%s = self" % var_name)
	code_lines.append("else:")
	code_lines.append("\tvar _scene_%s = get_tree().current_scene" % label)
	code_lines.append("\tif _scene_%s:" % label)
	code_lines.append("\t\t%s = _scene_%s.find_child(_target_name_%s, true, false)" % [var_name, label, label])
	code_lines.append("\tif %s == null:" % var_name)
	code_lines.append("\t\t%s = get_tree().root.find_child(_target_name_%s, true, false)" % [var_name, label])


## Append the common generated assignment used by 2D, 3D, and UI text actuators.
func _append_set_text_code(code_lines: Array, text_node_var: String, value_expr: String) -> void:
	code_lines.append("\tif %s is Label or %s is Label3D:" % [text_node_var, text_node_var])
	code_lines.append("\t\t%s.text = %s" % [text_node_var, value_expr])
	code_lines.append("\telif %s is RichTextLabel:" % text_node_var)
	code_lines.append("\t\t%s.text = %s" % [text_node_var, value_expr])
	code_lines.append("\telse:")
	code_lines.append("\t\tpush_warning(\"Text Actuator: found node is not a text node\")")


## Convert a user-entered numeric value or expression to generated GDScript.
## Blank values use the supplied fallback; non-blank values are emitted unchanged.
func _expr(value, fallback: String = "0.0") -> String:
	var text := str(value).strip_edges()
	return fallback if text.is_empty() else text


## Convert a numeric literal or expression to generated GDScript, formatting literal
## numbers consistently while leaving variable names and expressions untouched.
func _numeric_expr(value, fallback: String = "0.0", decimals: int = 3) -> String:
	var text := str(value).strip_edges()
	if text.is_empty():
		return fallback
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT or text.is_valid_float() or text.is_valid_int():
		return ("%." + str(decimals) + "f") % float(value if typeof(value) in [TYPE_FLOAT, TYPE_INT] else text)
	return text


## "Check Interval" for triggers whose check costs something (Proximity,
## Mouse hover). Wraps the trigger's code so the check runs at most once per
## interval and the last result is reported in between. interval <= 0 returns
## the code unchanged (check every frame). The counter is a member variable,
## so it resets, and the trigger checks right away, when a state is entered.
## Returns {"code": Array[String], "member_vars": Array[String]}.
## interval may also be generated code (a variable or math) as a String;
## then the check always runs through the counter and a value <= 0 checks every frame.
func _wrap_sensor_interval(code_lines: Array[String], interval, id_suffix: String) -> Dictionary:
	if typeof(interval) != TYPE_STRING and float(interval) <= 0.0:
		return {"code": code_lines, "member_vars": [] as Array[String]}
	var wait_var := "_lb_check_wait_%s" % id_suffix
	var last_var := "_lb_check_last_%s" % id_suffix
	var wrapped: Array[String] = []
	wrapped.append("var sensor_active = %s" % last_var)
	wrapped.append("%s -= _delta" % wait_var)
	wrapped.append("if %s <= 0.0:" % wait_var)
	wrapped.append("\t%s = %s" % [wait_var, interval if typeof(interval) == TYPE_STRING else _numeric_expr(interval, "0.0", 3)])
	var declared := RegEx.new()
	declared.compile("^(\\s*)var\\s+sensor_active\\s*=")
	for line in code_lines:
		if line.strip_edges().is_empty():
			continue
		wrapped.append("\t" + declared.sub(line, "$1sensor_active ="))
	wrapped.append("\t%s = sensor_active" % last_var)
	var members: Array[String] = ["var %s: float = 0.0" % wait_var, "var %s: bool = false" % last_var]
	return {"code": wrapped, "member_vars": members}


## True only when the supplied value is definitely a literal numeric zero.
## Variables/expressions are treated as potentially non-zero at generation time.
func _is_literal_zero(value) -> bool:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value) == 0.0
	var text := str(value).strip_edges()
	if text.is_empty():
		return true
	if text.is_valid_float() or text.is_valid_int():
		return float(text) == 0.0
	return false


## True for literal values greater than zero. Variables/expressions return true so
## generated code preserves them instead of incorrectly optimizing them away.
func _literal_gt_zero(value) -> bool:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value) > 0.0
	var text := str(value).strip_edges()
	if text.is_valid_float() or text.is_valid_int():
		return float(text) > 0.0
	return true


## Stable per-instance label for runtime helper variables/functions that only need
## to be unique within the generated script.
func _runtime_unique_label(chain_name: String) -> String:
	var base := ""
	for i in range(chain_name.length()):
		var ch := chain_name.substr(i, 1)
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_":
			base += ch
		else:
			base += "_"
	while base.begins_with("_"):
		base = base.substr(1)
	while base.ends_with("_") and not base.is_empty():
		base = base.substr(0, base.length() - 1)
	if base.is_empty():
		base = "chain"
	return "lb_%s_%d" % [base, abs(get_instance_id())]

func _unique_label(chain_name: String) -> String:
	var label = instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	label = label.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	return label if not label.is_empty() else chain_name


## Escape text for use inside a generated GDScript string literal ("...").
## c_escape() handles backslashes, both quote kinds, newlines, tabs and the
## other control characters, so typed text can never end the literal early.
func _gd_string(value) -> String:
	return str(value).c_escape()

func _tween_trans_constant(trans: String) -> String:
	match trans:
		"sine": return "Tween.TRANS_SINE"
		"quint": return "Tween.TRANS_QUINT"
		"quart": return "Tween.TRANS_QUART"
		"quad": return "Tween.TRANS_QUAD"
		"expo": return "Tween.TRANS_EXPO"
		"elastic": return "Tween.TRANS_ELASTIC"
		"bounce": return "Tween.TRANS_BOUNCE"
		"back": return "Tween.TRANS_BACK"
		"spring": return "Tween.TRANS_SPRING"
		"circular": return "Tween.TRANS_CIRC"
		"cubic": return "Tween.TRANS_CUBIC"
		_: return "Tween.TRANS_LINEAR"

func _tween_ease_constant(ease: String) -> String:
	match ease:
		"in": return "Tween.EASE_IN"
		"out": return "Tween.EASE_OUT"
		"out_in": return "Tween.EASE_OUT_IN"
		_: return "Tween.EASE_IN_OUT"


## Generate debug print code if debug is enabled
func get_debug_code() -> String:
	if debug_enabled and not debug_message.is_empty():
		return "print(\"%s\")" % _gd_string(str(debug_message))
	return ""
