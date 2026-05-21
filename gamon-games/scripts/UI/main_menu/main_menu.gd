extends Control

const MAP_SCENE := "res://scenes/map/map.tscn"
const OPTIONS_MENU := preload("res://scenes/UI/main_menu/options/options_menu.tscn")
const PROFILES_MENU := preload("res://scenes/UI/main_menu/profiles/profiles_menu.tscn")

@onready var profile_button: Button = $ProfileButton

func _ready() -> void:
	SaveLoad.profile_changed.connect(_on_profile_changed)
	
	if !SaveLoad.do_any_saves_exist():
		var profiles = PROFILES_MENU.instantiate()
		profiles.title = "Create a profile"
		add_child(profiles)
	else:
		SaveLoad.load_on_start()
	profile_button.text = "Profile: " + PlayerStats.profile_name

func _on_play_button_pressed() -> void:
	TransitionManager.change_scene(MAP_SCENE)

func _on_options_button_pressed() -> void:
	var options = OPTIONS_MENU.instantiate()
	add_child(options)

func _on_quit_button_pressed() -> void:
	SaveLoad.save_data()
	SaveLoad.save_meta()
	get_tree().quit()

func _on_save_pressed() -> void:
	SaveLoad.save_data()

func _on_load_pressed() -> void:
	SaveLoad.load_data(0)

func _on_profile_button_pressed() -> void:
	var profiles = PROFILES_MENU.instantiate()
	add_sibling(profiles)

func _on_profile_changed():
	profile_button.text = "Profile: " + PlayerStats.profile_name
