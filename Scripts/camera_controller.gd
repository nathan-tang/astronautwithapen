extends Camera2D
class_name CameraController

## Camera that follows the player and rotates to match gravity orientation
## Keeps "down" pointing toward the gravity center for intuitive gameplay

@export var player: Player  ## Reference to player node

@export_group("Follow Settings")
@export var follow_speed: float = 5.0  ## Position follow smoothing
@export var follow_offset: Vector2 = Vector2.ZERO  ## Offset from player position

@export_group("Rotation Settings")
@export var rotation_speed: float = 1.0  ## Rotation smoothing speed (higher = faster response)
@export var enable_rotation: bool = true  ## Toggle camera rotation

@export_group("Zoom Settings")
@export var base_zoom: Vector2 = Vector2(0.4, 0.4)
@export var dynamic_zoom: bool = false  ## Zoom based on player velocity
@export var max_zoom_out: float = 0.5  ## Min zoom when moving fast
@export var zoom_speed: float = 2.0

# Internal state
var target_rotation: float = 0.0

func _ready() -> void:
	# Auto-find player if not set
	if player == null:
		# Camera is child of player, so parent is the player
		player = get_parent() as Player

	if player == null:
		# Fallback to searching
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_warning("CameraController: No player found!")

	# Set initial zoom
	zoom = base_zoom

	# Enable the camera
	enabled = true
	make_current()


func _process(delta: float) -> void:
	if player == null:
		return

	# Note: Camera follows player automatically as a child node
	# No need to manually set position

	# Rotate to match gravity (counter-rotate from player's rotation)
	if enable_rotation:
		rotate_to_gravity(delta)

	# Dynamic zoom based on velocity
	if dynamic_zoom:
		update_dynamic_zoom(delta)


## Smoothly follow the player's position
func follow_player(delta: float) -> void:
	var target_position = player.global_position + follow_offset
	global_position = global_position.lerp(target_position, follow_speed * delta)


## Rotate camera to point toward the primary/closest planet
func rotate_to_gravity(delta: float) -> void:
	# Camera should rotate so that the primary planet is always "down" on screen

	# Get the primary planet (or closest if no primary)
	var target_planet = player.gravity_component.current_primary_planet

	if target_planet == null:
		# Fall back to finding closest planet
		var planets = get_tree().get_nodes_in_group("planets")
		var closest_planet: Planet = null
		var closest_distance = INF

		for planet in planets:
			if planet is Planet:
				var distance = player.global_position.distance_to(planet.global_position)
				if distance < closest_distance:
					closest_distance = distance
					closest_planet = planet

		target_planet = closest_planet

	if target_planet != null:
		# Direction from player to planet
		var direction_to_planet = (target_planet.global_position - player.global_position).normalized()
		target_rotation = direction_to_planet.angle() - PI / 2.0

		# Smooth rotation using lerp_angle to handle angle wrapping correctly
		global_rotation = lerp_angle(global_rotation, target_rotation, rotation_speed * delta)


## Adjust zoom based on player velocity
func update_dynamic_zoom(delta: float) -> void:
	var speed = player.velocity.length()
	var speed_normalized = clamp(speed / 500.0, 0.0, 1.0)  # Normalize to 0-1

	# Zoom out when moving fast
	var target_zoom_value = lerp(base_zoom.x, max_zoom_out, speed_normalized)
	var target_zoom_vector = Vector2(target_zoom_value, target_zoom_value)

	zoom = zoom.lerp(target_zoom_vector, zoom_speed * delta)


## Shake the camera (for impacts, explosions, etc.)
func shake(intensity: float, duration: float) -> void:
	var shake_tween = create_tween()
	var original_offset = offset

	var shake_time = 0.0
	while shake_time < duration:
		var shake_offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		shake_tween.tween_property(self, "offset", shake_offset, 0.05)
		shake_time += 0.05

	shake_tween.tween_property(self, "offset", original_offset, 0.1)
