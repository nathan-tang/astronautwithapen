extends Node2D
class_name PlanetHealthBar

## Circular health bar that displays around a planet

@export var planet: Planet
@export var ring_radius: float = 80.0  ## Radius of health ring
@export var ring_thickness: float = 8.0  ## Thickness of health ring

var health_percentage: float = 1.0


func _ready() -> void:
	# Auto-find planet parent if not set
	if planet == null:
		planet = get_parent() as Planet

	if planet == null:
		push_warning("PlanetHealthBar: No planet found!")
		return

	# Connect to planet signals
	planet.health_changed.connect(_on_health_changed)

	# Initialize
	health_percentage = planet.current_health / planet.max_health

	# Defer ring sizing to ensure planet radius is set
	call_deferred("_update_ring_size")


func _update_ring_size() -> void:
	"""Update ring radius based on planet's actual radius"""
	if planet:
		ring_radius = planet.planet_radius + 15.0
		queue_redraw()


func _draw() -> void:
	var center = Vector2.ZERO
	var num_segments = 64

	# Draw background ring (dark)
	draw_arc(center, ring_radius, 0, TAU, num_segments, Color(0.2, 0.2, 0.2, 0.6), ring_thickness, true)

	# Draw health arc (green to red based on percentage)
	if health_percentage > 0:
		var health_color = Color.GREEN.lerp(Color.RED, 1.0 - health_percentage)
		var health_angle = TAU * health_percentage
		draw_arc(center, ring_radius, 0, health_angle, num_segments, health_color, ring_thickness, true)


func _on_health_changed(new_health: float, max_health: float) -> void:
	health_percentage = new_health / max_health
	queue_redraw()
