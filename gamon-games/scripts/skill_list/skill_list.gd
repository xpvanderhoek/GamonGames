extends Control

@onready var marrow_shards_label: Label = $Control/TextureRect/MarrowShardsLabel
@onready var skill_vbox_container: VBoxContainer = $Panel/VBoxContainer/HBoxContainer/ScrollContainer/SkillVboxContainer
@export var skills: Array[SkillData]
@onready var item_tooltip_panel: Panel = $Control/ItemTooltipPanel
@onready var tooltip_label: Label = $Control/ItemTooltipPanel/TooltipLabel

const MAIN_MENU_SCENE := "res://scenes/UI/main_menu/main_menu.tscn"

var skill_list_line: SkillListLine

var new_skill_line:= preload("res://scenes/skill_list/skill_list_line.tscn")

func _ready() -> void:
	_update_marrow_shards_label()
	RunData.marrow_shards_changed.connect(_update_marrow_shards_label)
	if item_tooltip_panel:
		item_tooltip_panel.visible = false
		tooltip_label.text = ""
	_load_skill_lines(skills)

func _update_marrow_shards_label() -> void:
	marrow_shards_label.text = str(RunData.marrow_shards)

func _load_skill_lines(skills) -> void:
	if skills:
		for skill in skills:
			var line = new_skill_line.instantiate()
			skill_vbox_container.add_child(line)
			line.setup_skill(skill)
			if line.tooltip_requested.is_connected(_on_skill_tooltip_requested) == false:
				line.tooltip_requested.connect(_on_skill_tooltip_requested)
			if line.tooltip_cleared.is_connected(_on_skill_tooltip_cleared) == false:
				line.tooltip_cleared.connect(_on_skill_tooltip_cleared)
	else:
		print("Skills array is empty")

func _on_skill_tooltip_requested(text: String) -> void:
	if item_tooltip_panel == null or tooltip_label == null:
		return
	tooltip_label.text = text
	item_tooltip_panel.visible = text.strip_edges() != ""

func _on_skill_tooltip_cleared() -> void:
	if item_tooltip_panel:
		item_tooltip_panel.visible = false


func _on_quit_button_pressed() -> void:
	SaveLoad.save_data()
	SoundManager.play_click()
	TransitionManager.change_scene(MAIN_MENU_SCENE)


func _on_quit_button_mouse_entered() -> void:
	SoundManager.play_hover()
