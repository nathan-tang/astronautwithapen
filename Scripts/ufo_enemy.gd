extends RigidBody2D
class_name UfoEnemy

## UFO enemy that orbits planets and drops slime enemies via tractor beam
## Spawns with a scale-up animation and maintains orbital movement

signal died(position: Vector2)
signal slime_dropped(slime: SlimeEnemy)

@export_group("Enemy Settings")
@export var max_health: float = 50.0
@export var orbital_speed: float = 100.0  ## Speed while orbiting
@export var orbital_distance: float = 200.0  ## Distance from planet surface to orbit
@export var death_particle_count: int = 40

@export_group("Spawn Animation")
@export var spawn_duration: float = 1.5  ## Time to scale from small to full size
@export var spawn_start_scale: float = 0.1  ## Starting scale (very small)

@export_group("Slime Drop Settings")
@export var drop_cooldown: float = 5.0  ## Time between slime drops
@export var drop_chance: float = 0.3  ## Chance to drop when cooldown ready
@export var beam_duration: float = 1.0  ## How long the beam shows before dropping slime
@export var slime_scene: PackedScene = preload("res://Scenes/slime_enemy.tscn")

# State
var current_health: float = 50.0
var is_dead: bool = false
var is_spawning: bool = true
var spawn_timer: float = 0.0

# Orbital movement
var target_planet: Planet = null
var orbital_angle: float = 0.0  ## Current angle around planet
var gravity_component: GravityEntity

# Slime dropping
var drop_timer: float = 0.0
var is_showing_beam: bool = false
var beam_timer: float = 0.0

# Visual components
@onready var sprite: Sprite2D = $Sprite2D
@onready var beam_sprite: Sprite2D = $BeamSprite

func _ready() -> void:
	# Add to enemies group
	add_to_group("enemies")

	# Create gravity component
	gravity_component = GravityEntity.new()
	add_child(gravity_component)

	# Initialize health
	current_health = max_health

	# Set up physics
	gravity_scale = 0.0  # Use custom gravity
	mass = 1.0
	linear_damp = 2.0

	# Enable contact monitoring
	contact_monitor = true
	max_contacts_reported = 4

	# Connect signals
	body_entered.connect(_on_body_entered)

	# Start spawn animation
	scale = Vector2(spawn_start_scale, spawn_start_scale)
	is_spawning = true
	spawn_timer = 0.0

	# Find nearest planet to orbit
	_find_target_planet()

	# Initialize orbital angle based on current position
	if target_planet:
		var to_ufo = global_position - target_planet.global_position
		orbital_angle = to_ufo.angle()

	# Hide beam initially
	if beam_sprite:
		beam_sprite.visible = false

	# Random initial drop timer
	drop_timer = randf_range(0.0, drop_cooldown)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Handle spawn animation
	if is_spawning:
		spawn_timer += delta
		var progress = clamp(spawn_timer / spawn_duration, 0.0, 1.0)

		# Ease-out interpolation for smooth scaling
		var ease_progress = 1.0 - pow(1.0 - progress, 3.0)
		var current_scale = lerp(spawn_start_scale, 1.0, ease_progress)
		scale = Vector2(current_scale, current_scale)

		if spawn_timer >= spawn_duration:
			is_spawning = false
			scale = Vector2.ONE

		# Don't do other behaviors while spawning
		return

	# Update primary planet
	gravity_component.update_primary_planet(global_position)

	# Find target planet if we don't have one
	if not target_planet or not is_instance_valid(target_planet):
		_find_target_planet()

	# Orbital movement around target planet
	if target_planet:
		_update_orbital_movement(delta)

	# Handle slime dropping
	_update_slime_drop(delta)


func _find_target_planet() -> void:
	"""Find the nearest planet to orbit"""
	var planets = get_tree().get_nodes_in_group("planets")

	if planets.is_empty():
		return

	var nearest_planet: Planet = null
	var nearest_distance := INF

	for planet in planets:
		if not is_instance_valid(planet) or not planet is Planet:
			continue

		var distance = global_position.distance_to(planet.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_planet = planet

	target_planet = nearest_planet


func _update_orbital_movement(delta: float) -> void:
	"""Move in orbit around the target planet"""
	if not target_planet:
		return

	# Calculate desired orbital radius (planet radius + orbital distance)
	var desired_radius = target_planet.planet_radius + orbital_distance

	# Update orbital angle
	# Angular velocity = linear velocity / radius
	var angular_velocity = orbital_speed / desired_radius
	orbital_angle += angular_velocity * delta

	# Calculate target position on orbit
	var orbit_offset = Vector2(cos(orbital_angle), sin(orbital_angle)) * desired_radius
	var target_position = target_planet.global_position + orbit_offset

	# Smoothly move towards orbital position
	var to_target = target_position - global_position
	var distance_to_target = to_target.length()

	# Use stronger force when far from orbit, gentler when close
	var force_strength = clamp(distance_to_target * 0.5, 0.0, 200.0)
	var correction_force = to_target.normalized() * force_strength

	# Apply the correction force
	linear_velocity = linear_velocity.lerp(correction_force, 0.1)

	# Rotate UFO to face the planet (beam pointing toward planet)
	var to_planet = target_planet.global_position - global_position
	rotation = to_planet.angle() - PI / 2.0  # Subtract 90 degrees so sprite bottom (beam) points to planet


func _update_slime_drop(delta: float) -> void:
	"""Handle slime dropping mechanic"""
	if is_showing_beam:
		beam_timer += delta

		if beam_timer >= beam_duration:
			# Beam finished, hide it
			is_showing_beam = false
			beam_timer = 0.0
			if beam_sprite:
				beam_sprite.visible = false
	else:
		drop_timer += delta

		if drop_timer >= drop_cooldown:
			# Cooldown ready, check if we should drop
			if randf() < drop_chance:
				_start_beam()

			# Reset timer
			drop_timer = 0.0


func _start_beam() -> void:
	"""Start showing the tractor beam and spawn slime immediately"""
	is_showing_beam = true
	beam_timer = 0.0

	if beam_sprite:
		beam_sprite.visible = true

	# Drop slime immediately when beam appears
	_drop_slime()


func _drop_slime() -> void:
	"""Drop a slime enemy below the UFO"""
	if not slime_scene:
		push_warning("UfoEnemy: No slime scene assigned!")
		return

	# Instantiate slime
	var slime = slime_scene.instantiate()
	if not slime:
		push_error("UfoEnemy: Failed to instantiate slime!")
		return

	# Position slime below UFO (in direction of target planet)
	var drop_offset = Vector2.ZERO
	if target_planet:
		var to_planet = (target_planet.global_position - global_position).normalized()
		drop_offset = to_planet * 40.0  # Drop 40 pixels towards planet
	else:
		drop_offset = Vector2.DOWN * 40.0  # Default downward

	slime.global_position = global_position + drop_offset

	# Add to scene
	get_tree().root.add_child(slime)

	# Emit signal
	slime_dropped.emit(slime)

	print("UFO dropped slime at ", slime.global_position)


func _on_body_entered(body: Node) -> void:
	if is_dead:
		return

	# Ignore collisions with slimes
	if body is SlimeEnemy:
		return

	# Check if hit by bullet
	if body.has_method("get_class") and body.get_class() == "Bullet":
		if body.has("damage"):
			take_damage(body.damage)
		return

	# Check if body is Bullet class
	var bullet_script = load("res://Scripts/bullet.gd")
	if bullet_script and body.get_script() == bullet_script:
		if body.has("damage"):
			take_damage(body.damage)
		return


func take_damage(amount: float) -> void:
	if is_dead:
		return

	current_health -= amount

	# Visual feedback
	_flash_red()

	# Check if dead
	if current_health <= 0:
		die()


func _flash_red() -> void:
	"""Flash sprite red briefly for damage feedback"""
	if not sprite:
		return

	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout

	if is_instance_valid(self) and is_instance_valid(sprite) and not is_dead:
		sprite.modulate = Color.WHITE


func die() -> void:
	if is_dead:
		return

	is_dead = true
	died.emit(global_position)

	# Create death effect
	create_death_effect()

	# Remove from scene
	await get_tree().create_timer(0.1).timeout
	queue_free()


func create_death_effect() -> void:
	"""Create particle effect when UFO dies"""
	var death_particles = GPUParticles2D.new()
	death_particles.global_position = global_position
	death_particles.emitting = true
	death_particles.one_shot = true
	death_particles.explosiveness = 1.0
	death_particles.amount = death_particle_count
	death_particles.lifetime = 1.0
	death_particles.local_coords = false

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.particle_flag_disable_z = true
	particle_mat.direction = Vector3(0, -1, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 100.0
	particle_mat.initial_velocity_max = 250.0
	particle_mat.gravity = Vector3(0, 200, 0)
	particle_mat.damping_min = 50.0
	particle_mat.damping_max = 100.0
	particle_mat.scale_min = 1.0
	particle_mat.scale_max = 2.0

	# Metallic silver/grey color for UFO
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 0.8, 0.9, 1.0))  # Light silver
	gradient.add_point(0.5, Color(0.5, 0.5, 0.6, 1.0))  # Medium grey
	gradient.add_point(1.0, Color(0.3, 0.3, 0.3, 0.0))  # Dark grey, fade out
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_mat.color_ramp = gradient_texture

	death_particles.process_material = particle_mat

	# Add to scene root
	get_tree().root.add_child(death_particles)

	# Clean up after effect finishes
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(death_particles):
		death_particles.queue_free()
