extends Node2D
class_name Planet

## Planet with configurable gravity field
## Emits gravity force on bodies within its influence radius

@export_group("Gravity Settings")
@export var gravity_strength: float = 1.0  ## Gravity force magnitude
@export var gravity_radius: float = 2500.0  ## Effective gravity range

@export_group("Visual Settings")
@export var planet_radius: float = 64.0  ## Visual/collision radius

@export_group("Health Settings")
@export var max_health: float = 250.0  ## Can sustain 25 attacks at 10 damage each

# State
var current_health: float = 250.0

# Signals
signal health_changed(new_health: float, max_health: float)
signal planet_destroyed(planet: Planet)

@onready var collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

# Flash effect
var flash_timer: float = 0.0
var original_modulate: Color


func _ready() -> void:
	# Initialize health
	current_health = max_health

	# Store original color
	if sprite:
		original_modulate = sprite.modulate

	# Set up collision shapes based on radius values
	_setup_shapes()

	# Add to "planets" group so objects can find us
	add_to_group("planets")


func _process(delta: float) -> void:
	# Handle flash effect
	if flash_timer > 0:
		flash_timer -= delta
		if flash_timer <= 0 and sprite:
			sprite.modulate = original_modulate


func _setup_shapes() -> void:
	# Set planet collision shape (CircleShape2D)
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = planet_radius

	# Scale sprite to match planet radius exactly
	# Sprite diameter should equal collision diameter for accurate visual feedback
	if sprite:
		var texture_size = sprite.texture.get_size()
		# The actual planet graphic is ~1030px in a 1280px texture (lots of transparency)
		# Actual planet is about 80.47% of texture size (1030/1280)
		var actual_planet_ratio = 1030.0 / 1280.0
		# Scale based on actual planet size, not full texture size
		var scale_factor = (planet_radius * 2.0) / (texture_size.x * actual_planet_ratio)
		sprite.scale = Vector2(scale_factor, scale_factor)


## Calculate gravity falloff based on distance
func calculate_falloff(distance: float) -> float:
	if distance >= gravity_radius:
		return 0.0
	var dist_clamped = max(distance / gravity_radius, 0.01)  # Prevent division by zero
	return 1.0 / (dist_clamped * dist_clamped)


## Calculate gravity force at a given position
func get_gravity_at_position(pos: Vector2) -> Vector2:
	var direction = global_position - pos
	var distance = direction.length()

	if distance >= gravity_radius:
		return Vector2.ZERO

	var falloff = calculate_falloff(distance)
	return direction.normalized() * gravity_strength * falloff


## Take damage
func take_damage(amount: float) -> void:
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	print("Planet took ", amount, " damage. Health: ", current_health, "/", max_health)

	# Flash red
	if sprite:
		sprite.modulate = Color.RED
		flash_timer = 0.1

	# Play hit sound
	var hit_sound = AudioStreamPlayer.new()
	hit_sound.stream = load("res://Assets/sounds/gun.mp3")
	hit_sound.volume_db = -10.0
	add_child(hit_sound)
	hit_sound.play()
	# Clean up sound after it finishes
	hit_sound.finished.connect(hit_sound.queue_free)

	# Check if destroyed
	if current_health <= 0:
		print("Planet destroyed! Emitting signal...")
		planet_destroyed.emit(self)
		queue_free()
