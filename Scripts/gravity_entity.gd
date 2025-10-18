extends Node
class_name GravityEntity

## Shared gravity and ground detection logic for objects affected by planetary gravity
## This is a component that can be added to any physics body

## Signals
signal grounded_changed(is_grounded: bool)

## Configuration
@export var default_gravity: float = 400.0
@export var gravity_cancel_threshold: float = 50.0
@export var primary_planet_switch_threshold: float = 1.2

## State
var current_primary_planet: Planet = null
var last_stable_gravity: Vector2 = Vector2.DOWN
var gravity_direction: Vector2 = Vector2.DOWN
var current_gravity_strength: float = 0.0

## Calculate net gravity from all planets in the scene
func calculate_gravity(global_position: Vector2) -> Vector2:
	var planets = get_tree().get_nodes_in_group("planets")

	if planets.is_empty():
		var default_grav = Vector2.DOWN * default_gravity
		current_gravity_strength = default_grav.length()
		return default_grav

	var total_gravity := Vector2.ZERO
	var total_weight := 0.0

	for planet in planets:
		if not is_instance_valid(planet) or not planet is Planet:
			continue

		var direction = planet.global_position - global_position
		var distance = direction.length()

		# Calculate weight based on distance falloff
		var weight = planet.calculate_falloff(distance)

		# Bonus weight if currently primary (sticky gravity prevents jittering)
		if planet == current_primary_planet:
			weight *= 1.5

		var gravity_contribution = direction.normalized() * planet.gravity_strength * weight
		total_gravity += gravity_contribution
		total_weight += weight

	# Edge Case: If forces nearly cancel, maintain current orientation
	if total_gravity.length() < gravity_cancel_threshold:
		var stable_grav = last_stable_gravity.normalized() * default_gravity
		current_gravity_strength = stable_grav.length()
		return stable_grav

	# Store stable gravity for future reference
	last_stable_gravity = total_gravity
	current_gravity_strength = total_gravity.length()
	return total_gravity


## Update which planet is the primary gravity source
func update_primary_planet(global_position: Vector2) -> void:
	var planets = get_tree().get_nodes_in_group("planets")

	if planets.is_empty():
		current_primary_planet = null
		return

	# Find the strongest gravity source at current position
	var strongest_planet: Planet = null
	var strongest_force := 0.0

	for planet in planets:
		if not is_instance_valid(planet) or not planet is Planet:
			continue

		var gravity = planet.get_gravity_at_position(global_position)
		var force = gravity.length()

		if force > strongest_force:
			strongest_force = force
			strongest_planet = planet

	# Only switch if significantly stronger (hysteresis to prevent flickering)
	if strongest_planet != current_primary_planet:
		if current_primary_planet == null:
			current_primary_planet = strongest_planet
		else:
			var current_force = current_primary_planet.get_gravity_at_position(global_position).length()
			if strongest_force > current_force * primary_planet_switch_threshold:
				current_primary_planet = strongest_planet


## Calculate gravity for grounded bomb (only primary planet)
func calculate_grounded_bomb_gravity(global_position: Vector2, is_grounded: bool) -> Vector2:
	var planets = get_tree().get_nodes_in_group("planets")

	if planets.is_empty():
		return Vector2.ZERO

	# If grounded, only apply gravity from primary planet
	if is_grounded and current_primary_planet != null:
		return current_primary_planet.get_gravity_at_position(global_position)

	# Otherwise, apply gravity from all planets
	var total_gravity := Vector2.ZERO

	for planet in planets:
		if not is_instance_valid(planet) or not planet is Planet:
			continue

		var gravity_contribution = planet.get_gravity_at_position(global_position)
		total_gravity += gravity_contribution

	return total_gravity
