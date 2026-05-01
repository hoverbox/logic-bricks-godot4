@tool
extends RefCounted
class_name LogicBrickVariableUtils

const SUPPORTED_TYPES = ["bool", "int", "float", "String"]
const DEFAULT_LOCAL_NAME = "new_variable"
const DEFAULT_GLOBAL_NAME = "new_global"

static func create_default_local_variable() -> Dictionary:
	return {
		"name": DEFAULT_LOCAL_NAME,
		"type": "int",
		"value": "0",
		"exported": false,
		"use_min": false,
		"min_val": "0",
		"use_max": false,
		"max_val": "100"
	}


static func create_default_global_variable(global_id: String = "") -> Dictionary:
	var var_data := {
		"name": DEFAULT_GLOBAL_NAME,
		"type": "int",
		"value": "0",
		"use_min": false,
		"min_val": "0",
		"use_max": false,
		"max_val": "100"
	}
	if not global_id.is_empty():
		var var_id := str(global_id)
		if not var_id.is_empty():
			var_data["id"] = var_id
	return var_data


static func get_supported_types() -> Array:
	return SUPPORTED_TYPES.duplicate()


static func is_supported_type(type_name: String) -> bool:
	return SUPPORTED_TYPES.has(type_name)


static func normalize_type(type_name: String, fallback: String = "int") -> String:
	if is_supported_type(type_name):
		return type_name
	return fallback


static func get_type_index(type_name: String) -> int:
	var normalized := normalize_type(type_name)
	return SUPPORTED_TYPES.find(normalized)


static func is_numeric_type(type_name: String) -> bool:
	var normalized := normalize_type(type_name)
	return normalized == "int" or normalized == "float"


## Map a Godot Variant type integer (TYPE_*) to the GDScript type name string used
## by this addon (one of "bool", "int", "float", "String").
## Returns an empty string for types that are not in SUPPORTED_TYPES (e.g. Object, Array).
static func gdscript_type_name_from_variant_type(type_int: int) -> String:
	match type_int:
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "String"
		_:
			return ""


static func get_default_value_for_variable_type(var_type: String) -> String:
	match normalize_type(var_type):
		"bool":
			return "false"
		"int":
			return "0"
		"float":
			return "0.0"
		"String":
			return ""
		_:
			return "0"


static func coerce_variable_value_for_type(value, var_type: String) -> String:
	var normalized_type := normalize_type(var_type)
	var text_value := str(value)
	match normalized_type:
		"bool":
			var lowered := text_value.strip_edges().to_lower()
			if lowered == "true" or lowered == "1" or lowered == "yes" or lowered == "on":
				return "true"
			return "false"
		"int":
			if value is int:
				return str(value)
			if value is bool:
				if value:
					return "1"
				return "0"
			if text_value.is_valid_int():
				return text_value
			if text_value.is_valid_float():
				return str(int(text_value.to_float()))
			return "0"
		"float":
			if value is float:
				return str(value)
			if value is int:
				return str(float(value))
			if value is bool:
				if value:
					return "1.0"
				return "0.0"
			if text_value.is_valid_float():
				return text_value
			if text_value.is_valid_int():
				return str(float(text_value.to_int()))
			return "0.0"
		"String":
			return text_value
		_:
			return text_value


static func value_to_line_edit_text(value) -> String:
	return str(value)


static func to_gdscript_value_literal(value, var_type: String) -> String:
	var normalized_type := normalize_type(var_type)
	var coerced_value := coerce_variable_value_for_type(value, normalized_type)
	match normalized_type:
		"String":
			return '"%s"' % coerced_value.c_escape()
		"bool":
			return coerced_value
		"int":
			return coerced_value
		"float":
			return coerced_value
		_:
			return coerced_value


static func parse_gdscript_value_literal(value_literal: String, var_type: String) -> String:
	var normalized_type := normalize_type(var_type)
	var text := str(value_literal).strip_edges()
	match normalized_type:
		"String":
			if text.length() >= 2 and text.begins_with('"') and text.ends_with('"'):
				text = text.substr(1, text.length() - 2)
				text = text.replace("\\\"", '"')
				text = text.replace("\\\\", "\\")
				text = text.replace("\\n", "\n")
				text = text.replace("\\t", "\t")
			return text
		"bool":
			return coerce_variable_value_for_type(text, normalized_type)
		"int":
			return coerce_variable_value_for_type(text, normalized_type)
		"float":
			return coerce_variable_value_for_type(text, normalized_type)
		_:
			return text
