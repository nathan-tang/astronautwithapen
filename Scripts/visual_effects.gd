extends Node
class_name VisualEffects

## Utility class for common visual feedback effects
## Consolidates duplicated visual effect code from multiple classes

## Flash a sprite red briefly (damage indicator)
static func flash_red(sprite: Sprite2D, duration: float = 0.1) -> void:
	if not sprite or not is_instance_valid(sprite):
		return

	var original_modulate = sprite.modulate
	sprite.modulate = Color.RED

	await sprite.get_tree().create_timer(duration).timeout

	# Only restore if sprite is still valid
	if is_instance_valid(sprite):
		sprite.modulate = original_modulate


## Flash sprite with a custom color
static func flash_color(sprite: Sprite2D, color: Color, duration: float = 0.1) -> void:
	if not sprite or not is_instance_valid(sprite):
		return

	var original_modulate = sprite.modulate
	sprite.modulate = color

	await sprite.get_tree().create_timer(duration).timeout

	if is_instance_valid(sprite):
		sprite.modulate = original_modulate


## Make sprite blink (invincibility effect)
static func blink(sprite: Sprite2D, duration: float, blink_interval: float = 0.1) -> void:
	if not sprite or not is_instance_valid(sprite):
		return

	var elapsed = 0.0
	var visible_state = true

	while elapsed < duration:
		if not is_instance_valid(sprite):
			return

		sprite.visible = visible_state
		visible_state = not visible_state

		await sprite.get_tree().create_timer(blink_interval).timeout
		elapsed += blink_interval

	# Ensure sprite is visible at the end
	if is_instance_valid(sprite):
		sprite.modulate.a = 1.0
		sprite.visible = true
