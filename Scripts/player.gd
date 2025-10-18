extends CharacterBody2D
class_name Player

## Player controller with dynamic planetary gravity
## Handles movement, jumping, rotation, and smooth transitions between gravity sources

@export_group("Movement")
@export var move_speed: float = 800.0
@export var jump_force: float = 7000.0
@export var jump_gravity_multiplier: float = 4.0  ## Jump force scales with gravity strength
@export var jump_grace_period: float = 0.5  ## Seconds of reduced gravity after jump
@export var jump_grace_gravity_reduction: float = 0.1  ## Gravity multiplier during grace period (0.1 = 90% reduction)
@export var air_control: float = 0.9  ## Movement control while airborne (0-1)
@export var max_speed: float = 3000.0  ## Maximum velocity cap

@export_group("Gravity")
@export var default_gravity: float = 400.0
@export var gravity_cancel_threshold: float = 50.0  ## Min gravity to maintain orientation
@export var primary_planet_switch_threshold: float = 1.2  ## 20% stronger to switch primary

@export_group("Rotation")
@export var rotation_speed: float = 5.0  ## How fast player rotates to match gravity
@export var rotation_smoothing: float = 0.1  ## Lower = smoother rotation

@export_group("Ground Detection")
@export var ground_detection_distance: float = 5.0

# Internal state
var active_gravity_fields: Array[Planet] = []
var current_primary_planet: Planet = null
var last_stable_gravity: Vector2 = Vector2.DOWN
var gravity_direction: Vector2 = Vector2.DOWN  ## Current gravity direction (unit vector)
var is_grounded: bool = false

# Jump state
var jump_grace_timer: float = 0.0  ## Time remaining in jump grace period
var current_gravity_strength: float = 0.0  ## Current gravity magnitude for scaling jump

# For smooth rotation
var target_rotation: float = 0.0

# Animation
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var is_moving: bool = false
var animation_velocity_threshold_walk: float = 100.0  ## Speed needed to trigger walk
var animation_velocity_threshold_idle: float = 50.0   ## Speed below which we go idle (hysteresis)


func _ready() -> void:
	last_stable_gravity = Vector2.DOWN * default_gravity
	if animated_sprite:
		# Set sprite to face right by default (no rotation, mirrored)
		animated_sprite.rotation = 0
		animated_sprite.flip_h = true
		animated_sprite.flip_v = true
		animated_sprite.play("idle")


func _physics_process(delta: float) -> void:
	# 1. Calculate net gravity from all sources
	var net_gravity = calculate_gravity()
	current_gravity_strength = net_gravity.length()

	# 2. Determine primary gravity source (with hysteresis)
	update_primary_planet()

	# 3. Smooth rotation toward gravity direction
	smooth_rotate_to_gravity(net_gravity, delta)

	# 4. Check if grounded
	is_grounded = check_ground()

	# 5. Handle movement input
	handle_movement(delta)

	# 6. Handle jump input
	handle_jump()

	# 7. Update jump grace timer
	if jump_grace_timer > 0:
		jump_grace_timer -= delta

	# 8. Apply gravity (reduced during jump grace period, zero when grounded)
	if not is_grounded:
		var gravity_to_apply = net_gravity
		if jump_grace_timer > 0:
			gravity_to_apply *= jump_grace_gravity_reduction
		velocity += gravity_to_apply * delta
	else:
		# When grounded, remove any velocity going into the surface
		var surface_normal = -gravity_direction
		var velocity_into_surface = velocity.dot(surface_normal)
		if velocity_into_surface < 0:
			velocity -= surface_normal * velocity_into_surface

	# 10. Clamp velocity to prevent extreme speeds
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	move_and_slide()

	# 11. Update animations
	update_animation()


## Calculate net gravity from all active gravity fields
func calculate_gravity() -> Vector2:
	if active_gravity_fields.is_empty():
		return Vector2.DOWN * default_gravity

	var total_gravity := Vector2.ZERO
	var total_weight := 0.0

	for planet in active_gravity_fields:
		if not is_instance_valid(planet):
			continue

		var direction = planet.global_position - global_position
		var distance = direction.length()

		# Calculate weight based on distance falloff
		var weight = planet.calculate_falloff(distance)

		# Bonus weight if currently primary (sticky gravity prevents jittering)
		if planet == current_primary_planet and is_grounded:
			weight *= 1.5

		var gravity_contribution = direction.normalized() * planet.gravity_strength * weight
		total_gravity += gravity_contribution
		total_weight += weight

	# Edge Case: If forces nearly cancel, maintain current orientation
	if total_gravity.length() < gravity_cancel_threshold:
		return last_stable_gravity.normalized() * default_gravity

	# Store stable gravity for future reference
	last_stable_gravity = total_gravity
	return total_gravity


## Update which planet is the primary gravity source
func update_primary_planet() -> void:
	if active_gravity_fields.is_empty():
		current_primary_planet = null
		return

	# Find the strongest gravity source at current position
	var strongest_planet: Planet = null
	var strongest_force := 0.0

	for planet in active_gravity_fields:
		if not is_instance_valid(planet):
			continue

		var gravity = planet.get_gravity_at_position(global_position)
		var force = gravity.length()

		if force > strongest_force:
			strongest_force = force
			strongest_planet = planet

	# Only switch if significantly stronger (hysteresis to prevent flickering)
	if strongest_planet != current_primary_planet:
		if current_primary_planet == null:
			current_primary_planet = strongest_planet
		else:
			var current_force = current_primary_planet.get_gravity_at_position(global_position).length()
			if strongest_force > current_force * primary_planet_switch_threshold:
				current_primary_planet = strongest_planet


## Smoothly rotate player to align with gravity direction
func smooth_rotate_to_gravity(net_gravity: Vector2, delta: float) -> void:
	if net_gravity.length() < 0.1:
		return

	# Calculate target rotation (perpendicular to gravity)
	gravity_direction = net_gravity.normalized()
	target_rotation = gravity_direction.angle() + PI / 2.0

	# Smooth rotation using lerp_angle to handle angle wrapping
	rotation = lerp_angle(rotation, target_rotation, rotation_speed * delta)


## Handle player movement input
func handle_movement(delta: float) -> void:
	# Get input
	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")

	# Track if player is trying to move
	is_moving = abs(input_vector.x) > 0.1 or abs(input_vector.y) > 0.1

	# SCREEN-RELATIVE CONTROLS:
	# Convert screen-space input to world-space movement
	# Account for player rotation so controls always feel natural

	# Get the camera to know screen orientation
	var cam = get_viewport().get_camera_2d()
	var screen_to_world_rotation = 0.0
	if cam:
		# Camera's global rotation tells us how the screen is rotated relative to world
		screen_to_world_rotation = cam.global_rotation

	# Convert input from screen space to world space
	var input_angle = input_vector.angle()
	var world_angle = input_angle + screen_to_world_rotation
	var world_input = Vector2(cos(world_angle), sin(world_angle)) * input_vector.length()

	# Apply movement control reduction when airborne
	var control_factor = air_control if not is_grounded else 1.0
	var move_direction = world_input * move_speed * control_factor

	# Apply movement
	velocity.x = lerp(velocity.x, move_direction.x, 0.2)
	velocity.y = lerp(velocity.y, move_direction.y, 0.2)

	# Flip sprite horizontally based on movement direction
	if animated_sprite and is_moving:
		# Player's right direction in world space
		var player_right = Vector2(cos(rotation), sin(rotation))
		var dot_product = world_input.dot(player_right)

		# Flip horizontally when moving left (keep vertical flip constant)
		animated_sprite.flip_h = dot_product < 0


## Handle jump input
func handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_grounded:
		# Calculate adaptive jump force based on current gravity strength
		var adaptive_jump = jump_force + (current_gravity_strength * jump_gravity_multiplier)

		# Jump perpendicular to gravity (away from planet)
		var jump_direction = -gravity_direction
		velocity += jump_direction * adaptive_jump

		# Activate jump grace period (reduced gravity for smoother jump arc)
		jump_grace_timer = jump_grace_period


## Check if player is on the ground
func check_ground() -> bool:
	# Use built-in collision detection from move_and_slide
	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			# Check if collision normal is roughly opposite to gravity direction
			var collision_angle = collision.get_normal().dot(-gravity_direction)
			if collision_angle > 0.7:  # Within ~45 degrees
				return true

	# Fallback: raycast in gravity direction
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + gravity_direction * ground_detection_distance
	)
	query.exclude = [self]

	var result = space_state.intersect_ray(query)
	return result.size() > 0


## Called by Planet when player enters gravity field
func add_gravity_field(planet: Planet) -> void:
	if planet not in active_gravity_fields:
		active_gravity_fields.append(planet)


## Called by Planet when player exits gravity field
func remove_gravity_field(planet: Planet) -> void:
	active_gravity_fields.erase(planet)

	# If we lost our primary planet, clear it
	if planet == current_primary_planet:
		current_primary_planet = null




## Update animation based on player state
func update_animation() -> void:
	if not animated_sprite:
		return

	var current_speed = velocity.length()
	var current_anim = animated_sprite.animation

	# Priority: Jump > Walk > Idle
	if not is_grounded:
		# In air - play jump animation
		if current_anim != "jump":
			animated_sprite.play("jump")
	else:
		# On ground - use hysteresis to prevent jittering
		if current_anim == "walk":
			# Currently walking - need to slow down significantly to stop
			if current_speed < animation_velocity_threshold_idle:
				animated_sprite.play("idle")
		else:
			# Currently idle - need to speed up significantly to start walking
			if is_moving and current_speed > animation_velocity_threshold_walk:
				animated_sprite.play("walk")
