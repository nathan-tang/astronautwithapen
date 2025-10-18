extends Camera2D
class_name CameraController

## Camera that follows the player and rotates to match gravity orientation
## Keeps "down" pointing toward the gravity center for intuitive gameplay

@export var player: Player  ## Reference to player node

@export_group("Follow Settings")
@export var follow_speed: float = 5.0  ## Position follow smoothing
@export var follow_offset: Vector2 = Vector2.ZERO  ## Offset from player position

@export_group("Rotation Settings")
@export var rotation_speed: float = 50.0  ## Rotation smoothing speed (higher = faster response)
@export var enable_rotation: bool = true  ## Toggle camera rotation

@export_group("Zoom Settings")
@export var base_zoom: Vector2 = Vector2(1.0, 1.0)
@export var dynamic_zoom: bool = false  ## Zoom based on player velocity
@export var max_zoom_out: float = 0.8  ## Min zoom when moving fast
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


## Rotate camera to match player's gravity direction
func rotate_to_gravity(delta: float) -> void:
	# Camera should rotate so that the player's feet always point down on screen
	# This makes gravity always pull "down" and the player stands upright naturally

	# We want gravity to point down on screen
	# gravity_direction points toward the planet, so we want that to point down (angle = PI/2)
	# Camera's global rotation should make gravity_direction point downward
	var desired_down = player.gravity_direction
	target_rotation = desired_down.angle() - PI / 2.0

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
