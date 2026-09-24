@tool
extends RefCounted

const DOC_ROOT := "res://addons/logic_bricks/documentation"

const BRICK_DOCS: Dictionary = {
	"ANDController": {"2d": "controllers-2d.html#controller-controller-gd", "3d": "controllers-3d.html#controller-controller-gd", "ui": "controllers-ui.html#controller-controller-gd"},
	"ActuatorSensor": {"3d": "sensors-3d.html#actuator-3d"},
	"Always2DSensor": {"2d": "sensors-2d.html#always-common", "3d": "sensors-3d.html#always-common", "ui": "sensors-ui.html#always-ui"},
	"AlwaysSensor": {"2d": "sensors-2d.html#always-common", "3d": "sensors-3d.html#always-common", "ui": "sensors-ui.html#always-ui"},
	"Animation2DActuator": {"2d": "actuators-2d.html#sprite-animation-2d"},
	"AnimationActuator": {"2d": "actuators-2d.html#animation-2d", "3d": "actuators-3d.html#animation-3d"},
	"AnimationTreeActuator": {"3d": "actuators-3d.html#animation-state-3d"},
	"AnimationTreeSensor": {"3d": "sensors-3d.html#animation-tree-3d"},
	"Audio2D2DActuator": {"2d": "actuators-2d.html#2d-audio-2d", "3d": "actuators-3d.html#2d-audio-3d", "ui": "actuators-ui.html#2d-audio-ui"},
	"Audio2DActuator": {"2d": "actuators-2d.html#2d-audio-2d", "3d": "actuators-3d.html#2d-audio-3d", "ui": "actuators-ui.html#2d-audio-ui"},
	"ButtonActuator": {"ui": "actuators-ui.html#button-ui"},
	"ButtonSensor": {"ui": "sensors-ui.html#button-ui"},
	"CameraActuator": {"3d": "actuators-3d.html#set-camera-3d"},
	"CameraZoom2DActuator": {"2d": "actuators-2d.html#camera-zoom-2d"},
	"CameraZoomActuator": {"3d": "actuators-3d.html#camera-zoom-3d"},
	"Character2DActuator": {"2d": "actuators-2d.html#character-2d-physics-2d"},
	"CharacterActuator": {"3d": "actuators-3d.html#character-physics-3d"},
	"Collision2DActuator": {"2d": "actuators-2d.html#collisions-2d"},
	"Collision2DSensor": {"2d": "sensors-2d.html#collision-2d-2d"},
	"CollisionActuator": {"3d": "actuators-3d.html#collision-3d"},
	"CollisionSensor": {"3d": "sensors-3d.html#collision-3d"},
	"Controller": {"2d": "controllers-2d.html#controller-controller-gd", "3d": "controllers-3d.html#controller-controller-gd", "ui": "controllers-ui.html#controller-controller-gd"},
	"Delay2DSensor": {"2d": "sensors-2d.html#delay-common", "3d": "sensors-3d.html#delay-common", "ui": "sensors-ui.html#delay-ui"},
	"DelaySensor": {"2d": "sensors-2d.html#delay-common", "3d": "sensors-3d.html#delay-common", "ui": "sensors-ui.html#delay-ui"},
	"EditObjectActuator": {"3d": "actuators-3d.html#edit-object-3d"},
	"EnvironmentActuator": {"3d": "actuators-3d.html#environment-3d"},
	"FocusActuator": {"ui": "actuators-ui.html#focus-ui"},
	"Force2DActuator": {"2d": "actuators-2d.html#force-2d-2d"},
	"ForceActuator": {"3d": "actuators-3d.html#force-3d"},
	"Game2DActuator": {"2d": "actuators-2d.html#game-2d", "3d": "actuators-3d.html#game-3d"},
	"GameActuator": {"2d": "actuators-2d.html#game-2d", "3d": "actuators-3d.html#game-3d"},
	"GetTransformsActuator": {"2d": "actuators-2d.html#get-transforms-2d", "3d": "actuators-3d.html#get-transforms-3d"},
	"GetVariableActuator": {"2d": "actuators-2d.html#get-variable-2d", "3d": "actuators-3d.html#get-variable-3d"},
	"Gravity2DActuator": {"2d": "actuators-2d.html#gravity-2d"},
	"GravityActuator": {"3d": "actuators-3d.html#gravity-3d"},
	"HitStop2DActuator": {"2d": "actuators-2d.html#hit-stop-2d", "3d": "actuators-3d.html#hit-stop-3d"},
	"HitStopActuator": {"2d": "actuators-2d.html#hit-stop-2d", "3d": "actuators-3d.html#hit-stop-3d"},
	"Impulse2DActuator": {"2d": "actuators-2d.html#impulse-2d-2d"},
	"ImpulseActuator": {"3d": "actuators-3d.html#impulse-3d"},
	"InputMap2DSensor": {"2d": "sensors-2d.html#input-map-common", "3d": "sensors-3d.html#input-map-common", "ui": "sensors-ui.html#input-map-ui"},
	"InputMapSensor": {"2d": "sensors-2d.html#input-map-common", "3d": "sensors-3d.html#input-map-common", "ui": "sensors-ui.html#input-map-ui"},
	"Jump2DActuator": {"2d": "actuators-2d.html#character-jump-2d-2d"},
	"JumpActuator": {"3d": "actuators-3d.html#character-jump-3d"},
	"LightActuator": {"3d": "actuators-3d.html#light-3d"},
	"LinearVelocity2DActuator": {"2d": "actuators-2d.html#linear-velocity-2d-2d"},
	"LinearVelocityActuator": {"3d": "actuators-3d.html#linear-velocity-3d"},
	"LocationActuator": {"3d": "actuators-3d.html#motion-3d"},
	"LookAtInputActuator": {"3d": "actuators-3d.html#look-at-input-3d"},
	"LookAtMovementActuator": {"3d": "actuators-3d.html#look-at-movement-3d"},
	"Message2DActuator": {"2d": "actuators-2d.html#signal-2d", "3d": "actuators-3d.html#signal-3d"},
	"Message2DSensor": {"2d": "sensors-2d.html#signal-common", "3d": "sensors-3d.html#signal-common", "ui": "sensors-ui.html#signal-ui"},
	"MessageActuator": {"2d": "actuators-2d.html#signal-2d", "3d": "actuators-3d.html#signal-3d"},
	"MessageSensor": {"2d": "sensors-2d.html#signal-common", "3d": "sensors-3d.html#signal-common", "ui": "sensors-ui.html#signal-ui"},
	"Modulate2DActuator": {"2d": "actuators-2d.html#modulate-2d", "3d": "actuators-3d.html#modulate-3d", "ui": "actuators-ui.html#modulate-ui"},
	"ModulateActuator": {"2d": "actuators-2d.html#modulate-2d", "3d": "actuators-3d.html#modulate-3d", "ui": "actuators-ui.html#modulate-ui"},
	"Motion2DActuator": {"2d": "actuators-2d.html#motion-2d-2d"},
	"MotionActuator": {"3d": "actuators-3d.html#motion-3d"},
	"Mouse2DActuator": {"2d": "actuators-2d.html#mouse-2d"},
	"Mouse2DSensor": {"2d": "sensors-2d.html#mouse-common", "3d": "sensors-3d.html#mouse-common"},
	"MouseActuator": {"3d": "actuators-3d.html#mouse-3d"},
	"MouseSensor": {"2d": "sensors-2d.html#mouse-common", "3d": "sensors-3d.html#mouse-common"},
	"MoveTowards2DActuator": {"2d": "actuators-2d.html#steering-2d"},
	"MoveTowardsActuator": {"3d": "actuators-3d.html#steering-3d"},
	"Movement2DSensor": {"2d": "sensors-2d.html#movement-2d-2d"},
	"MovementSensor": {"3d": "sensors-3d.html#movement-3d"},
	"Music2DActuator": {"2d": "actuators-2d.html#music-2d", "3d": "actuators-3d.html#music-3d"},
	"MusicActuator": {"2d": "actuators-2d.html#music-2d", "3d": "actuators-3d.html#music-3d"},
	"ObjectFlash2DActuator": {"2d": "actuators-2d.html#object-flash-2d"},
	"ObjectFlashActuator": {"3d": "actuators-3d.html#object-flash-3d"},
	"ObjectPoolActuator": {"3d": "actuators-3d.html#object-pool-3d"},
	"ObjectShake2DActuator": {"2d": "actuators-2d.html#object-shake-2d"},
	"ObjectShakeActuator": {"3d": "actuators-3d.html#object-shake-3d"},
	"ParentActuator": {"3d": "actuators-3d.html#parent-3d"},
	"Parent2DActuator": {"2d": "actuators-2d.html#parent-2d"},
	"Physics2DSensor": {"2d": "sensors-2d.html#physics-2d-2d"},
	"PhysicsActuator": {"3d": "actuators-3d.html#physics-3d"},
	"PhysicsSensor": {"3d": "sensors-3d.html#physics-3d"},
	"PopupActuator": {"ui": "actuators-ui.html#popup-ui"},
	"Preload2DActuator": {"2d": "actuators-2d.html#preload-2d", "3d": "actuators-3d.html#preload-3d"},
	"PreloadActuator": {"2d": "actuators-2d.html#preload-2d", "3d": "actuators-3d.html#preload-3d"},
	"ProgressBar2DActuator": {"2d": "actuators-2d.html#progress-bar-2d"},
	"ProgressBarActuator": {"3d": "actuators-3d.html#progress-bar-3d"},
	"Property2DActuator": {"2d": "actuators-2d.html#property-2d", "3d": "actuators-3d.html#property-3d"},
	"PropertyActuator": {"2d": "actuators-2d.html#property-2d", "3d": "actuators-3d.html#property-3d"},
	"Proximity2DSensor": {"2d": "sensors-2d.html#proximity-2d-2d"},
	"ProximitySensor": {"3d": "sensors-3d.html#proximity-3d"},
	"Random2DActuator": {"2d": "actuators-2d.html#random-2d", "3d": "actuators-3d.html#random-3d"},
	"Random2DSensor": {"2d": "sensors-2d.html#random-common", "3d": "sensors-3d.html#random-common", "ui": "sensors-ui.html#random-ui"},
	"RandomActuator": {"2d": "actuators-2d.html#random-2d", "3d": "actuators-3d.html#random-3d"},
	"RandomSensor": {"2d": "sensors-2d.html#random-common", "3d": "sensors-3d.html#random-common", "ui": "sensors-ui.html#random-ui"},
	"Raycast2DSensor": {"2d": "sensors-2d.html#raycast-2d-2d"},
	"RaycastSensor": {"3d": "sensors-3d.html#raycast-3d"},
	"RotateTowards2DActuator": {"2d": "actuators-2d.html#rotate-towards-2d"},
	"RotateTowardsActuator": {"3d": "actuators-3d.html#rotate-towards-3d"},
	"RotationActuator": {"3d": "actuators-3d.html#rotation-3d"},
	"Rumble2DActuator": {"2d": "actuators-2d.html#rumble-2d", "3d": "actuators-3d.html#rumble-3d"},
	"RumbleActuator": {"2d": "actuators-2d.html#rumble-2d", "3d": "actuators-3d.html#rumble-3d"},
	"SaveGameActuator": {"3d": "actuators-3d.html#save-load-3d"},
	"SaveLoad2DActuator": {"2d": "actuators-2d.html#save-load-2d"},
	"SaveLoadActuator": {"3d": "actuators-3d.html#save-load-3d"},
	"ScaleActuator": {"3d": "actuators-3d.html#scale-3d"},
	"Scene2DActuator": {"2d": "actuators-2d.html#scene-2d", "3d": "actuators-3d.html#scene-3d"},
	"SceneActuator": {"2d": "actuators-2d.html#scene-2d", "3d": "actuators-3d.html#scene-3d"},
	"ScreenFlash2DActuator": {"2d": "actuators-2d.html#screen-flash-2d", "3d": "actuators-3d.html#screen-flash-3d", "ui": "actuators-ui.html#screen-flash-ui"},
	"ScreenFlashActuator": {"2d": "actuators-2d.html#screen-flash-2d", "3d": "actuators-3d.html#screen-flash-3d", "ui": "actuators-ui.html#screen-flash-ui"},
	"ScreenShake2DActuator": {"2d": "actuators-2d.html#camera-shake-2d"},
	"ScreenShakeActuator": {"3d": "actuators-3d.html#screen-shake-3d"},
	"ScriptController": {"2d": "controllers-2d.html#script-controller-script-controller-gd", "3d": "controllers-3d.html#script-controller-script-controller-gd", "ui": "controllers-ui.html#script-controller-script-controller-gd"},
	"ScrollActuator": {"ui": "actuators-ui.html#scroll-ui"},
	"Set2DCameraActuator": {"2d": "actuators-2d.html#set-camera-2d"},
	"SetCamera2DActuator": {"2d": "actuators-2d.html#set-camera-2d"},
	"SetCameraActuator": {"3d": "actuators-3d.html#set-camera-3d"},
	"ShaderParamActuator": {"2d": "actuators-2d.html#property-2d", "3d": "actuators-3d.html#property-3d"},
	"SliderActuator": {"ui": "actuators-ui.html#slider-ui"},
	"SmoothFollowCamera2DActuator": {"2d": "actuators-2d.html#smooth-follow-camera-2d"},
	"SmoothFollowCameraActuator": {"3d": "actuators-3d.html#smooth-follow-camera-3d"},
	"SoundActuator": {"3d": "actuators-3d.html#3d-audio-3d"},
	"SplitScreen2DActuator": {"2d": "actuators-2d.html#split-screen-2d"},
	"SplitScreenActuator": {"3d": "actuators-3d.html#split-screen-3d"},
	"SpriteAnimation2DActuator": {"2d": "actuators-2d.html#sprite-animation-2d"},
	"SpriteFramesActuator": {"3d": "actuators-3d.html#sprite-frames-3d"},
	"State2DActuator": {"2d": "actuators-2d.html#state-2d", "3d": "actuators-3d.html#state-3d"},
	"StateActuator": {"2d": "actuators-2d.html#state-2d", "3d": "actuators-3d.html#state-3d"},
	"TabActuator": {"ui": "actuators-ui.html#tab-ui"},
	"Teleport2DActuator": {"2d": "actuators-2d.html#teleport-2d-2d"},
	"TeleportActuator": {"3d": "actuators-3d.html#teleport-3d"},
	"Text2DActuator": {"2d": "actuators-2d.html#text-2d"},
	"TextActuator": {"3d": "actuators-3d.html#text-3d"},
	"ThirdPersonCameraActuator": {"3d": "actuators-3d.html#3rd-person-camera-3d"},
	"TorqueActuator": {"3d": "actuators-3d.html#torque-3d"},
	"TransformsActuator": {"2d": "actuators-2d.html#set-transforms-2d", "3d": "actuators-3d.html#set-transforms-3d"},
	"Tween2DActuator": {"2d": "actuators-2d.html#tween-animation-2d"},
	"TweenActuator": {"2d": "actuators-2d.html#tween-2d", "3d": "actuators-3d.html#tween-3d", "ui": "actuators-ui.html#tween-ui"},
	"UIAlwaysSensor": {"ui": "sensors-ui.html#always-ui"},
	"UIAudio2DActuator": {"ui": "actuators-ui.html#2d-audio-ui"},
	"UIButtonActuator": {"ui": "actuators-ui.html#button-ui"},
	"UIButtonSensor": {"ui": "sensors-ui.html#button-ui"},
	"UIDelaySensor": {"ui": "sensors-ui.html#delay-ui"},
	"UIFocusActuator": {"ui": "actuators-ui.html#focus-ui"},
	"UIInputMapSensor": {"ui": "sensors-ui.html#input-map-ui"},
	"UIMessageSensor": {"ui": "sensors-ui.html#signal-ui"},
	"UIModulateActuator": {"ui": "actuators-ui.html#modulate-ui"},
	"UIPopupActuator": {"ui": "actuators-ui.html#popup-ui"},
	"UIProgressBarActuator": {"ui": "actuators-ui.html#progress-bar-ui"},
	"UIRandomSensor": {"ui": "sensors-ui.html#random-ui"},
	"UIScreenFlashActuator": {"ui": "actuators-ui.html#screen-flash-ui"},
	"UIScrollActuator": {"ui": "actuators-ui.html#scroll-ui"},
	"UISliderActuator": {"ui": "actuators-ui.html#slider-ui"},
	"UITabActuator": {"ui": "actuators-ui.html#tab-ui"},
	"UITextActuator": {"ui": "actuators-ui.html#text-ui"},
	"UITweenActuator": {"ui": "actuators-ui.html#tween-ui"},
	"UIVariableSensor": {"ui": "sensors-ui.html#variable-ui"},
	"UIVisibilityActuator": {"ui": "actuators-ui.html#visibility-ui"},
	"UIWindowActuator": {"ui": "actuators-ui.html#window-ui"},
	"Variable2DActuator": {"2d": "actuators-2d.html#modify-variable-2d", "3d": "actuators-3d.html#modify-variable-3d"},
	"Variable2DSensor": {"2d": "sensors-2d.html#compare-variable-common", "3d": "sensors-3d.html#compare-variable-common"},
	"VariableActuator": {"2d": "actuators-2d.html#modify-variable-2d", "3d": "actuators-3d.html#modify-variable-3d"},
	"VariableSensor": {"2d": "sensors-2d.html#compare-variable-common", "3d": "sensors-3d.html#compare-variable-common"},
	"Visibility2DActuator": {"2d": "actuators-2d.html#visibility-2d", "3d": "actuators-3d.html#visibility-3d", "ui": "actuators-ui.html#visibility-ui"},
	"VisibilityActuator": {"2d": "actuators-2d.html#visibility-2d", "3d": "actuators-3d.html#visibility-3d", "ui": "actuators-ui.html#visibility-ui"},
	"WaypointPath2DActuator": {"2d": "actuators-2d.html#waypoint-path-2d"},
	"WaypointPathActuator": {"3d": "actuators-3d.html#waypoint-path-3d"},
	"WindowActuator": {"ui": "actuators-ui.html#window-ui"},
}

static func open_home() -> void:
	_open_local_page("index.html")

static func open_brick(brick_class: String, domain: String) -> void:
	var entries: Dictionary = BRICK_DOCS.get(brick_class, {})
	var relative_path: String = str(entries.get(domain, ""))
	if relative_path.is_empty():
		for fallback_domain in ["3d", "2d", "ui"]:
			if entries.has(fallback_domain):
				relative_path = str(entries[fallback_domain])
				break
	if relative_path.is_empty():
		relative_path = "brick-reference.html"
	_open_local_page(relative_path)

static func _open_local_page(relative_path: String) -> void:
	var anchor: String = ""
	var file_part: String = relative_path
	var hash_pos: int = relative_path.find("#")
	if hash_pos >= 0:
		file_part = relative_path.substr(0, hash_pos)
		anchor = relative_path.substr(hash_pos)

	var local_path: String = ProjectSettings.globalize_path(DOC_ROOT.path_join(file_part)).replace("\\", "/")
	var target_url: String = _file_url(local_path) + anchor

	# Some desktop file handlers drop a URL fragment when OS.shell_open() is
	# given file:///page.html#section directly. Use a tiny local redirect page
	# when deep-linking so the browser itself applies the fragment reliably.
	var open_url: String = target_url
	if not anchor.is_empty():
		var redirect_path: String = ProjectSettings.globalize_path("user://logic_bricks_doc_jump.html").replace("\\", "/")
		var redirect_file: FileAccess = FileAccess.open(redirect_path, FileAccess.WRITE)
		if redirect_file:
			var escaped_target: String = target_url.replace("&", "&amp;").replace("\"", "&quot;").replace("<", "&lt;").replace(">", "&gt;")
			redirect_file.store_string("<!doctype html><html><head><meta charset=\"utf-8\"><meta http-equiv=\"refresh\" content=\"0; url=" + escaped_target + "\"></head><body><p>Opening Logic Bricks documentation...</p><p><a href=\"" + escaped_target + "\">Continue</a></p></body></html>")
			redirect_file.close()
			open_url = _file_url(redirect_path)

	var err: int = OS.shell_open(open_url)
	if err != OK:
		push_warning("Logic Bricks: Could not open documentation: %s" % open_url)


static func _file_url(local_path: String) -> String:
	var encoded_path: String = local_path.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("\"", "%22")
	var url: String = "file://"
	if not encoded_path.begins_with("/"):
		url += "/"
	return url + encoded_path

