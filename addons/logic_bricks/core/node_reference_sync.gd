@tool
extends RefCounted

## Keeps bricks that point at other nodes by name working when those nodes are
## renamed in the editor.
##
## Bricks store node references as plain names (or relative paths), so
## renaming "Player" to "Hero" in the Scene dock used to leave every brick
## still looking for "Player" until someone noticed in play mode. The plugin
## calls rename_in_scene() when a node in the edited scene is renamed; it
## rewrites matching node-reference properties in every node's brick data.
## The generated scripts still contain the old name until Apply Code is
## pressed, which the caller reports.
##
## Renames inside a scene that other scenes instance (rename "Gun" in
## turret.tscn while bricks on a Turret instance in level.tscn aim at "Gun")
## can't be applied right away, because those scenes are not open. They are
## recorded with record_scene_rename() and applied by apply_pending_renames()
## the next time each instancing scene is opened in the editor.

const BrickRegistry = preload("res://addons/logic_bricks/core/brick_registry.gd")
const BRICK_META_KEYS := ["logic_bricks", "logic_bricks_graph"]

const PENDING_RENAMES_PATH := "res://.godot/logic_bricks_pending_renames.json"
const MAX_PENDING_RENAMES := 500

static var _reference_props_cache: Dictionary = {}


## True for brick properties that hold a node name or path. Bricks may opt in
## or out with "node_reference" in the property definition; otherwise the
## naming convention decides.
static func is_node_reference_property(prop_def: Dictionary, property_name: String) -> bool:
	if prop_def.has("node_reference"):
		return bool(prop_def.get("node_reference", false))
	if property_name.ends_with("_node_name"):
		return true
	return property_name in ["camera_name", "target_name", "animation_tree_name"]


## Names of the node-reference properties of a brick class.
static func reference_properties(brick_class: String) -> PackedStringArray:
	if _reference_props_cache.has(brick_class):
		return _reference_props_cache[brick_class]
	var names := PackedStringArray()
	var script_path := BrickRegistry.get_script_path(brick_class)
	if not script_path.is_empty():
		var script = load(script_path)
		if script and script.can_instantiate():
			var brick = script.new()
			for definition in brick.get_property_definitions():
				if definition is Dictionary and is_node_reference_property(definition, str(definition.get("name", ""))):
					names.append(str(definition["name"]))
	_reference_props_cache[brick_class] = names
	return names


## Replaces references to old_name with new_name in the brick data of every
## node under scene_root. Returns {"changed": [{node, count}], "skipped": reason}.
## Nothing is changed when another node in the scene is still called old_name,
## because the bricks may have meant that node.
static func rename_in_scene(scene_root: Node, old_name: String, new_name: String) -> Dictionary:
	var result := {"changed": [], "skipped": ""}
	if scene_root == null or old_name.is_empty() or new_name.is_empty() or old_name == new_name:
		return result
	if _scene_has_node_named(scene_root, old_name):
		result["skipped"] = "another node is still named '%s'" % old_name
		return result
	var stack: Array[Node] = [scene_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var count := 0
		for key in BRICK_META_KEYS:
			if not node.has_meta(key):
				continue
			var data = node.get_meta(key)
			if not (data is Array or data is Dictionary):
				continue
			var copy = data.duplicate(true)
			var replaced := _rename_in_value(copy, old_name, new_name)
			if replaced > 0:
				node.set_meta(key, copy)
				count += replaced
		if count > 0:
			result["changed"].append({"node": node, "count": count})
	return result


static func _scene_has_node_named(scene_root: Node, node_name: String) -> bool:
	return str(scene_root.name) == node_name or scene_root.find_child(node_name, true, false) != null


## Walks chains / graph data and rewrites node-reference properties of every
## brick found. Returns how many values changed.
static func _rename_in_value(value, old_name: String, new_name: String) -> int:
	var count := 0
	if value is Array:
		for item in value:
			count += _rename_in_value(item, old_name, new_name)
	elif value is Dictionary:
		var brick_class := str(value.get("type", value.get("brick_class", "")))
		var props = value.get("properties", null)
		if not brick_class.is_empty() and props is Dictionary:
			for prop in reference_properties(brick_class):
				if not props.has(prop):
					continue
				var renamed := rename_reference(str(props[prop]), old_name, new_name)
				if renamed != str(props[prop]):
					props[prop] = renamed
					count += 1
		for key in value:
			if key != "properties":
				count += _rename_in_value(value[key], old_name, new_name)
	return count


## The reference with old_name replaced: a bare name must match exactly, and
## in a path ("Level/Player", "../Player") every matching segment changes.
static func rename_reference(reference: String, old_name: String, new_name: String) -> String:
	if reference == old_name:
		return new_name
	if not reference.contains("/"):
		return reference
	var parts := reference.split("/")
	for i in parts.size():
		if parts[i] == old_name:
			parts[i] = new_name
	return "/".join(parts)


# ── Renames that other scenes still need ────────────────────────────────────

## Remembers that old_name became new_name inside scene_path, for every scene
## that instances it.
static func record_scene_rename(scene_path: String, old_name: String, new_name: String, pending_path: String = PENDING_RENAMES_PATH) -> void:
	if scene_path.is_empty() or old_name.is_empty() or old_name == new_name:
		return
	var data := _load_pending(pending_path)
	data["next_id"] = int(data["next_id"]) + 1
	data["renames"].append({"id": int(data["next_id"]), "scene": scene_path, "old": old_name, "new": new_name})
	while data["renames"].size() > MAX_PENDING_RENAMES:
		data["renames"].pop_front()
	_save_pending(data, pending_path)


## Applies recorded renames from scenes instanced inside scene_root that this
## scene has not received yet. Returns {"changed": [{node, count}], "renames": [{old, new, skipped}]}.
static func apply_pending_renames(scene_root: Node, pending_path: String = PENDING_RENAMES_PATH) -> Dictionary:
	var result := {"changed": [], "renames": []}
	if scene_root == null or scene_root.scene_file_path.is_empty():
		return result
	var data := _load_pending(pending_path)
	if data["renames"].is_empty():
		return result
	var instanced := {}
	var stack: Array[Node] = []
	stack.append_array(scene_root.get_children())
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if not node.scene_file_path.is_empty():
			instanced[node.scene_file_path] = true
		stack.append_array(node.get_children())
	var own_path := scene_root.scene_file_path
	# JSON stores numbers as floats, so compare ids as ints.
	var applied: Array = Array(data["applied"].get(own_path, [])).map(func(x): return int(x))
	var changed_by_node := {}
	for rename in data["renames"]:
		var id := int(rename["id"])
		if applied.has(id) or not instanced.has(str(rename["scene"])):
			continue
		applied.append(id)
		var one := rename_in_scene(scene_root, str(rename["old"]), str(rename["new"]))
		result["renames"].append({"old": rename["old"], "new": rename["new"], "skipped": one["skipped"]})
		for entry in one["changed"]:
			changed_by_node[entry["node"]] = int(changed_by_node.get(entry["node"], 0)) + int(entry["count"])
	if result["renames"].is_empty():
		return result
	data["applied"][own_path] = applied
	_save_pending(data, pending_path)
	for node in changed_by_node:
		result["changed"].append({"node": node, "count": changed_by_node[node]})
	return result


## Scenes under res:// whose files instance scene_path (for the rename notice).
static func scenes_instancing(scene_path: String) -> PackedStringArray:
	var found := PackedStringArray()
	if scene_path.is_empty():
		return found
	var needle := "path=\"%s\"" % scene_path
	var dirs: Array[String] = ["res://"]
	while not dirs.is_empty():
		var dir: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			if not sub.begins_with(".") and not (dir == "res://" and sub == "addons"):
				dirs.append(dir.path_join(sub))
		for file in DirAccess.get_files_at(dir):
			if file.ends_with(".tscn"):
				var path := dir.path_join(file)
				if path != scene_path and FileAccess.get_file_as_string(path).contains(needle):
					found.append(path)
	found.sort()
	return found


static func _load_pending(pending_path: String) -> Dictionary:
	var data := {"next_id": 0, "renames": [], "applied": {}}
	if FileAccess.file_exists(pending_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(pending_path))
		if parsed is Dictionary:
			data["next_id"] = int(parsed.get("next_id", 0))
			if parsed.get("renames") is Array:
				data["renames"] = parsed["renames"]
			if parsed.get("applied") is Dictionary:
				data["applied"] = parsed["applied"]
	return data


static func _save_pending(data: Dictionary, pending_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pending_path.get_base_dir()))
	var file := FileAccess.open(pending_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
