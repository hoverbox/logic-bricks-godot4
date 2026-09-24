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
		for key in data["properties"]:
			properties[key] = data["properties"][key]


## Generate the GDScript code for this brick in a chain
## Returns a dictionary with 'sensor_code', 'controller_code', or 'actuator_code'
func generate_code(node: Node, chain_name: String) -> Dictionary:
	return {}


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


func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")

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
		return "print(\"%s\")" % debug_message
	return ""
