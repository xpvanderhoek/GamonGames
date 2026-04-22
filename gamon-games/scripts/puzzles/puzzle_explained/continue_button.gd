extends Button



func _on_pressed() -> void:
	PuzzleData.knows_slide_puzzle = true
	get_parent().get_parent().get_parent().get_parent().queue_free()
