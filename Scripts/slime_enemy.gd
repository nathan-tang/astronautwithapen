extends RigidBody2D
class_name SlimeEnemy

## Slime enemy that is affected by gravity and can be damaged by player attacks
## Can be destroyed by bullets and bombs

signal died(position: Vector2)
signal damaged(amount: float, position: Vector2)

@export_group("Enemy Settings")
@export var max_health: float = 60.0  ## Can withstand 3 hits at 20 damage each
@export var patrol_speed: float = 80.0
@export var patrol_direction: int = 1  ## 1 for right, -1 for left
@export var death_particle_count: int = 30
@export var edge_detection_distance: float = 40.0  ## Distance to check for edges
@export var contact_damage: float = 10.0  ## Damage dealt to player on contact
@export var contact_damage_cooldown: float = 0.5  ## Seconds between contact damage
@export var upward_movement_bias: float = 0.15  ## How much to move away from surface (helps climb curves)

@export_group("Movement Style")
@export var scoot_enabled: bool = true  ## Enable scooting/pulsing movement
@export var scoot_cycle_time: float = 2.0  ## Total time for scoot cycle (pause + scoots)
@export var scoot_count: int = 2  ## Number of scoots per cycle
@export var scoot_burst_duration: float = 0.6  ## Duration of each scoot burst (long slow drag)
@export var scoot_strength: float = 1.8  ## Multiplier for scoot speed boost (gentle drag)

@export_group("Rest Behavior")
@export var enable_resting: bool = true  ## Whether slime occasionally stops to rest
@export var min_walk_time: float = 2.0  ## Minimum time to walk before resting
@export var max_walk_time: float = 5.0  ## Maximum time to walk before resting
@export var min_rest_time: float = 1.0  ## Minimum rest duration
@export var max_rest_time: float = 3.0  ## Maximum rest duration

@export_group("Rotation")
@export var rotation_speed: float = 5.0  ## How fast slime rotates to match gravity
@export var rotation_smoothing: float = 0.1  ## Lower = smoother rotation

@export_group("Planet Attack")
@export var planet_attack_damage: float = 10.0  ## Damage dealt to planet
@export var planet_attack_interval_min: float = 5.0  ## Minimum time between attacks
@export var planet_attack_interval_max: float = 15.0  ## Maximum time between attacks
@export var planet_attack_charge_time: float = 3.0  ## Windup time before attack

# State
var current_health: float = 60.0
var is_dead: bool = false

# Planet attack state
var nearest_planet: Planet = null
var planet_attack_timer: float = 0.0
var is_charging_attack: bool = false
var charge_timer: float = 0.0
var original_sprite_modulate: Color = Color.WHITE

# Gravity system
var gravity_component: GravityEntity
var is_grounded: bool = false
var gravity_direction: Vector2 = Vector2.DOWN
var ground_coyote_time: float = 0.0
var ground_normal: Vector2 = Vector2.UP  ## Actual surface normal from collision

# Patrol state
var stuck_timer: float = 0.0
var last_position: Vector2 = Vector2.ZERO
var stuck_threshold: float = 1.0  ## If stuck for this long, turn around
var is_resting: bool = false
var rest_timer: float = 0.0
var walk_timer: float = 0.0
var next_rest_time: float = 0.0
var next_walk_time: float = 0.0

# Scooting movement state
var scoot_cycle_timer: float = 0.0
var current_scoot_index: int = 0
var scoot_burst_timer: float = 0.0
var is_scooting: bool = false
var last_movement_direction: int = 1  ## Track last movement direction for consistent sprite flip

# Contact damage state
var last_contact_damage_time: float = -999.0  ## Last time damage was dealt to player

# Rotation state
var target_rotation: float = 0.0

# Visual components
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Audio
var slime_sound: AudioStreamPlayer = null
var player_ref: Node = null


func _ready() -> void:
	# Add to enemies group for homing bullets
	add_to_group("enemies")

	# Create gravity component
	gravity_component = GravityEntity.new()
	add_child(gravity_component)

	# Initialize health
	current_health = max_health

	# Set up physics
	gravity_scale = 0.0  # Use custom planetary gravity, not Godot's default
	mass = 1.0

	# Enable contact monitoring for ground detection
	contact_monitor = true
	max_contacts_reported = 4

	# Connect signals
	body_entered.connect(_on_body_entered)

	# Start idle animation
	if animated_sprite:
		animated_sprite.play("idle")
		original_sprite_modulate = animated_sprite.modulate

	# Find player reference
	player_ref = get_tree().get_first_node_in_group("player")

	# Initialize planet attack timer with random interval
	planet_attack_timer = randf_range(planet_attack_interval_min, planet_attack_interval_max)

	# Create slime sound (plays when near player)
	slime_sound = AudioStreamPlayer.new()
	slime_sound.stream = load("res://Assets/sounds/slime.mp3")
	slime_sound.volume_db = -20.0
	slime_sound.autoplay = false
	add_child(slime_sound)

	# Initialize position tracking
	last_position = global_position

	# Initialize rest behavior
	if enable_resting:
		next_rest_time = randf_range(min_walk_time, max_walk_time)

	# Initialize movement direction
	last_movement_direction = patrol_direction


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Check distance to player and play/stop slime sound
	if player_ref and slime_sound:
		var distance_to_player = global_position.distance_to(player_ref.global_position)
		if distance_to_player < 500.0:  # Play sound when within 500 pixels
			if not slime_sound.playing:
				slime_sound.play()
		else:
			if slime_sound.playing:
				slime_sound.stop()

	# Update planet attack system
	update_planet_attack(delta)

	# Update primary planet
	gravity_component.update_primary_planet(global_position)

	# Calculate net gravity
	var net_gravity = gravity_component.calculate_grounded_bomb_gravity(global_position, is_grounded)
	if net_gravity.length() > 0:
		gravity_direction = net_gravity.normalized()

	# Check if grounded by examining collision contacts
	var physically_grounded = false
	var best_ground_normal = Vector2.ZERO
	var best_alignment = -1.0

	var colliding_bodies = get_colliding_bodies()
	for body in colliding_bodies:
		# Only consider StaticBody2D (planets) as ground
		if body is StaticBody2D:
			# Use raycast to get surface normal at current position
			var space_state = get_world_2d().direct_space_state
			var query = PhysicsRayQueryParameters2D.create(
				global_position,
				global_position + (gravity_direction * 50.0)  # Cast downward
			)
			query.exclude = [self]
			query.collision_mask = 1  # Only static bodies

			var result = space_state.intersect_ray(query)
			if result:
				var contact_normal = result.normal
				# Check if collision normal is roughly opposite to gravity direction
				var alignment = contact_normal.dot(-gravity_direction)
				if alignment > 0.1:  # Lenient for curved surfaces
					if alignment > best_alignment:
						best_ground_normal = contact_normal
						best_alignment = alignment
					physically_grounded = true

	# Update ground normal if we found ground
	if physically_grounded and best_ground_normal.length() > 0:
		ground_normal = best_ground_normal

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

	# Apply friction when grounded, low when airborne
	if is_grounded:
		if is_resting:
			linear_damp = 20.0  # High friction when resting
		else:
			linear_damp = 5.0  # Medium friction when moving
		angular_damp = 10.0
	else:
		linear_damp = 1.0  # Low air resistance when airborne
		angular_damp = 0.0

	# Apply planetary gravity ONLY if not touching ground
	if not physically_grounded:
		if net_gravity.length() > 0:
			linear_velocity += net_gravity * delta

	# Patrol movement when grounded
	if is_grounded:
		# Handle rest behavior
		if enable_resting:
			if is_resting:
				rest_timer += delta
				if rest_timer >= next_walk_time:
					# Stop resting, start walking
					is_resting = false
					walk_timer = 0.0
					next_rest_time = randf_range(min_walk_time, max_walk_time)
			else:
				walk_timer += delta
				if walk_timer >= next_rest_time:
					# Stop walking, start resting
					is_resting = true
					rest_timer = 0.0
					next_walk_time = randf_range(min_rest_time, max_rest_time)

		# Only move if not resting
		if not is_resting:
			# Only check for direction changes when actively scooting
			# This prevents direction flips during pause frames
			if is_scooting:
				# Check for edges to prevent falling off
				var edge_detected = check_for_edge()
				if edge_detected:
					patrol_direction *= -1
					last_movement_direction = patrol_direction

				# Check if stuck (not moving despite trying)
				var distance_moved = global_position.distance_to(last_position)
				if distance_moved < 5.0:  # Barely moved
					stuck_timer += delta
					if stuck_timer >= stuck_threshold:
						patrol_direction *= -1  # Turn around if stuck
						last_movement_direction = patrol_direction
						stuck_timer = 0.0
				else:
					stuck_timer = 0.0

			last_position = global_position

			# Handle scooting movement (multiple short bursts)
			var current_speed = 0.0  # Start at zero (paused between cycles)
			if scoot_enabled:
				scoot_cycle_timer += delta

				# Calculate time per scoot (including gap between scoots)
				var time_per_scoot = scoot_cycle_time / float(scoot_count)

				# Determine which scoot we're in
				current_scoot_index = int(scoot_cycle_timer / time_per_scoot)

				# Reset cycle if complete
				if scoot_cycle_timer >= scoot_cycle_time:
					scoot_cycle_timer = 0.0
					current_scoot_index = 0

				# Check if we're within a scoot burst
				var time_in_current_scoot = fmod(scoot_cycle_timer, time_per_scoot)
				if time_in_current_scoot < scoot_burst_duration and current_scoot_index < scoot_count:
					current_speed = patrol_speed * scoot_strength
					is_scooting = true
				else:
					current_speed = 0.0
					is_scooting = false
			else:
				current_speed = patrol_speed

			# Get surface tangent perpendicular to ground normal (actual surface)
			# This makes the slime follow the curve of the planet
			var surface_tangent = Vector2(-ground_normal.y, ground_normal.x)

			# Apply movement similar to player - set velocity along surface tangent
			# Project current velocity onto tangent to preserve some momentum
			if current_speed > 0:
				# Diagonal movement: tangent + upward bias for consistent long drag
				var tangent_vel = surface_tangent * patrol_direction * current_speed
				var upward_vel = ground_normal * current_speed * upward_movement_bias

				# Combine for diagonal movement
				linear_velocity = tangent_vel + upward_vel

				# Update last movement direction when actually moving
				last_movement_direction = patrol_direction
			else:
				# Paused - only preserve normal velocity to stay on ground
				var normal_vel = linear_velocity.dot(ground_normal) * ground_normal
				linear_velocity = normal_vel

			# Update sprite flip based on last movement direction (not current patrol_direction)
			# This prevents flickering when paused between scoots
			# When moving right (1), flip; when moving left (-1), don't flip
			if animated_sprite:
				animated_sprite.flip_h = last_movement_direction > 0

			# After setting velocity, constrain normal component to prevent bouncing
			# Use the already-calculated surface_tangent from above
			if physically_grounded:
				var tangent_vel_constrained = linear_velocity.dot(surface_tangent) * surface_tangent
				var normal_vel_magnitude_constrained = linear_velocity.dot(ground_normal)

				# Prevent bouncing - heavily restrict normal velocity to keep slime on surface
				# Allow minimal upward movement to navigate curves, but clamp it tight
				normal_vel_magnitude_constrained = clamp(normal_vel_magnitude_constrained, -20.0, 50.0)

				# Reconstruct velocity with clamped normal component
				linear_velocity = tangent_vel_constrained + (ground_normal * normal_vel_magnitude_constrained)
		else:
			# Resting - apply small downward force to stay grounded
			# Let linear_damp slow us down naturally
			pass

	# Update rotation to match gravity
	smooth_rotate_to_gravity(delta)

	# Update animation
	update_animation()


func _on_body_entered(body: Node) -> void:
	if is_dead:
		return

	# Ignore collisions with other enemies
	if body is SlimeEnemy:
		return

	# Check if hit by bullet
	if body is Bullet:
		take_damage(body.damage)
		return

	# Deal contact damage to player
	if body is Player:
		_deal_contact_damage_to_player(body)
		return

	# Check if hit by bomb explosion (bombs will call take_damage through explosion force)
	# We don't need to do anything here for bombs - they apply damage through apply_explosion_force

	# Edge case: Check for edges/walls to turn around
	if body is StaticBody2D and is_grounded:
		# Turn around when hitting a wall
		patrol_direction *= -1


func _deal_contact_damage_to_player(player: Player) -> void:
	"""Deal contact damage to the player with cooldown"""
	var current_time = Time.get_ticks_msec() / 1000.0

	# Check if cooldown has passed
	if current_time - last_contact_damage_time < contact_damage_cooldown:
		return

	# Deal damage if player has take_damage method
	if player.has_method("take_damage"):
		# Pass damage amount and slime's position for knockback calculation
		player.take_damage(contact_damage, global_position)
		last_contact_damage_time = current_time


func take_damage(amount: float) -> void:
	if is_dead:
		return

	current_health -= amount
	damaged.emit(amount, global_position)

	# Visual feedback: flash red (non-blocking)
	_flash_red()

	# Check if dead
	if current_health <= 0:
		die()


func _flash_red() -> void:
	"""Flash sprite red briefly for damage feedback"""
	if not animated_sprite:
		return

	# Always restore to white, not the current modulate (which might be red)
	animated_sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout

	# Only restore if still valid and not dead
	if is_instance_valid(self) and is_instance_valid(animated_sprite) and not is_dead:
		animated_sprite.modulate = Color.WHITE


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
	"""Create particle effect when slime dies"""
	var death_particles = GPUParticles2D.new()
	death_particles.global_position = global_position
	death_particles.emitting = true
	death_particles.one_shot = true
	death_particles.explosiveness = 1.0
	death_particles.amount = death_particle_count
	death_particles.lifetime = 0.8
	death_particles.local_coords = false

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.particle_flag_disable_z = true
	particle_mat.direction = Vector3(0, -1, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 80.0
	particle_mat.initial_velocity_max = 200.0
	particle_mat.gravity = Vector3(0, 200, 0)
	particle_mat.damping_min = 50.0
	particle_mat.damping_max = 100.0
	particle_mat.scale_min = 0.5
	particle_mat.scale_max = 1.5

	# Slime green color
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.GREEN)
	gradient.add_point(0.5, Color(0.0, 0.8, 0.2, 1.0))
	gradient.add_point(1.0, Color(0.0, 0.5, 0.0, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_mat.color_ramp = gradient_texture

	death_particles.process_material = particle_mat

	# Add to scene root so it persists after enemy is deleted
	get_tree().root.add_child(death_particles)

	# Clean up after effect finishes
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(death_particles):
		death_particles.queue_free()


func smooth_rotate_to_gravity(delta: float) -> void:
	"""Smoothly rotate slime to align with gravity direction"""
	if gravity_direction.length() < 0.1:
		return

	# Calculate target rotation (perpendicular to gravity)
	# Subtract PI/2 instead of adding to flip it right-side up
	target_rotation = gravity_direction.angle() - PI / 2.0

	# Smooth rotation using lerp_angle to handle angle wrapping
	rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)


func update_planet_attack(delta: float) -> void:
	"""Update planet attack system"""
	# Find nearest planet
	find_nearest_planet()

	if not is_charging_attack:
		# Count down to next attack
		planet_attack_timer -= delta
		if planet_attack_timer <= 0:
			# Start charging attack
			is_charging_attack = true
			charge_timer = 0.0
			# Reset for next attack with random interval
			planet_attack_timer = randf_range(planet_attack_interval_min, planet_attack_interval_max)
	else:
		# Charging attack
		charge_timer += delta

		# Update color (turn red over 3 seconds)
		var charge_percentage = min(charge_timer / planet_attack_charge_time, 1.0)
		if animated_sprite:
			animated_sprite.modulate = original_sprite_modulate.lerp(Color.RED, charge_percentage)

		# Execute attack when charge completes
		if charge_timer >= planet_attack_charge_time:
			execute_planet_attack()
			is_charging_attack = false
			# Reset color
			if animated_sprite:
				animated_sprite.modulate = original_sprite_modulate


func find_nearest_planet() -> void:
	"""Find the closest planet to this slime"""
	var planets = get_tree().get_nodes_in_group("planets")
	var closest_distance = INF
	nearest_planet = null

	for planet in planets:
		if planet is Planet:
			var distance = global_position.distance_to(planet.global_position)
			if distance < closest_distance:
				closest_distance = distance
				nearest_planet = planet


func execute_planet_attack() -> void:
	"""Deal damage to the nearest planet"""
	if nearest_planet and is_instance_valid(nearest_planet):
		nearest_planet.take_damage(planet_attack_damage)


func check_for_edge() -> bool:
	"""Check if there's an edge ahead to prevent falling off"""
	if not is_grounded:
		return false

	# Get surface tangent for movement direction (use actual ground normal)
	var surface_tangent = Vector2(-ground_normal.y, ground_normal.x)
	var check_direction = surface_tangent * patrol_direction

	# Cast a ray ahead and downward to check for ground
	var check_pos = global_position + (check_direction * edge_detection_distance)
	var ray_start = check_pos
	var ray_end = check_pos + (gravity_direction * edge_detection_distance * 2)

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(ray_start, ray_end)
	query.exclude = [self]
	query.collision_mask = 1  # Only check static bodies (planets)

	var result = space_state.intersect_ray(query)

	# If no ground detected ahead, there's an edge
	return not result


func update_animation() -> void:
	"""Update sprite animation based on state"""
	if not animated_sprite:
		return

	if is_dead:
		return

	# Determine animation based on state
	var target_anim = "idle"
	if is_grounded:
		if is_resting:
			target_anim = "rest"
		else:
			target_anim = "walk"
	else:
		target_anim = "idle"

	if animated_sprite.animation != target_anim:
		animated_sprite.play(target_anim)
