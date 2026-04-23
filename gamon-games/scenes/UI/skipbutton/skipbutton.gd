extends Control

@onready var button = $Button
var puzzle_text = PuzzleTexts.SKIPPUZZLE[RunData.language]

func _ready() -> void:
	button.text = puzzle_text

func _on_button_pressed() -> void:
	TransitionManager.change_scene("res://scenes/map.tscn")
