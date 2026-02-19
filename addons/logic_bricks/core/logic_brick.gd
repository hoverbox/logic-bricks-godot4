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
	if instance_name.is_empty():
		return ""
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
	# Get the script filename as the type identifier
	var script_path = get_script().resource_path
	var type_name = script_path.get_file().get_basename()
	
	# Convert snake_case to PascalCase for consistency
	# keyboard_sensor -> KeyboardSensor
	# and_controller -> ANDController (special case)
	var parts = type_name.split("_")
	var class_name_str = ""
	for part in parts:
		# Special handling for acronyms
		if part == "and":
			class_name_str += "AND"
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
		properties = data["properties"].duplicate()


## Generate the GDScript code for this brick in a chain
## Returns a dictionary with 'sensor_code', 'controller_code', or 'actuator_code'
func generate_code(node: Node, chain_name: String) -> Dictionary:
	return {}


## Get property definitions for UI generation
## Returns array of dictionaries with 'name', 'type', 'default', 'hint', etc.
func get_property_definitions() -> Array:
	return []


## Get tooltip definitions for UI hover hints.
## Returns a dictionary mapping property names to tooltip strings.
## Include "_description" key for the overall brick description.
## Example: {"_description": "Plays animations", "speed": "Playback speed multiplier"}
func get_tooltip_definitions() -> Dictionary:
	return {}


## Generate debug print code if debug is enabled
func get_debug_code() -> String:
	if debug_enabled and not debug_message.is_empty():
		return "print(\"%s\")" % debug_message
	return ""
