extends Control

const MAP_SCENE := "res://scenes/map/map.tscn"
const OPTIONS_MENU := preload("res://scenes/UI/main_menu/options/options_menu.tscn")

func _on_play_button_pressed() -> void:
	TransitionManager.change_scene(MAP_SCENE)

func _on_options_button_pressed() -> void:
	var options = OPTIONS_MENU.instantiate()
	add_child(options)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
