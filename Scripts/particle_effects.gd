extends Node
class_name ParticleEffects

## Utility class for creating common particle effects
## Consolidates duplicated particle creation code from multiple classes

## Create an explosion particle effect
static func create_explosion(position: Vector2, color_start: Color = Color.YELLOW, color_end: Color = Color.RED, particle_count: int = 500) -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.global_position = position
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.5
	particles.amount = particle_count
	particles.lifetime = 0.25
	particles.local_coords = false

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.particle_flag_disable_z = true
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 180.0
	particle_mat.initial_velocity_min = 100.0
	particle_mat.initial_velocity_max = 500.0
	particle_mat.gravity = Vector3(0, 0, 0)
	particle_mat.damping_min = 30.0
	particle_mat.damping_max = 60.0
	particle_mat.scale_min = 2.0
	particle_mat.scale_max = 4.0

	# Gradient colors
	var gradient = Gradient.new()
	gradient.add_point(0.0, color_start)
	gradient.add_point(0.5, Color(color_end.r, color_end.g, color_end.b, color_end.a))
	gradient.add_point(1.0, Color(color_end.r, color_end.g, color_end.b, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_mat.color_ramp = gradient_texture

	particles.process_material = particle_mat
	return particles


## Create a death/impact particle burst
static func create_burst(position: Vector2, color: Color, particle_count: int = 100, spread: float = 180.0) -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.global_position = position
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 5.0
	particles.amount = particle_count
	particles.lifetime = 1.0
	particles.local_coords = false

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.particle_flag_disable_z = true
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = spread
	particle_mat.initial_velocity_min = 50.0
	particle_mat.initial_velocity_max = 150.0
	particle_mat.gravity = Vector3(0, 100, 0)
	particle_mat.damping_min = 50.0
	particle_mat.damping_max = 100.0
	particle_mat.scale_min = 2.0
	particle_mat.scale_max = 4.0

	# Color with fade
	var gradient = Gradient.new()
	gradient.add_point(0.0, color)
	gradient.add_point(0.5, color.lightened(0.2))
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_mat.color_ramp = gradient_texture

	particles.process_material = particle_mat
	return particles


## Create a trail effect (for bullets, etc.)
static func create_trail() -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.3
	particles.explosiveness = 0.3
	particles.local_coords = false

	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.particle_flag_disable_z = true
	particle_mat.direction = Vector3(0, 0, 0)
	particle_mat.spread = 20.0
	particle_mat.initial_velocity_min = 10.0
	particle_mat.initial_velocity_max = 30.0
	particle_mat.gravity = Vector3(0, 0, 0)
	particle_mat.damping_min = 10.0
	particle_mat.damping_max = 20.0
	particle_mat.scale_min = 1.0
	particle_mat.scale_max = 2.0

	# Blue gradient
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.CYAN)
	gradient.add_point(1.0, Color(0.0, 0.5, 1.0, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	particle_mat.color_ramp = gradient_texture

	particles.process_material = particle_mat
	return particles


## Add particle effect to scene and auto-cleanup after duration
static func spawn_and_cleanup(particles: GPUParticles2D, scene_root: Node, cleanup_delay: float = 2.0) -> void:
	scene_root.add_child(particles)

	# Auto-cleanup after effect finishes
	await scene_root.get_tree().create_timer(cleanup_delay).timeout
	if is_instance_valid(particles):
		particles.queue_free()
