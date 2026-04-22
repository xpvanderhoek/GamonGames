extends Button



func _on_pressed() -> void:
	PuzzleData.knows_slide_puzzle = true
	
	var root = get_parent().get_parent().get_parent().get_parent()
	
	var tween = create_tween()
	tween.tween_property(root, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	root.queue_free()
