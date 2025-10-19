extends Node
class_name UfoSpawner

## Spawns UFO enemies in orbit around planets at regular intervals

@export var ufo_scene: PackedScene = preload("res://Scenes/ufo_enemy.tscn")
@export var spawn_interval: float = 15.0  ## Time between UFO spawns
@export var max_ufos: int = 3  ## Maximum number of UFOs at once
@export var spawn_distance_from_planet: float = 200.0  ## Distance from planet to spawn UFO

var spawn_timer: float = 0.0
var active_ufos: Array[UfoEnemy] = []


func _ready() -> void:
	# Start with random offset to avoid all spawning at once
	spawn_timer = randf_range(0.0, spawn_interval * 0.5)


func _process(delta: float) -> void:
	# Clean up dead UFOs from tracking list
	active_ufos = active_ufos.filter(func(ufo): return is_instance_valid(ufo) and not ufo.is_dead)

	# Update spawn timer
	spawn_timer += delta

	# Check if we should spawn a new UFO
	if spawn_timer >= spawn_interval and active_ufos.size() < max_ufos:
		spawn_ufo()
		spawn_timer = 0.0


func spawn_ufo() -> void:
	"""Spawn a UFO in orbit around a random planet"""
	if not ufo_scene:
		push_error("UfoSpawner: No UFO scene assigned!")
		return

	# Get all planets
	var planets = get_tree().get_nodes_in_group("planets")
	if planets.is_empty():
		push_warning("UfoSpawner: No planets found in scene!")
		return

	# Pick a random planet
	var target_planet = planets[randi() % planets.size()] as Planet
	if not target_planet:
		return

	# Calculate spawn position in orbit
	var random_angle = randf() * TAU  # Random angle around planet
	var spawn_radius = target_planet.planet_radius + spawn_distance_from_planet
	var spawn_offset = Vector2(cos(random_angle), sin(random_angle)) * spawn_radius
	var spawn_position = target_planet.global_position + spawn_offset

	# Instantiate UFO
	var ufo = ufo_scene.instantiate() as UfoEnemy
	if not ufo:
		push_error("UfoSpawner: Failed to instantiate UFO!")
		return

	# Set position
	ufo.global_position = spawn_position

	# Set orbital distance to match spawn distance
	ufo.orbital_distance = spawn_distance_from_planet

	# Add to scene
	get_tree().root.add_child(ufo)

	# Track UFO
	active_ufos.append(ufo)

	# Connect death signal to remove from tracking
	ufo.died.connect(_on_ufo_died.bind(ufo))

	print("Spawned UFO at ", spawn_position, " orbiting planet at ", target_planet.global_position)


func _on_ufo_died(position: Vector2, ufo: UfoEnemy) -> void:
	"""Handle UFO death"""
	if ufo in active_ufos:
		active_ufos.erase(ufo)
