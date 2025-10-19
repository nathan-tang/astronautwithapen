extends CanvasLayer
class_name GameOverUI

## Game over screen that displays final score and options

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var score_label: Label = $Panel/VBoxContainer/ScoreLabel
@onready var play_again_button: Button = $Panel/VBoxContainer/PlayAgainButton
@onready var title_screen_button: Button = $Panel/VBoxContainer/TitleScreenButton


func _ready() -> void:

	# Hide initially
	visible = false

	# Wait for scene tree
	await get_tree().process_frame

	# Connect to game manager
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.game_over.connect(_on_game_over)

	# Connect button signals
	if play_again_button:
		play_again_button.pressed.connect(_on_play_again_pressed)
	if title_screen_button:
		title_screen_button.pressed.connect(_on_title_screen_pressed)



func _on_game_over(final_score: int) -> void:
	"""Show game over screen with final score"""

	if score_label:
		score_label.text = "Final Score: %d" % final_score

	visible = true

	# Pause the game
	get_tree().paused = true


func _on_play_again_pressed() -> void:
	"""Restart the current scene"""

	# Clean up all enemies and projectiles added to scene root
	var root = get_tree().root
	var cleanup_count = 0

	for child in root.get_children():
		# Remove enemies, bullets, and bombs that were added to root
		if child is SlimeEnemy or child is UfoEnemy or child is Bullet or child is Bomb:
			child.queue_free()
			cleanup_count += 1


	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_title_screen_pressed() -> void:
	"""Return to title screen"""
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
