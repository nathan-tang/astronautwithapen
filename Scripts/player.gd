extends CharacterBody2D
class_name Player

## Player controller with dynamic planetary gravity
## Handles movement, jumping, rotation, and smooth transitions between gravity sources

@export_group("Stats")
@export var max_health: float = 100.0
@export var max_ink: float = 100.0

@export_group("Damage")
@export var invincibility_duration: float = 1.0  ## Invincibility time after taking damage
@export var damage_flash_duration: float = 0.1  ## Duration of red flash effect
@export var knockback_force: float = 800.0  ## Force applied on taking damage
@export var knockback_upward_multiplier: float = 0.5  ## Extra upward component for knockback

@export_group("Movement")
@export var move_speed: float = 500.0
@export var jump_force: float = 1000.0
@export var jump_gravity_multiplier: float = 6.0  ## Jump force scales with gravity strength
@export var jump_grace_period: float = 0.3  ## Seconds of reduced gravity after jump
@export var jump_grace_gravity_reduction: float = 0.02  ## Gravity multiplier during grace period (0.05 = 95% reduction)
@export var air_control: float = 1.0  ## Movement control while airborne (0-1)
@export var max_speed: float = 2500.0  ## Maximum velocity cap

@export_group("Gravity")
## Gravity component handles planetary gravity calculations
var gravity_component: GravityEntity

@export_group("Rotation")
@export var rotation_speed: float = 5.0  ## How fast player rotates to match gravity
@export var rotation_smoothing: float = 0.1  ## Lower = smoother rotation

@export_group("Ground Detection")
@export var ground_detection_distance: float = 100.0

# Stats
var current_health: float = 100.0
var current_ink: float = 100.0

# Damage state
var is_invincible: bool = false
var invincibility_timer: float = 0.0
var last_damage_source_position: Vector2 = Vector2.ZERO  ## Position of what damaged us

# Signals for UI updates
signal health_changed(new_health: float, max_health: float)
signal ink_changed(new_ink: float, max_ink: float)

# Internal state
var gravity_direction: Vector2 = Vector2.DOWN  ## Current gravity direction (unit vector)
var is_grounded: bool = false
var ground_normal: Vector2 = Vector2.UP  ## Actual surface normal from collision
var ground_coyote_time: float = 0.0  ## Grace period for ground state to prevent flicker

# Jump state
var jump_grace_timer: float = 0.0  ## Time remaining in jump grace period

# External forces (like explosions)
var external_velocity: Vector2 = Vector2.ZERO

# For smooth rotation
var target_rotation: float = 0.0

# Animation
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var is_moving: bool = false
var animation_velocity_threshold_walk: float = 100.0  ## Speed needed to trigger walk
var animation_velocity_threshold_idle: float = 50.0   ## Speed below which we go idle (hysteresis)


func _ready() -> void:
	# Create gravity component
	gravity_component = GravityEntity.new()
	add_child(gravity_component)

	# Initialize stats
	current_health = max_health
	current_ink = max_ink
	health_changed.emit(current_health, max_health)
	ink_changed.emit(current_ink, max_ink)

	if animated_sprite:
		# Set sprite to face right by default (no rotation, mirrored)
		animated_sprite.rotation = 0
		animated_sprite.flip_h = true
		animated_sprite.flip_v = true
		animated_sprite.play("idle")


func _physics_process(delta: float) -> void:
	# 0. Update invincibility timer
	if is_invincible:
		invincibility_timer -= delta
		if invincibility_timer <= 0:
			is_invincible = false
			# Ensure sprite is fully visible when invincibility ends
			if animated_sprite:
				animated_sprite.modulate = Color.WHITE

	# 1. Calculate net gravity from all sources
	var net_gravity = gravity_component.calculate_gravity(global_position)

	# 2. Determine primary gravity source (with hysteresis)
	gravity_component.update_primary_planet(global_position)

	# 3. Smooth rotation toward gravity direction
	smooth_rotate_to_gravity(net_gravity, delta)

	# 4. Handle movement input
	handle_movement(delta)

	# 5. Handle jump input
	handle_jump()

	# 6. Update jump grace timer
	if jump_grace_timer > 0:
		jump_grace_timer -= delta

	# 7. Apply external forces (explosions, etc.)
	velocity += external_velocity
	external_velocity = external_velocity.lerp(Vector2.ZERO, 0.1)  # Decay external forces

	# 8. Apply gravity
	var gravity_to_apply = net_gravity
	if jump_grace_timer > 0:
		gravity_to_apply *= jump_grace_gravity_reduction

	if is_grounded:
		# When grounded, set normal velocity to a constant value to maintain contact
		# Don't accumulate gravity or we'll build up infinite velocity into the surface
		var surface_tangent = Vector2(-ground_normal.y, ground_normal.x)
		var tangent_vel = velocity.dot(surface_tangent) * surface_tangent
		var target_normal_vel = ground_normal * -50.0  # Small constant push into surface
		velocity = tangent_vel + target_normal_vel
	else:
		# When airborne, apply full gravity
		velocity += gravity_to_apply * delta

	# 9. Clamp velocity to prevent extreme speeds
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed

	var vel_before_slide = velocity
	move_and_slide()

	# 10. Check if grounded (AFTER move_and_slide to use current collision data)
	var physically_grounded = check_ground()

	# Use coyote time to prevent ground state flickering during fast movement
	if physically_grounded:
		is_grounded = true
		ground_coyote_time = 0.21  # 210ms grace period
	else:
		# Still consider grounded briefly if we were recently on ground (coyote time)
		if ground_coyote_time > 0:
			ground_coyote_time -= delta
			is_grounded = true
		else:
			is_grounded = false

	# When PHYSICALLY grounded, constrain velocity to only move along surface (after move_and_slide)
	# Use physically_grounded instead of is_grounded to avoid coyote time issues
	if physically_grounded:
		var surface_tangent = Vector2(-ground_normal.y, ground_normal.x)
		var tangent_vel = velocity.dot(surface_tangent) * surface_tangent
		var normal_vel_magnitude = velocity.dot(ground_normal)

		# Cap normal velocity to prevent excessive buildup into surface
		var max_normal_vel = 100.0
		normal_vel_magnitude = clamp(normal_vel_magnitude, -max_normal_vel, max_normal_vel)

		# If not moving, zero out tangent velocity; otherwise preserve it
		if not is_moving:
			velocity = ground_normal * normal_vel_magnitude
		else:
			velocity = tangent_vel + (ground_normal * normal_vel_magnitude)

	# 11. Regenerate ink
	if current_ink < max_ink:
		restore_ink(1.0 * delta)

	# 12. Update animations
	update_animation()


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
	# Get input (only left/right horizontal movement)
	var input_x = Input.get_axis("move_left", "move_right")

	# Track if player is trying to move
	is_moving = abs(input_x) > 0.1

	# SCREEN-RELATIVE CONTROLS:
	# Convert screen-space input to world-space movement
	# Account for player rotation so controls always feel natural

	# Get the camera to know screen orientation
	var cam = get_viewport().get_camera_2d()
	var screen_to_world_rotation = 0.0
	if cam:
		# Camera's global rotation tells us how the screen is rotated relative to world
		screen_to_world_rotation = cam.global_rotation

	# Convert horizontal input to world space direction
	# Input is along the screen's horizontal axis
	var screen_right = Vector2(cos(screen_to_world_rotation), sin(screen_to_world_rotation))
	var world_input = screen_right * input_x

	# When grounded, set velocity directly based on input (no momentum)
	if is_grounded:
		# Get surface tangent (perpendicular to actual ground normal, not gravity)
		var surface_tangent = Vector2(-ground_normal.y, ground_normal.x)

		# Project input onto tangent
		var tangent_projection = world_input.dot(surface_tangent)

		# Set tangential velocity directly from input (no lerp, no momentum)
		if abs(tangent_projection) > 0.01:
			# Moving - set velocity to move_speed along tangent
			var tangent_vel = surface_tangent * tangent_projection * move_speed

			# Preserve normal component, replace tangent component
			var normal_vel = velocity.dot(ground_normal) * ground_normal
			velocity = tangent_vel + normal_vel
		else:
			# No input - zero out tangential velocity completely
			var normal_vel = velocity.dot(ground_normal) * ground_normal
			velocity = normal_vel
	else:
		# In air, allow free movement with reduced control
		var move_direction = world_input * move_speed * air_control
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
		var adaptive_jump = jump_force + (gravity_component.current_gravity_strength * jump_gravity_multiplier)

		# Jump perpendicular to the ground surface (using ground normal)
		# This ensures we jump "away" from whatever surface we're standing on
		var jump_direction = ground_normal

		# Set velocity directly instead of adding to it for more aggressive jump
		velocity = jump_direction * adaptive_jump

		# Activate jump grace period (reduced gravity for smoother jump arc)
		jump_grace_timer = jump_grace_period

		# Immediately set as not grounded to prevent stick force from canceling jump
		is_grounded = false
		ground_coyote_time = 0.0


## Check if player is on the ground
func check_ground() -> bool:
	# First check slide collisions from move_and_slide
	var best_ground_normal := Vector2.ZERO
	var best_alignment := -1.0
	var found_ground := false

	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			# Check if collision normal is roughly opposite to gravity direction
			var collision_angle = collision.get_normal().dot(-gravity_direction)
			if collision_angle > 0.1:  # Very lenient for curved planetary surfaces
				# Store the actual ground normal for accurate tangent calculation
				# Use the collision with the best alignment
				if collision_angle > best_alignment:
					best_ground_normal = collision.get_normal()
					best_alignment = collision_angle
				found_ground = true

	if found_ground:
		ground_normal = best_ground_normal
		return true

	# If no collision detected, raycast downward to check for nearby ground
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + (gravity_direction * ground_detection_distance)
	)
	query.exclude = [self]

	var result = space_state.intersect_ray(query)
	if result:
		ground_normal = result.normal
		return true

	return false

## Update animation based on player state
func update_animation() -> void:
	if not animated_sprite:
		return

	var current_anim = animated_sprite.animation

	# Priority: Jump > Walk > Idle
	if not is_grounded:
		# In air - play jump animation
		if current_anim != "jump":
			animated_sprite.play("jump")
	else:
		# On ground - determine target animation based on input
		var target_anim = "idle"
		if is_moving:
			target_anim = "walk"

		# Only change animation if different from current
		# This prevents restarting the same animation
		if current_anim != target_anim:
			animated_sprite.play(target_anim)


## Damage the player
func take_damage(amount: float, damage_source_pos: Vector2 = Vector2.ZERO) -> void:
	# Ignore damage if invincible
	if is_invincible:
		return

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	# Store damage source position
	last_damage_source_position = damage_source_pos

	# Activate invincibility
	is_invincible = true
	invincibility_timer = invincibility_duration

	# Apply knockback away from damage source
	_apply_knockback()

	# Flash red for damage feedback
	_flash_red()

	# Play damage sound
	var damage_sound = AudioStreamPlayer.new()
	damage_sound.stream = load("res://Assets/sounds/damage.mp3")
	damage_sound.volume_db = -5.0
	add_child(damage_sound)
	damage_sound.play()
	# Clean up sound after it finishes
	damage_sound.finished.connect(damage_sound.queue_free)

	if current_health <= 0:
		die()


func _apply_knockback() -> void:
	"""Apply knockback force away from damage source"""
	if last_damage_source_position == Vector2.ZERO:
		# No damage source position, knockback away from gravity (upward)
		velocity += -gravity_direction * knockback_force
	else:
		# Knockback away from damage source
		var knockback_direction = (global_position - last_damage_source_position).normalized()
		velocity += knockback_direction * knockback_force

		# Also add upward component (away from gravity) for more dynamic knockback
		velocity += -gravity_direction * knockback_force * knockback_upward_multiplier


func _flash_red() -> void:
	"""Flash sprite red briefly for damage feedback"""
	if not animated_sprite:
		return

	animated_sprite.modulate = Color.RED
	await get_tree().create_timer(damage_flash_duration).timeout

	# Only restore if still valid and not dead
	if is_instance_valid(self) and is_instance_valid(animated_sprite):
		animated_sprite.modulate = Color.WHITE


## Heal the player
func heal(amount: float) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


## Use ink for drawing
func use_ink(amount: float) -> bool:
	if current_ink >= amount:
		current_ink -= amount
		ink_changed.emit(current_ink, max_ink)
		return true
	return false


## Restore ink
func restore_ink(amount: float) -> void:
	current_ink = min(max_ink, current_ink + amount)
	ink_changed.emit(current_ink, max_ink)


## Handle player death
func die() -> void:
	print("Player died!")
	# TODO: Implement death behavior (respawn, game over, etc.)
