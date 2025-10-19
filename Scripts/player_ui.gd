extends CanvasLayer
class_name PlayerUI

## UI overlay that displays player ink and score

@export var player: Player

# UI Elements
@onready var ink_label: Label = $MarginContainer/VBoxContainer/InkLabel
@onready var ink_bar: ProgressBar = $MarginContainer/VBoxContainer/InkBar
@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel


func _ready() -> void:
	# Auto-find player if not set
	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if player == null:
		push_warning("PlayerUI: No player found!")
		return

	# Connect to player signals
	player.ink_changed.connect(_on_ink_changed)

	# Initialize ink bar
	if ink_bar:
		ink_bar.max_value = player.max_ink
		ink_bar.value = player.current_ink
	if ink_label:
		ink_label.text = "Ink: %d/%d" % [player.current_ink, player.max_ink]

	# Initialize score
	if score_label:
		score_label.text = "Score: 0"

	# Connect to game manager score updates
	var game_manager = get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.score_changed.connect(_on_score_changed)


func _on_ink_changed(new_ink: float, max_ink: float) -> void:
	if ink_bar:
		ink_bar.max_value = max_ink
		ink_bar.value = new_ink
	if ink_label:
		ink_label.text = "Ink: %d/%d" % [new_ink, max_ink]


func _on_score_changed(new_score: int) -> void:
	if score_label:
		score_label.text = "Score: %d" % new_score
