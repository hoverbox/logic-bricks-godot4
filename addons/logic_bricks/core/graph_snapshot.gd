@tool
extends RefCounted

## A compressed copy of a node's whole Logic Bricks graph (bricks, layout,
## frames, reroutes, variables, states), written as one comment line into the
## generated code on every Apply Code:
##
##   # LB_GRAPH_SNAPSHOT_V1 H4sIAAAAAAAA...
##
## The graph itself lives in the scene's node metadata. If that is lost (node
## deleted and re-created, scene reverted, metadata wiped), Rebuild from Script
## reads this line back and restores the graph exactly as it was at the last
## Apply. Turn it off with the project setting
## logic_bricks/backup/save_graph_in_script.

const Migrations = preload("res://addons/logic_bricks/core/logic_brick_migrations.gd")

const PREFIX := "# LB_GRAPH_SNAPSHOT_V1 "
const SETTING := "logic_bricks/backup/save_graph_in_script"
## Everything Rebuild needs; UI-only state such as debug watches is left out.
const META_KEYS := ["logic_bricks", "logic_bricks_graph", "logic_bricks_frames",
	"logic_bricks_variables", "logic_bricks_states", "logic_bricks_global_usage",
	Migrations.SCHEMA_VERSION_KEY]


static func enabled() -> bool:
	return bool(ProjectSettings.get_setting(SETTING, true))


## Adds the project setting (on by default) so it shows in Project Settings.
static func register_setting() -> void:
	if not ProjectSettings.has_setting(SETTING):
		ProjectSettings.set_setting(SETTING, true)
	ProjectSettings.set_initial_value(SETTING, true)
	ProjectSettings.add_property_info({"name": SETTING, "type": TYPE_BOOL})
	ProjectSettings.set_as_basic(SETTING, true)


## The snapshot line for node, or "" when the node has no Logic Bricks data
## or snapshots are turned off.
static func line_for(node: Node) -> String:
	if node == null or not enabled() or not Migrations.has_logic_bricks_data(node):
		return ""
	var data := {}
	for key in META_KEYS:
		if node.has_meta(key):
			data[key] = node.get_meta(key)
	var raw: PackedByteArray = var_to_bytes(data)
	return PREFIX + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))


## The snapshot stored in generated code (or a whole script), or {} if none.
static func read(text: String) -> Dictionary:
	var at := text.find(PREFIX)
	if at < 0:
		return {}
	var encoded := text.substr(at + PREFIX.length()).get_slice("\n", 0).strip_edges()
	var compressed := Marshalls.base64_to_raw(encoded)
	if compressed.is_empty():
		return {}
	var raw := compressed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return {}
	var data = bytes_to_var(raw)  # never decodes objects
	return data if data is Dictionary else {}


## Replaces the node's Logic Bricks metadata with the snapshot, then upgrades
## it to the current schema (the snapshot may come from an older version).
static func restore(node: Node, data: Dictionary) -> void:
	for key in META_KEYS:
		if data.has(key):
			var value = data[key]
			node.set_meta(key, value.duplicate(true) if value is Array or value is Dictionary else value)
		elif node.has_meta(key):
			node.remove_meta(key)
	Migrations.migrate_node(node)
