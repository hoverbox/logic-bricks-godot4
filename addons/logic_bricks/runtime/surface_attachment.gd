extends Node

# One runtime component per body, shared by every Attach/Detach brick.
# Kept as a child so graph state changes cannot discard an active attachment.
var body = null
var surface = null
var attached: bool = false
var follow_surface: bool = true
var allow_movement: bool = false
var local_anchor
var local_normal
var world_anchor
var world_normal
var surface_velocity
var previous_surface_position
var original_freeze: bool = false
var original_freeze_mode: int = 0
var detach_frame: int = -1
var body_properties: Dictionary = {}
var pending_body = null
var pending_options: Dictionary = {}
var pending_time: float = 0.0
var contact_reach: float = 0.2
var balance_path: Path3D = null
var balance_strength: float = 0.0

func _ready() -> void:
	# Finish after the body's generated movement chains.
	process_physics_priority = get_parent().process_physics_priority + 1

func attach(target: Node, options: Dictionary) -> bool:
	if attached or detach_frame == Engine.get_physics_frames():
		return attached
	# Area entry can arrive before the physics body touches the surface.
	# Keep the request briefly so a one-shot Collision trigger can still attach.
	pending_body = target
	pending_options = options.duplicate()
	pending_time = 0.25
	return _try_attach(target, options)

func _try_attach(target: Node, options: Dictionary) -> bool:
	if attached or detach_frame == Engine.get_physics_frames():
		return attached
	if not (target is CharacterBody3D or target is RigidBody3D or target is CharacterBody2D or target is RigidBody2D):
		return false
	var contact = _find_contact(target)
	if contact.is_empty():
		return false # Overlap Areas alone are not physical surfaces.
	body = target
	body_properties.clear()
	for property in body.get_property_list():
		body_properties[str(property.name)] = true
	surface = contact.collider
	world_normal = contact.normal.normalized()
	follow_surface = bool(options.get("follow_surface", true))
	allow_movement = bool(options.get("allow_movement", false))
	balance_path = null
	balance_strength = 0.0
	if body is CharacterBody3D and allow_movement and bool(options.get("balance_assist", false)):
		var path_name = str(options.get("balance_path", "")).strip_edges()
		var guide = body.get_node_or_null(NodePath(path_name)) if not path_name.is_empty() else null
		if guide is Path3D and guide.curve != null and guide.curve.point_count >= 2:
			balance_path = guide
			balance_strength = clampf(float(options.get("balance_strength", 0.75)), 0.0, 1.0)
		else:
			push_warning("Surface Attachment: Balance Assist needs a Path3D with at least two curve points. Attachment will continue without assistance.")
	var rigid = body is RigidBody3D or body is RigidBody2D
	if rigid:
		original_freeze = body.freeze
		original_freeze_mode = body.freeze_mode
		body.freeze_mode = 1 # FREEZE_MODE_KINEMATIC in both dimensions.
		body.freeze = true
		body.linear_velocity *= 0.0
		body.angular_velocity *= 0.0
	else:
		body.velocity *= 0.0
	if rigid and bool(options.get("align_to_surface", false)):
		if body is Node3D:
			var up = Vector3.UP if absf(world_normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
			body.global_basis = Basis.looking_at(-world_normal, up).scaled(body.global_basis.get_scale())
		else:
			body.global_rotation = (-world_normal).angle()
	var offset = maxf(0.0, float(options.get("surface_offset", 0.0)))
	contact_reach = offset + (0.2 if body is Node3D else 4.0)
	body.global_position += world_normal * offset
	world_anchor = body.global_transform
	local_anchor = surface.global_transform.affine_inverse() * world_anchor
	if body is Node3D:
		local_normal = surface.global_basis.inverse() * world_normal
	else:
		local_normal = surface.global_transform.basis_xform_inv(world_normal)
	previous_surface_position = body.global_position
	surface_velocity = world_normal * 0.0
	attached = true
	pending_time = 0.0
	pending_body = null
	body.set_meta("_lb_surface_attached", true)
	return true

func detach(push_off_speed: float = 0.0) -> void:
	detach_frame = Engine.get_physics_frames()
	pending_time = 0.0
	pending_body = null
	if not attached:
		return
	attached = false
	if is_instance_valid(body):
		body.remove_meta("_lb_surface_attached")
		var release_velocity = surface_velocity + world_normal * maxf(0.0, push_off_speed)
		if body is RigidBody3D or body is RigidBody2D:
			body.freeze_mode = original_freeze_mode
			body.freeze = original_freeze
			body.linear_velocity = release_velocity
			body.sleeping = false
		else:
			body.velocity += release_velocity
	surface = null

func _physics_process(delta: float) -> void:
	if not attached:
		if pending_time > 0.0 and is_instance_valid(pending_body):
			pending_time -= delta
			_try_attach(pending_body, pending_options)
		return
	if not is_instance_valid(body) or not is_instance_valid(surface):
		detach()
		return
	var next_anchor = world_anchor
	if follow_surface:
		next_anchor = surface.global_transform * local_anchor
		if body is Node3D:
			world_normal = (surface.global_basis * local_normal).normalized()
		else:
			world_normal = surface.global_transform.basis_xform(local_normal).normalized()
		surface_velocity = (next_anchor.origin - previous_surface_position) / delta if delta > 0.0 else world_normal * 0.0
	else:
		surface_velocity = world_normal * 0.0
	body.global_transform = next_anchor
	if body is CharacterBody3D or body is CharacterBody2D:
		if allow_movement:
			# Motion bricks may accumulate requests rather than writing velocity directly.
			if body is CharacterBody2D and body_properties.has("_logic_brick_character_2d_motion_active"):
				if body.get("_logic_brick_character_2d_motion_active"):
					body.velocity = body.get("_logic_brick_character_2d_target_velocity")
				else:
					body.velocity *= 0.0
			elif body is CharacterBody3D and body_properties.has("_logic_brick_character_use_acceleration"):
				if body.get("_logic_brick_character_use_acceleration"):
					var requested = body.get("_logic_brick_character_target_velocity")
					body.velocity.x = requested.x
					body.velocity.z = requested.z
			# Preserve tangent input while excluding gravity/normal movement.
			body.velocity -= world_normal * body.velocity.dot(world_normal)
			_apply_balance_assist(delta)
			body.move_and_slide()
			var reach = contact_reach
			var collision = KinematicCollision3D.new() if body is CharacterBody3D else KinematicCollision2D.new()
			if not body.test_move(body.global_transform, -world_normal * reach, collision) or collision.get_collider() != surface:
				detach()
				return
		else:
			body.velocity *= 0.0
		world_anchor = body.global_transform
		local_anchor = surface.global_transform.affine_inverse() * world_anchor
	previous_surface_position = body.global_position

func _apply_balance_assist(delta: float) -> void:
	if not body is CharacterBody3D or not is_instance_valid(balance_path) or balance_strength <= 0.0 or delta <= 0.0:
		return
	var curve = balance_path.curve
	if curve == null or curve.point_count < 2:
		return
	# Predict drift before moving so assistance can prevent crossing a narrow edge.
	var predicted = body.global_position + body.velocity * delta
	var local_position = balance_path.to_local(predicted)
	var offset = curve.get_closest_offset(local_position)
	var length = curve.get_baked_length()
	if length <= 0.00001:
		return
	var step = minf(0.05, length * 0.5)
	var before = balance_path.to_global(curve.sample_baked(maxf(0.0, offset - step)))
	var after = balance_path.to_global(curve.sample_baked(minf(length, offset + step)))
	var tangent = after - before
	tangent -= world_normal * tangent.dot(world_normal)
	if tangent.length_squared() <= 0.000001:
		return
	tangent = tangent.normalized()
	var sideways = body.velocity - tangent * body.velocity.dot(tangent)
	sideways -= world_normal * sideways.dot(world_normal)
	body.velocity -= sideways * balance_strength
	predicted = body.global_position + body.velocity * delta
	local_position = balance_path.to_local(predicted)
	var center = balance_path.to_global(curve.get_closest_point(local_position))
	var correction = center - predicted
	# Assist sideways only; preserve surface height and forward/backward control.
	correction -= world_normal * correction.dot(world_normal)
	correction -= tangent * correction.dot(tangent)
	var response = 1.0 - exp(-12.0 * balance_strength * delta)
	body.velocity += correction * response / delta

func _exit_tree() -> void:
	# Pooling/removing the body must not leave it frozen or marked as attached.
	if attached:
		detach()

func _find_contact(target) -> Dictionary:
	var is_3d = target is Node3D
	var directions: Array = []
	if target is CharacterBody3D or target is CharacterBody2D:
		# Prefer walls for characters, while still allowing floors and ceilings.
		var fallback: Dictionary = {}
		for i in range(target.get_slide_collision_count()):
			var hit = target.get_slide_collision(i)
			var collider = hit.get_collider()
			if not _valid_surface(target, collider):
				continue
			var normal = hit.get_normal()
			var probe = KinematicCollision3D.new() if is_3d else KinematicCollision2D.new()
			var reach = 0.15 if is_3d else 3.0
			if not target.test_move(target.global_transform, -normal * reach, probe) or probe.get_collider() != collider:
				continue
			var contact = {"collider": collider, "normal": normal}
			if absf(normal.dot(target.up_direction.normalized())) < 0.7:
				return contact
			fallback = contact
		if not fallback.is_empty():
			return fallback
		if target.velocity.length_squared() > 0.0001:
			directions.append(target.velocity.normalized())
	elif target.linear_velocity.length_squared() > 0.0001:
		directions.append(target.linear_velocity.normalized())
	# Shape sweeps obtain real contact normals without enabling RigidBody contact monitoring.
	# A small reach also covers a Collision Area firing just before physical contact.
	if is_3d:
		directions.append_array([Vector3.FORWARD, Vector3.BACK, Vector3.RIGHT, Vector3.LEFT, Vector3.DOWN, Vector3.UP])
	else:
		directions.append_array([Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP])
	var reach = 0.15 if is_3d else 3.0
	for direction in directions:
		var collision = KinematicCollision3D.new() if is_3d else KinematicCollision2D.new()
		if target.test_move(target.global_transform, direction * reach, collision):
			var collider = collision.get_collider()
			if _valid_surface(target, collider):
				return {"collider": collider, "normal": collision.get_normal()}
	return {}

func _valid_surface(target: Node, collider) -> bool:
	return is_instance_valid(collider) and collider != target and ((target is Node3D and collider is PhysicsBody3D) or (target is Node2D and collider is PhysicsBody2D))
