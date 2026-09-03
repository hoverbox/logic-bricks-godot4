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


func _unique_label(chain_name: String) -> String:
	var label = instance_name if not instance_name.is_empty() else "%s_%s_%s" % [brick_name, chain_name, str(abs(str(properties).hash()))]
	label = label.to_lower().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-z0-9_]")
	label = regex.sub(label, "", true)
	return label if not label.is_empty() else chain_name


func _gd_string(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")


## Generate debug print code if debug is enabled
func get_debug_code() -> String:
	if debug_enabled and not debug_message.is_empty():
		return "print(\"%s\")" % debug_message
	return ""
