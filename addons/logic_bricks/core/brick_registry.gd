@tool
extends RefCounted

## Runtime registry for Logic Brick scripts.
##
## New bricks can be added by dropping a single .gd file anywhere under:
##   res://addons/logic_bricks/bricks/sensors/
##   res://addons/logic_bricks/bricks/controllers/
##   res://addons/logic_bricks/bricks/actuators/
##
## Minimum brick file requirements:
##   - extends res://addons/logic_bricks/core/logic_brick.gd
##   - _init() sets brick_type and brick_name
##
## Optional per-brick metadata:
##   func get_brick_info() -> Dictionary:
##       return {
##           "class": "GridMapActuator",
##           "name": "Grid Map",
##           "type": "actuator",
##           "category": "Grid",
##           "description": "Set, clear, or read cells in a GridMap.",
##           "menu_order": 360,
##           "aliases": []
##       }

const BRICK_ROOT := "res://addons/logic_bricks/bricks"

static var _scanned: bool = false
static var _bricks_by_class: Dictionary = {}
static var _bricks_by_type: Dictionary = {"sensor": [], "controller": [], "actuator": []}
static var _aliases: Dictionary = {}
static var _next_menu_id: int = 1000


static var _class_overrides: Dictionary = {
}

static var _legacy_aliases: Dictionary = {
	# Legacy 2D shared bricks now resolve to the common implementation.
	"Always2DSensor": "AlwaysSensor",
	"Delay2DSensor": "DelaySensor",
	"InputMap2DSensor": "InputMapSensor",
	"Message2DSensor": "MessageSensor",
	"Mouse2DSensor": "MouseSensor",
	"Mouse2DActuator": "Mouse2DActuator",
	"Random2DSensor": "RandomSensor",
	"Variable2DSensor": "VariableSensor",
	"Animation2DActuator": "SpriteAnimation2DActuator",
	"Audio2D2DActuator": "Audio2DActuator",
	"Game2DActuator": "GameActuator",
	"HitStop2DActuator": "HitStopActuator",
	"Message2DActuator": "MessageActuator",
	"Modulate2DActuator": "ModulateActuator",
	"Music2DActuator": "MusicActuator",
	"Preload2DActuator": "PreloadActuator",
	"Property2DActuator": "PropertyActuator",
	"Random2DActuator": "RandomActuator",
	"Rumble2DActuator": "RumbleActuator",
	"Scene2DActuator": "SceneActuator",
	"ScreenFlash2DActuator": "ScreenFlashActuator",
	"State2DActuator": "StateActuator",
	"Tween2DActuator": "TweenAnimation2DActuator",
	"Variable2DActuator": "VariableActuator",
	"Visibility2DActuator": "VisibilityActuator",
	# UI Button was briefly serialized from its file name before UI bricks
	# were taught to serialize with their registry class name.
	"ButtonSensor": "UIButtonSensor",
	# UI actuator files serialize from their file names unless the base class
	# uses get_brick_info(). Keep these aliases so saved scenes and metadata
	# written as FocusActuator/ButtonActuator/etc. resolve correctly.
	"FocusActuator": "UIFocusActuator",
	"ButtonActuator": "UIButtonActuator",
	"PopupActuator": "UIPopupActuator",
	"ScrollActuator": "UIScrollActuator",
	"TabActuator": "UITabActuator",
	"SliderActuator": "UISliderActuator",
	"WindowActuator": "UIWindowActuator",
	"ANDController": "Controller",
	"LocationActuator": "MotionActuator",
	"RotationActuator": "MotionActuator",
	# Ghost classes produced by panel_script_rebuild_helper pattern detection.
	# These bricks no longer exist; map to the nearest current equivalent so that
	# "Rebuild from Script" does not write unresolvable class names into metadata.
	"CameraActuator": "SetCameraActuator",
	"Set2DCameraActuator": "SetCamera2DActuator",
	"ShaderParamActuator": "PropertyActuator",
	"SaveGameActuator": "SaveLoadActuator",
}

static var _ui_actuator_whitelist: Array[String] = [
	"AnimationActuator",
	"UIAudio2DActuator",
	"MusicActuator",
	"MessageActuator",
	"StateActuator",
	"PropertyActuator",
	"UIVisibilityActuator",
	"UITextActuator",
	"UIProgressBarActuator",
	"UIModulateActuator",
	"UITweenActuator",
	"UIScreenFlashActuator",
	"GetVariableActuator",
	"VariableActuator",
	"UIFocusActuator",
	"UIButtonActuator",
	"UIPopupActuator",
	"UIScrollActuator",
	"UITabActuator",
	"UISliderActuator",
	"UIWindowActuator",
]

static var _fallback_categories: Dictionary = {
	"MotionActuator": "Motion", "CharacterActuator": "Motion", "JumpActuator": "Motion",
	"LookAtMovementActuator": "Motion", "LookAtInputActuator": "Motion", "RotateTowardsActuator": "Motion",
	"WaypointPathActuator": "Motion", "MoveTowardsActuator": "Motion", "TeleportActuator": "Motion",
	"MouseActuator": "Motion", "Mouse2DActuator": "Motion",
	"PhysicsActuator": "Physics", "ForceActuator": "Physics", "GravityActuator": "Physics",
	"TorqueActuator": "Physics", "LinearVelocityActuator": "Physics", "ImpulseActuator": "Physics",
	"CollisionActuator": "Physics", "EditObjectActuator": "Object", "ObjectPoolActuator": "Object",
	"ParentActuator": "Object", "PropertyActuator": "Object", "VisibilityActuator": "Object",
	"EnvironmentActuator": "Environment", "LightActuator": "Environment", "SetCameraActuator": "Camera",
	"SmoothFollowCameraActuator": "Camera", "CameraZoomActuator": "Camera", "ThirdPersonCameraActuator": "Camera",
	"SetCamera2DActuator": "Camera", "SmoothFollowCamera2DActuator": "Camera", "CameraZoom2DActuator": "Camera",
	"SplitScreenActuator": "Camera", "SoundActuator": "Audio", "Audio2DActuator": "Audio",
	"MusicActuator": "Audio", "ScreenFlashActuator": "Game Feel", "ScreenShakeActuator": "Game Feel",
	"ObjectFlashActuator": "Game Feel", "ObjectShakeActuator": "Game Feel", "HitStopActuator": "Game Feel",
	"RumbleActuator": "Game Feel", "TextActuator": "UI", "ModulateActuator": "UI",
	"ProgressBarActuator": "UI", "TweenActuator": "UI", "StateActuator": "Logic",
	"RandomActuator": "Logic", "MessageActuator": "Logic", "VariableActuator": "Logic",
	"GameActuator": "Game", "SceneActuator": "Game", "SaveLoadActuator": "Game", "PreloadActuator": "Game",
	"AnimationActuator": "Animation", "AnimationTreeActuator": "Animation", "SpriteFramesActuator": "Animation", "SpriteAnimation2DActuator": "Animation", "TweenAnimation2DActuator": "Animation"
}

static func refresh() -> void:
	_scanned = false
	_bricks_by_class.clear()
	_bricks_by_type = {"sensor": [], "controller": [], "actuator": []}
	_aliases.clear()
	_next_menu_id = 1000
	ensure_scanned()

static func ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	_scan_dir(BRICK_ROOT)
	for alias_name in _legacy_aliases.keys():
		var target = _legacy_aliases[alias_name]
		if _bricks_by_class.has(target):
			_aliases[alias_name] = target
			var alias_info: Dictionary = _bricks_by_class[target].duplicate(true)
			alias_info["class"] = alias_name
			alias_info["alias_for"] = target
			_bricks_by_class[alias_name] = alias_info
	for t in _bricks_by_type.keys():
		_bricks_by_type[t].sort_custom(func(a, b):
			var ac: String = str(a.get("category", ""))
			var bc: String = str(b.get("category", ""))
			if ac == bc:
				var ao: int = int(a.get("menu_order", 9999))
				var bo: int = int(b.get("menu_order", 9999))
				if ao == bo:
					return str(a.get("name", "")) < str(b.get("name", ""))
				return ao < bo
			return ac < bc
		)

static func _scan_dir(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var child_path = path.path_join(file_name)
		if dir.current_is_dir():
			_scan_dir(child_path)
		elif file_name.ends_with(".gd"):
			_register_script(child_path)
		file_name = dir.get_next()
	dir.list_dir_end()

static func _register_script(script_path: String) -> void:
	var script = load(script_path)
	if script == null or not script.can_instantiate():
		return
	var instance = script.new()
	if instance == null:
		return
	var info := _build_info_from_instance(instance, script_path)
	if info.is_empty():
		return
	_register_info(info)

static func _build_info_from_instance(instance, script_path: String) -> Dictionary:
	var info: Dictionary = {}
	if instance.has_method("get_brick_info"):
		var custom = instance.call("get_brick_info")
		if typeof(custom) == TYPE_DICTIONARY:
			info = custom.duplicate(true)

	var brick_type := str(info.get("type", ""))
	if brick_type.is_empty():
		brick_type = _infer_type_from_path(script_path)
	if not ["sensor", "controller", "actuator"].has(brick_type):
		return {}

	var brick_class_name: String = str(info.get("class", ""))
	if brick_class_name.is_empty():
		brick_class_name = str(_class_overrides.get(script_path.get_file(), ""))
	if brick_class_name.is_empty():
		brick_class_name = _class_name_from_file(script_path, brick_type)

	var display_name := str(info.get("name", ""))
	if display_name.is_empty():
		var bn = instance.get("brick_name")
		if bn != null:
			display_name = str(bn)
	if display_name.is_empty():
		display_name = _display_name_from_class(brick_class_name)

	var tooltips: Dictionary = {}
	if instance.has_method("get_tooltip_definitions"):
		var tip_defs = instance.call("get_tooltip_definitions")
		if typeof(tip_defs) == TYPE_DICTIONARY:
			tooltips = tip_defs

	var category := str(info.get("category", ""))
	if category.is_empty():
		category = str(_fallback_categories.get(brick_class_name, "General"))
	if brick_type != "actuator" and category == "General":
		category = ""

	var description := str(info.get("description", ""))
	if description.is_empty() and tooltips.has("_description"):
		description = str(tooltips["_description"])

	return {
		"class": brick_class_name,
		"name": display_name,
		"type": brick_type,
		"category": category,
		"description": description,
		"menu_order": int(info.get("menu_order", 9999)),
		"script_path": script_path,
		"menu_id": int(info.get("menu_id", _allocate_menu_id())),
		"aliases": info.get("aliases", []),
		"domain": str(info.get("domain", _infer_domain_from_path(script_path))),
	}

static func _register_info(info: Dictionary) -> void:
	var brick_class_name: String = str(info.get("class", ""))
	var brick_type := str(info.get("type", ""))
	if brick_class_name.is_empty() or brick_type.is_empty():
		return

	# The registry scans every .gd file under bricks/. During refactors, users can
	# temporarily have both an old domain-specific file and the new common file
	# with the same brick class, which used to create duplicate right-click menu
	# entries. Keep the most recently registered script for the class, but remove
	# the older menu entry first. This keeps legacy files from showing duplicate
	# bricks while still allowing saved graphs to resolve through aliases.
	if _bricks_by_class.has(brick_class_name):
		var previous: Dictionary = _bricks_by_class.get(brick_class_name, {})
		var previous_type := str(previous.get("type", ""))
		if _bricks_by_type.has(previous_type):
			var list: Array = _bricks_by_type[previous_type]
			for i in range(list.size() - 1, -1, -1):
				if str(list[i].get("class", "")) == brick_class_name:
					list.remove_at(i)

	_bricks_by_class[brick_class_name] = info
	if _bricks_by_type.has(brick_type):
		_bricks_by_type[brick_type].append(info)
	for alias_name in info.get("aliases", []):
		_aliases[str(alias_name)] = brick_class_name

static func get_script_path(brick_class: String) -> String:
	ensure_scanned()
	var resolved = str(_aliases.get(brick_class, brick_class))
	var info: Dictionary = _bricks_by_class.get(resolved, _bricks_by_class.get(brick_class, {}))
	return str(info.get("script_path", ""))

static func get_brick_info(brick_class: String) -> Dictionary:
	ensure_scanned()
	var resolved = str(_aliases.get(brick_class, brick_class))
	return _bricks_by_class.get(resolved, _bricks_by_class.get(brick_class, {})).duplicate(true)

static func get_bricks_by_type(brick_type: String, domain: String = "") -> Array:
	ensure_scanned()
	var bricks: Array = _bricks_by_type.get(brick_type, [])
	if domain.is_empty():
		return bricks.duplicate(true)
	var filtered: Array = []
	for info in bricks:
		var brick_class := str(info.get("class", ""))
		# 2D uses Sprite Animation and Tween Animation instead of the generic
		# AnimationPlayer/Tween entries from the common folder.
		if domain == "2d" and ["AnimationActuator", "TweenActuator"].has(brick_class):
			continue
		# UI nodes should only restrict the actuator list. Sensors and controllers
		# still need their normal common/UI-compatible entries.
		# This also removes duplicate common/UI actuator entries such as Visibility,
		# Screen Flash, 2D Audio, Modulate, and Tween.
		if brick_type == "actuator" and domain == "ui" and not _ui_actuator_whitelist.has(brick_class):
			continue
		if _is_domain_compatible(str(info.get("domain", "common")), domain):
			filtered.append(info)
	return filtered

static func get_all_bricks(domain: String = "") -> Array:
	ensure_scanned()
	var result: Array = []
	for t in ["sensor", "controller", "actuator"]:
		result.append_array(get_bricks_by_type(t, domain))
	return result

static func _is_domain_compatible(brick_domain: String, target_domain: String) -> bool:
	if brick_domain.is_empty():
		brick_domain = "common"
	if target_domain.is_empty():
		return true
	if brick_domain == "common":
		return true
	return brick_domain == target_domain

static func _infer_type_from_path(path: String) -> String:
	if path.find("/sensors/") >= 0:
		return "sensor"
	if path.find("/controllers/") >= 0:
		return "controller"
	if path.find("/actuators/") >= 0:
		return "actuator"
	return ""


static func _infer_domain_from_path(path: String) -> String:
	if path.find("/ui/") >= 0:
		return "ui"
	if path.find("/2d/") >= 0:
		return "2d"
	if path.find("/3d/") >= 0:
		return "3d"
	return "common"

static func _class_name_from_file(path: String, brick_type: String) -> String:
	var base := path.get_file().get_basename()
	var parts := base.split("_")
	var result := ""
	for p in parts:
		if p.is_empty():
			continue
		result += p.substr(0, 1).to_upper() + p.substr(1)
	if brick_type == "controller" and not result.ends_with("Controller"):
		result += "Controller"
	return result

static func _display_name_from_class(cls_name: String) -> String:
	var s := cls_name
	for suffix in ["Sensor", "Controller", "Actuator"]:
		if s.ends_with(suffix):
			s = s.substr(0, s.length() - suffix.length())
	var out := ""
	for i in range(s.length()):
		var c := s.substr(i, 1)
		if i > 0 and c == c.to_upper() and c != c.to_lower():
			out += " "
		out += c
	return out

static func _allocate_menu_id() -> int:
	_next_menu_id += 1
	return _next_menu_id
