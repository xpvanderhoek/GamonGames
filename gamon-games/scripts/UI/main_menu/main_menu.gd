extends Control

const MAP_SCENE := "res://scenes/map.tscn"
const OPTIONS_MENU := preload("res://scenes/UI/main_menu/options/options_menu.tscn")

func _ready() -> void:
	SaveLoad.save_meta()
	SaveLoad.load_on_start()

func _on_play_button_pressed() -> void:
	TransitionManager.change_scene(MAP_SCENE)

func _on_options_button_pressed() -> void:
	var options = OPTIONS_MENU.instantiate()
	add_child(options)

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_save_pressed() -> void:
	SaveLoad.save_data(PlayerStats)

func _on_load_pressed() -> void:
	SaveLoad.load_data(0)
