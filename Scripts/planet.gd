extends Node2D
class_name Planet

## Planet with configurable gravity field
## Emits gravity force on bodies within its influence radius

@export_group("Gravity Settings")
@export var gravity_strength: float = 980.0  ## Gravity force magnitude
@export var gravity_radius: float = 500.0  ## Effective gravity range
@export_enum("Linear", "Quadratic", "Inverse Square") var falloff_type: String = "Inverse Square"

@export_group("Visual Settings")
@export var planet_radius: float = 64.0  ## Visual/collision radius

@onready var gravity_field: Area2D = $GravityField
@onready var collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var gravity_field_shape: CollisionShape2D = $GravityField/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Set up collision shapes based on radius values
	_setup_shapes()

	# Ensure gravity field monitors physics bodies
	if gravity_field:
		gravity_field.monitoring = true
		gravity_field.monitorable = true

	# Connect gravity field signals
	if gravity_field:
		gravity_field.body_entered.connect(_on_body_entered)
		gravity_field.body_exited.connect(_on_body_exited)

	# Check for bodies already overlapping at start
	# Delay one frame to ensure everything is initialized
	await get_tree().process_frame
	_check_initial_overlaps()


func _check_initial_overlaps() -> void:
	if gravity_field:
		var overlapping_bodies = gravity_field.get_overlapping_bodies()
		for body in overlapping_bodies:
			if body.has_method("add_gravity_field"):
				body.add_gravity_field(self)


func _setup_shapes() -> void:
	# Set planet collision shape (CircleShape2D)
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = planet_radius

	# Set gravity field shape (larger CircleShape2D)
	if gravity_field_shape and gravity_field_shape.shape is CircleShape2D:
		gravity_field_shape.shape.radius = gravity_radius

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


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("add_gravity_field"):
		body.add_gravity_field(self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("remove_gravity_field"):
		body.remove_gravity_field(self)


## Calculate gravity falloff based on distance
func calculate_falloff(distance: float) -> float:
	if distance >= gravity_radius:
		return 0.0

	var normalized_distance = distance / gravity_radius

	match falloff_type:
		"Linear":
			return 1.0 - normalized_distance
		"Quadratic":
			return 1.0 - (normalized_distance * normalized_distance)
		"Inverse Square":
			# Inverse square law: strength decreases with square of distance
			# Normalized to return value between 0 and 1
			var dist_clamped = max(normalized_distance, 0.01)  # Prevent division by zero
			return 1.0 / (dist_clamped * dist_clamped)
		_:
			return 1.0 - normalized_distance


## Calculate gravity force at a given position
func get_gravity_at_position(pos: Vector2) -> Vector2:
	var direction = global_position - pos
	var distance = direction.length()

	if distance >= gravity_radius:
		return Vector2.ZERO

	var falloff = calculate_falloff(distance)
	return direction.normalized() * gravity_strength * falloff
