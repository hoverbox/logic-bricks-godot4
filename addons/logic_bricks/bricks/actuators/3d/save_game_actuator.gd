@tool
extends "res://addons/logic_bricks/bricks/actuators/3d/save_load_actuator.gd"

## Legacy compatibility shim.
## SaveGameActuator was removed from the public registry/UI; existing Godot
## projects may still have a cached script resource at this path. Keeping this
## no-op subclass prevents File not found errors while old scenes are migrated.
