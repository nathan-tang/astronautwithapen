extends Node2D
class_name StarBackground

## Generates a starfield background with random stars and parallax effect

@export_group("Star Settings")
@export var star_count: int = 200  ## Number of stars to generate
@export var star_color: Color = Color.WHITE
@export var star_min_size: float = 1.0
@export var star_max_size: float = 3.0
@export var star_min_brightness: float = 0.3
@export var star_max_brightness: float = 1.0

@export_group("Area Settings")
@export var area_width: float = 10000.0  ## Width of star field
@export var area_height: float = 10000.0  ## Height of star field
@export var center_offset: Vector2 = Vector2.ZERO  ## Offset from origin

@export_group("Parallax Settings")
@export var enable_parallax: bool = true
@export var parallax_strength: float = 0.3  ## How much stars move relative to camera (0-1, lower = further away)

@export_group("Drift Settings")
@export var enable_drift: bool = false  ## Make stars drift slowly (for menu screens)
@export var drift_speed: float = 20.0  ## Speed of star drift

var stars: Array[Dictionary] = []
var camera: Camera2D = null


func _ready() -> void:
	generate_stars()

	# Find the camera
	if enable_parallax:
		camera = get_viewport().get_camera_2d()
		if camera == null:
			push_warning("StarBackground: No camera found for parallax effect")


func _process(delta: float) -> void:
	if enable_parallax and camera:
		# Update position based on camera with parallax offset
		global_position = camera.global_position * (1.0 - parallax_strength)
		queue_redraw()
	elif enable_drift:
		# Drift stars slowly for menu screens
		for star in stars:
			star.position.x += drift_speed * delta
			# Wrap around when star goes off screen
			if star.position.x > area_width/2 + center_offset.x:
				star.position.x = -area_width/2 + center_offset.x
		queue_redraw()


func generate_stars() -> void:
	"""Generate random stars across the defined area"""
	stars.clear()

	for i in range(star_count):
		var star = {
			"position": Vector2(
				randf_range(-area_width/2, area_width/2) + center_offset.x,
				randf_range(-area_height/2, area_height/2) + center_offset.y
			),
			"size": randf_range(star_min_size, star_max_size),
			"brightness": randf_range(star_min_brightness, star_max_brightness)
		}
		stars.append(star)

	queue_redraw()


func _draw() -> void:
	"""Draw all stars"""
	for star in stars:
		var color = Color(
			star_color.r * star.brightness,
			star_color.g * star.brightness,
			star_color.b * star.brightness,
			star_color.a
		)
		draw_circle(star.position, star.size, color)
