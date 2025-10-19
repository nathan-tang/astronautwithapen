extends Node2D
class_name Planet

## Planet with configurable gravity field
## Emits gravity force on bodies within its influence radius

@export_group("Gravity Settings")
@export var gravity_strength: float = 1.0  ## Gravity force magnitude
@export var gravity_radius: float = 2500.0  ## Effective gravity range

@export_group("Visual Settings")
@export var planet_radius: float = 64.0  ## Visual/collision radius
@export var randomize_size: bool = true  ## Randomize planet size on spawn
@export var size_min: float = 200.0  ## Minimum planet radius
@export var size_max: float = 350.0  ## Maximum planet radius
@export var randomize_color: bool = true  ## Randomize planet color on spawn

@export_group("Health Settings")
@export var max_health: float = 250.0  ## Can sustain 25 attacks at 10 damage each

@export_group("Meander Settings")
@export var enable_meander: bool = true  ## Enable wandering movement
@export var meander_distance_percent: float = 0.5  ## Max distance as percentage of radius
@export var meander_speed: float = 10.0  ## Speed of meandering movement

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

# Meander state
var starting_position: Vector2 = Vector2.ZERO
var meander_target: Vector2 = Vector2.ZERO
var meander_timer: float = 0.0
var meander_change_interval: float = 3.0  ## How often to pick new target


func _ready() -> void:
	# Randomize size if enabled
	if randomize_size:
		planet_radius = randf_range(size_min, size_max)

	# Initialize health
	current_health = max_health

	# Randomize and store color
	if sprite:
		if randomize_color:
			sprite.modulate = _generate_random_planet_color()
		original_modulate = sprite.modulate

	# Store starting position for meandering
	starting_position = global_position
	_pick_new_meander_target()

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

	# Handle meandering movement
	if enable_meander:
		update_meander(delta)


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


func update_meander(delta: float) -> void:
	"""Update planet's meandering movement"""
	# Update timer
	meander_timer -= delta
	if meander_timer <= 0:
		_pick_new_meander_target()
		meander_timer = meander_change_interval

	# Move towards target
	var direction = (meander_target - global_position).normalized()
	var distance = global_position.distance_to(meander_target)

	# Slow down as we approach target
	var speed_factor = min(distance / 10.0, 1.0)
	global_position += direction * meander_speed * speed_factor * delta


func _pick_new_meander_target() -> void:
	"""Pick a new random position within meander distance"""
	var max_offset = planet_radius * meander_distance_percent
	var random_offset = Vector2(
		randf_range(-max_offset, max_offset),
		randf_range(-max_offset, max_offset)
	)
	meander_target = starting_position + random_offset


func _generate_random_planet_color() -> Color:
	"""Generate a random pleasant planet color"""
	var color_options = [
		Color(0.8, 0.6, 0.3),   # Orange/tan
		Color(0.3, 0.6, 0.8),   # Blue
		Color(0.6, 0.3, 0.7),   # Purple
		Color(0.9, 0.7, 0.2),   # Yellow
		Color(0.7, 0.2, 0.5),   # Pink
		Color(0.5, 0.8, 0.3),   # Green
		Color(0.9, 0.3, 0.3),   # Red
		Color(0.3, 0.9, 0.9),   # Cyan
		Color(0.8, 0.5, 0.6),   # Rose
		Color(0.4, 0.7, 0.5),   # Teal
	]
	return color_options[randi() % color_options.size()]
