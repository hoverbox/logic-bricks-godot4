@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Random Actuator - Set variable to random value using various distributions
## Similar to UPBGE's Random actuator


func _init() -> void:
	super._init()
	brick_type = BrickType.ACTUATOR
	brick_name = "Random"


func _initialize_properties() -> void:
	properties = {
		"variable_name": "",           # Variable to modify
		"distribution": "int_uniform", # Distribution type
		"bool_value": true,            # For Bool Constant
		"bool_probability": 0.5,       # For Bool Bernoulli (0.0-1.0)
		"int_value": 0,                # For Int Constant
		"int_min": 0,                  # For Int Uniform min
		"int_max": 100,                # For Int Uniform max
		"int_lambda": 1.0,             # For Int Poisson (average rate)
		"float_value": 0.0,            # For Float Constant
		"float_min": 0.0,              # For Float Uniform min
		"float_max": 1.0,              # For Float Uniform max
		"float_mean": 0.0,             # For Float Normal (mean)
		"float_stddev": 1.0,           # For Float Normal (standard deviation)
		"float_lambda": 1.0,           # For Float Negative Exponential (rate parameter)
		"use_seed": false,             # Use custom seed
		"seed_value": 0                # Seed value
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "variable_name",
			"type": TYPE_STRING,
			"default": ""
		},
		{
			"name": "distribution",
			"type": TYPE_STRING,
			"hint": PROPERTY_HINT_ENUM,
			"hint_string": "Bool Constant,Bool Uniform,Bool Bernoulli,Int Constant,Int Uniform,Int Poisson,Float Constant,Float Uniform,Float Normal,Float Neg Exp",
			"default": "int_uniform"
		},
		# Bool properties
		{
			"name": "bool_value",
			"type": TYPE_BOOL,
			"default": true,
			"visible_if": {"distribution": "bool_constant"}
		},
		{
			"name": "bool_probability",
			"type": TYPE_FLOAT,
			"default": 0.5,
			"visible_if": {"distribution": "bool_bernoulli"}
		},
		# Int properties
		{
			"name": "int_value",
			"type": TYPE_INT,
			"default": 0,
			"visible_if": {"distribution": "int_constant"}
		},
		{
			"name": "int_min",
			"type": TYPE_INT,
			"default": 0,
			"visible_if": {"distribution": "int_uniform"}
		},
		{
			"name": "int_max",
			"type": TYPE_INT,
			"default": 100,
			"visible_if": {"distribution": "int_uniform"}
		},
		{
			"name": "int_lambda",
			"type": TYPE_FLOAT,
			"default": 1.0,
			"visible_if": {"distribution": "int_poisson"}
		},
		# Float properties
		{
			"name": "float_value",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"visible_if": {"distribution": "float_constant"}
		},
		{
			"name": "float_min",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"visible_if": {"distribution": "float_uniform"}
		},
		{
			"name": "float_max",
			"type": TYPE_FLOAT,
			"default": 1.0,
			"visible_if": {"distribution": "float_uniform"}
		},
		{
			"name": "float_mean",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"visible_if": {"distribution": "float_normal"}
		},
		{
			"name": "float_stddev",
			"type": TYPE_FLOAT,
			"default": 1.0,
			"visible_if": {"distribution": "float_normal"}
		},
		{
			"name": "float_lambda",
			"type": TYPE_FLOAT,
			"default": 1.0,
			"visible_if": {"distribution": "float_neg_exp"}
		},
		# Seed properties (always visible)
		{
			"name": "use_seed",
			"type": TYPE_BOOL,
			"default": false
		},
		{
			"name": "seed_value",
			"type": TYPE_INT,
			"default": 0,
			"visible_if": {"use_seed": true}
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var var_name = properties.get("variable_name", "")
	var distribution = properties.get("distribution", "int_uniform")
	
	# Normalize distribution type
	if typeof(distribution) == TYPE_STRING:
		distribution = distribution.to_lower().replace(" ", "_")
	
	if var_name.is_empty():
		return {"actuator_code": "pass # Random actuator: no variable name specified"}
	
	# Sanitize variable name (preserve casing)
	var sanitized_name = var_name.strip_edges().replace(" ", "_")
	var regex = RegEx.new()
	regex.compile("[^a-zA-Z0-9_]")
	sanitized_name = regex.sub(sanitized_name, "", true)
	
	var code_lines: Array[String] = []
	var member_vars: Array[String] = []
	
	# RNG member variable
	var rng_var = "_rng_random_%s" % chain_name
	member_vars.append("var %s: RandomNumberGenerator = null" % rng_var)
	
	# Initialize RNG
	code_lines.append("# Initialize RNG if needed")
	code_lines.append("if %s == null:" % rng_var)
	code_lines.append("\t%s = RandomNumberGenerator.new()" % rng_var)
	
	var use_seed = properties.get("use_seed", false)
	var seed_value = properties.get("seed_value", 0)
	
	if use_seed:
		code_lines.append("\t%s.seed = %d" % [rng_var, seed_value])
	else:
		code_lines.append("\t%s.randomize()" % rng_var)
	code_lines.append("")
	
	# Generate value based on distribution
	var debug_code = get_debug_code()
	var debug_msg = debug_message if not debug_message.is_empty() else "Random Actuator"
	
	match distribution:
		"bool_constant":
			var bool_val = properties.get("bool_value", true)
			code_lines.append("self.%s = %s" % [sanitized_name, "true" if bool_val else "false"])
			if not debug_code.is_empty():
				code_lines.append("print(\"%s - Set %s = %%s\" %% self.%s)" % [debug_msg, sanitized_name, sanitized_name])
		
		"bool_uniform":
			code_lines.append("self.%s = %s.randf() < 0.5" % [sanitized_name, rng_var])
			if not debug_code.is_empty():
				code_lines.append("print(\"%s - Set %s = %%s\" %% self.%s)" % [debug_msg, sanitized_name, sanitized_name])
		
		"bool_bernoulli":
			var prob = properties.get("bool_probability", 0.5)
			code_lines.append("self.%s = %s.randf() < %.3f" % [sanitized_name, rng_var, prob])
			if not debug_code.is_empty():
				code_lines.append("print(\"%s - Set %s = %%s\" %% self.%s)" % [debug_msg, sanitized_name, sanitized_name])
		
		"int_constant":
			var int_val = properties.get("int_value", 0)
			code_lines.append("self.%s = %d" % [sanitized_name, int_val])
			if not debug_code.is_empty():
				code_lines.append("print(\"%s - Set %s = %%d\" %% self.%s)" % [debug_msg, sanitized_name, sanitized_name])
		
		"int_uniform":
			var int_min = properties.get("int_min", 0)
			var int_max = properties.get("int_max", 100)
			code_lines.append("self.%s = %s.randi_range(%d, %d)" % [sanitized_name, rng_var, int_min, int_max])
			if not debug_code.is_empty():
				code_lines.append("print(\"%s - Set %s = %%d\" %% self.%s)" % [debug_msg, sanitized_name, sanitized_name])
		
		"int_poisson":
			var lambda_val = properties.get("int_lambda", 1.0)
			code_lines.append("# Poisson distribution (approximate using exponential)")
			code_lines.append("var _poisson_sum = 0")
			code_lines.append("var _poisson_product = 1.0")
			code_lines.append("var _poisson_threshold = exp(-%.3f)" % lambda_val)
			code_lines.append("while _poisson_product > _poisson_threshold:")
			code_lines.append("\t_poisson_sum += 1")
			code_lines.append("\t_poisson_product *= %s.randf()" % rng_var)
			code_lines.append("self.%s = _poisson_sum - 1" % sanitized_name)
			if not debug_code.is_empty():
				code_lines.append("print(\"%s - Set %s = %%d\" %% self.%s)" % [debug_msg, sanitized_name, sanitized_name])
		
		"float_constant":
			var float_val = properties.get("float_value", 0.0)
			code_lines.append("self.%s = %.3f" % [sanitized_name, float_val])
			if not debug_code.is_empty():
				code_lines.append("print(\"%s - Set %s = %%0.3f\" %% self.%s)" % [debug_msg, sanitized_name, sanitized_name])
		
		"float_uniform":
			var float_min = properties.get("float_min", 0.0)
			var float_max = properties.get("float_max", 1.0)
			code_lines.append("self.%s = %s.randf_range(%.3f, %.3f)" % [sanitized_name, rng_var, float_min, float_max])
			if not debug_code.is_empty():
				code_lines.append("print(\"%s - Set %s = %%0.3f\" %% self.%s)" % [debug_msg, sanitized_name, sanitized_name])
		
		"float_normal":
			var mean = properties.get("float_mean", 0.0)
			var stddev = properties.get("float_stddev", 1.0)
			code_lines.append("# Normal distribution using Box-Muller transform")
			code_lines.append("var _u1 = %s.randf()" % rng_var)
			code_lines.append("var _u2 = %s.randf()" % rng_var)
			code_lines.append("var _z0 = sqrt(-2.0 * log(_u1)) * cos(2.0 * PI * _u2)")
			code_lines.append("self.%s = %.3f + %.3f * _z0" % [sanitized_name, mean, stddev])
			if not debug_code.is_empty():
				code_lines.append("print(\"%s - Set %s = %%0.3f\" %% self.%s)" % [debug_msg, sanitized_name, sanitized_name])
		
		"float_neg_exp":
			var lambda_exp = properties.get("float_lambda", 1.0)
			code_lines.append("# Negative exponential distribution")
			code_lines.append("var _uniform = %s.randf()" % rng_var)
			code_lines.append("self.%s = -log(1.0 - _uniform) / %.3f" % [sanitized_name, lambda_exp])
			if not debug_code.is_empty():
				code_lines.append("print(\"%s - Set %s = %%0.3f\" %% self.%s)" % [debug_msg, sanitized_name, sanitized_name])
			code_lines.append("# Negative exponential distribution")
			code_lines.append("var _uniform = %s.randf()" % rng_var)
			code_lines.append("self.%s = -log(1.0 - _uniform) / %.3f" % [sanitized_name, lambda_exp])
		
		_:
			code_lines.append("pass # Unknown distribution type")
	
	var result = {
		"actuator_code": "\n".join(code_lines)
	}
	
	if member_vars.size() > 0:
		result["member_vars"] = member_vars
	
	return result
