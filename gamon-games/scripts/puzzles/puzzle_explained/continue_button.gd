extends Button



func _on_pressed() -> void:
	PuzzleData.knows_slide_puzzle = true
	get_tree().current_scene.queue_free()
