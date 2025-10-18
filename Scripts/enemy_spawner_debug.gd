extends Node
class_name EnemySpawnerDebug

## Debug tool for spawning enemies at cursor location
## Press 'E' to spawn a slime enemy at the mouse position

@export var enemy_scene: PackedScene = preload("res://Scenes/slime_enemy.tscn")
@export var spawn_offset: Vector2 = Vector2.ZERO

# Reference to the camera for screen-to-world conversion
var camera: Camera2D


func _ready() -> void:
	# Find the camera (assumes it's a child of the player or in the scene)
	camera = get_viewport().get_camera_2d()
	if not camera:
		push_warning("EnemySpawnerDebug: No Camera2D found in scene!")


func _process(_delta: float) -> void:
	# Check for E key press
	if Input.is_action_just_pressed("spawn_enemy"):
		spawn_enemy_at_cursor()


func spawn_enemy_at_cursor() -> void:
	"""Spawn an enemy at the current mouse cursor position (camera-relative)"""
	if not enemy_scene:
		push_error("EnemySpawnerDebug: No enemy scene assigned!")
		return

	if not camera:
		push_error("EnemySpawnerDebug: No camera found!")
		return

	# Get mouse position in viewport (screen space)
	var mouse_screen_pos = get_viewport().get_mouse_position()

	# Get viewport center
	var viewport_size = get_viewport().get_visible_rect().size
	var viewport_center = viewport_size / 2.0

	# Calculate offset from center in screen space
	var offset_from_center = mouse_screen_pos - viewport_center

	# Convert offset to world space by dividing by zoom
	var world_offset = offset_from_center / camera.zoom

	# Rotate offset by camera rotation to account for camera orientation
	var rotated_offset = world_offset.rotated(camera.global_rotation)

	# Final world position = camera position + rotated offset
	var mouse_world_pos = camera.global_position + rotated_offset

	# Instantiate enemy
	var enemy = enemy_scene.instantiate()
	if not enemy:
		push_error("EnemySpawnerDebug: Failed to instantiate enemy!")
		return

	# Set position
	enemy.global_position = mouse_world_pos + spawn_offset

	# Add to scene root so it's not a child of the player
	get_tree().root.add_child(enemy)

	print("Spawned enemy at ", mouse_world_pos)
