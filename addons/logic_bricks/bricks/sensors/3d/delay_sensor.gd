@tool

extends "res://addons/logic_bricks/core/logic_brick.gd"

## Delay Sensor - Activates after a delay
## Automatically resets after triggering unless repeat is enabled


func _init() -> void:
	super._init()
	brick_type = BrickType.SENSOR
	brick_name = "Delay"


func _initialize_properties() -> void:
	properties = {
		"delay": 1.0,      # Time in seconds before activating
		"duration": 0.0,   # How long to stay active (0 = one frame)
		"repeat": false    # Keep repeating the delay cycle
	}


func get_property_definitions() -> Array:
	return [
		{
			"name": "delay",
			"type": TYPE_FLOAT,
			"default": 1.0
		},
		{
			"name": "duration",
			"type": TYPE_FLOAT,
			"default": 0.0
		},
		{
			"name": "repeat",
			"type": TYPE_BOOL,
			"default": false
		}
	]


func generate_code(node: Node, chain_name: String) -> Dictionary:
	var delay = properties.get("delay", 1.0)
	var duration = properties.get("duration", 0.0)
	var repeat = properties.get("repeat", false)
	
	var elapsed_var = "_delay_%s_elapsed" % chain_name
	
	var member_vars = [
		"var %s: float = 0.0" % elapsed_var
	]
	
	var code_lines: Array[String] = []
	
	# Simple delay - always resets to 0 after completing cycle
	code_lines.append("# Delay sensor")
	code_lines.append("%s += _delta" % elapsed_var)
	code_lines.append("var sensor_active = false")
	code_lines.append("if %s >= %.2f:" % [elapsed_var, delay])
	code_lines.append("\tsensor_active = true")
	code_lines.append("\t%s = 0.0  # Reset timer" % elapsed_var)
	
	return {
		"sensor_code": "\n".join(code_lines),
		"member_vars": member_vars
	}
