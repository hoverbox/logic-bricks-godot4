@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Object Pool Actuator - Spawn/recycle instances from pre-allocated pools
## Supports multiple scene types with individual pool sizes
## Spawn modes: Random (pick one randomly), All (spawn one of each type)


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Object Pool"


func _initialize_properties() -> void:
	properties = {
		"action":           "spawn",   # spawn, despawn_all
		"scenes":           [],        # Array of scene file paths
		"pool_sizes":       [],        # Array of pool sizes (parallel to scenes)
		"spawn_mode":       "random",  # random, all
		"spawn_delay":      0.0,       # Minimum seconds between spawns
		"spawn_at_self":    true,
		"spawn_node":       "",
		"inherit_rotation": true,
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "action",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Spawn,Despawn All",
			"default": "spawn"
		},
		{
			"name": "scenes",
			"type": TYPE_ARRAY,
			"default": [],
			"item_hint": PROPERTY_HINT_FILE,
			"item_hint_string": "*.tscn,*.scn",
			"item_label": "Scene",
			"linked_array": "pool_sizes",
			"linked_default": "10"
		},
		{
			"name": "spawn_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Random,All",
			"default": "random"
		},
		{
			"name": "spawn_delay",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,60.0,0.05",
			"default": 0.0
		},
		{
			"name": "spawn_at_self",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "spawn_node",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "inherit_rotation",
			"type": TYPE_BOOL,
			"default": true
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Spawns objects from reusable pools.\nFaster than instancing — reuses inactive nodes.\nPools are created at startup.",
		"action":           "Spawn: activate the next available pooled object.\nDespawn All: deactivate all pooled objects.",
		"scenes":           "Scene files to pool. Add one per type.",
		"pool_sizes":       "Pool size for each scene. Must match the Scenes list order.\nLeave a value empty to default to 10.",
		"spawn_mode":       "Random: pick a random scene type each spawn.\nAll: spawn one of each type simultaneously.",
		"spawn_delay":      "Minimum seconds between spawns.\n0 = no limit. Use this to control spawn rate with a repeating sensor.",
		"spawn_at_self":    "Spawn at this node's position.\nDisable to use a custom spawn point node.",
		"spawn_node":       "Node path to spawn point (if Spawn At Self is disabled).",
		"inherit_rotation": "Copy this node's rotation when spawning.",
	}


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var action          = properties.get("action", "spawn")
	var scenes          = properties.get("scenes", [])
	var pool_sizes      = properties.get("pool_sizes", [])
	var spawn_mode      = properties.get("spawn_mode", "random")
	var spawn_delay     = float(properties.get("spawn_delay", 0.0))
	var spawn_at_self   = properties.get("spawn_at_self", true)
	var spawn_node_path = str(properties.get("spawn_node", "")).strip_edges()
	var inherit_rot     = properties.get("inherit_rotation", true)

	if typeof(action) == TYPE_STRING:
		action = action.to_lower().replace(" ", "_")
	if typeof(spawn_mode) == TYPE_STRING:
		spawn_mode = spawn_mode.to_lower()

	# Filter out empty scene paths
	var valid_scenes: Array = []
	var valid_sizes:  Array = []
	for i in scenes.size():
		var path = str(scenes[i]).strip_edges()
		if not path.is_empty():
			valid_scenes.append(path)
			var sz = "10"
			if i < pool_sizes.size():
				var raw = str(pool_sizes[i]).strip_edges()
				if not raw.is_empty():
					sz = raw  # Accept integers OR variable/expression names
			valid_sizes.append(sz)

	if valid_scenes.is_empty():
		return {
			"actuator_code": "pass",
			"ready_code": ["push_warning(\"Object Pool: No scenes added — open the brick and add at least one scene\")"]
		}

	# Derive shared pool name from instance/brick name
	var _export_label = instance_name if not instance_name.is_empty() else brick_name
	_export_label = _export_label.to_lower().replace(" ", "_")
	var _regex = RegEx.new()
	_regex.compile("[^a-z0-9_]")
	_export_label = _regex.sub(_export_label, "", true)
	if _export_label.is_empty():
		_export_label = chain_name

	var pools_var = "_pools_%s" % _export_label   # Array of Arrays
	var member_vars: Array[String] = []
	var ready_code:  Array[String] = []
	var code_lines:  Array[String] = []

	# Collision helper — only emit once per script via member_vars deduplication
	member_vars.append("var %s: Array = []" % pools_var)
	member_vars.append("")
	member_vars.append("func _pool_set_collision(node: Node, enabled: bool) -> void:")
	member_vars.append("\tfor child in node.get_children():")
	member_vars.append("\t\tif child is CollisionShape3D or child is CollisionShape2D:")
	member_vars.append("\t\t\tchild.set_deferred(\"disabled\", not enabled)")
	member_vars.append("\t\t_pool_set_collision(child, enabled)")

	# _ready: create one sub-pool per scene type
	ready_code.append("# Object Pool: pre-allocate pools")
	ready_code.append("await get_tree().process_frame")
	for i in valid_scenes.size():
		var path = valid_scenes[i]
		var sz   = valid_sizes[i]
		var sv   = "_pool_scene_%s_%d" % [_export_label, i]
		var pv   = "_pool_%s_%d" % [_export_label, i]
		member_vars.append("var %s: PackedScene = preload(\"%s\")" % [sv, path])
		ready_code.append("var %s: Array = []" % pv)
		ready_code.append("for _i_%d in range(%s):" % [i, sz])
		ready_code.append("\tvar _inst_%s_%d = %s.instantiate()" % [_export_label, i, sv])
		ready_code.append("\tget_parent().add_child(_inst_%s_%d)" % [_export_label, i])
		ready_code.append("\t_inst_%s_%d.visible = false" % [_export_label, i])
		ready_code.append("\t_pool_set_collision(_inst_%s_%d, false)" % [_export_label, i])
		ready_code.append("\t%s.append(_inst_%s_%d)" % [pv, _export_label, i])
		ready_code.append("%s.append(%s)" % [pools_var, pv])

	# Position/rotation helper lines (reused in spawn code)
	var pos_lines: Array[String] = []
	if spawn_at_self:
		pos_lines.append("\t\t_spawn_obj.global_position = global_position")
		if inherit_rot:
			pos_lines.append("\t\t_spawn_obj.global_rotation = global_rotation")
	elif not spawn_node_path.is_empty():
		pos_lines.append("\t\tvar _sp = get_node_or_null(\"%s\")" % spawn_node_path)
		pos_lines.append("\t\tif _sp:")
		pos_lines.append("\t\t\t_spawn_obj.global_position = _sp.global_position")
		if inherit_rot:
			pos_lines.append("\t\t\t_spawn_obj.global_rotation = _sp.global_rotation")

	# Spawn delay timer
	var delay_var = "_pool_last_spawn_%s" % _export_label
	if spawn_delay > 0.0:
		member_vars.append("var %s: float = -999.0" % delay_var)

	# Actuator code
	code_lines.append("# Object Pool Actuator")
	match action:
		"spawn":
			# Wrap entire spawn block in delay check if needed
			var ind = ""
			if spawn_delay > 0.0:
				code_lines.append("var _now_%s = Time.get_ticks_msec() / 1000.0" % chain_name)
				code_lines.append("if _now_%s - %s >= %.3f:" % [chain_name, delay_var, spawn_delay])
				code_lines.append("\t%s = _now_%s" % [delay_var, chain_name])
				ind = "\t"
			match spawn_mode:
				"random":
					code_lines.append("%sif not %s.is_empty():" % [ind, pools_var])
					code_lines.append("%s\tvar _pick = %s[randi() %% %s.size()]" % [ind, pools_var, pools_var])
					code_lines.append("%s\tvar _spawned = false" % ind)
					code_lines.append("%s\tfor _spawn_obj in _pick:" % ind)
					code_lines.append("%s\t\tif not _spawn_obj.visible:" % ind)
					for l in pos_lines:
						code_lines.append(ind + "\t" + l)
					code_lines.append("%s\t\t\t_pool_set_collision(_spawn_obj, true)" % ind)
					code_lines.append("%s\t\t\t_spawn_obj.visible = true" % ind)
					code_lines.append("%s\t\t\t_spawned = true" % ind)
					code_lines.append("%s\t\t\tbreak" % ind)
					code_lines.append("%s\tif not _spawned:" % ind)
					code_lines.append("%s\t\tpush_warning(\"Object Pool: Pool exhausted for random pick — increase pool size\")" % ind)
				"all":
					code_lines.append("%sfor _sub_pool in %s:" % [ind, pools_var])
					code_lines.append("%s\tvar _spawned = false" % ind)
					code_lines.append("%s\tfor _spawn_obj in _sub_pool:" % ind)
					code_lines.append("%s\t\tif not _spawn_obj.visible:" % ind)
					for l in pos_lines:
						code_lines.append(ind + "\t" + l)
					code_lines.append("%s\t\t\t_pool_set_collision(_spawn_obj, true)" % ind)
					code_lines.append("%s\t\t\t_spawn_obj.visible = true" % ind)
					code_lines.append("%s\t\t\t_spawned = true" % ind)
					code_lines.append("%s\t\t\tbreak" % ind)
					code_lines.append("%s\tif not _spawned:" % ind)
					code_lines.append("%s\t\tpush_warning(\"Object Pool: A sub-pool is exhausted — increase pool size\")" % ind)

		"despawn_all":
			code_lines.append("for _sub_pool in %s:" % pools_var)
			code_lines.append("\tfor _spawn_obj in _sub_pool:")
			code_lines.append("\t\t_pool_set_collision(_spawn_obj, false)")
			code_lines.append("\t\t_spawn_obj.visible = false")

	return {
		"actuator_code": "\n".join(code_lines),
		"member_vars":   member_vars,
		"ready_code":    ready_code
	}


func _to_expr(val) -> String:
	var s = str(val).strip_edges()
	if s.is_empty(): return "0"
	if s.is_valid_float() or s.is_valid_int(): return s
	return s
