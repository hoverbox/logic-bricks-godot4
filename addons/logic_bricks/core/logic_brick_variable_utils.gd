@tool
extends RefCounted
class_name LogicBrickVariableUtils

const SUPPORTED_TYPES = ["bool", "int", "float", "String", "Vector2", "Vector3", "Array"]
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
		TYPE_VECTOR2:
			return "Vector2"
		TYPE_VECTOR3:
			return "Vector3"
		TYPE_ARRAY:
			return "Array"
		_:
			return ""


static func get_default_value_for_variable_type(var_type: String):
	match normalize_type(var_type):
		"bool":
			return "false"
		"int":
			return "0"
		"float":
			return "0.0"
		"String":
			return ""
		"Vector2":
			return "Vector2.ZERO"
		"Vector3":
			return "Vector3.ZERO"
		"Array":
			return []
		_:
			return "0"


static func coerce_variable_value_for_type(value, var_type: String):
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
		"Vector2":
			var text := text_value.strip_edges()
			if text.begins_with("Vector2(") and text.ends_with(")"):
				return text
			var parts := text.split(",", false)
			if parts.size() == 2 and str(parts[0]).strip_edges().is_valid_float() and str(parts[1]).strip_edges().is_valid_float():
				return "Vector2(%s, %s)" % [str(parts[0]).strip_edges(), str(parts[1]).strip_edges()]
			return "Vector2.ZERO"
		"Vector3":
			var text := text_value.strip_edges()
			if text.begins_with("Vector3(") and text.ends_with(")"):
				return text
			var parts := text.split(",", false)
			if parts.size() == 3 and str(parts[0]).strip_edges().is_valid_float() and str(parts[1]).strip_edges().is_valid_float() and str(parts[2]).strip_edges().is_valid_float():
				return "Vector3(%s, %s, %s)" % [str(parts[0]).strip_edges(), str(parts[1]).strip_edges(), str(parts[2]).strip_edges()]
			return "Vector3.ZERO"
		"Array":
			if value is Array:
				return value.duplicate(true)
			return []
		_:
			return text_value


static func value_to_line_edit_text(value) -> String:
	return str(value)


static func to_gdscript_value_literal(value, var_type: String) -> String:
	var normalized_type := normalize_type(var_type)
	var coerced_value: Variant = coerce_variable_value_for_type(value, normalized_type)
	match normalized_type:
		"String":
			return '"%s"' % coerced_value.c_escape()
		"bool":
			return coerced_value
		"int":
			return coerced_value
		"float":
			return coerced_value
		"Vector2", "Vector3":
			return coerced_value
		"Array":
			return _array_to_gdscript_literal(coerced_value)
		_:
			return coerced_value


static func parse_gdscript_value_literal(value_literal: String, var_type: String):
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
		"Vector2", "Vector3":
			return coerce_variable_value_for_type(text, normalized_type)
		"Array":
			return _parse_array_literal(text)
		_:
			return text


static func _array_item_to_literal(item) -> String:
	if item is Dictionary and item.has("type"):
		return to_gdscript_value_literal(item.get("value", ""), str(item.get("type", "String")))
	match typeof(item):
		TYPE_BOOL: return "true" if item else "false"
		TYPE_INT, TYPE_FLOAT: return str(item)
		TYPE_STRING: return '"%s"' % str(item).c_escape()
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR: return str(item)
		TYPE_ARRAY: return _array_to_gdscript_literal(item)
		_: return '"%s"' % str(item).c_escape()

static func _array_to_gdscript_literal(value) -> String:
	if not (value is Array):
		return "[]"
	var parts: Array[String] = []
	for item in value:
		parts.append(_array_item_to_literal(item))
	return "[%s]" % ", ".join(parts)

static func _parse_array_literal(text: String) -> Array:
	# Disk fallback parser. Metadata is the authoritative source for typed array items.
	# Preserve common scalar literals when globals are reconstructed from global_vars.gd.
	var result: Array = []
	var body := text.strip_edges()
	if not body.begins_with("[") or not body.ends_with("]"):
		return result
	body = body.substr(1, body.length() - 2).strip_edges()
	if body.is_empty():
		return result
	var current := ""
	var depth := 0
	var quoted := false
	var escaped := false
	for ch in body:
		if escaped:
			current += ch
			escaped = false
			continue
		if ch == "\\" and quoted:
			current += ch
			escaped = true
			continue
		if ch == '"':
			quoted = not quoted
			current += ch
			continue
		if not quoted:
			if ch in ["(", "["]:
				depth += 1
			elif ch in [")", "]"]:
				depth -= 1
			elif ch == "," and depth == 0:
				result.append(_literal_to_typed_item(current.strip_edges()))
				current = ""
				continue
		current += ch
	if not current.strip_edges().is_empty():
		result.append(_literal_to_typed_item(current.strip_edges()))
	return result

static func _literal_to_typed_item(text: String) -> Dictionary:
	if text.to_lower() in ["true", "false"]:
		return {"type":"bool", "value":text.to_lower()}
	if text.is_valid_int():
		return {"type":"int", "value":text}
	if text.is_valid_float():
		return {"type":"float", "value":text}
	if text.begins_with("Vector2("):
		return {"type":"Vector2", "value":text}
	if text.begins_with("Vector3("):
		return {"type":"Vector3", "value":text}
	if text.length() >= 2 and text.begins_with('"') and text.ends_with('"'):
		return {"type":"String", "value":parse_gdscript_value_literal(text, "String")}
	return {"type":"String", "value":text}
