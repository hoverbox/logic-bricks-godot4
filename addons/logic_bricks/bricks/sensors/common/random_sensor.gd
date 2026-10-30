@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Random Sensor - Activates randomly based on probability or a value comparison
##
## Trigger Modes:
##   Chance:  fires TRUE with a given probability each frame it is evaluated.
##   Value:   generates a random integer and fires TRUE when it equals a target.
##   Range:   generates a random integer and fires TRUE when it falls in [min, max].
##
## Use Seed to get reproducible results (same sequence every run).
## Pair with a Delay Trigger to control how often the roll is evaluated.


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Random Chance"


func _initialize_properties() -> void:
	properties = {
		"trigger_mode":   "chance",  # chance, value, range
		"chance_percent": 10.0,      # Probability (0-100%) for chance mode
		"target_value":   0,         # Integer to match for value mode
		"target_min":     0,         # Inclusive minimum for range mode
		"target_max":     100,       # Inclusive maximum for range mode
		"use_seed":       false,     # Use a fixed seed for reproducible results
		"seed_value":     0,         # Seed (only when use_seed is true)
		"store_value":    false,     # Store the generated number in a variable
		"value_variable": "",        # Variable name to receive the result
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "trigger_mode",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Chance,Value,Range",
			"default": "chance"
		},
		# Chance mode
		{
			"name": "chance_percent",
			"type": TYPE_FLOAT,
			"hint": PROPERTY_HINT_RANGE,
			"hint_string": "0.0,100.0,0.1",
			"default": 10.0
		},
		# Value mode
		{
			"name": "target_value",
			"type": TYPE_INT,
			"default": 0
		},
		# Range mode
		{
			"name": "target_min",
			"type": TYPE_INT,
			"default": 0
		},
		{
			"name": "target_max",
			"type": TYPE_INT,
			"default": 100
		},
		# Shared options
		{
			"name": "use_seed",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "seed_value",
			"type": TYPE_INT,
			"default": 0
		},
		{
			"name": "store_value",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "value_variable", "required": true, "required_label": "a variable to store the random value", "required_if": {"store_value": true},
			"type": TYPE_STRING,
			"default": ""
		},
	]


func get_tooltip_definitions() -> Dictionary:
	return {
		"_description": "Activates randomly each time it is evaluated.\nPair with a Delay Trigger to control how often it rolls.\nUseful for random behaviors, AI variation, and loot rolls.",
		"trigger_mode":   "Chance: rolls TRUE with a given probability each evaluation.\nValue: rolls an integer and fires TRUE when it matches the target.\nRange: rolls a whole number from Min to Max and fires every time.\nTurn on Store Value to use the number (for example, a dice roll or a loot table).",
		"chance_percent": "Probability of firing TRUE (0–100%).\n10 = 10% chance per evaluation.\n100 = always fires.",
		"target_value":   "The integer the roll must equal to fire TRUE (Value mode).\nThe roll range is [0, target_value * 2] so the target sits in the middle.",
		"target_min":     "Smallest number the roll can be (Range mode). Included.",
		"target_max":     "Largest number the roll can be (Range mode). Included.",
		"use_seed":       "Use a fixed seed for reproducible random sequences.\nSame seed always produces the same sequence of results.",
		"seed_value":     "The seed value to use when Use Seed is enabled.",
		"store_value":    "Store the generated random number in a variable each evaluation.\nChance mode stores 1.0 when fired, 0.0 otherwise.",
		"value_variable": "Variable name to store the generated value in.\nCreate it in the Variables tab first.",
	}


## Which of this brick's fields the editor shows for its current settings:
## {property_name: visible}. Fields not listed keep their default (shown).
## context_node is the node the brick is on. "visible_if" in a property
## definition is applied on top (see LogicBrick.get_field_visibility()).
func get_field_visibility_rules(context_node: Node) -> Dictionary:
	var shown := {}
	var trigger_mode = properties.get("trigger_mode", "value")
	var use_seed = properties.get("use_seed", false)
	var store_val = properties.get("store_value", false)

	# Normalize trigger_mode
	if typeof(trigger_mode) == TYPE_STRING:
		trigger_mode = trigger_mode.to_lower()

	# Show/hide fields based on settings
	for child in _get_field_names():
		if true:
			var prop_name = child
			match prop_name:
				"target_value":
					shown[child] = (trigger_mode == "value")
				"target_min", "target_max":
					shown[child] = (trigger_mode == "range")
				"chance_percent":
					shown[child] = (trigger_mode == "chance")
				"seed_value":
					shown[child] = use_seed
				"value_variable":
					shown[child] = store_val
	return shown


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var trigger_mode   = properties.get("trigger_mode",   "chance")
	# Number fields may hold a variable or math; those are read when the brick runs.
	var chance_percent = _literal_number("chance_percent", 10.0)
	var target_value   = _literal_number("target_value",   0)
	var target_min     = _literal_number("target_min",     0)
	var target_max     = _literal_number("target_max",     100)
	var use_seed       = properties.get("use_seed",       false)
	var store_value    = properties.get("store_value",    false)
	var value_variable = str(properties.get("value_variable", "")).strip_edges()

	if typeof(trigger_mode) == TYPE_STRING:
		trigger_mode = trigger_mode.to_lower().replace(" ", "_")

	# Sanitize the store-to variable name
	var store_var = ""
	if store_value and not value_variable.is_empty():
		var regex = RegEx.new()
		regex.compile("[^a-zA-Z0-9_]")
		store_var = regex.sub(value_variable.strip_edges().replace(" ", "_"), "", true)

	# Per-chain RNG — seeded once on first evaluation
	var rng_var      = "_rng_%s" % chain_name
	var rng_init_var = "_rng_ready_%s" % chain_name

	var member_vars: Array[String] = []
	var code_lines:  Array[String] = []

	member_vars.append("var %s: RandomNumberGenerator = RandomNumberGenerator.new()" % rng_var)
	member_vars.append("var %s: bool = false" % rng_init_var)

	# Seed once on the very first evaluation frame
	code_lines.append("# Random Sensor: initialise RNG on first use")
	code_lines.append("if not %s:" % rng_init_var)
	if use_seed:
		code_lines.append("\t%s.seed = %s" % [rng_var, _int_num("seed_value", 0)])
	else:
		code_lines.append("\t%s.randomize()" % rng_var)
	code_lines.append("\t%s = true" % rng_init_var)
	code_lines.append("")

	match trigger_mode:
		"chance":
			if chance_percent == null:
				code_lines.append("# Chance mode: fire with the given percent probability per evaluation")
				code_lines.append("var sensor_active = %s.randf() * 100.0 < %s" % [rng_var, _num("chance_percent")])
			else:
				code_lines.append("# Chance mode: %.2f%% probability per evaluation" % chance_percent)
				code_lines.append("var sensor_active = %s.randf() * 100.0 < %.4f" % [rng_var, chance_percent])
			if not store_var.is_empty():
				code_lines.append("%s = 1.0 if sensor_active else 0.0" % store_var)

		"value":
			# Roll range: span at least 100 wide, always containing the target.
			# Handles zero and negative targets by anchoring the range around the target
			# rather than assuming target >= 0.
			if target_value == null:
				# Variable/math target: work out the roll range when the brick runs.
				code_lines.append("# Value mode: roll an integer around the target, fire when it matches")
				code_lines.append("var _rand_target = %s" % _int_num("target_value"))
				code_lines.append("var _rand_half_span = maxi(absi(_rand_target), 50)")
				code_lines.append("var _rand_roll = %s.randi_range(_rand_target - _rand_half_span, _rand_target + _rand_half_span)" % rng_var)
				if not store_var.is_empty():
					code_lines.append("%s = _rand_roll" % store_var)
				code_lines.append("var sensor_active = _rand_roll == _rand_target")
			else:
				var target_int := int(target_value)
				var half_span = max(abs(target_int), 50)
				var roll_lo   = target_int - half_span
				var roll_hi   = target_int + half_span
				code_lines.append("# Value mode: roll integer in [%d, %d], fire when == %d" % [roll_lo, roll_hi, target_int])
				code_lines.append("var _rand_roll = %s.randi_range(%d, %d)" % [rng_var, roll_lo, roll_hi])
				if not store_var.is_empty():
					code_lines.append("%s = _rand_roll" % store_var)
				code_lines.append("var sensor_active = _rand_roll == %d" % target_int)

		"range":
			# Range mode is a dice roll: pick a whole number from Min to Max and
			# fire. Store Value keeps the number so other bricks can use it.
			var lo: String
			var hi: String
			if target_min == null or target_max == null:
				# Variable/math bounds: order them when the brick runs.
				code_lines.append("# Range mode: roll a whole number from min to max")
				code_lines.append("var _rand_lo = mini(%s, %s)" % [_int_num("target_min"), _int_num("target_max", 100)])
				code_lines.append("var _rand_hi = maxi(%s, %s)" % [_int_num("target_min"), _int_num("target_max", 100)])
				lo = "_rand_lo"
				hi = "_rand_hi"
			else:
				lo = str(mini(int(target_min), int(target_max)))
				hi = str(maxi(int(target_min), int(target_max)))
				code_lines.append("# Range mode: roll a whole number from %s to %s" % [lo, hi])
			code_lines.append("var _rand_roll = %s.randi_range(%s, %s)" % [rng_var, lo, hi])
			if not store_var.is_empty():
				code_lines.append("%s = _rand_roll" % store_var)
			code_lines.append("var sensor_active = true")

		_:
			code_lines.append("var sensor_active = false  # Unknown trigger mode")

	return {
		"sensor_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
