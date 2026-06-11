extends Control

const MAIN_MENU = "res://scenes/UI/main_menu/main_menu.tscn"

@onready var yes: Button = $Window/Yes
@onready var abandon: Button = $Window/Abandon

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if !RunData.run_active:
		get_tree().paused = false
		queue_free()
		return
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _on_yes_pressed() -> void:
	get_tree().paused = false
	SoundManager.stop_combat_music()
	RunData.end_run()
	SoundManager.play_click()
	TransitionManager.change_scene(MAIN_MENU)

func _on_no_pressed() -> void:
	SoundManager.play_click()
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	get_tree().paused = true
	queue_free()

func _on_button_hover():
	SoundManager.play_hover()
