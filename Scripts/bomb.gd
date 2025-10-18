extends RigidBody2D
class_name Bomb

## Bomb projectile spawned from drawing circles
## Explodes after a timer or on impact

signal exploded(position: Vector2)

@export_group("Bomb Settings")
@export var fuse_time: float = 3.0  ## Time before auto-detonation
@export var explosion_radius: float = 150.0
@export var explosion_force: float = 5000.0
@export var player_explosion_multiplier: float = 2.0  ## Extra force multiplier for player
@export var explode_on_impact: bool = false  ## Explode immediately on collision

# State
var fuse_timer: float = 0.0
var has_exploded: bool = false

# Gravity system
var gravity_component: GravityEntity
var is_grounded: bool = false
var gravity_direction: Vector2 = Vector2.DOWN
var ground_coyote_time: float = 0.0

# Visual components
@onready var sprite: Sprite2D = $Sprite2D
var fuse_particles: GPUParticles2D = null


func _ready() -> void:
	# Create gravity component
	gravity_component = GravityEntity.new()
	add_child(gravity_component)

	# Set up physics
	gravity_scale = 0.0  # Use custom planetary gravity, not Godot's default
	mass = 0.2
	# Damping is set dynamically in _physics_process based on grounded state

	# Enable contact monitoring for ground detection
	contact_monitor = true
	max_contacts_reported = 4

	# Create fuse particle effect
	setup_fuse_particles()

	# Start fuse timer
	fuse_timer = fuse_time

	# Connect body collision signal
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if has_exploded:
		return

	# Update primary planet
	gravity_component.update_primary_planet(global_position)

	# Check if grounded (only count collisions with planets, not other bombs)
	var physically_grounded = false
	var colliding_bodies = get_colliding_bodies()
	for body in colliding_bodies:
		# Only consider StaticBody2D (planets) as ground, not other RigidBody2D (bombs/bullets)
		if body is StaticBody2D:
			physically_grounded = true
			break

	# Update is_grounded with coyote time
	if physically_grounded:
		is_grounded = true
		ground_coyote_time = 0.15
	else:
		if ground_coyote_time > 0:
			ground_coyote_time -= delta
			is_grounded = true
		else:
			is_grounded = false

	# Apply high friction when grounded, low when airborne
	if is_grounded:
		linear_damp = 500.0  # Very high friction when on ground
		angular_damp = 500.0
	else:
		linear_damp = 1.0 # Low air resistance when airborne
		angular_damp = 0.0

	# Apply planetary gravity ONLY if physically not touching ground
	# Use physically_grounded, not is_grounded (coyote time would cause issues)
	if not physically_grounded:
		var net_gravity = gravity_component.calculate_grounded_bomb_gravity(global_position, is_grounded)
		if net_gravity.length() > 0:
			gravity_direction = net_gravity.normalized()
			linear_velocity += net_gravity * delta


func _process(delta: float) -> void:
	if has_exploded:
		return

	# Count down fuse
	fuse_timer -= delta

	# Flash faster as timer runs out
	if sprite:
		var flash_speed = 5.0 + (5.0 * (1.0 - fuse_timer / fuse_time))
		var flash = sin(Time.get_ticks_msec() * 0.001 * flash_speed) * 0.5 + 0.5
		sprite.modulate = Color(1.0, flash, flash, 1.0)

	# Detonate when timer runs out
	if fuse_timer <= 0:
		explode()


func _on_body_entered(body: Node) -> void:
	if has_exploded:
		return

	if explode_on_impact:
		explode()


func setup_fuse_particles() -> void:
	"""Create sparking fuse particle effect"""
	fuse_particles = GPUParticles2D.new()
	fuse_particles.emitting = true
	fuse_particles.amount = 20
	fuse_particles.lifetime = 0.5
	fuse_particles.explosiveness = 0.5
	fuse_particles.local_coords = false

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.particle_flag_disable_z = true
	particle_mat.direction = Vector3(0, -1, 0)
	particle_mat.spread = 45.0
	particle_mat.initial_velocity_min = 30.0
	particle_mat.initial_velocity_max = 60.0
	particle_mat.gravity = Vector3(0, 50, 0)
	particle_mat.scale_min = 2.5
	particle_mat.scale_max = 4

	# Orange/yellow sparks
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.ORANGE)
	gradient.add_point(1.0, Color(1.0, 0.5, 0.0, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_mat.color_ramp = gradient_texture

	fuse_particles.process_material = particle_mat
	add_child(fuse_particles)


func explode() -> void:
	"""Trigger explosion"""
	if has_exploded:
		return

	has_exploded = true

	# Hide sprite immediately
	if sprite:
		sprite.visible = false

	# Stop fuse particles
	if fuse_particles:
		fuse_particles.emitting = false

	# Emit signal
	exploded.emit(global_position)

	# Create explosion effect
	create_explosion_effect()

	# Apply force to nearby objects
	apply_explosion_force()

	# Remove bomb immediately (particles are in scene root, so they persist)
	queue_free()


func create_explosion_effect() -> void:
	"""Visual explosion effect"""
	var explosion_particles = GPUParticles2D.new()
	explosion_particles.global_position = global_position
	explosion_particles.emitting = true
	explosion_particles.one_shot = true
	explosion_particles.explosiveness = 0.5
	explosion_particles.amount = 500  # Way more particles
	explosion_particles.lifetime = 0.25  # Last longer
	explosion_particles.local_coords = false

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.particle_flag_disable_z = true
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 100.0  # Faster explosion
	particle_mat.initial_velocity_max = 500.0
	particle_mat.gravity = Vector3(0, 0, 0)
	particle_mat.damping_min = 30.0  # Less damping for more dramatic spread
	particle_mat.damping_max = 60.0
	particle_mat.scale_min = 2.0  # Much bigger particles
	particle_mat.scale_max = 4.0

	# Fiery colors
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.YELLOW)
	gradient.add_point(0.5, Color.ORANGE)
	gradient.add_point(1.0, Color(0.5, 0.0, 0.0, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_mat.color_ramp = gradient_texture

	explosion_particles.process_material = particle_mat

	# Add to scene root so it persists after bomb is deleted
	get_tree().root.add_child(explosion_particles)

	# Clean up after effect finishes (wait longer for all particles to fade)
	await get_tree().create_timer(2.0).timeout
	explosion_particles.queue_free()


func apply_explosion_force() -> void:
	"""Apply force to nearby physics objects"""
	# Get all bodies in the explosion radius
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = explosion_radius
	query.shape = circle_shape
	query.transform = Transform2D(0, global_position)
	query.collide_with_bodies = true

	var results = space_state.intersect_shape(query)

	for result in results:
		var body = result.collider
		if body != self:
			var direction = (body.global_position - global_position).normalized()
			var distance = global_position.distance_to(body.global_position)
			var falloff = 1.0 - (distance / explosion_radius)
			var impulse = direction * explosion_force * falloff

			# Apply force based on body type
			if body is RigidBody2D:
				body.apply_central_impulse(impulse)
				print("Applied impulse to RigidBody2D: ", impulse)
			elif body is CharacterBody2D:
				# For CharacterBody2D (like player), use external_velocity to apply force over time
				var player_impulse = impulse * player_explosion_multiplier
				if body.has_method("apply_external_force"):
					body.apply_external_force(player_impulse)
				else:
					# Fallback: add to external_velocity if it exists
					if "external_velocity" in body:
						body.external_velocity += player_impulse
				print("Applied impulse to player: ", player_impulse)


func initialize(spawn_position: Vector2, initial_velocity: Vector2) -> void:
	"""Initialize bomb with position and velocity"""
	global_position = spawn_position
	linear_velocity = initial_velocity
