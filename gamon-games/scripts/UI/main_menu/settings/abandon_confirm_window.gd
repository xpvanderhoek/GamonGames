extends Control

const MAIN_MENU = "res://scenes/UI/main_menu/main_menu.tscn"

@onready var yes: Button = $Window/Yes
@onready var abandon: Button = $Window/Abandon

func _ready() -> void:
	if !RunData.run_active:
		get_tree().paused = false
		queue_free()
		return
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	get_tree().paused = false

func _on_yes_pressed() -> void:
	RunData.end_run()
	TransitionManager.change_scene(MAIN_MENU)

func _on_no_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	queue_free()
