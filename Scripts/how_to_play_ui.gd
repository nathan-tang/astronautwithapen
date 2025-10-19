extends CanvasLayer
class_name HowToPlayUI

## How to Play screen showing game instructions

@onready var back_button: Button = $Panel/VBoxContainer/BackButton


func _ready() -> void:
	# Hide initially
	visible = false

	# Connect button
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func show_instructions() -> void:
	"""Show the instructions screen"""
	visible = true


func _on_back_pressed() -> void:
	"""Hide the instructions screen"""
	visible = false
