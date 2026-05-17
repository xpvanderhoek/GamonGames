extends Control

@onready var ign_input = $VBoxContainer/IGNInput

const MAP_SCENE := "res://scenes/map.tscn"
const OPTIONS_MENU := preload("res://scenes/UI/main_menu/options/options_menu.tscn")

func _on_play_button_pressed():
	ProfileManager.set_ign(ign_input.text)
	TransitionManager.change_scene(MAP_SCENE)

func _on_options_button_pressed() -> void:
	var options = OPTIONS_MENU.instantiate()
	add_child(options)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
