extends Control
class_name MainMenu

## Main menu for the game with play and quit buttons

@onready var play_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/PlayButton
@onready var how_to_play_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/HowToPlayButton
@onready var quit_button: Button = $MarginContainer/VBoxContainer/ButtonContainer/QuitButton
@onready var how_to_play_ui: HowToPlayUI = $HowToPlayUI


func _ready() -> void:
	# Skip main menu if setting is enabled (for faster iteration during development)
	if GameSettings.skip_main_menu:
		get_tree().change_scene_to_file("res://Scenes/main.tscn")
		return

	# Connect button signals
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if how_to_play_button:
		how_to_play_button.pressed.connect(_on_how_to_play_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

	# Focus the play button by default
	if play_button:
		play_button.grab_focus()


func _on_play_pressed() -> void:
	# Load the main game scene
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_how_to_play_pressed() -> void:
	# Show how to play screen
	if how_to_play_ui:
		how_to_play_ui.show_instructions()


func _on_quit_pressed() -> void:
	# Quit the game
	get_tree().quit()
