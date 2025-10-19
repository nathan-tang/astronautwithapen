extends Node
class_name GameManager

## Manages game state, scoring, and game over conditions

signal score_changed(new_score: int)
signal game_over(final_score: int)

@export var slime_points: int = 1
@export var ufo_points: int = 10

var current_score: int = 0
var is_game_over: bool = false


func _ready() -> void:
	# Add to game_manager group so UI can find us
	add_to_group("game_manager")

	# Wait for scene tree to be ready
	await get_tree().process_frame

	# Connect to all existing planets
	_connect_to_planets()

	# Connect to existing enemies
	_connect_to_existing_enemies()


func _connect_to_planets() -> void:
	"""Connect to all planet destroyed signals"""
	var planets = get_tree().get_nodes_in_group("planets")

	for planet in planets:
		if planet is Planet:
			planet.planet_destroyed.connect(_on_planet_destroyed)
		else:
			push_warning("GameManager: Found non-Planet in planets group: " + str(planet))


func _connect_to_existing_enemies() -> void:
	"""Connect to all existing enemy death signals"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is SlimeEnemy:
			enemy.died.connect(_on_slime_died)
		elif enemy is UfoEnemy:
			enemy.died.connect(_on_ufo_died)


func _process(_delta: float) -> void:
	# Check if we need to connect to new enemies (spawned after _ready)
	# This runs every frame but the connection check is cheap
	if not is_game_over:
		_check_for_new_enemies()


func _check_for_new_enemies() -> void:
	"""Check for and connect to newly spawned enemies"""
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is SlimeEnemy:
			if not enemy.died.is_connected(_on_slime_died):
				enemy.died.connect(_on_slime_died)
		elif enemy is UfoEnemy:
			if not enemy.died.is_connected(_on_ufo_died):
				enemy.died.connect(_on_ufo_died)


func _on_slime_died(position: Vector2) -> void:
	"""Award points for killing a slime"""
	if is_game_over:
		return

	add_score(slime_points)


func _on_ufo_died(position: Vector2) -> void:
	"""Award points for killing a UFO"""
	if is_game_over:
		return

	add_score(ufo_points)


func add_score(points: int) -> void:
	"""Add points to the score"""
	current_score += points
	score_changed.emit(current_score)


func _on_planet_destroyed(planet: Planet) -> void:
	"""Check if all planets are destroyed"""
	if is_game_over:
		return

	# Wait a frame for the planet to be removed from the group
	await get_tree().process_frame

	# Check if any planets remain
	var remaining_planets = get_tree().get_nodes_in_group("planets")

	if remaining_planets.is_empty():
		trigger_game_over()


func trigger_game_over() -> void:
	"""End the game"""
	if is_game_over:
		return

	is_game_over = true
	game_over.emit(current_score)
