@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Preload Actuator - Preload resources into memory to prevent runtime hitching.
##
## Triggers background (threaded) or immediate loading of materials, scenes, textures,
## audio streams, meshes, and any other Godot resource. Once loaded, resources are
## held in a cache on the host node so the engine does not unload them between frames.
##
## Use this before a loading screen ends, before spawning a boss, or anywhere a
## sudden resource load would cause a visible stutter.


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Preload"


func _initialize_properties() -> void:
	properties = {
		"load_mode":          "background", # background, immediate
		"resource_type":      "Any",        # Any, Scene, Material, Texture, AudioStream, Mesh, Shader
		"resources":          [],           # Array of resource paths
		"on_complete_signal": true,         # Emit a message when all loads finish
		"signal_group":       "",           # Group to message on completion
		"signal_message":     "preload_done", # Message body sent to group
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "load_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Background (Threaded),Immediate (Blocking)",
			"default": "background"
		},
		{
			"name": "resource_type",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Any,Scene,Material,Texture,AudioStream,Mesh,Shader",
			"default": "Any"
		},
		{
			"name": "resources",
			"type": TYPE_ARRAY,
			"default": [],
			"item_hint": PROPERTY_HINT_FILE,
			"item_hint_string": "*.tres,*.res,*.tscn,*.scn,*.material,*.png,*.jpg,*.webp,*.ogg,*.mp3,*.wav,*.mesh,*.obj,*.glsl",
			"item_label": "Resource"
		},
		{
			"name": "on_complete_signal",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "signal_group",
			"type": TYPE_STRING,
			"default": "",
			"visible_if": {"on_complete_signal": true}
		},
		{
			"name": "signal_message",
			"type": TYPE_STRING,
			"default": "preload_done",
			"visible_if": {"on_complete_signal": true}
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Preloads resources (materials, scenes, textures, audio, meshes) into memory before they are needed, preventing runtime hitches and frame drops.",
		"load_mode": "Background: loads on a thread without blocking gameplay (recommended). Immediate: blocks the main thread until done — use only on loading screens.",
		"resource_type": "Filter hint for the file picker. Choose 'Any' to mix resource types freely.",
		"resources": "List of resource paths to preload. Add as many as needed.",
		"on_complete_signal": "When all resources finish loading, send a message to a group. Useful to hide loading screens or trigger the next event.",
		"signal_group": "The node group that will receive the completion message.",
		"signal_message": "The message string sent to the group when loading is complete.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var load_mode        = properties.get("load_mode", "background")
	var resources: Array = properties.get("resources", [])
	var on_complete      = properties.get("on_complete_signal", true)
	var signal_group     = properties.get("signal_group", "")
	var signal_message   = properties.get("signal_message", "preload_done")

	# Normalise enum display label to code key
	if typeof(load_mode) == TYPE_STRING:
		load_mode = load_mode.to_lower()
		if "background" in load_mode or "thread" in load_mode:
			load_mode = "background"
		else:
			load_mode = "immediate"

	# Filter out blank entries
	var valid_resources: Array[String] = []
	for r in resources:
		var rs = str(r).strip_edges()
		if not rs.is_empty():
			valid_resources.append(rs)

	if valid_resources.is_empty():
		return {"actuator_code": "pass # Preload Actuator: no resources configured"}

	var lines: Array[String] = []

	# Initialise the resource cache dict on the node (idempotent across triggers)
	lines.append("# Preload Actuator: cache keeps resources resident so GC cannot collect them")
	lines.append("if not has_meta(\"_preload_cache\"):")
	lines.append("\tset_meta(\"_preload_cache\", {})")
	lines.append("var _preload_cache: Dictionary = get_meta(\"_preload_cache\")")
	lines.append("")

	if load_mode == "background":
		# Build the pending list
		lines.append("var _to_load: Array[String] = []")
		for path in valid_resources:
			lines.append("if not _preload_cache.has(\"%s\"):" % path)
			lines.append("\t_to_load.append(\"%s\")" % path)
		lines.append("")
		lines.append("if not _to_load.is_empty():")
		lines.append("\tfor _path in _to_load:")
		lines.append("\t\tif ResourceLoader.load_threaded_get_status(_path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:")
		lines.append("\t\t\tResourceLoader.load_threaded_request(_path)")

		if on_complete and not signal_group.is_empty():
			# Inline polling loop via a Callable variable — GDScript requires lambdas
			# to be assigned before calling; standalone lambdas are a parse error.
			var suffix = _safe_var(signal_group + "_" + signal_message)
			lines.append("\tvar _monitor_%s: Callable = func():" % suffix)
			lines.append("\t\tvar _rem = _to_load.duplicate()")
			lines.append("\t\twhile not _rem.is_empty():")
			lines.append("\t\t\tawait get_tree().process_frame")
			lines.append("\t\t\tvar _done: Array = []")
			lines.append("\t\t\tfor _p in _rem:")
			lines.append("\t\t\t\tvar _st = ResourceLoader.load_threaded_get_status(_p)")
			lines.append("\t\t\t\tif _st == ResourceLoader.THREAD_LOAD_LOADED:")
			lines.append("\t\t\t\t\t_preload_cache[_p] = ResourceLoader.load_threaded_get(_p)")
			lines.append("\t\t\t\t\t_done.append(_p)")
			lines.append("\t\t\t\telif _st == ResourceLoader.THREAD_LOAD_FAILED:")
			lines.append("\t\t\t\t\tpush_warning(\"Preload Actuator: failed to load '\" + _p + \"'\")")
			lines.append("\t\t\t\t\t_done.append(_p)")
			lines.append("\t\t\tfor _d in _done:")
			lines.append("\t\t\t\t_rem.erase(_d)")
			lines.append("\t\tget_tree().call_group(\"%s\", \"receive_message\", \"%s\")" % [signal_group, signal_message])
			lines.append("\t_monitor_%s.call()" % suffix)

	else:
		# Immediate / blocking load
		lines.append("# Immediately load all resources (blocks the main thread)")
		for path in valid_resources:
			var v = _safe_var(path)
			lines.append("if not _preload_cache.has(\"%s\"):" % path)
			lines.append("\tvar _res_%s = load(\"%s\")" % [v, path])
			lines.append("\tif _res_%s:" % v)
			lines.append("\t\t_preload_cache[\"%s\"] = _res_%s" % [path, v])
			lines.append("\telse:")
			lines.append("\t\tpush_warning(\"Preload Actuator: failed to load '%s'\")" % path)
		if on_complete and not signal_group.is_empty():
			lines.append("get_tree().call_group(\"%s\", \"receive_message\", \"%s\")" % [signal_group, signal_message])

	return {"actuator_code": "\n".join(lines)}


## Convert a resource path into a safe GDScript variable suffix
func _safe_var(path: String) -> String:
	var base = path.get_file().get_basename() if "/" in path or "\\" in path else path
	var result = ""
	for ch in base:
		if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			result += ch
		else:
			result += "_"
	return result if not result.is_empty() else "resource"
