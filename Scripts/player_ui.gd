extends CanvasLayer
class_name PlayerUI

## UI overlay that displays player health and ink bars

@export var player: Player

# UI Elements
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthLabel
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var ink_label: Label = $MarginContainer/VBoxContainer/InkLabel
@onready var ink_bar: ProgressBar = $MarginContainer/VBoxContainer/InkBar


func _ready() -> void:
	# Auto-find player if not set
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_warning("PlayerUI: No player found!")
		return

	# Connect to player signals
	player.health_changed.connect(_on_health_changed)
	player.ink_changed.connect(_on_ink_changed)

	# Initialize bars
	if health_bar:
		health_bar.max_value = player.max_health
		health_bar.value = player.current_health
	if health_label:
		health_label.text = "Health: %d/%d" % [player.current_health, player.max_health]

	if ink_bar:
		ink_bar.max_value = player.max_ink
		ink_bar.value = player.current_ink
	if ink_label:
		ink_label.text = "Ink: %d/%d" % [player.current_ink, player.max_ink]


func _on_health_changed(new_health: float, max_health: float) -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = new_health
	if health_label:
		health_label.text = "Health: %d/%d" % [new_health, max_health]


func _on_ink_changed(new_ink: float, max_ink: float) -> void:
	if ink_bar:
		ink_bar.max_value = max_ink
		ink_bar.value = new_ink
	if ink_label:
		ink_label.text = "Ink: %d/%d" % [new_ink, max_ink]
