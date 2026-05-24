extends Control

@onready var marrow_shards_label: Label = $Control/TextureRect/MarrowShardsLabel
@onready var skill_vbox_container: VBoxContainer = $Panel/VBoxContainer/HBoxContainer/ScrollContainer/SkillVboxContainer
@export var skills: Array[SkillData]

const MAIN_MENU_SCENE := "res://scenes/UI/main_menu/main_menu.tscn"

var skill_list_line: SkillListLine

var new_skill_line:= preload("res://scenes/skill_list/skill_list_line.tscn")

func _ready() -> void:
	_update_marrow_shards_label()
	RunData.marrow_shards_changed.connect(_update_marrow_shards_label)
	_load_skill_lines(skills)

func _update_marrow_shards_label() -> void:
	marrow_shards_label.text = str(RunData.marrow_shards)

func _load_skill_lines(skills) -> void:
	if skills:
		for skill in skills:
			var line = new_skill_line.instantiate()
			skill_vbox_container.add_child(line)
			line.setup_skill(skill)
	else:
		print("Skills array is empty")


func _on_quit_button_pressed() -> void:
	SaveLoad.save_data()
	TransitionManager.change_scene(MAIN_MENU_SCENE)
