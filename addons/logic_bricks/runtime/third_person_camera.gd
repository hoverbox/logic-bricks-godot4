extends RefCounted

## The camera behind the 3rd Person Camera brick.
##
## The brick's generated code makes one of these, sets the settings that
## differ from the defaults below, calls setup() once and update() every frame:
##
##     camera = preload("res://addons/logic_bricks/runtime/third_person_camera.gd").new()
##     camera.sensitivity_x = 0.5
##     camera.setup(self, "CameraPivot", "Camera3D")
##     ...
##     camera.update(delta)
##
## The pivot (a Node3D near the character's head) follows the character and is
## turned by the mouse and/or a gamepad stick. The camera keeps its starting
## offset from the pivot, so it orbits around it. Pivot and camera are found by
## name anywhere in the scene, so the camera can live inside a SubViewport
## (split screen) or anywhere else.
##
## Avoid Walls: a SpringArm3D ("LogicBricksCameraArm") is added under the pivot,
## pointing at the camera. It reports how far it can reach before hitting a wall
## (ignoring the character's own colliders), and the camera is placed there, so
## walls never come between the camera and the player.

# ── Settings (the brick's fields) ────────────────────────────────────────────
var use_mouse := true
var use_joystick := false
var capture_mouse := true            # capture the cursor when the camera starts
var release_mouse_escape := true     # Escape frees the cursor
var recapture_mouse_click := true    # left-click captures it again
var sensitivity_x := 0.3
var sensitivity_y := 0.3
var invert_x := false
var invert_y := false
var pitch_min := -60.0               # degrees, looking down
var pitch_max := 30.0                # degrees, looking up
var joystick_device := 0
var joy_axis_x := 2                  # 2/3 = right stick, 0/1 = left stick
var joy_axis_y := 3
var joy_deadzone := 0.15
var joy_sensitivity := 100.0         # degrees per second at full tilt
var smooth_physics_motion := true    # follow the character's interpolated position
var avoid_walls := false
var camera_distance := 0.0           # 0 = keep the distance the camera has in the scene
var collision_mask := 1
var collision_margin := 0.2
var probe_radius := 0.25             # sphere swept toward the camera; 0 = thin ray
var return_smoothing := 0.3          # seconds to ease back out; 0 = snap
var narrow_obstacle_width := 1.0     # pillars narrower than this don't pull it in; 0 = off

# ── Nodes and state ─────────────────────────────────────────────────────────
var character: Node3D
var pivot: Node3D
var camera: Camera3D
var arm: SpringArm3D
var yaw := 0.0
var pitch := 0.0
var pivot_offset := Vector3.ZERO     # character -> pivot
var camera_offset := Vector3.ZERO    # pivot -> camera, in the pivot's own space
var _arm_distance := -1.0
var _arm_exclude: Array[RID] = []
var _arm_skipped := PackedVector2Array()  # obstacles looked past (from, to)
var _mouse_delta := Vector2.ZERO


## Find the pivot and camera, remember where they start, and add the wall arm.
func setup(owner: Node3D, pivot_name: String, camera_name: String) -> void:
	character = owner
	var found = _find_in_scene(pivot_name)
	if found is Node3D:
		pivot = found
	found = _find_in_scene(camera_name)
	if found is Camera3D:
		camera = found
	if not pivot:
		push_warning("3rd Person Camera: no Node3D named '%s' was found for the pivot" % pivot_name)
	if not camera:
		push_warning("3rd Person Camera: no Camera3D named '%s' was found" % camera_name)
	if pivot:
		yaw = pivot.global_rotation_degrees.y
		pitch = pivot.global_rotation_degrees.x
		pivot_offset = pivot.global_position - character.global_position
		if camera:
			camera_offset = pivot.global_basis.inverse() * (camera.global_position - pivot.global_position)
	if avoid_walls and pivot and camera:
		_make_arm()
	if smooth_physics_motion:
		# The character is drawn between physics ticks; the pivot and camera are
		# moved every rendered frame, so they must not be interpolated themselves.
		if not character.get_tree().physics_interpolation:
			push_warning("3rd Person Camera: turn on Project Settings > Physics > Common > Physics Interpolation (Apply Code does this) for smooth motion.")
		if pivot:
			pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		if camera:
			camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	if use_mouse and capture_mouse:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func make_current() -> void:
	if camera:
		camera.make_current()


## Collect mouse motion; call from _input().
func input(event: InputEvent) -> void:
	if use_mouse and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_delta += event.relative


## Turn the pivot from input, follow the character, and place the camera.
func update(delta: float) -> void:
	if not pivot:
		return
	if use_mouse:
		if release_mouse_escape and Input.is_key_pressed(KEY_ESCAPE) and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif recapture_mouse_click and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			# 0.06 keeps the original feel: the same turn per pixel as at 60 fps.
			yaw -= _mouse_delta.x * sensitivity_x * 0.06 * (-1.0 if invert_x else 1.0)
			pitch -= _mouse_delta.y * sensitivity_y * 0.06 * (-1.0 if invert_y else 1.0)
		_mouse_delta = Vector2.ZERO
	if use_joystick:
		var jx := Input.get_joy_axis(joystick_device, joy_axis_x)
		var jy := Input.get_joy_axis(joystick_device, joy_axis_y)
		if abs(jx) > joy_deadzone:
			yaw -= jx * joy_sensitivity * delta * (-1.0 if invert_x else 1.0)
		if abs(jy) > joy_deadzone:
			pitch -= jy * joy_sensitivity * delta * (-1.0 if invert_y else 1.0)
	pitch = clampf(pitch, pitch_min, pitch_max)

	# Move and turn the pivot in world space, so the hierarchy doesn't matter.
	if smooth_physics_motion:
		pivot.global_position = character.get_global_transform_interpolated().origin + pivot_offset
	else:
		pivot.global_position = character.global_position + pivot_offset
	pivot.global_rotation_degrees.y = yaw
	pivot.global_rotation_degrees.x = pitch

	if not camera:
		return
	if arm:
		camera.global_position = arm.global_position + arm.global_basis.z.normalized() * _wall_distance(delta)
	else:
		camera.global_position = pivot.global_position + pivot.global_basis * camera_offset
	if camera.global_position.distance_squared_to(pivot.global_position) > 0.000001:
		camera.look_at(pivot.global_position, Vector3.UP)


# ── Avoid Walls ──────────────────────────────────────────────────────────────

func _make_arm() -> void:
	arm = SpringArm3D.new()
	arm.name = "LogicBricksCameraArm"
	arm.collision_mask = collision_mask
	_apply_arm_settings()
	var dir := camera_offset.normalized() if camera_offset.length() > 0.01 else Vector3.BACK
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	arm.basis = Basis.looking_at(-dir, up)  # the arm casts along its +Z axis
	# Ignore the character's own colliders.
	if character is CollisionObject3D:
		arm.add_excluded_object((character as CollisionObject3D).get_rid())
		_arm_exclude.append((character as CollisionObject3D).get_rid())
	for body in character.find_children("*", "CollisionObject3D", true, false):
		arm.add_excluded_object(body.get_rid())
		_arm_exclude.append(body.get_rid())
	pivot.add_child(arm)
	arm.set_meta("lb_ready_physics_frame", Engine.get_physics_frames())


## Length, margin and probe shape, kept in step with the settings (a setting
## driven by a variable can change while the game runs).
func _apply_arm_settings() -> void:
	var length := maxf(0.0, camera_distance)
	arm.spring_length = length if length > 0.0 else (camera_offset.length() if camera_offset.length() > 0.01 else 4.0)
	arm.margin = maxf(0.0, collision_margin)
	var radius := maxf(0.0, probe_radius)
	if radius <= 0.0:
		arm.shape = null
	elif not arm.shape is SphereShape3D or (arm.shape as SphereShape3D).radius != radius:
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		arm.shape = sphere


## How far along the arm the camera sits this frame: in at once when something
## blocks the view, easing back out when it clears.
func _wall_distance(delta: float) -> float:
	_apply_arm_settings()
	var narrow := maxf(0.0, narrow_obstacle_width)
	var hit := arm.get_hit_length()
	# The arm reports 0 until its first physics update; use the full length until then.
	if Engine.get_physics_frames() <= int(arm.get_meta("lb_ready_physics_frame", -1)):
		hit = arm.spring_length
	elif hit < arm.spring_length - 0.01 and narrow > 0.0:
		var clear := _ignore_narrow(narrow, maxf(0.0, probe_radius))
		if clear >= 0.0:
			hit = clear
	var smoothing := maxf(0.0, return_smoothing)
	if _arm_distance < 0.0 or hit < _arm_distance or smoothing <= 0.0:
		_arm_distance = hit
	else:
		_arm_distance = lerpf(_arm_distance, hit, 1.0 - exp(-delta / smoothing))
	# Easing back out through a pillar it looked past: jump past it instead.
	if narrow > 0.0 and _arm_distance < hit and _in_skipped(_arm_distance, maxf(maxf(0.0, probe_radius), 0.1)):
		_arm_distance = hit
	return _arm_distance


## Narrow Obstacle Width: pillars, posts and trees should not pull the camera
## in when they pass between it and the player. When the line of sight is
## blocked, parallel rays a little to the left and right test whether the view
## gets around the obstacle within that width. Works for any collider, including
## one mesh collider for a whole room. The camera never rests inside something
## it looked past. Returns the camera distance, or -1 to keep the arm's.
func _ignore_narrow(max_width: float, radius: float) -> float:
	_arm_skipped.clear()
	var space := arm.get_world_3d().direct_space_state
	var from := arm.global_position
	var dir := arm.global_basis.z.normalized()
	var side := arm.global_basis.x.normalized()
	var length := arm.spring_length
	var to := from + dir * length
	var origin := from
	var stop := length
	for attempt in 6:
		var hit := _ray(space, origin, to)
		if hit.is_empty():
			break
		var point: Vector3 = hit["position"]
		var d := (point - from).dot(dir)
		if not _is_narrow(space, from, dir, side, length, d, point, hit["normal"], max_width):
			if attempt == 0:
				return -1.0
			stop = maxf(0.0, d - radius - arm.margin)
			break
		# Where the line of sight leaves it: look back at it from beyond its far
		# side (an obstacle narrower than max_width is not much deeper). This may
		# be past the camera spot, so a camera spot inside it is caught too.
		# Rays that start inside a mesh collider would hit it from within.
		var past := d + max_width + 0.1
		var back := _ray(space, from + dir * past, point - dir * 0.01)
		var exit_d: float = (back["position"] - from).dot(dir) if not back.is_empty() else past
		exit_d = maxf(d, exit_d)
		_arm_skipped.append(Vector2(d, exit_d))
		origin = from + dir * (exit_d + 0.02)
	# Never rest inside (or touching) something that was looked past.
	for i in range(_arm_skipped.size() - 1, -1, -1):
		if stop + radius > _arm_skipped[i].x and stop - radius < _arm_skipped[i].y:
			stop = maxf(0.0, _arm_skipped[i].x - radius - arm.margin)
	if _arm_skipped.is_empty() and _spot_touches(space, from + dir * stop, radius):
		return -1.0
	return stop


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a, b, arm.collision_mask, _arm_exclude)
	query.hit_back_faces = false
	return space.intersect_ray(query)


## True when parallel lanes to the left and right get past the obstacle with
## less than max_width between them.
func _is_narrow(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, side: Vector3, length: float, d: float, point: Vector3, normal: Vector3, max_width: float) -> bool:
	var step := max_width / 8.0
	var left := INF
	var right := INF
	for k in range(1, 9):
		var offset := step * k
		if minf(left, right) < INF and minf(left, right) + offset > max_width:
			return false  # one side got past, the other cannot within the width
		if left == INF and _lane_clear(space, from, from - side * offset, dir, length, d, point, normal, max_width):
			left = offset
		if right == INF and _lane_clear(space, from, from + side * offset, dir, length, d, point, normal, max_width):
			right = offset
		if left + right <= max_width:
			return true
	return false


func _lane_clear(space: PhysicsDirectSpaceState3D, from: Vector3, start: Vector3, dir: Vector3, length: float, d: float, point: Vector3, normal: Vector3, max_width: float) -> bool:
	if not _ray(space, from, start).is_empty():
		return false  # the lane starts behind a wall next to the player
	var hit := _ray(space, start, start + dir * length)
	if hit.is_empty():
		return true
	var hit_point: Vector3 = hit["position"]
	if (hit_point - start).dot(dir) < d + clampf(max_width * 0.5, 0.3, 1.0):
		return false  # still blocked around the same depth
	# The same flat wall seen at a slant is not a way around it.
	return not (absf((hit_point - point).dot(normal)) < 0.05 and (hit["normal"] as Vector3).dot(normal) > 0.95)


func _spot_touches(space: PhysicsDirectSpaceState3D, spot: Vector3, radius: float) -> bool:
	if radius <= 0.0:
		return false
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var overlap := PhysicsShapeQueryParameters3D.new()
	overlap.shape = sphere
	overlap.transform = Transform3D(Basis(), spot)
	overlap.collision_mask = arm.collision_mask
	overlap.exclude = _arm_exclude
	return not space.intersect_shape(overlap, 1).is_empty()


func _in_skipped(distance: float, radius: float) -> bool:
	for block in _arm_skipped:
		if distance + radius > block.x and distance - radius < block.y:
			return true
	return false


func _find_in_scene(target_name: String) -> Node:
	if target_name.is_empty() or character == null:
		return null
	var tree := character.get_tree()
	var found := _find_by_name(tree.current_scene, target_name) if tree.current_scene else null
	return found if found else _find_by_name(tree.root, target_name)


func _find_by_name(node: Node, target_name: String) -> Node:
	if node == null:
		return null
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_by_name(child, target_name)
		if found:
			return found
	return null
