extends Node2D
class_name Planet

## Planet with configurable gravity field
## Emits gravity force on bodies within its influence radius

@export_group("Gravity Settings")
@export var gravity_strength: float = 1.0  ## Gravity force magnitude
@export var gravity_radius: float = 2500.0  ## Effective gravity range

@export_group("Visual Settings")
@export var planet_radius: float = 64.0  ## Visual/collision radius

@onready var collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Set up collision shapes based on radius values
	_setup_shapes()

	# Add to "planets" group so objects can find us
	add_to_group("planets")


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
