@tool
extends RefCounted

## Centralized saved-data migrations for Logic Bricks node metadata.
## Unversioned projects are schema 0. Every migration upgrades exactly one step.

const SCHEMA_VERSION_KEY := "logic_bricks_schema_version"
const CURRENT_SCHEMA_VERSION := 3

const _LOGIC_META_KEYS := [
	"logic_bricks",
	"logic_bricks_graph",
	"logic_bricks_frames",
	"logic_bricks_variables",
	"logic_bricks_states",
	"logic_bricks_global_usage",
	"logic_bricks_debug_watch_state",
]


static func has_logic_bricks_data(node: Node) -> bool:
	if node == null:
		return false
	for key in _LOGIC_META_KEYS:
		if node.has_meta(key):
			return true
	return false


static func get_schema_version(node: Node) -> int:
	if node == null:
		return 0
	return int(node.get_meta(SCHEMA_VERSION_KEY, 0))


static func stamp_current_schema(node: Node) -> void:
	if node != null:
		node.set_meta(SCHEMA_VERSION_KEY, CURRENT_SCHEMA_VERSION)


## Upgrade all known Logic Bricks metadata on a node to the current schema.
## Returns {changed, from_version, to_version, future_version}.
static func migrate_node(node: Node) -> Dictionary:
	var result := {
		"changed": false,
		"from_version": 0,
		"to_version": 0,
		"future_version": false,
	}
	if node == null or not has_logic_bricks_data(node):
		return result

	var version := get_schema_version(node)
	result["from_version"] = version
	result["to_version"] = version

	if version > CURRENT_SCHEMA_VERSION:
		result["future_version"] = true
		return result

	while version < CURRENT_SCHEMA_VERSION:
		match version:
			0:
				_migrate_v0_to_v1(node)
				version = 1
			1:
				_migrate_v1_to_v2(node)
				version = 2
			2:
				_migrate_v2_to_v3(node)
				version = 3
			_:
				break
		result["changed"] = true

	if get_schema_version(node) != CURRENT_SCHEMA_VERSION:
		stamp_current_schema(node)
		result["changed"] = true

	result["to_version"] = CURRENT_SCHEMA_VERSION
	return result


## Schema 1 canonicalizes the two legacy shapes we still intentionally support:
## - top-level chain["controller"] becomes chain["controllers"]
## - graph metadata explicitly stores the default connection style
static func _migrate_v0_to_v1(node: Node) -> void:
	if node.has_meta("logic_bricks"):
		var raw_chains = node.get_meta("logic_bricks")
		if raw_chains is Array:
			var chains: Array = raw_chains.duplicate(true)
			for i in range(chains.size()):
				if not (chains[i] is Dictionary):
					continue
				var chain: Dictionary = chains[i]
				var controllers = chain.get("controllers", [])
				if not (controllers is Array):
					controllers = []
				if controllers.is_empty():
					var legacy_controller = chain.get("controller", null)
					if legacy_controller is Dictionary:
						chain["controllers"] = [legacy_controller.duplicate(true)]
				elif not chain.has("controllers"):
					chain["controllers"] = []
				chain.erase("controller")
				chains[i] = chain
			node.set_meta("logic_bricks", chains)

	if node.has_meta("logic_bricks_graph"):
		var raw_graph = node.get_meta("logic_bricks_graph")
		if raw_graph is Dictionary:
			var graph: Dictionary = raw_graph.duplicate(true)
			if not graph.has("connection_style"):
				graph["connection_style"] = "bezier"
			node.set_meta("logic_bricks_graph", graph)

	stamp_current_schema(node)


## Schema 2 splits the Save/Load "target" field, which held either a node name
## or a group name depending on Scope, into target_node_name and target_group.
## Node renames can then update the node field without touching group names.
const SAVE_LOAD_CLASSES := ["SaveLoadActuator", "SaveLoad2DActuator", "SaveGameActuator"]

static func _migrate_v1_to_v2(node: Node) -> void:
	for key in ["logic_bricks", "logic_bricks_graph"]:
		if node.has_meta(key):
			var data = node.get_meta(key)
			if data is Array or data is Dictionary:
				var copy = data.duplicate(true)
				if _split_save_load_target(copy) > 0:
					node.set_meta(key, copy)
	stamp_current_schema(node)


static func _split_save_load_target(value) -> int:
	var count := 0
	if value is Array:
		for item in value:
			count += _split_save_load_target(item)
	elif value is Dictionary:
		var brick_class := str(value.get("type", value.get("brick_class", "")))
		var props = value.get("properties", null)
		if brick_class in SAVE_LOAD_CLASSES and props is Dictionary and props.has("target"):
			var scope := str(props.get("scope", "this_node")).to_lower().replace(" ", "_")
			var field := "target_group" if scope == "group" else "target_node_name"
			if str(props.get(field, "")).is_empty():
				props[field] = props["target"]
			props.erase("target")
			count += 1
		for key in value:
			if key != "properties":
				count += _split_save_load_target(value[key])
	return count


## Schema 3 renames properties whose editor label did not match the name used in
## code: Signal Send/Receive "subject" -> "signal_name", and the Physics trigger's
## "minimum_impact_speed" -> "minimum_landing_speed" (shown as Minimum Landing Speed).
const RENAMED_PROPERTIES := {
	"MessageSensor": {"subject": "signal_name"},
	"Message2DSensor": {"subject": "signal_name"},
	"UIMessageSensor": {"subject": "signal_name"},
	"MessageActuator": {"subject": "signal_name"},
	"Message2DActuator": {"subject": "signal_name"},
	"UIMessageActuator": {"subject": "signal_name"},
	"PhysicsSensor": {"minimum_impact_speed": "minimum_landing_speed"},
	"Physics2DSensor": {"minimum_impact_speed": "minimum_landing_speed"},
}

static func _migrate_v2_to_v3(node: Node) -> void:
	for key in ["logic_bricks", "logic_bricks_graph"]:
		if node.has_meta(key):
			var data = node.get_meta(key)
			if data is Array or data is Dictionary:
				var copy = data.duplicate(true)
				if rename_properties(copy) > 0:
					node.set_meta(key, copy)
	stamp_current_schema(node)


## Renames old property keys in any nested chain/graph data. Returns the count.
static func rename_properties(value) -> int:
	var count := 0
	if value is Array:
		for item in value:
			count += rename_properties(item)
	elif value is Dictionary:
		var brick_class := str(value.get("type", value.get("brick_class", "")))
		var props = value.get("properties", null)
		if RENAMED_PROPERTIES.has(brick_class) and props is Dictionary:
			var renames: Dictionary = RENAMED_PROPERTIES[brick_class]
			for old_key in renames:
				if props.has(old_key):
					if not props.has(renames[old_key]):
						props[renames[old_key]] = props[old_key]
					props.erase(old_key)
					count += 1
		for key in value:
			if key != "properties":
				count += rename_properties(value[key])
	return count
