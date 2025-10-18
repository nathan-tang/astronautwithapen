extends AnimatedSprite2D
class_name DVDBounce

## DVD screensaver-style bouncing sprite that bounces around the screen

@export var speed: float = 100.0  ## Movement speed in pixels per second
@export var bounce_padding: float = 50.0  ## Padding from screen edges

var velocity: Vector2
var screen_size: Vector2

func _ready() -> void:
	# Get the viewport size from the project settings
	screen_size = Vector2(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height")
	)

	# Start with random direction
	var random_angle = randf() * TAU
	velocity = Vector2(cos(random_angle), sin(random_angle)) * speed

	# Start at random position
	position = Vector2(
		randf_range(bounce_padding, screen_size.x - bounce_padding),
		randf_range(bounce_padding, screen_size.y - bounce_padding)
	)

	# Make sure sprite is visible
	visible = true
	modulate = Color(1, 1, 1, 1)  # Start with white color

	# Play walk animation
	if sprite_frames != null:
		if sprite_frames.has_animation(&"walk"):
			play(&"walk")
		elif sprite_frames.has_animation(&"idle"):
			play(&"idle")

	print("DVDBounce ready - Position: ", position, " Screen size: ", screen_size)


func _process(delta: float) -> void:
	# Move the sprite
	position += velocity * delta

	# Get sprite dimensions for better collision detection
	var sprite_width = 32.0  # Approximate width
	var sprite_height = 32.0  # Approximate height

	# Bounce off edges
	if position.x <= bounce_padding or position.x >= screen_size.x - bounce_padding:
		velocity.x = -velocity.x
		position.x = clamp(position.x, bounce_padding, screen_size.x - bounce_padding)
		_on_bounce()

	if position.y <= bounce_padding or position.y >= screen_size.y - bounce_padding:
		velocity.y = -velocity.y
		position.y = clamp(position.y, bounce_padding, screen_size.y - bounce_padding)
		_on_bounce()

	# Flip sprite based on direction
	flip_h = velocity.x < 0


func _on_bounce() -> void:
	# Change color on bounce for DVD effect (subtle pastel colors)
	# Use higher minimum values for less intense colors
	var r = randf_range(0.6, 1.0)
	var g = randf_range(0.6, 1.0)
	var b = randf_range(0.6, 1.0)
	modulate = Color(r, g, b, 1.0)
