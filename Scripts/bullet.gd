extends RigidBody2D
class_name Bullet

## Bullet projectile spawned from drawing triangles
## Travels in a straight line and deals damage on impact

signal hit_target(body: Node2D, position: Vector2)

@export_group("Bullet Settings")
@export var bullet_speed: float = 800.0
@export var lifetime: float = 5.0  ## Auto-destroy after this many seconds
@export var damage: float = 10.0
@export var pierce_count: int = 0  ## How many targets it can pierce through (0 = destroy on first hit)

@export_group("Explosion Settings")
@export var explosion_radius: float = 100.0
@export var explosion_force: float = 3000.0

# State
var time_alive: float = 0.0
var hits_remaining: int = 0
var direction: Vector2 = Vector2.RIGHT

# Visual components
@onready var sprite: Sprite2D = $Sprite2D
var trail_particles: GPUParticles2D = null


func _ready() -> void:
	# Set up physics
	gravity_scale = 0.0  # Bullets ignore gravity
	mass = 0.1
	linear_damp = 0.0  # No friction/air resistance
	angular_damp = 0.0  # No rotation damping
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY  # Prevent tunneling through objects
	lock_rotation = true  # Don't rotate from physics, only from code
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC  # Don't freeze when off-screen

	# Initialize pierce counter
	hits_remaining = pierce_count + 1  # +1 for initial hit

	# Create trail effect
	setup_trail_particles()

	# Connect collision signal
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# Rotate sprite to match velocity direction
	if linear_velocity.length() > 0:
		rotation = linear_velocity.angle()


func _process(delta: float) -> void:
	# Track lifetime
	time_alive += delta

	# Destroy after lifetime expires
	if time_alive >= lifetime:
		queue_free()


func _on_body_entered(body: Node) -> void:
	# Emit hit signal
	hit_target.emit(body, global_position)

	# Decrement hits remaining
	hits_remaining -= 1

	# Destroy if no hits remaining
	if hits_remaining <= 0:
		create_impact_effect()
		apply_explosion_force()
		queue_free()


func setup_trail_particles() -> void:
	"""Create trailing particle effect"""
	trail_particles = GPUParticles2D.new()
	trail_particles.emitting = true
	trail_particles.amount = 50  # More particles for dramatic effect
	trail_particles.lifetime = 0.2  # Longer trail
	trail_particles.explosiveness = 0.2
	trail_particles.local_coords = false
	trail_particles.process_material = create_trail_material()
	add_child(trail_particles)


func create_trail_material() -> ParticleProcessMaterial:
	"""Create particle material for bullet trail"""
	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.particle_flag_disable_z = true
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 50.0  # Wider spread
	particle_mat.initial_velocity_min = 20.0  # Faster particles
	particle_mat.initial_velocity_max = 50.0
	particle_mat.gravity = Vector3(0, 0, 0)
	particle_mat.damping_min = 50.0  # Less damping = longer visible trail
	particle_mat.damping_max = 100.0
	particle_mat.scale_min = 5.0  # Bigger particles
	particle_mat.scale_max = 7.5

	# Trail color fades out (bright cyan/blue with more vibrant start)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.0, 2.0, 2.5, 1.0))  # Super bright cyan at start
	gradient.add_point(0.3, Color.CYAN)  # Normal cyan
	gradient.add_point(1.0, Color(0.0, 1.0, 1.0, 0.0))  # Fade to transparent
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_mat.color_ramp = gradient_texture

	return particle_mat


func create_impact_effect() -> void:
	"""Create visual effect when bullet hits and is destroyed"""
	var impact_particles = GPUParticles2D.new()
	impact_particles.global_position = global_position
	impact_particles.emitting = true
	impact_particles.one_shot = true
	impact_particles.explosiveness = 1.0
	impact_particles.amount = 15
	impact_particles.lifetime = 0.4
	impact_particles.local_coords = false

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.particle_flag_disable_z = true
	particle_mat.direction = Vector3(-direction.x, -direction.y, 0)  # Bounce back
	particle_mat.spread = 60.0
	particle_mat.initial_velocity_min = 50.0
	particle_mat.initial_velocity_max = 150.0
	particle_mat.gravity = Vector3(0, 0, 0)
	particle_mat.damping_min = 100.0
	particle_mat.damping_max = 200.0
	particle_mat.scale_min = 0.5
	particle_mat.scale_max = 1.5

	# Impact color (cyan/blue)
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.CYAN)
	gradient.add_point(1.0, Color(0.0, 1.0, 1.0, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_mat.color_ramp = gradient_texture

	impact_particles.process_material = particle_mat

	# Add to scene root
	get_tree().root.add_child(impact_particles)

	# Clean up after effect finishes
	await get_tree().create_timer(1.0).timeout
	impact_particles.queue_free()


func apply_explosion_force() -> void:
	"""Apply force to nearby physics objects (same as bomb)"""
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
			var direction_to_body = (body.global_position - global_position).normalized()
			var distance = global_position.distance_to(body.global_position)
			var falloff = 1.0 - (distance / explosion_radius)
			var impulse = direction_to_body * explosion_force * falloff

			# Apply force based on body type
			if body is RigidBody2D:
				body.apply_central_impulse(impulse)
			elif body is CharacterBody2D:
				# For CharacterBody2D (like player), add to velocity directly
				body.velocity += impulse


func initialize(spawn_position: Vector2, fire_direction: Vector2) -> void:
	"""Initialize bullet with position and direction"""
	global_position = spawn_position
	direction = fire_direction.normalized()
	linear_velocity = direction * bullet_speed
	rotation = direction.angle()

	print("Bullet initialized at ", spawn_position, " with velocity ", linear_velocity)
