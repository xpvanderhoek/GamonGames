extends Control

const MAP_SCENE := "res://scenes/map.tscn"

func _on_play_button_pressed() -> void:
	TransitionManager.change_scene(MAP_SCENE)

func _on_options_button_pressed() -> void:
	pass

func _on_quit_button_pressed() -> void:
	get_tree().quit()
