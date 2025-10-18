extends Node2D
class_name PenDrawing

## Pen drawing system for capturing mouse input and drawing shapes
## Handles right-click drawing, path visualization, and particle effects

signal drawing_started()
signal drawing_updated(point: Vector2)
signal drawing_finished(points: Array[Vector2])
signal shape_recognized(shape_type: ShapeRecognizer.ShapeType, points: Array[Vector2])

@export_group("Drawing Settings")
@export var min_draw_distance: float = 5.0  ## Minimum distance between points
@export var max_points: int = 100  ## Maximum points in a single drawing
@export var draw_smoothness: float = 0.5  ## Smoothing factor for path (0-1)

@export_group("Visual Settings")
@export var line_width: float = 5.0
@export var line_color: Color = Color.WHITE
@export var line_alpha: float = 0.8
@export var success_color: Color = Color.GREEN
@export var failure_color: Color = Color.RED
@export var feedback_duration: float = 0.3

@export_group("Particle Settings")
@export var enable_particles: bool = true
@export var particle_amount: int = 3  ## Particles spawned per point
@export var particle_lifetime: float = 0.5
@export var particle_color: Color = Color.CYAN
@export var particle_scale: float = 0.5

@export_group("Shape Recognition")
@export var enable_shape_recognition: bool = true

@export_group("Ink Costs")
@export var bomb_ink_cost: float = 5.0
@export var bullet_ink_cost: float = 10.0
@export var debug_shape_detection: bool = true  ## Print detected shapes to console

@export_group("Projectile Spawning")
@export var spawn_projectiles: bool = true
@export var bullet_spawn_offset: float = 50.0  ## Distance from mouse to spawn bullet

# Drawing state
var is_drawing: bool = false
var current_points: Array[Vector2] = []
var last_point: Vector2 = Vector2.ZERO

# Visual components
var draw_line: Line2D = null
var particle_system: GPUParticles2D = null

# Shape recognition
var shape_recognizer: ShapeRecognizer = null

# Player reference
var player: Player = null


func _ready() -> void:
	# Find player reference
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("PenDrawing: No player found!")

	# Create Line2D for visualizing the drawing path
	draw_line = Line2D.new()
	draw_line.width = line_width
	draw_line.default_color = Color(line_color.r, line_color.g, line_color.b, line_alpha)
	draw_line.antialiased = true
	draw_line.joint_mode = Line2D.LINE_JOINT_ROUND
	draw_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	draw_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(draw_line)

	# Create particle system for drawing trail
	setup_particle_system()

	# Create shape recognizer
	if enable_shape_recognition:
		shape_recognizer = ShapeRecognizer.new()
		add_child(shape_recognizer)


func _input(event: InputEvent) -> void:
	# Start drawing on right mouse button press
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed:
				start_drawing(get_local_mouse_position())
			else:
				finish_drawing()

	# Update drawing path on mouse motion
	elif event is InputEventMouseMotion and is_drawing:
		add_point(get_local_mouse_position())


func start_drawing(start_pos: Vector2) -> void:
	"""Begin a new drawing path"""
	is_drawing = true
	current_points.clear()
	draw_line.clear_points()
	last_point = start_pos

	# Add initial point
	current_points.append(start_pos)
	draw_line.add_point(start_pos)

	drawing_started.emit()


func add_point(point: Vector2) -> void:
	"""Add a point to the current drawing path"""
	if not is_drawing:
		return

	# Only add point if it's far enough from the last point
	if point.distance_to(last_point) < min_draw_distance:
		return

	# Check max points limit
	if current_points.size() >= max_points:
		finish_drawing()
		return

	current_points.append(point)
	draw_line.add_point(point)
	last_point = point

	# Spawn particles at this point
	spawn_particles(point)

	drawing_updated.emit(point)


func finish_drawing() -> void:
	"""Complete the current drawing and process the shape"""
	if not is_drawing:
		return

	is_drawing = false

	# Emit the completed path
	if current_points.size() > 1:
		drawing_finished.emit(current_points.duplicate())

		# Recognize shape
		if enable_shape_recognition and shape_recognizer:
			var detected_shape = shape_recognizer.detect_shape(current_points)
			shape_recognized.emit(detected_shape, current_points.duplicate())

			# Spawn projectiles based on shape (this will call show_drawing_feedback)
			if spawn_projectiles:
				spawn_projectile_for_shape(detected_shape, current_points)
	else:
		# No shape drawn, just clear
		clear_drawing()


func clear_drawing() -> void:
	"""Clear the current drawing immediately"""
	is_drawing = false
	current_points.clear()
	draw_line.clear_points()


func setup_particle_system() -> void:
	"""Initialize the particle system for drawing effects"""
	particle_system = GPUParticles2D.new()
	particle_system.emitting = false
	particle_system.one_shot = true
	particle_system.explosiveness = 1.0
	particle_system.lifetime = particle_lifetime
	particle_system.local_coords = false

	# Create particle material
	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.particle_flag_disable_z = true
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 20.0
	particle_mat.initial_velocity_max = 50.0
	particle_mat.gravity = Vector3(0, 0, 0)
	particle_mat.scale_min = particle_scale * 0.5
	particle_mat.scale_max = particle_scale * 1.5

	# Set particle color
	var gradient = Gradient.new()
	gradient.add_point(0.0, particle_color)
	gradient.add_point(1.0, Color(particle_color.r, particle_color.g, particle_color.b, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_mat.color_ramp = gradient_texture

	particle_system.process_material = particle_mat
	particle_system.amount = particle_amount

	add_child(particle_system)


func spawn_particles(pos: Vector2) -> void:
	"""Spawn particles at the given position"""
	if not enable_particles or not particle_system:
		return

	particle_system.global_position = pos
	particle_system.emitting = true
	particle_system.restart()


func spawn_projectile_for_shape(shape_type: ShapeRecognizer.ShapeType, points: Array[Vector2]) -> void:
	"""Spawn appropriate projectile based on detected shape"""
	match shape_type:
		ShapeRecognizer.ShapeType.CIRCLE:
			spawn_bomb(points)
		ShapeRecognizer.ShapeType.TRIANGLE:
			spawn_bullet(points)
		_:
			spawn_unknown_shape_effect(points)


func spawn_bomb(points: Array[Vector2]) -> void:
	"""Spawn a bomb at the center of the drawn circle"""
	# Check if player has enough ink
	if player == null or not player.use_ink(bomb_ink_cost):
		print("Not enough ink to spawn bomb! Need ", bomb_ink_cost)
		show_drawing_feedback(false)
		return

	# Calculate bounding box center (better for circles with overlap)
	var center = calculate_bounding_box_center(points)
	var global_center = to_global(center)

	# Spawn red particles for bomb creation
	spawn_shape_particles(global_center, Color.RED)

	# Load and instance bomb scene
	var bomb_scene = load("res://Scenes/bomb.tscn")
	var bomb = bomb_scene.instantiate()

	# Add to scene root so it's not affected by camera movement
	get_tree().root.add_child(bomb)

	# Initialize bomb with zero velocity (will be affected by planetary gravity)
	bomb.initialize(global_center, Vector2.ZERO)

	# Show success feedback
	show_drawing_feedback(true)


func spawn_bullet(points: Array[Vector2]) -> void:
	"""Spawn a bullet from the triangle in the direction based on drawing direction"""
	if points.size() < 3:
		return

	# Check if player has enough ink
	if player == null or not player.use_ink(bullet_ink_cost):
		print("Not enough ink to spawn bullet! Need ", bullet_ink_cost)
		show_drawing_feedback(false)
		return

	# Calculate centroid
	var centroid = calculate_centroid(points)

	# Calculate direction from centroid to where drawing started
	var start_point = points[0]
	var path_direction = (start_point - centroid).normalized()

	# Spawn position at centroid
	var spawn_pos = centroid

	# Convert to global coordinates
	var global_spawn_pos = to_global(spawn_pos)

	# Spawn blue particles for bullet creation
	spawn_shape_particles(global_spawn_pos, Color.BLUE)

	# Load and instance bullet scene
	var bullet_scene = load("res://Scenes/bullet.tscn")
	var bullet = bullet_scene.instantiate()

	# Add to scene root
	get_tree().root.add_child(bullet)

	# Initialize bullet with direction (bullet.gd will apply velocity)
	bullet.initialize(global_spawn_pos, path_direction)

	# Show success feedback
	show_drawing_feedback(true)


func spawn_unknown_shape_effect(points: Array[Vector2]) -> void:
	"""Spawn red error particles for unrecognized shapes"""
	var centroid = calculate_centroid(points)
	var global_centroid = to_global(centroid)
	spawn_shape_particles(global_centroid, Color.RED)
	show_drawing_feedback(false)


func spawn_shape_particles(position: Vector2, color: Color) -> void:
	"""Spawn colored particle burst at the given position"""
	# Create particle system
	var particles = GPUParticles2D.new()
	particles.global_position = position
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 5.0
	particles.amount = 100
	particles.lifetime = 1.0
	particles.local_coords = false

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.particle_flag_disable_z = true
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 50.0
	particle_mat.initial_velocity_max = 150.0
	particle_mat.gravity = Vector3(0, 100, 0)  # Slight downward drift
	particle_mat.damping_min = 50.0
	particle_mat.damping_max = 100.0
	particle_mat.scale_min = 2.0
	particle_mat.scale_max = 4.0

	# Color that fades out
	var gradient = Gradient.new()
	gradient.add_point(0.0, color)
	gradient.add_point(0.5, color.lightened(0.2))
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_mat.color_ramp = gradient_texture

	particles.process_material = particle_mat

	# Add to scene root
	get_tree().root.add_child(particles)

	# Clean up after effect finishes
	await get_tree().create_timer(2.0).timeout
	particles.queue_free()


func calculate_centroid(points: Array[Vector2]) -> Vector2:
	"""Calculate the centroid (center) of a set of points"""
	var centroid = Vector2.ZERO
	for point in points:
		centroid += point
	return centroid / points.size()


func calculate_bounding_box_center(points: Array[Vector2]) -> Vector2:
	"""Calculate the center of the bounding box for a set of points"""
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for point in points:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	return Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)


func show_drawing_feedback(success: bool) -> void:
	"""Change line color to indicate success or failure, then clear"""
	var feedback_color = success_color if success else failure_color
	draw_line.default_color = Color(feedback_color.r, feedback_color.g, feedback_color.b, line_alpha)

	# Clear the visual line after feedback duration
	await get_tree().create_timer(feedback_duration).timeout
	draw_line.clear_points()
	current_points.clear()

	# Reset color back to default
	draw_line.default_color = Color(line_color.r, line_color.g, line_color.b, line_alpha)
