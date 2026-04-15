extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !PlayerStats.knows_ghost:
		await DialogueManager.start_dialogue("limbo_enter")
