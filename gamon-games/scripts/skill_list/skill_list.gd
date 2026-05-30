extends Control

@onready var marrow_shards_label: Label = $Control/TextureRect/MarrowShardsLabel
@onready var skill_vbox_container: VBoxContainer = $Panel/VBoxContainer/HBoxContainer/ScrollContainer/SkillVboxContainer
@export var skills: Array[SkillData]
@onready var item_tooltip_panel: Panel = $Control/ItemTooltipPanel
@onready var tooltip_label: Label = $Control/ItemTooltipPanel/TooltipLabel

const MAIN_MENU_SCENE := "res://scenes/UI/main_menu/main_menu.tscn"

var skill_list_line: SkillListLine

var new_skill_line:= preload("res://scenes/skill_list/skill_list_line.tscn")

var _marrow_shards_base_modulate: Color
var _marrow_shards_base_position: Vector2
var _marrow_shards_flash_tween: Tween
var _marrow_shards_shake_tween: Tween

func _ready() -> void:
	_update_marrow_shards_label()
	RunData.marrow_shards_changed.connect(_update_marrow_shards_label)
	_marrow_shards_base_modulate = _get_marrow_shards_base_modulate()
	_marrow_shards_base_position = _get_marrow_shards_base_position()
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
			if line.upgrade_failed.is_connected(_on_skill_upgrade_failed) == false:
				line.upgrade_failed.connect(_on_skill_upgrade_failed)
	else:
		print("Skills array is empty")

func _get_marrow_shards_base_modulate() -> Color:
	if marrow_shards_label != null:
		return marrow_shards_label.modulate
	return Color(1, 1, 1, 1)

func _get_marrow_shards_base_position() -> Vector2:
	if marrow_shards_label != null:
		return marrow_shards_label.position
	return Vector2.ZERO

func _flash_marrow_shards_label() -> void:
	if marrow_shards_label == null:
		return
	if _marrow_shards_flash_tween != null and _marrow_shards_flash_tween.is_running():
		_marrow_shards_flash_tween.kill()
	if _marrow_shards_shake_tween != null and _marrow_shards_shake_tween.is_running():
		_marrow_shards_shake_tween.kill()
	marrow_shards_label.modulate = _marrow_shards_base_modulate
	marrow_shards_label.position = _marrow_shards_base_position
	_marrow_shards_flash_tween = create_tween()
	_marrow_shards_flash_tween.tween_property(
		marrow_shards_label,
		"modulate",
		Color(1, 0.3, 0.3, 1),
		0.08
	)
	_marrow_shards_flash_tween.tween_property(
		marrow_shards_label,
		"modulate",
		_marrow_shards_base_modulate,
		0.2
	)
	_marrow_shards_shake_tween = create_tween()
	_marrow_shards_shake_tween.tween_property(
		marrow_shards_label,
		"position",
		_marrow_shards_base_position + Vector2(-4, 0),
		0.05
	)
	_marrow_shards_shake_tween.tween_property(
		marrow_shards_label,
		"position",
		_marrow_shards_base_position + Vector2(4, 0),
		0.05
	)
	_marrow_shards_shake_tween.tween_property(
		marrow_shards_label,
		"position",
		_marrow_shards_base_position + Vector2(-3, 0),
		0.05
	)
	_marrow_shards_shake_tween.tween_property(
		marrow_shards_label,
		"position",
		_marrow_shards_base_position,
		0.06
	)

func _on_skill_tooltip_requested(text: String, max_level: int) -> void:
	if item_tooltip_panel == null or tooltip_label == null:
		return
	tooltip_label.text = text + "\nMax lvl: " + str(max_level)
	item_tooltip_panel.visible = text.strip_edges() != ""

func _on_skill_tooltip_cleared() -> void:
	if item_tooltip_panel:
		item_tooltip_panel.visible = false

func _on_skill_upgrade_failed() -> void:
	_flash_marrow_shards_label()


func _on_quit_button_pressed() -> void:
	SaveLoad.save_data()
	SoundManager.play_click()
	TransitionManager.change_scene(MAIN_MENU_SCENE)


func _on_quit_button_mouse_entered() -> void:
	SoundManager.play_hover()
