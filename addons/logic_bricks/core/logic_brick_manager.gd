@tool
extends RefCounted

## Manages logic brick chains and generates GDScript code

const LogicBrick = preload("res://addons/logic_bricks/core/logic_brick.gd")
const VariableUtils = preload("res://addons/logic_bricks/core/logic_brick_variable_utils.gd")
const BrickRegistry = preload("res://addons/logic_bricks/core/brick_registry.gd")
const Migrations = preload("res://addons/logic_bricks/core/logic_brick_migrations.gd")
const GraphSnapshot = preload("res://addons/logic_bricks/core/graph_snapshot.gd")

## Metadata key for storing brick chains
const METADATA_KEY = "logic_bricks"
const SCHEMA_VERSION_KEY = Migrations.SCHEMA_VERSION_KEY
const CURRENT_SCHEMA_VERSION = Migrations.CURRENT_SCHEMA_VERSION
const GLOBAL_VARS_PATH := "res://logic_bricks_global_vars.gd"
const GLOBAL_VARS_SETTING := "logic_bricks/global_vars"

## Code generation markers
const CODE_START_MARKER = "# === LOGIC BRICKS START ==="
## Annotation arguments, allowing one level of nested parentheses,
## e.g. @export_range(0, 10) or @rpc("any_peer", "call_local").
const ANNOTATION_ARGS_RX := "\\((?:[^()]|\\([^()]*\\))*\\)"
const CODE_END_MARKER = "# === LOGIC BRICKS END ==="
const BRICK_BEGIN_PREFIX = "# LB_BRICK_BEGIN_B64 "
const BRICK_END_PREFIX = "# LB_BRICK_END "

## Apply Code outcomes (see check_apply_candidate()).
const APPLY_OK := "ok"
const APPLY_GENERATED_ERROR := "generated_error"
const APPLY_ALREADY_BROKEN := "already_broken"
const APPLY_REFUSED := "refused"
## Copy of the last script version that parsed, kept after an Apply that
## produced an error and removed by the next clean Apply.
const LAST_GOOD_SUFFIX := ".logic_bricks_last_good"
const ERROR_CAPTURE_SOURCE := """extends Logger
var errors: Array = []
func _log_error(_function, file, line, code, rationale, _editor_notify, _error_type, _script_backtraces):
	# Only parse errors from in-memory scripts (the candidate being checked).
	if str(file).begins_with("gdscript://"):
		var text := str(code) if not str(code).is_empty() else str(rationale)
		errors.append({"line": line, "message": text})
func _log_message(_message, _error):
	pass
"""

## Outcome of the most recent regenerate_script() call (see check_apply_candidate()).
var last_apply_report: Dictionary = {}

## Reference to editor interface for marking scenes as modified
var editor_interface = null


## Get all brick chains from a node's metadata
func get_chains(node: Node) -> Array:
	migrate_node_metadata(node)
	if node.has_meta(METADATA_KEY):
		var data = node.get_meta(METADATA_KEY)
		if data is Array:
			return data.duplicate()
	return []


## Save brick chains to node metadata
func save_chains(node: Node, chains: Array) -> void:
	node.set_meta(METADATA_KEY, chains)
	Migrations.stamp_current_schema(node)

	# Mark the scene as modified so changes are saved
	_mark_scene_modified(node)


## Upgrade old Logic Bricks metadata before the rest of the addon consumes it.
## Returns true only when metadata changed.
func migrate_node_metadata(node: Node) -> bool:
	if node == null:
		return false
	var result: Dictionary = Migrations.migrate_node(node)
	if bool(result.get("future_version", false)):
		push_warning("Logic Bricks: Node '%s' uses newer saved-data schema v%d (this addon supports v%d). Metadata was left unchanged." % [node.name, int(result.get("from_version", 0)), CURRENT_SCHEMA_VERSION])
		return false
	if bool(result.get("changed", false)):
		_mark_scene_modified(node)
		return true
	return false


func stamp_current_schema(node: Node) -> void:
	Migrations.stamp_current_schema(node)


## Regenerate the script for a node based on its brick chains.
## Returns true when the script was written, even if it now has an error from
## generated code; last_apply_report then says what went wrong. Returns false
## when nothing was written (write failure, or check_apply_candidate() found
## that the student's own code would be damaged).
func regenerate_script(node: Node, variables_code: String = "") -> bool:
	var chains = get_chains(node)

	# If no variables code was passed, generate it from node metadata
	if variables_code.is_empty() and node.has_meta("logic_bricks_variables"):
		variables_code = _get_variables_code_from_metadata(node)

	# Generate the new logic bricks code
	var generated_code = _generate_code_for_chains(node, chains, variables_code)

	# Only regenerate for nodes that already have a user-assigned script.
	if not node.get_script():
		push_warning("Logic Bricks: Node '%s' has no script. Add a script manually before applying Logic Bricks code." % node.name)
		return false

	var script_path: String = node.get_script().resource_path
	if script_path.is_empty():
		push_error("Logic Bricks: The selected script has no resource path. Existing script was not modified.")
		return false

	# Read existing script.
	var file := FileAccess.open(script_path, FileAccess.READ)
	if not file:
		push_error("Logic Bricks: Could not open script file: " + script_path)
		return false

	var existing_code: String = file.get_as_text()
	file.close()

	# Build the complete candidate without touching the working file.
	var new_code: String = _replace_generated_code(existing_code, generated_code, node)

	# Apply Code stays permissive: students must be able to regenerate even when
	# a brick is incomplete. The only thing refused is a candidate where the
	# addon itself damaged the student's own code. See check_apply_candidate().
	var report := check_apply_candidate(existing_code, new_code, node)
	last_apply_report = report
	var status: String = report["status"]
	if status == APPLY_REFUSED:
		push_error("Logic Bricks: " + str(report["message"]))
		return false

	var last_good_path := script_path + LAST_GOOD_SUFFIX
	if status == APPLY_GENERATED_ERROR:
		# Keep the last version that parsed so the student can always go back.
		# If one is already kept from an earlier failed Apply, it is older and
		# still the last good version, so leave it alone.
		if not FileAccess.file_exists(last_good_path) and FileAccess.file_exists(script_path):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(script_path), ProjectSettings.globalize_path(last_good_path))
		if FileAccess.file_exists(last_good_path):
			report["message"] = str(report["message"]) + " The version from before this Apply is saved at %s." % last_good_path

	if not write_gdscript_unchecked(script_path, new_code, "Apply Code"):
		return false

	if status == APPLY_OK:
		_cleanup_regeneration_artifact(last_good_path)
	else:
		push_warning("Logic Bricks: " + str(report["message"]))
	return true


## Classify a candidate script before Apply Code writes it.
## Returns {"status", "message", "short_message", "line", "graph_node_id"}:
##   APPLY_OK              candidate parses.
##   APPLY_GENERATED_ERROR the original parsed, the error comes from generated
##                         code (or user code that relies on something no
##                         longer generated). Saved with a warning.
##   APPLY_ALREADY_BROKEN  the original script already failed to parse, so the
##                         error is not ours to block. Saved with a warning.
##   APPLY_REFUSED         the original parsed but inserting/replacing the block
##                         broke the student's own code. Not saved.
func check_apply_candidate(existing_code: String, new_code: String, node: Node) -> Dictionary:
	var report := {"status": APPLY_OK, "message": "", "short_message": "", "line": -1, "graph_node_id": ""}
	var candidate := _parse_check(new_code)
	if candidate["ok"]:
		return report
	report["line"] = candidate["line"]
	var error_text: String = str(candidate["message"]).strip_edges().trim_suffix(".")
	var where := " (line %d)" % int(candidate["line"]) if int(candidate["line"]) > 0 else ""

	var original := _parse_check(existing_code) if not existing_code.strip_edges().is_empty() else {"ok": true, "line": -1}
	# An error inside the previous generated block came from an earlier Apply,
	# not from the student, so it does not count as "already broken".
	var original_error_is_ours := _line_is_inside_generated_block(existing_code, int(original["line"]))
	if not original["ok"] and not original_error_is_ours:
		report["status"] = APPLY_ALREADY_BROKEN
		report["message"] = "Code applied, but the script already had an error before this Apply%s: %s" % [where, error_text]
		return report

	var had_markers := existing_code.contains(CODE_START_MARKER) and existing_code.contains(CODE_END_MARKER)
	if not had_markers:
		# First Apply on this script: the student's code cannot depend on generated
		# code yet, so the same insertion with an empty block must still parse.
		if not _parse_check(_replace_generated_code(existing_code, "", node))["ok"]:
			report["status"] = APPLY_REFUSED
			report["message"] = "Apply Code was cancelled because adding the Logic Bricks block would have broken your own code%s: %s. Your script was not changed. This is a Logic Bricks bug; please report it." % [where, error_text]
			return report

	report["status"] = APPLY_GENERATED_ERROR
	var brick := _find_brick_at_line(new_code, int(candidate["line"]))
	if not brick.is_empty():
		report["graph_node_id"] = brick["graph_node_id"]
		report["short_message"] = "Generated code error: %s" % error_text
		report["message"] = "Code applied, but the code generated for the %s brick has an error%s: %s. Check that brick's settings." % [brick["name"], where, error_text]
	elif _line_is_inside_generated_block(new_code, int(candidate["line"])):
		report["message"] = "Code applied, but the generated Logic Bricks code has an error%s: %s." % [where, error_text]
	elif int(candidate["line"]) > 0:
		report["message"] = "Code applied, but your own code now has an error%s: %s. It may use something Logic Bricks no longer generates, such as a removed variable." % [where, error_text]
	else:
		report["message"] = "Code applied, but the script now has an error: %s. See the Output panel for details." % error_text
	return report


## Parse/compile-check GDScript source without touching any file.
## Returns {"ok": bool, "line": int (1-based, -1 if unknown), "message": String}.
## class_name is stripped first so a copy of a script never collides with the
## real script's global class. Line numbers are unaffected.
func _parse_check(source_code: String) -> Dictionary:
	var candidate := GDScript.new()
	candidate.source_code = _strip_class_name_for_check(source_code)
	var capture = _new_error_capture()
	if capture:
		OS.add_logger(capture)
	var err: Error = candidate.reload()
	if capture:
		OS.remove_logger(capture)
	if err == OK:
		return {"ok": true, "line": -1, "message": ""}
	var result := {"ok": false, "line": -1, "message": "error %d" % int(err)}
	if capture and not capture.errors.is_empty():
		result["line"] = int(capture.errors[0]["line"])
		result["message"] = str(capture.errors[0]["message"]).trim_prefix("Parse Error: ")
	return result


static func _strip_class_name_for_check(source_code: String) -> String:
	var lines := source_code.split("\n")
	var rx := RegEx.new()
	rx.compile("^class_name\\s+\\w+\\s*")
	for i in lines.size():
		if rx.search(lines[i]):
			lines[i] = rx.sub(lines[i], "")
			break
	return "\n".join(lines)


## A Logger that records parse errors from pathless scripts (Godot 4.5+).
## Built from source at runtime so the addon still loads on versions without
## the Logger class; there it returns null and errors have no line number.
static var _error_capture_script: GDScript = null

func _new_error_capture():
	if not ClassDB.class_exists("Logger"):
		return null
	if _error_capture_script == null:
		var script := GDScript.new()
		script.source_code = ERROR_CAPTURE_SOURCE
		if script.reload() != OK:
			return null
		_error_capture_script = script
	return _error_capture_script.new()


## The innermost brick whose LB_BRICK markers enclose a 1-based line, as
## {"graph_node_id", "name"}, or {} when the line is outside every brick.
func _find_brick_at_line(source_code: String, line_number: int) -> Dictionary:
	if line_number <= 0:
		return {}
	var lines := source_code.split("\n")
	var stack: Array[Dictionary] = []
	for i in mini(line_number, lines.size()):
		var stripped := lines[i].strip_edges()
		if stripped.begins_with(BRICK_BEGIN_PREFIX.strip_edges()):
			stack.append(_decode_brick_marker(stripped))
		elif stripped.begins_with(BRICK_END_PREFIX.strip_edges()) and not stack.is_empty():
			stack.pop_back()
	return stack.back() if not stack.is_empty() else {}


func _decode_brick_marker(marker_line: String) -> Dictionary:
	var b64 := marker_line.trim_prefix(BRICK_BEGIN_PREFIX.strip_edges()).strip_edges()
	var payload = bytes_to_var(Marshalls.base64_to_raw(b64))
	if not (payload is Dictionary):
		return {"graph_node_id": "", "name": "a"}
	var display_name := str(payload.get("instance_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = str(payload.get("type", "unknown")).capitalize()
	return {"graph_node_id": str(payload.get("graph_node_id", "")), "name": "'%s'" % display_name}


func _line_is_inside_generated_block(source_code: String, line_number: int) -> bool:
	if line_number <= 0:
		return false
	var lines := source_code.split("\n")
	var inside := false
	for i in mini(line_number, lines.size()):
		var stripped := lines[i].strip_edges()
		if stripped == CODE_START_MARKER:
			inside = true
		elif stripped == CODE_END_MARKER:
			inside = false
	return inside


## Write a generated script atomically without compile-gating it.
## Used by Apply Code so validation warnings/errors never block regeneration.
func write_gdscript_unchecked(script_path: String, source_code: String, operation_label: String = "Generated script update") -> bool:
	var temp_path := script_path + ".logic_bricks_tmp"
	var backup_path := script_path + ".logic_bricks_backup"
	_cleanup_regeneration_artifact(temp_path)
	_cleanup_regeneration_artifact(backup_path)

	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		push_error("Logic Bricks: %s could not create a temporary script file." % operation_label)
		return false
	file.store_string(source_code)
	file.close()

	var original_exists := FileAccess.file_exists(script_path)
	var original_abs := ProjectSettings.globalize_path(script_path)
	var temp_abs := ProjectSettings.globalize_path(temp_path)
	var backup_abs := ProjectSettings.globalize_path(backup_path)

	if original_exists:
		var move_old_error: Error = DirAccess.rename_absolute(original_abs, backup_abs)
		if move_old_error != OK:
			_cleanup_regeneration_artifact(temp_path)
			push_error("Logic Bricks: %s could not prepare the script for replacement (error %d)." % [operation_label, int(move_old_error)])
			return false

	var install_error: Error = DirAccess.rename_absolute(temp_abs, original_abs)
	if install_error != OK:
		_cleanup_regeneration_artifact(temp_path)
		if original_exists:
			var rollback_error: Error = DirAccess.rename_absolute(backup_abs, original_abs)
			if rollback_error != OK:
				push_error("Logic Bricks: %s replacement failed and automatic rollback also failed. Backup remains at: %s" % [operation_label, backup_path])
			else:
				push_error("Logic Bricks: %s could not replace the script (error %d). Original script was restored." % [operation_label, int(install_error)])
		else:
			push_error("Logic Bricks: %s could not install the generated script (error %d)." % [operation_label, int(install_error)])
		return false

	_cleanup_regeneration_artifact(backup_path)
	return true


## Compile a generated GDScript candidate before replacing the working file.
## Uses a sibling temp file plus a short-lived backup so callers such as Apply
## Code and GlobalVars generation share the same rollback-safe write path.
func safe_write_gdscript(script_path: String, source_code: String, operation_label: String = "Generated script update") -> bool:
	var candidate := GDScript.new()
	candidate.source_code = source_code
	var validation_error: Error = candidate.reload()
	if validation_error != OK:
		push_error("Logic Bricks: %s aborted because the generated script did not compile (error %d). Existing script was not modified." % [operation_label, int(validation_error)])
		return false

	var temp_path := script_path + ".logic_bricks_tmp"
	var backup_path := script_path + ".logic_bricks_backup"
	_cleanup_regeneration_artifact(temp_path)
	_cleanup_regeneration_artifact(backup_path)

	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		push_error("Logic Bricks: %s could not create a temporary script file. Existing script was not modified." % operation_label)
		return false
	file.store_string(source_code)
	file.close()

	var original_exists := FileAccess.file_exists(script_path)
	var original_abs := ProjectSettings.globalize_path(script_path)
	var temp_abs := ProjectSettings.globalize_path(temp_path)
	var backup_abs := ProjectSettings.globalize_path(backup_path)

	if original_exists:
		var move_old_error: Error = DirAccess.rename_absolute(original_abs, backup_abs)
		if move_old_error != OK:
			_cleanup_regeneration_artifact(temp_path)
			push_error("Logic Bricks: %s could not prepare the script for safe replacement (error %d). Existing script was not modified." % [operation_label, int(move_old_error)])
			return false

	var install_error: Error = DirAccess.rename_absolute(temp_abs, original_abs)
	if install_error != OK:
		_cleanup_regeneration_artifact(temp_path)
		if original_exists:
			var rollback_error: Error = DirAccess.rename_absolute(backup_abs, original_abs)
			if rollback_error != OK:
				push_error("Logic Bricks: %s safe replacement failed and automatic rollback also failed. Backup remains at: %s" % [operation_label, backup_path])
			else:
				push_error("Logic Bricks: %s could not replace the script (error %d). Original script was restored." % [operation_label, int(install_error)])
		else:
			push_error("Logic Bricks: %s could not install the generated script (error %d)." % [operation_label, int(install_error)])
		return false

	_cleanup_regeneration_artifact(backup_path)
	return true


func _cleanup_regeneration_artifact(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_path)


## Generate code for all chains
## Generate variables code from node metadata (same format as panel's get_variables_code)
func _read_global_vars_from_script() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var script_path = GLOBAL_VARS_PATH
	if not FileAccess.file_exists(script_path):
		return result

	# Use the GDScript API instead of hand-parsing the source text.
	# get_script_property_list() is authoritative — it handles typed arrays,
	# multi-line declarations, comments, and any other syntax the parser accepts.
	var script = load(script_path)
	if not script:
		return result

	# get_script_property_list() returns the properties defined directly on the
	# script (not inherited ones), exactly what we need for global_vars.gd.
	for prop in script.get_script_property_list():
		var prop_name: String = prop["name"]
		if prop_name.is_empty() or prop_name.begins_with("_") or prop_name.begins_with("@"):
			continue
		# Map Godot Variant type integers to the string type names the rest of the
		# addon uses (e.g. "int", "float", "bool", "String").
		var type_int: int = prop["type"]
		var type_str: String = VariableUtils.gdscript_type_name_from_variant_type(type_int)
		if type_str.is_empty():
			continue  # Skip non-primitive types (Object refs, Arrays, etc.)
		# Read the current default value from a temporary instance so we get the
		# actual initialised value, not just a text representation.
		var tmp = script.new()
		var value = tmp.get(prop_name)
		result.append({
			"name": prop_name,
			"type": type_str,
			"value": str(value) if value != null else VariableUtils.get_default_value_for_variable_type(type_str)
		})
	return result


func _get_selected_global_vars(node: Node) -> Array[Dictionary]:
	var usage_map: Dictionary = {}
	if node.has_meta("logic_bricks_global_usage"):
		var usage = node.get_meta("logic_bricks_global_usage")
		if usage is Dictionary:
			usage_map = usage
	if usage_map.is_empty():
		return []

	var globals_data: Array[Dictionary] = []
	# ProjectSettings is the project-wide source of truth. Scene metadata is only
	# a legacy fallback so an older scene cannot resurrect a deleted global.
	if ProjectSettings.has_setting(GLOBAL_VARS_SETTING):
		var project_globals = ProjectSettings.get_setting(GLOBAL_VARS_SETTING, [])
		if project_globals is Array:
			for var_data in project_globals:
				if var_data is Dictionary:
					globals_data.append(var_data.duplicate(true))
	else:
		var scene_root = node.get_tree().edited_scene_root if node.get_tree() else null
		if scene_root and scene_root.has_meta("logic_bricks_global_vars"):
			var meta_globals = scene_root.get_meta("logic_bricks_global_vars")
			if meta_globals is Array:
				for var_data in meta_globals:
					if var_data is Dictionary:
						globals_data.append(var_data.duplicate(true))
	if globals_data.is_empty():
		globals_data = _read_global_vars_from_script()

	var selected: Array[Dictionary] = []
	for var_data in globals_data:
		var gid = str(var_data.get("id", ""))
		if not gid.is_empty() and bool(usage_map.get(gid, false)):
			selected.append(var_data)
	return selected


func _get_variables_code_from_metadata(node: Node) -> String:
	var variables_data = []
	if node.has_meta("logic_bricks_variables"):
		variables_data = node.get_meta("logic_bricks_variables")

	var used_globals = _get_selected_global_vars(node)
	var lines: Array[String] = []
	var has_any_vars = false
	for vd in variables_data:
		if not vd.get("global", false) and not vd.get("name", "").is_empty():
			has_any_vars = true
			break
	if not has_any_vars and not used_globals.is_empty():
		has_any_vars = true
	if not has_any_vars:
		return ""
	lines.append("# Variables")

	for var_data in variables_data:
		var var_name = VariableUtils.normalize_name_spaces(str(var_data.get("name", "")))
		var var_type = VariableUtils.normalize_type(str(var_data.get("type", "float")), "float")
		var var_value = VariableUtils.to_gdscript_value_literal(var_data.get("value", VariableUtils.get_default_value_for_variable_type(var_type)), var_type)
		var exported = var_data.get("exported", false)
		var is_global = var_data.get("global", false)

		if var_name.is_empty():
			continue

		var use_min   = var_data.get("use_min", false)
		var min_val   = var_data.get("min_val", "0")
		var use_max   = var_data.get("use_max", false)
		var max_val   = var_data.get("max_val", "100")
		var has_range = (var_type in ["int", "float"]) and (use_min or use_max)

		if is_global:
			continue
		elif has_range and exported:
			var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
			var hi = max_val if use_max else ("9999999"  if var_type == "int" else "9999999.0")
			lines.append("@export_range(%s, %s) var %s: %s = %s" % [lo, hi, var_name, var_type, var_value])
		elif has_range and not exported:
			var clamp_fn = "clampi" if var_type == "int" else "clampf"
			var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
			var hi = max_val if use_max else ("9999999"  if var_type == "int" else "9999999.0")
			lines.append("var _%s_raw: %s = %s" % [var_name, var_type, var_value])
			lines.append("var %s: %s:" % [var_name, var_type])
			lines.append("\tget: return _%s_raw" % var_name)
			lines.append("\tset(val): _%s_raw = %s(val, %s, %s)" % [var_name, clamp_fn, lo, hi])
		else:
			var declaration = ""
			if exported:
				declaration += "@export "
			declaration += "var %s: %s = %s" % [var_name, var_type, var_value]
			lines.append(declaration)

	for var_data in used_globals:
		var var_name = VariableUtils.normalize_name_spaces(str(var_data.get("name", "")))
		var var_type = VariableUtils.normalize_type(str(var_data.get("type", "int")), "int")
		var use_min = var_data.get("use_min", false)
		var min_val = var_data.get("min_val", "0")
		var use_max = var_data.get("use_max", false)
		var max_val = var_data.get("max_val", "100")
		if var_name.is_empty():
			continue
		lines.append("var %s: %s:" % [var_name, var_type])
		lines.append("	get:")
		lines.append("		var _gv = get_node_or_null(\"/root/GlobalVars\")")
		var fallback_value = VariableUtils.to_gdscript_value_literal(VariableUtils.get_default_value_for_variable_type(var_type), var_type)
		lines.append("		return _gv.get(\"%s\") if _gv and \"%s\" in _gv else %s" % [var_name, var_name, fallback_value])
		lines.append("	set(val):")
		lines.append("		var _gv = get_node_or_null(\"/root/GlobalVars\")")
		if var_type in ["int", "float"] and (use_min or use_max):
			var clamp_fn = "clampi" if var_type == "int" else "clampf"
			var lo = min_val if use_min else ("-9999999" if var_type == "int" else "-9999999.0")
			var hi = max_val if use_max else ("9999999" if var_type == "int" else "9999999.0")
			lines.append("		if _gv and \"%s\" in _gv: _gv.set(\"%s\", %s(val, %s, %s))" % [var_name, var_name, clamp_fn, lo, hi])
		else:
			lines.append("		if _gv and \"%s\" in _gv: _gv.set(\"%s\", val)" % [var_name, var_name])

	lines.append("")  # Empty line after variables
	return "\n".join(lines)


func _generate_code_for_chains(node: Node, chains: Array, variables_code: String = "") -> String:
	var code_lines: Array[String] = []

	# Normalize every chain name to its sanitized form before any code is emitted.
	# This guards against hand-edited scene metadata, old saves, or two display names
	# that collapse to the same identifier after sanitization (e.g. "my chain" / "my-chain"
	# both become "my_chain"). We resolve collisions by appending a numeric suffix, mirroring
	# _generate_unique_chain_name, but only touching duplicates — stable names stay stable.
	var seen_sanitized: Dictionary = {}
	for chain in chains:
		var sanitized = _sanitize_chain_name(chain["name"])
		if seen_sanitized.has(sanitized):
			var counter: int = seen_sanitized[sanitized]
			counter += 1
			seen_sanitized[sanitized] = counter
			sanitized = "%s_%d" % [sanitized, counter]
		else:
			seen_sanitized[sanitized] = 0
		chain["name"] = sanitized

	# Add variables code first (if any)
	if not variables_code.is_empty():
		code_lines.append(variables_code)

	# Runtime -> editor bridge (low-overhead state mirror). Each generated chain
	# updates one byte of local state. The debugger autoload polls this compact
	# snapshot only four times per second, so gameplay never sends per-brick IPC.
	if not chains.is_empty():
		var debug_chain_id_lists: Array = []
		for debug_chain in chains:
			debug_chain_id_lists.append(_collect_debug_brick_ids_for_chain(debug_chain))
		var debug_state_init: Array[String] = []
		for _i in range(chains.size()):
			debug_state_init.append("0")
		var debug_id_literals: Array[String] = []
		for id_list in debug_chain_id_lists:
			var quoted_ids: Array[String] = []
			for brick_id in id_list:
				quoted_ids.append(_gdscript_string_literal(str(brick_id)))
			debug_id_literals.append("[" + ", ".join(quoted_ids) + "]")
		code_lines.append("var _logic_bricks_debug_enabled: bool = false")
		code_lines.append("var _logic_bricks_debug_chain_states: PackedByteArray = PackedByteArray([%s])" % ", ".join(debug_state_init))
		code_lines.append("const _LOGIC_BRICKS_DEBUG_CHAIN_BRICK_IDS: Array = [%s]" % ", ".join(debug_id_literals))
		code_lines.append("")
		code_lines.append("func _logic_bricks_get_debug_snapshot() -> Array:")
		code_lines.append("\tvar active_ids: Array[String] = []")
		code_lines.append("\tfor chain_index in range(_logic_bricks_debug_chain_states.size()):")
		code_lines.append("\t\tif _logic_bricks_debug_chain_states[chain_index] == 0:")
		code_lines.append("\t\t\tcontinue")
		code_lines.append("\t\tfor brick_id in _LOGIC_BRICKS_DEBUG_CHAIN_BRICK_IDS[chain_index]:")
		code_lines.append("\t\t\tactive_ids.append(str(brick_id))")
		code_lines.append("\t_logic_bricks_debug_chain_states.fill(0)")
		code_lines.append("\treturn active_ids")
		code_lines.append("")

	var states_data: Array = []
	if node.has_meta("logic_bricks_states"):
		var saved_states = node.get_meta("logic_bricks_states")
		if saved_states is Array:
			for state_data in saved_states:
				states_data.append(state_data.duplicate(true))

	# First pass: collect any member variables from all sensors AND actuators across all chains.
	# These need to live at script scope (above the functions) because they persist across frames.
	# Also collect per-chain member vars so we can reset them on state entry.
	var member_vars: Array[String] = []
	var chain_member_vars: Dictionary = {}  # state_id -> Array[String] of reset lines
	var kept_member_var_patterns := PackedStringArray()  # from each brick's get_kept_member_vars()
	var chain_setup_calls: Dictionary = {}  # state_id -> Array[String] of setup func calls (re-run on state enter)
	var ready_code: Array[String] = []
	if not chains.is_empty():
		ready_code.append("if EngineDebugger.is_active():")
		ready_code.append("\t_logic_bricks_debug_enabled = true")
		ready_code.append("\tLogicBricksDebugger.register_debug_node(self)")
	var pre_process_code: Array[String] = []
	var post_process_code: Array[String] = []
	var physics_pre_process_code: Array[String] = []
	var physics_post_process_code: Array[String] = []
	var extra_methods: Array[String] = []
	var input_handler_bodies: Array[String] = []  # Body lines for shared _input()
	var message_handler_calls: Array[String] = []  # Call lines for shared _on_message_received()

	# Pause controls need a way to evaluate while SceneTree.paused is true, but
	# forcing the owning gameplay node to PROCESS_MODE_ALWAYS would also keep all
	# of its movement/custom script running. Use an always-processing SceneTreeTimer
	# as a tiny pause-only heartbeat instead; signals can resume this coroutine even
	# while the owning gameplay node itself remains paused.
	var pause_control_chain_names: Array[String] = []
	for chain in chains:
		if _chain_has_pause_control(chain):
			pause_control_chain_names.append(str(chain.get("name", "")))
	if not pause_control_chain_names.is_empty():
		ready_code.append("_logic_bricks_start_pause_watch()")

	# Check if any chain uses an ActuatorSensor — only then do we need the flags dict.
	# Do NOT clear it independently in _process() / _physics_process(): Action Active
	# may observe an actuator running in the other loop. Each source chain writes its
	# own current true/false value whenever it runs, so the latest value must persist
	# across loop boundaries. State changes clear the dictionary below.
	var has_actuator_sensor = false
	for chain in chains:
		for sensor_data in _collect_all_sensors_for_chain(chain):
			if sensor_data.get("type", "") == "ActuatorSensor":
				has_actuator_sensor = true
				break
		if has_actuator_sensor:
			break
	if has_actuator_sensor:
		member_vars.append("var _actuator_active_flags: Dictionary = {}  # Action Active: latest state of named actuators")
	for chain in chains:
		var this_chain_resets: Array[String] = []
		var chain_needs_physics_process := _chain_needs_physics_process(chain)

		# Check which state this chain belongs to. Member vars for state-specific
		# chains must reset when that state is entered, not when a chain-name-like
		# id is entered. The runtime calls _on_logic_brick_state_enter("state_...").
		# Older code incorrectly keyed resets by chain["name"], so checks like
		# state_id == "_10" never matched actual ids such as "state_2".
		var is_all_states_chain = false
		var chain_state_id := ""
		var controllers = chain.get("controllers", [])
		if controllers.size() > 0:
			var ctrl_props: Dictionary = controllers[0].get("properties", {})
			is_all_states_chain = bool(ctrl_props.get("all_states", false))
			chain_state_id = str(ctrl_props.get("state_id", "")).strip_edges()
			# Fall back to instantiated properties for older/oddly-shaped metadata.
			if chain_state_id.is_empty():
				var ctrl_brick = _instantiate_brick(controllers[0])
				if ctrl_brick:
					is_all_states_chain = bool(ctrl_brick.properties.get("all_states", is_all_states_chain))
					chain_state_id = str(ctrl_brick.properties.get("state_id", "")).strip_edges()

		# Collect from direct sensors and sensors nested inside controller inputs.
		# Each sensor gets its own code namespace so duplicated sensors do not
		# generate duplicate member/local variable names.
		for sensor_entry in _collect_sensor_generation_entries_for_chain(chain):
			var sensor_data: Dictionary = sensor_entry.get("data", {})
			var sensor_namespace: String = _sensor_code_namespace(chain["name"], str(sensor_entry.get("fallback_var", "sensor_active")))
			var sensor_brick = _instantiate_brick(sensor_data)
			if sensor_brick:
				var generated = sensor_brick.generate_code_for_node(node, sensor_namespace)
				_collect_kept_member_vars(kept_member_var_patterns, sensor_brick)
				if generated.has("member_vars"):
					_append_member_var_items(member_vars, generated["member_vars"])
					# Only collect resets for state-specific chains
					if not is_all_states_chain:
						for mv in generated["member_vars"]:
							var reset = _member_var_to_reset(mv)
							if not reset.is_empty() and reset not in this_chain_resets:
								this_chain_resets.append(reset)
					# Track setup helpers (e.g. _setup_collision_sensor_<chain>) so
					# _on_logic_brick_state_enter can re-invoke them after state transitions,
					# re-establishing Area3D refs and signal connections that would otherwise
					# be lost if the area var was nulled on state entry.
					if not is_all_states_chain:
						for mv in generated["member_vars"]:
							if mv.begins_with("func _setup_"):
								var func_name = mv.replace("func ", "").split("(")[0].strip_edges()
								var call_line = "%s()" % func_name
								if not chain_state_id.is_empty():
									if not chain_setup_calls.has(chain_state_id):
										chain_setup_calls[chain_state_id] = []
									if call_line not in chain_setup_calls[chain_state_id]:
										chain_setup_calls[chain_state_id].append(call_line)
				if generated.has("ready_code"):
					for rc in generated["ready_code"]:
						if rc not in ready_code:
							ready_code.append(rc)
				if generated.has("pre_process_code"):
					var _target_pre_process := physics_pre_process_code if chain_needs_physics_process else pre_process_code
					for pc in generated["pre_process_code"]:
						if pc not in _target_pre_process:
							_target_pre_process.append(pc)
				if generated.has("post_process_code"):
					var _target_post_process := physics_post_process_code if chain_needs_physics_process else post_process_code
					for pc in generated["post_process_code"]:
						if pc not in _target_post_process:
							_target_post_process.append(pc)
				if generated.has("methods"):
					for method in generated["methods"]:
						if method.begins_with("input_handler::"):
							var _body = method.substr(len("input_handler::"))
							if _body not in input_handler_bodies:
								input_handler_bodies.append(_body)
						elif method not in extra_methods:
							extra_methods.append(method)
				if generated.has("message_handler_calls"):
					for call_line in generated["message_handler_calls"]:
						if call_line not in message_handler_calls:
							message_handler_calls.append(call_line)

		# Collect from controllers — ScriptController emits a cached instance member var
		# and ready_code to load it once. Standard controllers emit nothing here.
		for controller_data in chain.get("controllers", []):
			var controller_brick = _instantiate_brick(controller_data)
			if controller_brick:
				var generated = controller_brick.generate_code_for_node(node, chain["name"])
				_collect_kept_member_vars(kept_member_var_patterns, controller_brick)
				if generated.has("member_vars"):
					_append_member_var_items(member_vars, generated["member_vars"])
				if generated.has("ready_code"):
					for rc in generated["ready_code"]:
						if rc not in ready_code:
							ready_code.append(rc)

		# Collect from actuators (they can also have member vars like RNG instances).
		# Use a per-actuator code namespace so multiple actuators of the same type in
		# one chain do not generate duplicate member variable or helper names.
		var actuator_list = chain.get("actuators", [])
		for actuator_index in range(actuator_list.size()):
			var actuator_data = actuator_list[actuator_index]
			var actuator_brick = _instantiate_brick(actuator_data)
			if actuator_brick:
				var actuator_code_name := "%s_%d" % [chain["name"], actuator_index]
				var generated = actuator_brick.generate_code_for_node(node, actuator_code_name)
				_collect_kept_member_vars(kept_member_var_patterns, actuator_brick)
				if generated.has("member_vars"):
					_append_member_var_items(member_vars, generated["member_vars"])
					# Only collect resets for state-specific chains
					if not is_all_states_chain:
						for mv in generated["member_vars"]:
							var reset = _member_var_to_reset(mv)
							if not reset.is_empty() and reset not in this_chain_resets:
								this_chain_resets.append(reset)
				if generated.has("ready_code"):
					for rc in generated["ready_code"]:
						if rc not in ready_code:
							ready_code.append(rc)
				if generated.has("pre_process_code"):
					var _target_pre_process := physics_pre_process_code if chain_needs_physics_process else pre_process_code
					for pc in generated["pre_process_code"]:
						if pc not in _target_pre_process:
							_target_pre_process.append(pc)
				if generated.has("post_process_code"):
					var _target_post_process := physics_post_process_code if chain_needs_physics_process else post_process_code
					for pc in generated["post_process_code"]:
						if pc not in _target_post_process:
							_target_post_process.append(pc)
				if generated.has("methods"):
					for method in generated["methods"]:
						if method.begins_with("input_handler::"):
							var _body = method.substr(len("input_handler::"))
							if _body not in input_handler_bodies:
								input_handler_bodies.append(_body)
						elif method not in extra_methods:
							extra_methods.append(method)

		if this_chain_resets.size() > 0 and not chain_state_id.is_empty():
			if not chain_member_vars.has(chain_state_id):
				chain_member_vars[chain_state_id] = []
			for _reset_line in this_chain_resets:
				if _reset_line not in chain_member_vars[chain_state_id]:
					chain_member_vars[chain_state_id].append(_reset_line)

	# Drop resets for variables a brick declared as long-lived. Done after all
	# chains so a variable listed by any brick on the node is kept everywhere.
	for _state_id in chain_member_vars:
		chain_member_vars[_state_id] = chain_member_vars[_state_id].filter(
			func(reset_line: String) -> bool:
				return not _is_kept_member_var(reset_line.get_slice(" = ", 0).strip_edges(), kept_member_var_patterns))

	if member_vars.size() > 0:
		for mv in member_vars:
			code_lines.append(mv)
		code_lines.append("")

	code_lines.append("")

	# Generate _ready() function
	# Collect export validation checks from member vars
	var export_checks: Array[String] = []
	# Primitive types that should NOT get null-checks
	var primitive_types = ["float", "int", "bool", "String", "Vector2", "Vector3", "Color", "Basis", "Transform3D"]
	for mv in member_vars:
		if mv.begins_with("@export var "):
			# Extract variable name and type: "@export var _cam: Camera3D" -> name="_cam", type="Camera3D"
			var parts = mv.replace("@export var ", "").split(":")
			if parts.size() >= 2:
				var var_name = parts[0].strip_edges()
				# Strip any initializer from the type. Example: `String = "Player"` -> `String`.
				var var_type = parts[1].split("=", false, 1)[0].strip_edges()
				# Skip null-checks for primitive types — they always have a value
				if var_type in primitive_types:
					continue
				var label = var_name
				export_checks.append("if not %s:" % var_name)
				export_checks.append("\tpush_warning(\"Logic Bricks: '%s' is not assigned! Drag a node into the inspector.\")" % label)

	var needs_state_runtime := _chains_need_state_runtime(chains, states_data)

	if ready_code.size() > 0 or export_checks.size() > 0 or needs_state_runtime:
		code_lines.append("func _ready() -> void:")
		if needs_state_runtime:
			code_lines.append("	_logic_brick_init_states()")
		# Defer export validation by one frame so all nodes are in the scene tree.
		# Accessing @export node references before the tree is ready triggers
		# "Cannot get path of node as it is not in a scene tree" errors.
		if export_checks.size() > 0:
			code_lines.append("\tawait get_tree().process_frame")
			for ec in export_checks:
				# Use is_instance_valid instead of plain truthiness —
				# a plain "if not node:" can also trigger the path error.
				var safe_ec = ec.replace("if not ", "if not is_instance_valid(").replace(":", "):")
				if "is_instance_valid" in safe_ec:
					code_lines.append("\t" + safe_ec)
				else:
					code_lines.append("\t" + ec)
		# Other ready code runs immediately (not deferred)
		for rc in ready_code:
			code_lines.append("\t" + rc)
		code_lines.append("")

	# Runtime state is emitted only when the graph actually uses named states.
	if needs_state_runtime:
		code_lines.append("var _logic_brick_state: String = \"\"")
		code_lines.append("")
		code_lines.append("func _logic_brick_init_states() -> void:")
		if states_data.is_empty():
			code_lines.append("	_logic_brick_state = \"\"")
		else:
			code_lines.append("	_logic_brick_state = %s" % _gdscript_string_literal(str(states_data[0].get("id", ""))))
		code_lines.append("")
		code_lines.append("func _logic_brick_chain_state_matches(state_id: String, all_states: bool = false) -> bool:")
		code_lines.append("	if all_states:")
		code_lines.append("		return true")
		code_lines.append("	if state_id.is_empty():")
		code_lines.append("		return true")
		code_lines.append("	return _logic_brick_state == state_id")
		code_lines.append("")
		code_lines.append("func _logic_brick_get_state_signature() -> String:")
		code_lines.append("	return _logic_brick_state")
		code_lines.append("")
		code_lines.append("func _logic_brick_set_state(new_state: String) -> void:")
		code_lines.append("\tif _logic_brick_state == new_state:")
		code_lines.append("\t\treturn")
		code_lines.append("\t_logic_brick_state = new_state")
		if has_actuator_sensor:
			code_lines.append("\t_actuator_active_flags.clear()")
		code_lines.append("\t_on_logic_brick_state_enter(new_state)")
		code_lines.append("")
		code_lines.append("func _on_logic_brick_state_enter(_state_id: String) -> void:")
		var _has_state_body := false
		for _chain_name in chain_member_vars:
			var _resets: Array = chain_member_vars[_chain_name]
			var _setups: Array = chain_setup_calls.get(_chain_name, [])
			if _resets.is_empty() and _setups.is_empty():
				continue
			if not _has_state_body:
				_has_state_body = true
			code_lines.append("\tif _state_id == %s:" % _gdscript_string_literal(_chain_name))
			for _reset_line in _resets:
				code_lines.append("\t\t" + _reset_line)
			for _setup_call in _setups:
				code_lines.append("\t\t" + _setup_call)
		if not _has_state_body:
			code_lines.append("\tpass")
		code_lines.append("")

	# Pre-generate all chain functions — this is the single source of truth for
	# whether a chain produces valid output. Calls are only emitted if the function
	# is non-empty, preventing mismatches between call sites and definitions.
	var generated_chain_functions: Dictionary = {}  # chain_name -> code string
	for chain_index in range(chains.size()):
		var chain = chains[chain_index]
		# Warn early if the chain mixes physics and non-physics actuators. The whole
		# chain runs in _physics_process when any physics actuator is present, so
		# non-physics actuators (animation, UI, etc.) will run at the wrong time.
		if _chain_has_mixed_actuators(chain):
			push_warning(
				"Logic Bricks: Chain '%s' on node '%s' mixes physics movement with timing-sensitive actuators. The entire chain will run in _physics_process, which may cause incorrect timing for animation, UI, audio, or other time-based actuators. Split only those timing-sensitive actuators into a separate chain." \
				% [chain["name"], node.name]
			)
		var chain_code = _generate_chain_function(node, chain, has_actuator_sensor, chain_index)
		if not chain_code.is_empty():
			generated_chain_functions[chain["name"]] = chain_code

	# Determine if we need process or physics process
	var has_process = false
	var has_physics_process = false

	for chain in chains:
		if not generated_chain_functions.has(chain["name"]):
			continue
		var needs_physics = _chain_needs_physics_process(chain)
		if needs_physics:
			has_physics_process = true
		else:
			has_process = true

	# Generate process functions
	if has_process:
		code_lines.append("func _process(delta: float) -> void:")
		if pre_process_code.size() > 0:
			for pc in pre_process_code:
				code_lines.append("	" + pc)
			code_lines.append("	")
		var has_any_process_chain = false
		for chain in chains:
			if generated_chain_functions.has(chain["name"]) and not _chain_needs_physics_process(chain) and _chain_is_state_transition_only(chain):
				code_lines.append("	_logic_brick_%s(delta)" % chain["name"])
				has_any_process_chain = true
		for chain in chains:
			if generated_chain_functions.has(chain["name"]) and not _chain_needs_physics_process(chain) and not _chain_is_state_transition_only(chain):
				code_lines.append("	_logic_brick_%s(delta)" % chain["name"])
				has_any_process_chain = true
		if not has_any_process_chain:
			code_lines.append("	pass")
		if post_process_code.size() > 0:
			code_lines.append("	")
			for pc in post_process_code:
				code_lines.append("	" + pc)
		code_lines.append("")

	if has_physics_process:
		code_lines.append("func _physics_process(delta: float) -> void:")
		if physics_pre_process_code.size() > 0:
			for pc in physics_pre_process_code:
				code_lines.append("	" + pc)
			code_lines.append("	")
		var has_any_physics_chain = false
		# Do not run non-physics state-transition-only chains again here. They are
		# already emitted in _process(); emitting them in both loops makes delay
		# sensors advance twice and can switch states in the same frame.
		for chain in chains:
			if generated_chain_functions.has(chain["name"]) and _chain_needs_physics_process(chain):
				code_lines.append("	_logic_brick_%s(delta)" % chain["name"])
				has_any_physics_chain = true
		if not has_any_physics_chain:
			code_lines.append("	pass")
		if physics_post_process_code.size() > 0:
			code_lines.append("	")
			for pc in physics_post_process_code:
				code_lines.append("	" + pc)
		code_lines.append("")

	# While paused, normal _process/_physics_process callbacks on this node stop.
	# SceneTreeTimer can explicitly process while paused, and its timeout signal can
	# resume a method on a paused node. Poll only the chains that contain a Game
	# Pause/Unpause/Toggle Pause action; all other Logic Bricks and user callbacks
	# remain genuinely paused.
	if not pause_control_chain_names.is_empty():
		code_lines.append("func _logic_bricks_start_pause_watch() -> void:")
		code_lines.append("\tvar _was_paused := false")
		code_lines.append("\twhile is_inside_tree():")
		code_lines.append("\t\tawait get_tree().create_timer(0.01, true, false, true).timeout")
		code_lines.append("\t\tif not is_inside_tree():")
		code_lines.append("\t\t\treturn")
		code_lines.append("\t\tvar _is_paused := get_tree().paused")
		code_lines.append("\t\tif _is_paused:")
		code_lines.append("\t\t\tif _was_paused:")
		code_lines.append("\t\t\t\t_logic_bricks_pause_tick()")
		code_lines.append("\t\t\t_was_paused = true")
		code_lines.append("\t\telse:")
		code_lines.append("\t\t\t_was_paused = false")
		code_lines.append("")
		code_lines.append("func _logic_bricks_pause_tick() -> void:")
		for chain in chains:
			var _pause_chain_name := str(chain.get("name", ""))
			if _pause_chain_name not in pause_control_chain_names or not generated_chain_functions.has(_pause_chain_name):
				continue
			var _pause_delta := "get_physics_process_delta_time()" if _chain_needs_physics_process(chain) else "get_process_delta_time()"
			code_lines.append("\t_logic_brick_%s(%s)" % [_pause_chain_name, _pause_delta])
		code_lines.append("")

	# Emit assembled _input() if any sensors contributed handler bodies
	if input_handler_bodies.size() > 0:
		code_lines.append("func _input(event: InputEvent) -> void:")
		for _body_block in input_handler_bodies:
			for _body_line in _body_block.split("\n"):
				code_lines.append("	" + _body_line)
		code_lines.append("")

	# Emit single _on_message_received dispatcher that forwards to each chain's
	# scoped handler. This avoids duplicate-function errors when multiple Message
	# Sensors are present on the same node.
	if message_handler_calls.size() > 0:
		code_lines.append("func _on_message_received(signal_name: String, body: String, sender: Node) -> void:")
		for call_line in message_handler_calls:
			code_lines.append("\t" + call_line)
		code_lines.append("")

	# Append generated chain functions
	for chain in chains:
		if generated_chain_functions.has(chain["name"]):
			code_lines.append(generated_chain_functions[chain["name"]])
			code_lines.append("")

	# Append extra methods (e.g. message handlers)
	for method in extra_methods:
		code_lines.append(method)
		code_lines.append("")

	var generated := _cache_node_lookups("\n".join(code_lines))
	if generated.strip_edges().is_empty():
		return generated
	var header := GENERATED_BY_PREFIX + addon_version() + "\n"
	var snapshot := GraphSnapshot.line_for(node)
	if not snapshot.is_empty():
		header += snapshot + "\n"
	return header + generated


## First line of every generated block, so an addon update that was not
## followed by Apply Code can be detected (see panel_version_helper.gd).
const GENERATED_BY_PREFIX := "# Generated by Logic Bricks "
## generated_by_version() result for blocks made before versions were stamped.
const UNKNOWN_VERSION := "unknown"
static var _addon_version := ""


## The addon version from plugin.cfg. Bump it there with every release you
## give to students so outdated scripts can be found.
static func addon_version() -> String:
	if _addon_version.is_empty():
		var cfg := ConfigFile.new()
		if cfg.load("res://addons/logic_bricks/plugin.cfg") == OK:
			_addon_version = str(cfg.get_value("plugin", "version", "")).strip_edges()
		if _addon_version.is_empty():
			_addon_version = "dev"
	return _addon_version


## Version that generated the Logic Bricks block in source: "" when there is
## no block, UNKNOWN_VERSION when the block predates version stamps.
static func generated_by_version(source: String) -> String:
	var start := source.find(CODE_START_MARKER)
	var end := source.find(CODE_END_MARKER)
	if start < 0 or end < start:
		return ""
	var block := source.substr(start, end - start)
	var at := block.find(GENERATED_BY_PREFIX)
	if at < 0:
		return UNKNOWN_VERSION
	return block.substr(at + GENERATED_BY_PREFIX.length()).get_slice("\n", 0).strip_edges()


## Generated code finds nodes by name (find_child(), or the recursive
## _lb_find_node_in_current_scene() helper). Many bricks do that every time
## they run, which walks the whole scene tree every frame. This rewrites those
## calls to cached versions that remember the node found and only search again
## when it was freed, left the tree or was renamed. A failed search is retried
## every few frames, so nodes spawned later are still found.
const NODE_LOOKUP_RETRY_FRAMES := 10

## Rewrite calls only when they begin outside strings and comments. Literals
## stay available to the regex so quoted node names still match.
func _rewrite_lookup_calls(code: String, pattern: RegEx, replacement: String) -> String:
	var protected := PackedByteArray()
	protected.resize(code.length())
	var i := 0
	while i < code.length():
		var ch := code[i]
		if ch == "#":
			while i < code.length() and code[i] != "\n":
				protected[i] = 1
				i += 1
		elif ch == '"' or ch == "'":
			var delimiter := ch
			if code.substr(i, 3) == ch.repeat(3):
				delimiter = ch.repeat(3)
			var end := i + delimiter.length()
			while end < code.length():
				if code[end] == "\\":
					end = mini(end + 2, code.length())
				elif code.substr(end, delimiter.length()) == delimiter:
					end += delimiter.length()
					break
				else:
					end += 1
			while i < end:
				protected[i] = 1
				i += 1
		else:
			i += 1
	var matches := pattern.search_all(code)
	# Work backwards to preserve offsets into the original source.
	for index in range(matches.size() - 1, -1, -1):
		var found := matches[index]
		if protected[found.get_start()] == 0:
			var rewritten := pattern.sub(found.get_string(), replacement)
			code = code.substr(0, found.get_start()) + rewritten + code.substr(found.get_end())
	return code


func _cache_node_lookups(code: String) -> String:
	# root.find_child(name, true, false)  ->  _lb_find_child_cached(root, name)
	# The root is a simple chain like get_tree().current_scene or a variable;
	# the name is a string literal or an identifier.
	var arg := "(\"(?:[^\"\\\\]|\\\\.)*\"|[A-Za-z_][\\w.]*)"
	var with_root := RegEx.create_from_string("([A-Za-z_]\\w*(?:\\(\\))?(?:\\.[A-Za-z_]\\w*(?:\\(\\))?)*)\\.find_child\\(" + arg + ",\\s*true,\\s*false\\)")
	var on_self := RegEx.create_from_string("(?<![\\w.])find_child\\(" + arg + ",\\s*true,\\s*false\\)")
	var scene_helper := RegEx.create_from_string("(?<!func )(?<![\\w.])_lb_find_node_in_current_scene\\(")
	var rewritten := _rewrite_lookup_calls(code, with_root, "_lb_find_child_cached($1, $2)")
	rewritten = _rewrite_lookup_calls(rewritten, on_self, "_lb_find_child_cached(self, $1)")
	var scene_rewritten := _rewrite_lookup_calls(rewritten, scene_helper, "_lb_find_node_in_current_scene_cached(")
	var uses_scene_helper := scene_rewritten != rewritten
	rewritten = scene_rewritten
	if rewritten == code:
		return code

	var lines: Array[String] = [rewritten, ""]
	lines.append("# Node lookup cache: see LogicBrickManager._cache_node_lookups().")
	lines.append("var _lb_node_lookup_cache: Dictionary = {}")
	lines.append("")
	lines.append("func _lb_cached_node(key: String, target_name: String, root: Node) -> Variant:")
	lines.append("\t# Node: still valid. null: not found recently. false: search again.")
	lines.append("\tvar entry = _lb_node_lookup_cache.get(key)")
	lines.append("\tif entry == null:")
	lines.append("\t\treturn false")
	lines.append("\tif entry[0] == 0:")
	lines.append("\t\treturn null if Engine.get_process_frames() < entry[1] else false")
	lines.append("\tvar node := instance_from_id(entry[0]) as Node")
	lines.append("\tif node and node.is_inside_tree() and String(node.name).match(target_name) and (root == null or node == root or root.is_ancestor_of(node)):")
	lines.append("\t\treturn node")
	lines.append("\treturn false")
	lines.append("")
	lines.append("func _lb_store_cached_node(key: String, node: Node) -> Node:")
	lines.append("\t_lb_node_lookup_cache[key] = [node.get_instance_id() if node else 0, Engine.get_process_frames() + %d]" % NODE_LOOKUP_RETRY_FRAMES)
	lines.append("\treturn node")
	lines.append("")
	lines.append("func _lb_find_child_cached(root: Node, target_name: String) -> Node:")
	lines.append("\tif root == null or target_name.is_empty():")
	lines.append("\t\treturn null")
	lines.append("\tvar key := \"%d/%s\" % [root.get_instance_id(), target_name]")
	lines.append("\tvar cached = _lb_cached_node(key, target_name, root)")
	lines.append("\tif not (cached is bool):")
	lines.append("\t\treturn cached")
	lines.append("\treturn _lb_store_cached_node(key, root.find_child(target_name, true, false))")
	if uses_scene_helper:
		lines.append("")
		lines.append("func _lb_find_node_in_current_scene_cached(target_name: String) -> Node:")
		lines.append("\tvar key := \"scene/\" + target_name")
		lines.append("\tvar cached = _lb_cached_node(key, target_name, null)")
		lines.append("\tif not (cached is bool):")
		lines.append("\t\treturn cached")
		lines.append("\treturn _lb_store_cached_node(key, _lb_find_node_in_current_scene(target_name))")
	lines.append("")
	return "\n".join(lines)


## Generate code for a single chain
func _generate_chain_function(node: Node, chain: Dictionary, has_actuator_sensor: bool = false, debug_chain_index: int = -1) -> String:
	# Always sanitize at generation time — guards against hand-edited scene metadata
	# or chains saved by older versions of the addon before sanitization was enforced.
	var chain_name = _sanitize_chain_name(chain["name"])
	var sensors = chain.get("sensors", [])
	var controller_inputs = chain.get("controller_inputs", [])
	var controller_data = null
	var controllers = chain.get("controllers", [])
	if controllers.size() > 0:
		controller_data = controllers[0]
	else:
		# Legacy: try singular key — only present in data saved by very old versions of the addon.
		# Remove this fallback once the migration window has passed.
		controller_data = chain.get("controller", null)
	var actuators = chain.get("actuators", [])

	var lines: Array[String] = []
	lines.append("func _logic_brick_%s(_delta: float) -> void:" % chain_name)

	var is_script_controller = controller_data != null and controller_data.get("type", "") == "ScriptController"
	if (sensors.is_empty() and controller_inputs.is_empty()) or not controller_data:
		return ""  # Incomplete chain — skip entirely, generate nothing
	if not is_script_controller and actuators.is_empty():
		return ""  # Standard chains need at least one actuator

	# Collect @export var node names from this chain's bricks so we can
	# guard against freed instances (e.g. object pool recycling nodes).
	# Primitive types (float, int, bool, etc.) are skipped — is_instance_valid
	# always returns false for them, which would incorrectly kill the function.
	var _guard_primitive_types = ["float", "int", "bool", "String", "Vector2", "Vector3", "Color", "Basis", "Transform3D"]
	var _chain_export_vars: Array[String] = []
	for _sensor_entry in _collect_sensor_generation_entries_for_chain(chain):
		var _sd: Dictionary = _sensor_entry.get("data", {})
		var _sensor_namespace: String = _sensor_code_namespace(chain_name, str(_sensor_entry.get("fallback_var", "sensor_active")))
		var _sb = _instantiate_brick(_sd)
		if _sb:
			var _sg = _sb.generate_code_for_node(node, _sensor_namespace)
			for _mv in _sg.get("member_vars", []):
				if _mv.begins_with("@export var "):
					var _parts = _mv.replace("@export var ", "").split(":")
					var _vname = _parts[0].strip_edges()
					var _vtype = _parts[1].strip_edges().split(" ")[0] if _parts.size() > 1 else ""
					if _vtype in _guard_primitive_types:
						continue
					if _vname not in _chain_export_vars:
						_chain_export_vars.append(_vname)
	for _actuator_index in range(actuators.size()):
		var _ad = actuators[_actuator_index]
		var _ab = _instantiate_brick(_ad)
		if _ab:
			# Must match the namespace used when member vars and actuator code are generated.
			# Otherwise guards can reference an export var that was never declared,
			# e.g. _screen_shake_<chain> instead of _screen_shake_<chain>_0.
			var _actuator_code_name := "%s_%d" % [chain_name, _actuator_index]
			var _ag = _ab.generate_code_for_node(node, _actuator_code_name)
			for _mv in _ag.get("member_vars", []):
				if _mv.begins_with("@export var "):
					var _parts = _mv.replace("@export var ", "").split(":")
					var _vname = _parts[0].strip_edges()
					var _vtype = _parts[1].strip_edges().split(" ")[0] if _parts.size() > 1 else ""
					if _vtype in _guard_primitive_types:
						continue
					if _vname not in _chain_export_vars:
						_chain_export_vars.append(_vname)
	if _chain_export_vars.size() > 0:
		lines.append("\t# Guard: skip if any assigned node has been freed (e.g. by object pool)")
		for _ev in _chain_export_vars:
			lines.append("\tif %s != null and not is_instance_valid(%s): return" % [_ev, _ev])

	var state_id := ""
	var all_states := false
	if controller_data:
		state_id = str(controller_data.get("properties", {}).get("state_id", "")).strip_edges()
		all_states = bool(controller_data.get("properties", {}).get("all_states", false))
	var state_condition := "true"
	if not state_id.is_empty() and not all_states:
		state_condition = "_logic_brick_chain_state_matches(%s, false)" % _gdscript_string_literal(state_id)

	# Gate state-specific chains before evaluating sensors. This prevents inactive-state
	# sensors such as Delay from counting down before their state becomes active.
	if state_condition != "true":
		lines.append("\tif not " + state_condition + ":")
		lines.append("\t\treturn")
		lines.append("\t")

	# Generate sensor code for ALL direct and nested controller inputs.
	lines.append("\t# Sensor and controller input evaluation")
	var sensor_vars = []
	var sensor_index = 0

	for sensor_data in sensors:
		var sensor_var = _emit_sensor_eval(lines, node, chain_name, sensor_data, "sensor_%d_active" % sensor_index)
		if not sensor_var.is_empty():
			sensor_vars.append(sensor_var)
			sensor_index += 1

	var nested_index = 0
	for nested_controller in controller_inputs:
		var nested_var = _emit_nested_controller_eval(lines, node, chain_name, nested_controller, "controller_%d" % nested_index)
		if not nested_var.is_empty():
			sensor_vars.append(nested_var)
		nested_index += 1

	# Generate controller code
	lines.append("\t")
	lines.append("\t# Controller logic")
	if controller_data:
		lines.append("\t" + _brick_sync_begin(controller_data, "controller"))
		var controller_brick = _instantiate_brick(controller_data)
		if controller_brick:
			# ── Script Controller ───────────────────────────────────────────────
			if controller_data["type"] == "ScriptController":
				var condition = controller_brick.get_condition(sensor_vars) if sensor_vars.size() > 0 else "true"
				lines.append("\tvar controller_active = " + condition)
				if debug_chain_index >= 0:
					lines.append("\tif _logic_bricks_debug_enabled and controller_active:")
					lines.append("\t\t_logic_bricks_debug_chain_states[%d] = 1" % debug_chain_index)
				lines.append("\t" + _brick_sync_end(controller_data))
				lines.append("\t")
				lines.append("\t# Script Controller — custom code")
				lines.append("\tif controller_active:")
				lines.append(controller_brick.get_script_body(chain_name))
				if has_actuator_sensor:
					lines.append("\t")
					lines.append("\t# Actuator Sensor flags")
					for actuator_data in actuators:
						var inst_name = actuator_data.get("instance_name", "")
						if not inst_name.is_empty():
							lines.append("\tif controller_active:")
							lines.append("\t\t_actuator_active_flags[\"%s\"] = true" % str(inst_name).c_escape())
							lines.append("\telse:")
							lines.append("\t\t_actuator_active_flags[\"%s\"] = false" % str(inst_name).c_escape())
				return "\n".join(lines)

			# ── Standard Controller ─────────────────────────────────────────────
			# Determine logic mode from properties, fall back to class name for legacy bricks
			var logic_mode = "and"
			if controller_brick.properties.has("logic_mode"):
				logic_mode = controller_brick.properties.get("logic_mode", "and")
				if typeof(logic_mode) == TYPE_STRING:
					logic_mode = logic_mode.to_lower()
			elif controller_data["type"] == "ANDController":
				logic_mode = "and"

			if sensor_vars.size() > 0:
				var condition = _controller_condition_from_vars(logic_mode, sensor_vars)
				lines.append("\tvar controller_active = " + condition)
			else:
				lines.append("\tvar controller_active = true")
	else:
		# No controller - default to AND logic. State gating already happened above.
		if sensor_vars.size() > 0:
			lines.append("\tvar controller_active = " + " and ".join(sensor_vars))
		else:
			lines.append("\tvar controller_active = true")

	if debug_chain_index >= 0:
		lines.append("\tif _logic_bricks_debug_enabled and controller_active:")
		lines.append("\t\t_logic_bricks_debug_chain_states[%d] = 1" % debug_chain_index)

	if controller_data:
		lines.append("\t" + _brick_sync_end(controller_data))

	# Generate actuator code for ALL actuators
	lines.append("\t")
	lines.append("\t# Actuator execution")
	lines.append("\tif controller_active:")

	if actuators.is_empty():
		return ""  # No actuators — incomplete chain
	else:
		var actuator_lines_written = 0
		var inactive_code_blocks: Array[String] = []
		for actuator_index in range(actuators.size()):
			var actuator_data = actuators[actuator_index]
			var actuator_brick = _instantiate_brick(actuator_data)
			if actuator_brick:
				var actuator_code_name := "%s_%d" % [chain_name, actuator_index]
				var generated = actuator_brick.generate_code_for_node(node, actuator_code_name)
				if generated.has("actuator_code"):
					lines.append("\t\t" + _brick_sync_begin(actuator_data, "actuator"))
					var actuator_code = str(generated["actuator_code"])
					actuator_code = _uniquify_generated_local_vars(actuator_code, actuator_code_name)
					var code_lines_array = actuator_code.split("\n")
					for code_line in code_lines_array:
						if code_line.strip_edges() != "":
							lines.append("\t\t" + code_line)
							actuator_lines_written += 1

					var debug_code = actuator_brick.get_debug_code()
					if not debug_code.is_empty():
						lines.append("\t\t" + debug_code)
						actuator_lines_written += 1
					lines.append("\t\t" + _brick_sync_end(actuator_data))

				# inactive_code: code to emit in the else branch (when controller is NOT active).
				# Used by actuators that need to reset state every frame regardless of activation
				# (e.g. AnimationTree conditions, which are consumed by the state machine and must
				# be driven continuously to avoid one-shot race conditions).
				if generated.has("inactive_code") and not str(generated["inactive_code"]).is_empty():
					var inactive = str(generated["inactive_code"])
					inactive = _uniquify_generated_local_vars(inactive, actuator_code_name + "_inactive")
					inactive_code_blocks.append(inactive)

		# Emit one shared inactive branch after all active actuator code. This keeps
		# additional actuators in the active branch when one actuator needs cleanup.
		if not inactive_code_blocks.is_empty():
			lines.append("\telse:")
			for inactive in inactive_code_blocks:
				for il in inactive.split("\n"):
					if il.strip_edges() != "":
						lines.append("\t\t" + il)

		# If all actuators produced empty code, treat as incomplete — skip entirely
		if actuator_lines_written == 0:
			return ""

	# Write active flags for any named actuators so the Actuator Sensor can read them.
	# Flags are written both when active (true) and when not (false) so the sensor
	# always has an up-to-date value regardless of which branch ran.
	if has_actuator_sensor:
		lines.append("\t")
		lines.append("\t# Actuator Sensor flags")
		for actuator_data in actuators:
			var inst_name = actuator_data.get("instance_name", "")
			if not inst_name.is_empty():
				lines.append("\tif controller_active:")
				lines.append("\t\t_actuator_active_flags[\"%s\"] = true" % str(inst_name).c_escape())
				lines.append("\telse:")
				lines.append("\t\t_actuator_active_flags[\"%s\"] = false" % str(inst_name).c_escape())

	return "\n".join(lines)


func _emit_sensor_eval(lines: Array[String], node: Node, chain_name: String, sensor_data: Dictionary, fallback_var: String) -> String:
	var sensor_brick = _instantiate_brick(sensor_data)
	if not sensor_brick:
		return ""
	var sensor_namespace: String = _sensor_code_namespace(chain_name, fallback_var)
	var generated = sensor_brick.generate_code_for_node(node, sensor_namespace)
	if not generated.has("sensor_code"):
		return ""

	var instance_name = sensor_data.get("instance_name", "")
	var sensor_var = fallback_var
	if not instance_name.is_empty():
		# Include the fallback namespace so duplicated/renamed sensors with the same
		# display instance name cannot redeclare the same generated variable.
		sensor_var = _sanitize_chain_name("%s_%s" % [instance_name, fallback_var])

	var sensor_code = str(generated["sensor_code"])
	# First replace the canonical sensor result variable with the public
	# variable name that controller logic will read. Then uniquify only
	# helper locals. Doing this in the opposite order creates unused locals
	# like `sensor_active_sensor_0_active` and leaves `sensor_0_active` false.
	var _rename_rx = RegEx.new()
	_rename_rx.compile("\\bsensor_active\\b")
	sensor_code = _rename_rx.sub(sensor_code, sensor_var, true)
	sensor_code = _uniquify_generated_local_vars(sensor_code, sensor_var, [sensor_var])

	# Source-map marker: preserves the identity and editable property snapshot for
	# code -> graph synchronization without changing the generated behavior.
	lines.append("\t" + _brick_sync_begin(sensor_data, "sensor"))
	# Predeclare the result so controller logic can read it. Helper locals have already
	# been uniquified above, so an extra `if true` scope is unnecessary.
	lines.append("\tvar %s = false" % sensor_var)
	var first_decl_rx = RegEx.new()
	first_decl_rx.compile("^([\\t ]*)var\\s+" + sensor_var + "(?:\\s*:[^=]+)?\\s*(?::=|=)\\s*(.*)$")
	for code_line in sensor_code.split("\n"):
		if code_line.strip_edges() != "":
			# The result variable is predeclared outside the isolation block so
			# controller code can read it. Convert the brick's first declaration
			# into an assignment to avoid shadowing and UNUSED_VARIABLE errors.
			var isolated_line = first_decl_rx.sub(code_line, "$1" + sensor_var + " = $2", false)
			lines.append("\t" + isolated_line)

	var debug_code = sensor_brick.get_debug_code()
	if not debug_code.is_empty():
		lines.append("\t" + debug_code)
	lines.append("\t" + _brick_sync_end(sensor_data))
	return sensor_var


func _emit_nested_controller_eval(lines: Array[String], node: Node, chain_name: String, controller_tree: Dictionary, prefix: String) -> String:
	if bool(controller_tree.get("cycle", false)):
		var cycle_var = "%s_cycle_active" % prefix
		lines.append("\tvar %s = false  # Controller chain cycle ignored" % cycle_var)
		return cycle_var

	var input_vars: Array[String] = []
	var sensor_index := 0
	for sensor_data in controller_tree.get("sensors", []):
		var sensor_var = _emit_sensor_eval(lines, node, chain_name, sensor_data, "%s_sensor_%d_active" % [prefix, sensor_index])
		if not sensor_var.is_empty():
			input_vars.append(sensor_var)
		sensor_index += 1

	var nested_index := 0
	for nested_tree in controller_tree.get("controller_inputs", []):
		var nested_var = _emit_nested_controller_eval(lines, node, chain_name, nested_tree, "%s_controller_%d" % [prefix, nested_index])
		if not nested_var.is_empty():
			input_vars.append(nested_var)
		nested_index += 1

	var controller_data = controller_tree.get("controller", null)
	var out_var = "%s_active" % prefix
	if controller_data == null:
		lines.append("\tvar %s = false" % out_var)
		return out_var

	lines.append("\t" + _brick_sync_begin(controller_data, "controller"))
	var controller_brick = _instantiate_brick(controller_data)
	if controller_brick and controller_data.get("type", "") == "ScriptController":
		lines.append("\tvar %s = %s" % [out_var, controller_brick.get_condition(input_vars) if input_vars.size() > 0 else "true"])
		lines.append("\t" + _brick_sync_end(controller_data))
		return out_var

	var logic_mode = "and"
	if controller_brick and controller_brick.properties.has("logic_mode"):
		logic_mode = str(controller_brick.properties.get("logic_mode", "and")).to_lower()
	var condition = _controller_condition_from_vars(logic_mode, input_vars) if input_vars.size() > 0 else "true"

	var state_id = str(controller_data.get("properties", {}).get("state_id", "")).strip_edges()
	var all_states = bool(controller_data.get("properties", {}).get("all_states", false))
	if not state_id.is_empty() or all_states:
		condition = "_logic_brick_chain_state_matches(%s, %s) and (%s)" % [_gdscript_string_literal(state_id), "true" if all_states else "false", condition]

	lines.append("\tvar %s = %s" % [out_var, condition])
	lines.append("\t" + _brick_sync_end(controller_data))
	return out_var


func _controller_condition_from_vars(logic_mode: String, input_vars: Array) -> String:
	if input_vars.is_empty():
		return "true"
	match logic_mode:
		"or":
			return " or ".join(input_vars)
		"nand":
			return "not (" + " and ".join(input_vars) + ")"
		"nor":
			return "not (" + " or ".join(input_vars) + ")"
		"xor":
			var int_vars: Array[String] = []
			for sv in input_vars:
				int_vars.append("int(%s)" % sv)
			return "(" + " + ".join(int_vars) + ") == 1"
		_:
			return " and ".join(input_vars)


func _brick_sync_begin(brick_data: Dictionary, role: String) -> String:
	var payload: Dictionary = brick_data.duplicate(true)
	payload["brick_role"] = role
	var raw: PackedByteArray = var_to_bytes(payload)
	return BRICK_BEGIN_PREFIX + Marshalls.raw_to_base64(raw)


func _brick_sync_end(brick_data: Dictionary) -> String:
	return BRICK_END_PREFIX + str(brick_data.get("graph_node_id", ""))


func _sensor_code_namespace(chain_name: String, fallback_var: String) -> String:
	var code_namespace := "%s_%s" % [chain_name, fallback_var]
	if code_namespace.ends_with("_active"):
		code_namespace = code_namespace.substr(0, code_namespace.length() - len("_active"))
	return _sanitize_chain_name(code_namespace)


func _uniquify_generated_local_vars(code: String, suffix: String, keep_names: Array[String] = []) -> String:
	# Some brick generators emit generic local names such as _node_name_<chain>.
	# Duplicated bricks can then create the same local variable more than once in
	# a generated function. GDScript does not allow redeclaring a local name in
	# the same function scope, even inside nested if blocks, so rewrite generated
	# local vars with a per-brick suffix before inserting the code.
	var safe_suffix := _sanitize_chain_name(suffix)
	if safe_suffix.is_empty():
		return code

	var declarations := RegEx.new()
	declarations.compile("\\bvar\\s+([A-Za-z_][A-Za-z0-9_]*)")

	var replacements: Dictionary = {}
	for result in declarations.search_all(code):
		var local_name := result.get_string(1)
		if local_name in keep_names:
			continue
		if local_name.ends_with("_" + safe_suffix):
			continue
		replacements[local_name] = "%s_%s" % [local_name, safe_suffix]

	var rewritten := code
	for local_name in replacements.keys():
		var rx := RegEx.new()
		rx.compile("\\b" + String(local_name) + "\\b")
		rewritten = rx.sub(rewritten, String(replacements[local_name]), true)
	return rewritten


func _collect_sensor_generation_entries_for_chain(chain: Dictionary) -> Array:
	var entries: Array = []
	var sensors: Array = chain.get("sensors", [])
	for sensor_index in range(sensors.size()):
		entries.append({
			"data": sensors[sensor_index],
			"fallback_var": "sensor_%d_active" % sensor_index
		})
	_collect_sensor_generation_entries_from_controller_inputs(chain.get("controller_inputs", []), entries, "controller")
	return entries


func _collect_sensor_generation_entries_from_controller_inputs(controller_inputs: Array, entries: Array, prefix: String) -> void:
	for controller_index in range(controller_inputs.size()):
		var controller_tree: Dictionary = controller_inputs[controller_index]
		var controller_prefix := "%s_%d" % [prefix, controller_index]
		var sensors: Array = controller_tree.get("sensors", [])
		for sensor_index in range(sensors.size()):
			entries.append({
				"data": sensors[sensor_index],
				"fallback_var": "%s_sensor_%d_active" % [controller_prefix, sensor_index]
			})
		_collect_sensor_generation_entries_from_controller_inputs(controller_tree.get("controller_inputs", []), entries, "%s_controller" % controller_prefix)


func _collect_all_sensors_for_chain(chain: Dictionary) -> Array:
	var sensors: Array = []
	for sensor_data in chain.get("sensors", []):
		sensors.append(sensor_data)
	_collect_sensors_from_controller_inputs(chain.get("controller_inputs", []), sensors)
	return sensors


func _collect_sensors_from_controller_inputs(controller_inputs: Array, sensors: Array) -> void:
	for controller_tree in controller_inputs:
		for sensor_data in controller_tree.get("sensors", []):
			sensors.append(sensor_data)
		_collect_sensors_from_controller_inputs(controller_tree.get("controller_inputs", []), sensors)

func _chains_need_state_runtime(chains: Array, states_data: Array) -> bool:
	if not states_data.is_empty():
		return true
	for chain in chains:
		for actuator_data in chain.get("actuators", []):
			if actuator_data.get("type", "") == "StateActuator":
				return true
		for controller_data in chain.get("controllers", []):
			if _controller_uses_named_state(controller_data):
				return true
		var legacy_controller = chain.get("controller", null)
		if legacy_controller is Dictionary and _controller_uses_named_state(legacy_controller):
			return true
		if _controller_inputs_use_named_state(chain.get("controller_inputs", [])):
			return true
	return false


func _controller_uses_named_state(controller_data: Dictionary) -> bool:
	var props: Dictionary = controller_data.get("properties", {})
	return not str(props.get("state_id", "")).strip_edges().is_empty() and not bool(props.get("all_states", false))


func _controller_inputs_use_named_state(controller_inputs: Array) -> bool:
	for controller_tree in controller_inputs:
		var controller_data = controller_tree.get("controller", null)
		if controller_data is Dictionary and _controller_uses_named_state(controller_data):
			return true
		if _controller_inputs_use_named_state(controller_tree.get("controller_inputs", [])):
			return true
	return false


func _gdscript_string_literal(value: String) -> String:
	return '"%s"' % value.c_escape()

func _append_member_var_items(target: Array[String], items: Array) -> void:
	# member_vars can contain both plain top-level declarations and entire helper
	# functions flattened into line arrays. Deduplicating them line-by-line corrupts
	# function bodies when two helpers share common lines. Keep function blocks intact
	# and dedupe whole helper functions by signature so repeated bricks can safely
	# share helpers such as _find_anim_player() and _find_sprite_node().
	var existing_function_signatures: Dictionary = {}
	for target_line in target:
		var target_text := str(target_line)
		if target_text.begins_with("func ") or target_text.begins_with("static func "):
			existing_function_signatures[_function_signature_key(target_text)] = true

	var i := 0
	while i < items.size():
		var line := str(items[i])
		if line.begins_with("func ") or line.begins_with("static func "):
			var block: Array[String] = [line]
			i += 1
			while i < items.size():
				var next_line := str(items[i])
				if next_line.begins_with("	") or next_line.is_empty():
					block.append(next_line)
					i += 1
					continue
				break
			var signature_key := _function_signature_key(line)
			if not existing_function_signatures.has(signature_key):
				for block_line in block:
					target.append(block_line)
				existing_function_signatures[signature_key] = true
			continue
		if line not in target:
			target.append(line)
		i += 1


func _function_signature_key(signature_line: String) -> String:
	var text := signature_line.strip_edges()
	var paren_index := text.find("(")
	if paren_index == -1:
		return text
	return text.substr(0, paren_index)

## Check if a chain needs physics process (has force/torque actuators)
func _chain_has_pause_control(chain: Dictionary) -> bool:
	for actuator_data in chain.get("actuators", []):
		if str(actuator_data.get("type", "")) != "GameActuator":
			continue
		var action := str(actuator_data.get("properties", {}).get("action", "exit")).to_lower().replace(" ", "_")
		if action in ["pause", "unpause", "toggle_pause"]:
			return true
	return false


func _chain_needs_physics_process(chain: Dictionary) -> bool:
	# Physics-dependent sensors must also run in _physics_process.
	# Example: PhysicsSensor uses is_on_floor()/is_on_wall()/is_on_ceiling(),
	# which are only reliable after physics movement has been resolved.
	var sensors = _collect_all_sensors_for_chain(chain)
	for sensor_data in sensors:
		var sensor_type = sensor_data.get("type", "")
		if sensor_type in ["PhysicsSensor", "Physics2DSensor"]:
			return true

	var actuators = chain.get("actuators", [])
	for actuator_data in actuators:
		var brick_type = actuator_data.get("type", "")
		# Mouse Look rotates Node3D transforms. Run it in the same physics tick
		# as CharacterBody movement to avoid interpolation/camera jitter.
		if brick_type == "MouseActuator":
			var mouse_mode = str(actuator_data.get("properties", {}).get("mode", "cursor_visibility")).to_lower().replace(" ", "_")
			if mouse_mode == "mouse_look":
				return true
		if brick_type in ["SurfaceAttachmentActuator", "ForceActuator", "TorqueActuator", "ImpulseActuator", "LinearVelocityActuator", "SoftBodyPointForceActuator", "SoftBodyPointImpulseActuator", "CharacterActuator", "GravityActuator", "JumpActuator", "WaypointPathActuator", "WaypointPath2DActuator", "Force2DActuator", "Impulse2DActuator", "LinearVelocity2DActuator", "Character2DActuator", "Gravity2DActuator", "Jump2DActuator", "SaveLoad2DActuator", "SmoothFollowCameraActuator"]:
			return true
		if brick_type == "MotionActuator" or brick_type == "Motion2DActuator":
			var props = actuator_data.get("properties", {})
			var motion_type = str(props.get("motion_type", "location")).to_lower().replace(" ", "_")
			var movement_method = str(props.get("movement_method", "character_velocity")).to_lower().replace(" ", "_")
			var call_move_and_slide = props.get("call_move_and_slide", false) == true
			if motion_type == "location" or movement_method == "character_velocity" or call_move_and_slide:
				return true
		if brick_type == "PositionActuator" or brick_type == "Position2DActuator":
			var props = actuator_data.get("properties", {})
			var movement_method = str(props.get("movement_method", "character_velocity")).to_lower().replace(" ", "_")
			if movement_method == "character_velocity":
				return true
	return false


func _chain_is_state_transition_only(chain: Dictionary) -> bool:
	var actuators = chain.get("actuators", [])
	if actuators.is_empty():
		return false
	for actuator_data in actuators:
		if actuator_data.get("type", "") != "StateActuator":
			return false
	return true

## Returns true if this chain mixes physics actuators with timing-sensitive
## non-physics actuators. Physics-compatible actuators such as LookAtMovement
## are allowed in the same chain, because they should run after the character
## velocity has been resolved in _physics_process.
func _chain_has_mixed_actuators(chain: Dictionary) -> bool:
	var actuators = chain.get("actuators", [])
	var has_physics = false
	var has_timing_sensitive_non_physics = false
	for actuator_data in actuators:
		var brick_type = actuator_data.get("type", "")
		if _logic_brick_actuator_requires_physics(actuator_data):
			has_physics = true
		elif _logic_brick_actuator_is_timing_sensitive_non_physics(brick_type):
			has_timing_sensitive_non_physics = true
	return has_physics and has_timing_sensitive_non_physics


func _logic_brick_actuator_requires_physics(actuator_data: Dictionary) -> bool:
	var brick_type = actuator_data.get("type", "")
	if brick_type == "MouseActuator":
		return str(actuator_data.get("properties", {}).get("mode", "cursor_visibility")).to_lower().replace(" ", "_") == "mouse_look"
	if brick_type in ["SurfaceAttachmentActuator", "ForceActuator", "TorqueActuator", "ImpulseActuator", "LinearVelocityActuator", "CharacterActuator", "GravityActuator", "JumpActuator", "WaypointPathActuator", "WaypointPath2DActuator", "Force2DActuator", "Impulse2DActuator", "LinearVelocity2DActuator", "Character2DActuator", "Gravity2DActuator", "Jump2DActuator", "SaveLoad2DActuator"]:
		return true
	if brick_type == "MotionActuator" or brick_type == "Motion2DActuator":
		var props = actuator_data.get("properties", {})
		var motion_type = str(props.get("motion_type", "location")).to_lower().replace(" ", "_")
		var movement_method = str(props.get("movement_method", "character_velocity")).to_lower().replace(" ", "_")
		var call_move_and_slide = props.get("call_move_and_slide", false) == true
		return motion_type == "location" or movement_method == "character_velocity" or call_move_and_slide
	if brick_type == "PositionActuator" or brick_type == "Position2DActuator":
		var props = actuator_data.get("properties", {})
		var movement_method = str(props.get("movement_method", "character_velocity")).to_lower().replace(" ", "_")
		return movement_method == "character_velocity"
	return false


func _logic_brick_actuator_is_timing_sensitive_non_physics(brick_type: String) -> bool:
	# These are actuators that are actually timing-sensitive if forced into
	# _physics_process by a movement chain. Avoid warning for common frame-safe
	# pairings like AnimationActuator, SpriteAnimation2D, or SmoothFollowCamera2D,
	# because those are expected to be used beside character movement and the
	# warning becomes noisy rather than helpful.
	return brick_type in [
		"AnimationTreeActuator",
		"Audio2DActuator",
		"CameraZoomActuator",
		"EnvironmentActuator",
		"GameActuator",
		"HitStopActuator",
		"MusicActuator",
		"ObjectFlashActuator",
		"ObjectShakeActuator",
		"ProgressBarActuator",
		"ScreenShakeActuator",
		"SpriteFramesActuator",
		"TweenAnimation2DActuator",
		"TextActuator",
		"TimerActuator",
		"UIActuator"
	]


## Instantiate a brick from serialized data
func _instantiate_brick(brick_data: Dictionary) -> LogicBrick:
	var brick_type = brick_data.get("type", "")
	var brick_script_path = _get_brick_script_path(brick_type)

	if brick_script_path.is_empty():
		push_error("Logic Bricks: Unknown brick type: " + brick_type)
		return null

	var brick_script = load(brick_script_path)
	if not brick_script:
		push_error("Logic Bricks: Could not load brick script: " + brick_script_path)
		return null

	var brick = brick_script.new()
	brick.deserialize(brick_data)
	brick.wrap_numeric_expressions()
	return brick


## Get the script path for a brick type.
## Brick scripts are discovered automatically by BrickRegistry.
func _get_brick_script_path(brick_type: String) -> String:
	return BrickRegistry.get_script_path(brick_type)


## Replace the code between markers in the existing script
func _replace_generated_code(existing_code: String, generated_code: String, node: Node) -> String:
	var start_pos = existing_code.find(CODE_START_MARKER)
	var end_pos = existing_code.find(CODE_END_MARKER)

	if start_pos == -1 or end_pos == -1:
		# Markers don't exist, add them first, then resolve any user callback collisions.
		var marked_code: String = _create_script_with_markers(existing_code, generated_code, node)
		return _bridge_existing_process_callbacks(marked_code)

	# Calculate positions correctly
	# We want to keep everything BEFORE the start marker
	var before = existing_code.substr(0, start_pos)

	# We want to keep everything AFTER the end marker (including the marker itself on its own line)
	# end_pos points to the start of CODE_END_MARKER, so we add its length to skip past it
	var after_marker_pos = end_pos + CODE_END_MARKER.length()
	var after = existing_code.substr(after_marker_pos)

	# Build the new code with proper formatting
	# Keep the start marker on its own line, add generated code, then the end marker
	var new_code = before + CODE_START_MARKER + "\n"

	# Add the generated code (it already has proper indentation)
	if not generated_code.is_empty():
		new_code += generated_code
		if not generated_code.ends_with("\n"):
			new_code += "\n"

	# Add the end marker
	new_code += CODE_END_MARKER + after

	return _bridge_existing_process_callbacks(new_code)


## If the user's script already owns _process() or _physics_process(), keep that
## callback and route Logic Bricks through a generated helper instead of emitting
## a second engine callback with the same name. The bridge line lives outside
## the generated region, so it is removed/re-added on each Apply Code.
func _bridge_existing_process_callbacks(source_code: String) -> String:
	var start_pos: int = source_code.find(CODE_START_MARKER)
	var end_pos: int = source_code.find(CODE_END_MARKER)
	if start_pos == -1 or end_pos == -1 or end_pos < start_pos:
		return source_code

	var generated_start: int = start_pos + CODE_START_MARKER.length()
	var generated_code: String = source_code.substr(generated_start, end_pos - generated_start)
	var user_before: String = _strip_logic_bricks_callback_bridges(source_code.substr(0, start_pos))
	var user_after: String = _strip_logic_bricks_callback_bridges(source_code.substr(end_pos + CODE_END_MARKER.length()))
	var user_code: String = user_before + user_after

	var bridges: Array[Dictionary] = [
		{
			"callback": "_physics_process",
			"generated_decl": "func _physics_process(delta: float) -> void:",
			"helper_decl": "func _logic_bricks_physics_process(delta: float) -> void:",
			"bridge_line": "\t_logic_bricks_physics_process(get_physics_process_delta_time())  # Logic Bricks callback bridge",
		},
		{
			"callback": "_process",
			"generated_decl": "func _process(delta: float) -> void:",
			"helper_decl": "func _logic_bricks_process(delta: float) -> void:",
			"bridge_line": "\t_logic_bricks_process(get_process_delta_time())  # Logic Bricks callback bridge",
		},
	]

	for bridge in bridges:
		var callback_name: String = bridge["callback"]
		var generated_decl: String = bridge["generated_decl"]
		if not generated_code.contains(generated_decl) or not _has_top_level_function(user_code, callback_name):
			continue
		generated_code = generated_code.replace(generated_decl, bridge["helper_decl"])
		if _has_top_level_function(user_before, callback_name):
			user_before = _inject_bridge_into_top_level_function(user_before, callback_name, bridge["bridge_line"])
		else:
			user_after = _inject_bridge_into_top_level_function(user_after, callback_name, bridge["bridge_line"])

	return user_before + CODE_START_MARKER + generated_code + CODE_END_MARKER + user_after


func _strip_logic_bricks_callback_bridges(source_code: String) -> String:
	var kept: PackedStringArray = []
	for line in source_code.split("\n"):
		if line.contains("# Logic Bricks callback bridge"):
			continue
		kept.append(line)
	return "\n".join(kept)


func _has_top_level_function(source_code: String, function_name: String) -> bool:
	var prefix: String = "func %s(" % function_name
	for line in source_code.split("\n"):
		if line.begins_with(prefix):
			return true
	return false


func _inject_bridge_into_top_level_function(source_code: String, function_name: String, bridge_line: String) -> String:
	var lines: PackedStringArray = source_code.split("\n")
	var prefix: String = "func %s(" % function_name
	for index in range(lines.size()):
		if lines[index].begins_with(prefix):
			lines.insert(index + 1, bridge_line)
			break
	return "\n".join(lines)


## Scan a script's header: leading blank lines, comments, class annotations
## (@tool, @icon(...), @static_unload), class_name and extends.
## Returns {"has_extends": bool, "header_end": int}. header_end is the line
## index just after the last annotation/class_name line, which is where a
## missing extends line belongs. Scanning stops at the first other statement,
## so text inside strings or function bodies is never mistaken for a header.
## Accepts the one-line forms Godot 4 allows: "@tool extends X" and
## "class_name Foo extends X".
static func _scan_script_header(lines: PackedStringArray) -> Dictionary:
	var extends_rx := RegEx.new()
	extends_rx.compile("^(?:@\\w+(?:\\([^)]*\\))?\\s+)*(?:class_name\\s+\\w+\\s+)?extends\\b")
	var header_end := 0
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if extends_rx.search(line):
			return {"has_extends": true, "header_end": i + 1}
		if line.begins_with("@tool") or line.begins_with("@icon") \
				or line.begins_with("@static_unload") or line.begins_with("class_name"):
			header_end = i + 1
			continue
		break
	return {"has_extends": false, "header_end": header_end}


## Insert "extends <node_class>" after any class annotations/class_name,
## keeping the script's line endings.
static func _insert_extends_line(code: String, node_class: String) -> String:
	var lines := code.split("\n")
	var header_end: int = _scan_script_header(lines)["header_end"]
	var cr := "\r" if code.contains("\r\n") else ""
	var new_lines: PackedStringArray = ["extends %s%s" % [node_class, cr]]
	# Keep a blank line between extends and following code, but let a
	# "##" class doc comment sit directly under extends.
	if header_end < lines.size():
		var next_line := lines[header_end].strip_edges()
		if not next_line.is_empty() and not next_line.begins_with("##"):
			new_lines.append(cr)
	for j in range(new_lines.size() - 1, -1, -1):
		lines.insert(header_end, new_lines[j])
	return "\n".join(lines)


## Line index where the generated block should go in a script that has no
## markers yet: before the first top-level function, moved up over the
## annotation-only lines and "##" doc comments directly above it.
## Returns lines.size() when the script has no top-level function.
## Indented functions (inner classes) and text inside multi-line strings
## are ignored.
static func _find_generated_block_insert_line(lines: PackedStringArray) -> int:
	var func_rx := RegEx.new()
	# Optional same-line annotations, optional "static", then "func".
	func_rx.compile("^(?:@\\w+(?:" + ANNOTATION_ARGS_RX + ")?\\s+)*(?:static\\s+)?func\\b")
	var annotation_only_rx := RegEx.new()
	# One or more annotations and nothing else (trailing comment allowed).
	annotation_only_rx.compile("^(?:@\\w+(?:" + ANNOTATION_ARGS_RX + ")?\\s*)+(?:#.*)?$")

	var in_multiline_string := false
	for i in lines.size():
		var raw := lines[i]
		var stripped := raw.strip_edges()
		var quote_count := stripped.count("\"\"\"") + stripped.count("'''")
		if in_multiline_string:
			if quote_count % 2 == 1:
				in_multiline_string = false
			continue
		if quote_count % 2 == 1:
			in_multiline_string = true
			continue
		if raw.begins_with(" ") or raw.begins_with("\t"):
			continue
		if not func_rx.search(stripped):
			continue

		# Found the first top-level function. Back up over what belongs to it.
		return _function_attachment_start(lines, i, annotation_only_rx)
	return lines.size()


## First line of the annotations, "##" doc comments and directly attached
## comments that belong to the function at func_line. Annotations apply to the next member even across
## blank lines and ordinary comments, so those are crossed too, but only when
## an annotation is found above them. Annotations whose arguments span
## several lines are treated as one annotation.
static func _function_attachment_start(lines: PackedStringArray, func_line: int, annotation_only_rx: RegEx) -> int:
	var start := func_line
	var k := func_line - 1
	while k >= 0:
		var above := lines[k].strip_edges()
		if above.begins_with("##") or annotation_only_rx.search(above):
			start = k
			k -= 1
			continue
		if above.begins_with("#") and k == start - 1:
			# A comment sitting directly on top of the group describes it.
			start = k
			k -= 1
			continue
		if above.is_empty() or above.begins_with("#"):
			# Maybe crossed, if an annotation turns up further up.
			k -= 1
			continue
		var multi_start := _multiline_annotation_start(lines, k, annotation_only_rx)
		if multi_start >= 0:
			start = multi_start
			k = multi_start - 1
			continue
		break
	return start


## If line end_line closes an annotation whose arguments started on an
## earlier line (for example @rpc("any_peer",\n\t"call_local")), returns the
## line holding the "@". Returns -1 otherwise.
static func _multiline_annotation_start(lines: PackedStringArray, end_line: int, annotation_only_rx: RegEx) -> int:
	if not lines[end_line].strip_edges().ends_with(")"):
		return -1
	var joined := lines[end_line].strip_edges()
	for k in range(end_line - 1, maxi(end_line - 20, -1), -1):
		var text := lines[k].strip_edges()
		joined = text + " " + joined
		if text.begins_with("@"):
			return k if annotation_only_rx.search(joined) else -1
		if text.is_empty():
			return -1
	return -1


## Create a new script with markers
func _create_script_with_markers(existing_code: String, generated_code: String, node: Node) -> String:
	var node_class = node.get_class()

	# If there's existing code without markers, preserve it. Only add an
	# extends line when the script really has none: @tool, @icon, class_name
	# and doc comments can legitimately come before an existing extends.
	if existing_code.strip_edges().is_empty():
		existing_code = "extends %s\n" % node_class
	elif not _scan_script_header(existing_code.split("\n"))["has_extends"]:
		existing_code = _insert_extends_line(existing_code, node_class)

	# Insert markers before the first top-level function, together with any
	# annotations (@rpc, @warning_ignore, ...) and "##" doc comments that sit
	# directly above it, so they stay attached to that function.
	var lines_scan := existing_code.split("\n")
	var insert_line := _find_generated_block_insert_line(lines_scan)
	var insert_pos := existing_code.length()
	if insert_line < lines_scan.size():
		var char_offset := 0
		for i in insert_line:
			char_offset += lines_scan[i].length() + 1  # +1 for the "\n" that split consumed
		insert_pos = char_offset

	var before = existing_code.substr(0, insert_pos)
	var after = existing_code.substr(insert_pos)

	# Build with proper newline handling
	var marked_code = before
	if not before.ends_with("\n"):
		marked_code += "\n"

	marked_code += "\n" + CODE_START_MARKER + "\n"
	marked_code += generated_code

	if not generated_code.ends_with("\n"):
		marked_code += "\n"

	marked_code += CODE_END_MARKER + "\n"

	if not after.is_empty():
		if not after.begins_with("\n"):
			marked_code += "\n"
		marked_code += after

	return marked_code

## Names each chain after what it does, so the generated functions read like
## _logic_brick_proximity_then_move_towards instead of a number. A name typed
## on the Controller brick is used as-is; a name typed on a trigger or action
## replaces that brick's title. Duplicates get _2, _3, ... in graph order.
func assign_readable_chain_names(chains: Array) -> void:
	var used: Dictionary = {}
	# Complete chains first, so a half-built chain never shifts the _2/_3 suffix
	# of a chain that already has code.
	var ordered: Array = []
	for chain in chains:
		if _chain_is_complete(chain):
			ordered.append(chain)
	for chain in chains:
		if not _chain_is_complete(chain):
			ordered.append(chain)
	for chain in ordered:
		var base := readable_chain_name(chain)
		var name := base
		var counter := 1
		while used.has(name):
			counter += 1
			name = "%s_%d" % [base, counter]
		used[name] = true
		chain["name"] = name


func _chain_is_complete(chain: Dictionary) -> bool:
	var controllers: Array = chain.get("controllers", [])
	if controllers.is_empty() or not (controllers[0] is Dictionary):
		return false
	var has_inputs: bool = not chain.get("sensors", []).is_empty() or not chain.get("controller_inputs", []).is_empty()
	var is_script: bool = str(controllers[0].get("type", "")) == "ScriptController"
	return has_inputs and (is_script or not chain.get("actuators", []).is_empty())


func readable_chain_name(chain: Dictionary) -> String:
	var controllers: Array = chain.get("controllers", [])
	var controller: Dictionary = controllers[0] if not controllers.is_empty() and controllers[0] is Dictionary else {}
	var own_name := _identifier_words(str(controller.get("instance_name", "")))
	if not own_name.is_empty():
		if own_name in _RESERVED_CHAIN_NAMES or own_name.begins_with("character_") or own_name.begins_with("2d_") or own_name.begins_with("external_motion"):
			own_name += "_chain"
		return own_name

	var sensors: Array = []
	_collect_naming_sensors(chain, sensors)
	var logic_mode := str(controller.get("properties", {}).get("logic_mode", "and")).to_lower() if controller.get("properties", {}) is Dictionary else "and"
	var joiner := "_or_" if logic_mode in ["or", "xor", "nor"] else "_and_"
	var sensor_part := _join_brick_words(sensors, joiner)
	if sensor_part.is_empty():
		sensor_part = "chain"

	var action_part := _join_brick_words(chain.get("actuators", []), "_and_")
	if action_part.is_empty():
		action_part = "script" if str(controller.get("type", "")) == "ScriptController" else "nothing"
	return "%s_then_%s" % [sensor_part, action_part]


const _RESERVED_CHAIN_NAMES := ["state", "state_enter", "set_state", "init_states", "chain_state_matches",
	"get_state_signature", "variable", "col", "col_i", "normal", "bounce", "friction", "hvel",
	"floor_hit", "rebound_y", "impact_speed", "jumps_remaining", "gravity_dir", "gravity_direction",
	"gravity_acceleration", "default_gravity", "default_gravity_dir", "project_gravity",
	"previous_gravity_direction", "pre_slide_velocity", "pre_slide_velocity_2d", "accel_step",
	"current_hvel", "target_hvel", "soft_gravity_force"]


func _collect_naming_sensors(tree: Dictionary, out: Array) -> void:
	for sensor in tree.get("sensors", []):
		if sensor is Dictionary:
			out.append(sensor)
	for nested in tree.get("controller_inputs", []):
		if nested is Dictionary:
			_collect_naming_sensors(nested, out)


## Up to two brick names joined by the joiner; more than two add "_etc".
func _join_brick_words(bricks: Array, joiner: String) -> String:
	var words: Array[String] = []
	for brick in bricks:
		if not (brick is Dictionary):
			continue
		var word := _identifier_words(str(brick.get("instance_name", "")))
		if word.is_empty():
			word = _identifier_words(_brick_title(str(brick.get("type", ""))))
		if not word.is_empty() and word not in words:
			words.append(word)
	if words.is_empty():
		return ""
	var shown := words.slice(0, 2)
	var text := joiner.join(shown)
	if words.size() > 2:
		text += "_etc"
	return text


var _brick_title_cache: Dictionary = {}

## The title shown on the brick in the graph (for example "Signal Receive").
func _brick_title(brick_type: String) -> String:
	if _brick_title_cache.has(brick_type):
		return _brick_title_cache[brick_type]
	var title := ""
	var path := _get_brick_script_path(brick_type)
	if not path.is_empty():
		var script = load(path)
		if script:
			var brick = script.new()
			title = str(brick.get_brick_name())
	if title.is_empty():
		title = brick_type.trim_suffix("Sensor").trim_suffix("Actuator").to_snake_case()
	_brick_title_cache[brick_type] = title
	return title


## "Color / Transparency" -> "color_transparency", "3rd Person Camera" -> "3rd_person_camera".
func _identifier_words(text: String) -> String:
	var rx := RegEx.new()
	rx.compile("[^a-z0-9]+")
	return rx.sub(text.strip_edges().to_lower(), "_", true).strip_edges().trim_prefix("_").trim_suffix("_")


## Generate a unique chain name
func _generate_unique_chain_name(existing_chains: Array) -> String:
	var counter = 0
	var name = "chain_%d" % counter

	while _chain_name_exists(existing_chains, name):
		counter += 1
		name = "chain_%d" % counter

	return name


## Check if a chain name already exists
func _chain_name_exists(chains: Array, name: String) -> bool:
	for chain in chains:
		if chain["name"] == name:
			return true
	return false


## Sanitize chain name for use in function names
func _sanitize_chain_name(name: String) -> String:
	# Replace invalid characters with underscores
	var sanitized = ""
	for i in range(name.length()):
		var c = name[i]
		if c.is_valid_identifier() or (i > 0 and c.is_valid_int()):
			sanitized += c
		else:
			sanitized += "_"

	# Ensure it starts with a letter or underscore
	if sanitized.is_empty() or sanitized[0].is_valid_int():
		sanitized = "_" + sanitized

	return sanitized


## Mark the scene as modified so changes are saved
func _mark_scene_modified(node: Node) -> void:
	if not editor_interface:
		return

	# Mark the currently edited scene as unsaved
	# This is the correct way to tell Godot the scene needs saving
	editor_interface.mark_scene_as_unsaved()


## Add brick's get_kept_member_vars() patterns to patterns.
func _collect_kept_member_vars(patterns: PackedStringArray, brick) -> void:
	if brick == null or not brick.has_method("get_kept_member_vars"):
		return
	for pattern in brick.get_kept_member_vars():
		if not patterns.has(pattern):
			patterns.append(pattern)


## True when var_name matches one of the kept-variable glob patterns.
static func _is_kept_member_var(var_name: String, patterns: PackedStringArray) -> bool:
	for pattern in patterns:
		if var_name.match(pattern):
			return true
	return false


## Parse a member variable declaration into a reset statement.
## e.g. "var _delay_elapsed__27: float = 0.0"  ->  "_delay_elapsed__27 = 0.0"
## e.g. "var _on_ground: bool = false"          ->  "_on_ground = false"
## Returns empty string for @export vars or declarations without a default value.
func _member_var_to_reset(member_var_line: String) -> String:
	# Skip exported vars — those are set by the user in the inspector, not reset on state entry
	if member_var_line.begins_with("@export"):
		return ""

	# Must start with "var "
	if not member_var_line.begins_with("var "):
		return ""

	var after_var = member_var_line.substr(4)  # strip "var "

	# Long-lived runtime state (pools, music players, character motion...) is
	# not listed here: each brick declares it with get_kept_member_vars(), and
	# _generate_code_for_chains() drops those resets.

	# Skip any var typed as PackedScene — these are preloaded resources, not runtime state
	if ": PackedScene" in member_var_line:
		return ""

	# Check there's a "=" to split on
	var eq_pos = member_var_line.find("=")
	if eq_pos == -1:
		return ""

	# Extract default value (trim trailing comments)
	var default_val = member_var_line.substr(eq_pos + 1).strip_edges()
	var comment_pos = default_val.find("  #")
	if comment_pos == -1:
		comment_pos = default_val.find("\t#")
	if comment_pos != -1:
		default_val = default_val.substr(0, comment_pos).strip_edges()

	# Extract variable name: "var _foo: float = ..." or "var _foo = ..."
	var colon_pos = after_var.find(":")
	var var_name = ""
	if colon_pos != -1:
		var_name = after_var.substr(0, colon_pos).strip_edges()
	else:
		var space_pos = after_var.find(" ")
		var_name = after_var.substr(0, space_pos if space_pos != -1 else after_var.length()).strip_edges()

	if var_name.is_empty() or default_val.is_empty():
		return ""

	return "%s = %s" % [var_name, default_val]

## Collect every visual brick ID that belongs to a generated chain. Runtime only
## stores one active byte per chain; this static mapping is used when the debugger
## requests a snapshot, avoiding per-brick work in the game loop.
func _collect_debug_brick_ids_for_chain(chain: Dictionary) -> Array:
	var result: Array = []
	for sensor_data in chain.get("sensors", []):
		_append_debug_brick_id(result, sensor_data)
	for controller_data in chain.get("controllers", []):
		_append_debug_brick_id(result, controller_data)
	if chain.has("controller"):
		_append_debug_brick_id(result, chain.get("controller", null))
	for actuator_data in chain.get("actuators", []):
		_append_debug_brick_id(result, actuator_data)
	for controller_tree in chain.get("controller_inputs", []):
		_collect_debug_ids_from_controller_tree(result, controller_tree)
	return result


func _collect_debug_ids_from_controller_tree(result: Array, controller_tree) -> void:
	if not (controller_tree is Dictionary):
		return
	for sensor_data in controller_tree.get("sensors", []):
		_append_debug_brick_id(result, sensor_data)
	_append_debug_brick_id(result, controller_tree.get("controller", null))
	for nested_tree in controller_tree.get("controller_inputs", []):
		_collect_debug_ids_from_controller_tree(result, nested_tree)


func _append_debug_brick_id(result: Array, brick_data) -> void:
	if not (brick_data is Dictionary):
		return
	var brick_id := str(brick_data.get("graph_node_id", ""))
	if not brick_id.is_empty() and brick_id not in result:
		result.append(brick_id)

