extends CanvasLayer

signal transition_midpoint
signal transition_finished

@onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	color_rect.color = Color.RED
	color_rect.pivot_offset = color_rect.get_rect().get_center()


func fade_in(duration: float = 0.5) -> void:
	color_rect.scale = Vector2(0.0, 0.0)
	color_rect.modulate = Color.BLACK
	color_rect.color = Color(0.1, 0.0, 0.0, 1)  
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	tween.tween_property(color_rect, "scale", Vector2(1.5, 1.5), duration * 0.4)
	
	var flash_tween = create_tween()
	flash_tween.tween_property(color_rect, "modulate", Color(0.4, 0.0, 0.0, 1), duration * 0.15)
	flash_tween.tween_property(color_rect, "modulate", Color(0.2, 0.0, 0.0, 1), duration * 0.1)
	flash_tween.tween_property(color_rect, "modulate", Color(0.5, 0.05, 0.05, 1), duration * 0.15)
	flash_tween.tween_property(color_rect, "modulate", Color(0.15, 0.0, 0.0, 1), duration * 0.1)
	
	await tween.finished
	transition_midpoint.emit()


func fade_out(duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	
	tween.tween_property(color_rect, "scale", Vector2(0.0, 0.0), duration)
	tween.parallel().tween_property(color_rect, "modulate", Color(0.05, 0.0, 0.0, 1), duration)
	
	await tween.finished
	transition_finished.emit()
