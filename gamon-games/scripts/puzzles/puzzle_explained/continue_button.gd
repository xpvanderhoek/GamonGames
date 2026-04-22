extends Button

var play = PuzzleTexts.CLOSEEXPLANATION[RunData.language]

func _ready() -> void:
	text = play
	disabled = true
	modulate.a = 0.5
	scale = Vector2(0.95, 0.95)
	
	await get_tree().create_timer(8.0).timeout
	
	disabled = false
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(self, "scale", Vector2(1, 1), 0.3)

func _on_pressed() -> void:
	PuzzleData.knows_slide_puzzle = true
	
	var root = get_parent().get_parent().get_parent().get_parent()
	
	var tween = create_tween()
	tween.tween_property(root, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	root.queue_free()
