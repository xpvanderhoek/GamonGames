extends CanvasLayer

signal transition_midpoint
signal transition_finished

@onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	color_rect.color = Color(0, 0, 0, 0)


func fade_in(duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished
	transition_midpoint.emit()


func fade_out(duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished
	transition_finished.emit()
