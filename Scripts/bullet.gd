extends RigidBody2D
class_name Bullet

## Bullet projectile spawned from drawing triangles
## Travels in a straight line and deals damage on impact

signal hit_target(body: Node2D, position: Vector2)

@export_group("Bullet Settings")
@export var bullet_speed: float = 800.0
@export var acceleration: float = 1200.0  ## How fast bullet accelerates to max speed
@export var lifetime: float = 5.0  ## Auto-destroy after this many seconds
@export var damage: float = 10.0
@export var pierce_count: int = 0  ## How many targets it can pierce through (0 = destroy on first hit)

@export_group("Homing Settings")
@export var homing_enabled: bool = true  ## Enable homing behavior
@export var homing_strength: float = 3.0  ## How aggressively bullet turns (0-10, higher = sharper turns)
@export var homing_range: float = 800.0  ## Max distance to detect targets (0 = infinite)
@export var homing_delay: float = 0.0  ## Delay before homing activates (seconds)

@export_group("Explosion Settings")
@export var explosion_radius: float = 100.0
@export var explosion_force: float = 150.0
@export var explosion_damage: float = 10.0  ## Damage dealt to enemies in explosion radius
@export var player_impulse_multiplier: float = 200.0

# State
var time_alive: float = 0.0
var hits_remaining: int = 0
var direction: Vector2 = Vector2.RIGHT
var current_speed: float = 0.0  ## Current speed (accelerates from 0 to bullet_speed)

# Homing state
var current_target: Node2D = null
var homing_active: bool = false

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

	# Enable contact monitoring for collision detection
	contact_monitor = true
	max_contacts_reported = 4

	# Initialize pierce counter
	hits_remaining = pierce_count + 1  # +1 for initial hit

	# Create trail effect
	setup_trail_particles()

	# Connect collision signal
	body_entered.connect(_on_body_entered)

	# Play firework sound while flying
	var firework_sound = AudioStreamPlayer.new()
	firework_sound.stream = load("res://Assets/sounds/firework.mp3")
	firework_sound.volume_db = -15.0
	add_child(firework_sound)
	firework_sound.play()


func _physics_process(delta: float) -> void:
	# Accelerate to max speed
	if current_speed < bullet_speed:
		current_speed = min(current_speed + acceleration * delta, bullet_speed)

	# Apply homing behavior
	if homing_enabled and homing_active:
		apply_homing(delta)
	else:
		# If not homing, just accelerate in the initial direction
		linear_velocity = direction * current_speed

	# Rotate sprite to match velocity direction
	if linear_velocity.length() > 0:
		rotation = linear_velocity.angle()


func _process(delta: float) -> void:
	# Track lifetime
	time_alive += delta

	# Activate homing after delay
	if homing_enabled and not homing_active and time_alive >= homing_delay:
		homing_active = true

	# Destroy after lifetime expires
	if time_alive >= lifetime:
		queue_free()


func apply_homing(delta: float) -> void:
	"""Smoothly steer bullet toward nearest enemy"""
	# Update target if current target is invalid or dead
	var target_is_dead = false
	if is_instance_valid(current_target):
		if current_target is SlimeEnemy and current_target.is_dead:
			target_is_dead = true
		elif current_target is UfoEnemy and current_target.is_dead:
			target_is_dead = true

	if not is_instance_valid(current_target) or target_is_dead:
		current_target = find_nearest_enemy()

	# If no valid target, continue straight in initial direction
	if not current_target:
		linear_velocity = direction * current_speed
		return

	# Check if target is within range
	var distance_to_target = global_position.distance_to(current_target.global_position)
	if homing_range > 0 and distance_to_target > homing_range:
		current_target = null
		return

	# Calculate direction to target
	var direction_to_target = (current_target.global_position - global_position).normalized()

	# Get current velocity direction
	var current_direction = linear_velocity.normalized()

	# Smoothly interpolate between current direction and target direction
	var new_direction = current_direction.lerp(direction_to_target, homing_strength * delta)

	# Update velocity with new direction using current_speed (which accelerates)
	linear_velocity = new_direction.normalized() * current_speed


func find_nearest_enemy() -> Node2D:
	"""Find the nearest enemy (SlimeEnemy or UfoEnemy) in the scene"""
	var nearest_enemy: Node2D = null
	var nearest_distance: float = INF

	# Get all nodes in the "enemies" group (SlimeEnemy and UfoEnemy both add themselves to this group)
	var enemies = get_tree().get_nodes_in_group("enemies")

	# Fallback: search all nodes for enemy types if group is empty
	if enemies.is_empty():
		enemies = []
		var all_nodes = get_tree().root.get_children()
		for node in all_nodes:
			_collect_enemies(node, enemies)

	for enemy in enemies:
		var is_valid_target = false
		var is_dead = false

		# Check if it's a valid enemy type and not dead
		if enemy is SlimeEnemy:
			is_valid_target = true
			is_dead = enemy.is_dead
		elif enemy is UfoEnemy:
			is_valid_target = true
			is_dead = enemy.is_dead

		if is_valid_target and not is_dead:
			var distance = global_position.distance_to(enemy.global_position)

			# Check range limit
			if homing_range > 0 and distance > homing_range:
				continue

			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy

	return nearest_enemy


func _collect_enemies(node: Node, enemies_array: Array) -> void:
	"""Recursively collect all enemy nodes (SlimeEnemy and UfoEnemy)"""
	if node is SlimeEnemy or node is UfoEnemy:
		enemies_array.append(node)

	for child in node.get_children():
		_collect_enemies(child, enemies_array)


func _on_body_entered(body: Node) -> void:
	# Emit hit signal
	hit_target.emit(body, global_position)

	# Always destroy on contact with anything (planet, enemy, etc.)
	create_impact_effect()
	apply_explosion_force()
	queue_free()
	# Decrement hits remaining
	hits_remaining -= 1

	# Destroy if no hits remaining
	if hits_remaining <= 0:
		# Play gun sound on impact
		var gun_sound = AudioStreamPlayer.new()
		gun_sound.stream = load("res://Assets/sounds/gun.mp3")
		gun_sound.volume_db = -10.0
		get_tree().root.add_child(gun_sound)
		gun_sound.play()
		# Clean up sound after it finishes
		gun_sound.finished.connect(gun_sound.queue_free)

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
	"""Apply force to nearby physics objects and damage enemies"""
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
				# Don't damage other bullets or bombs, only enemies
				if not body is Bullet and not body is Bomb:
					body.apply_central_impulse(impulse)

					# Deal damage to enemies (SlimeEnemy is a RigidBody2D)
					if body.has_method("take_damage"):
						var damage_to_deal = explosion_damage * falloff
						body.take_damage(damage_to_deal)
			elif body is CharacterBody2D:
				# For CharacterBody2D (like player), add to velocity directly
				body.velocity += impulse * player_impulse_multiplier


func initialize(spawn_position: Vector2, fire_direction: Vector2) -> void:
	"""Initialize bullet with position and direction"""
	global_position = spawn_position
	direction = fire_direction.normalized()
	current_speed = 0.0  # Start at zero speed
	linear_velocity = Vector2.ZERO  # Start with no velocity
	rotation = direction.angle()

	print("Bullet initialized at ", spawn_position, " - will accelerate to ", bullet_speed)
