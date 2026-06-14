extends Control

signal continue_pressed


@onready var title: Label = $PanelContainer/PanelMargin/VBoxContainer/Title
@onready var exp_recieved: Label = $PanelContainer/PanelMargin/VBoxContainer/ExpRecieved
@onready var current_level: Label = $PanelContainer/PanelMargin/VBoxContainer/LevelContainer/CurrentLevel
@onready var next_level: Label = $PanelContainer/PanelMargin/VBoxContainer/LevelContainer/NextLevel
@onready var progress_bar: ProgressBar = $PanelContainer/PanelMargin/VBoxContainer/LevelContainer/ProgressBar
@onready var continue_button: Button = $PanelContainer/PanelMargin/VBoxContainer/MarginContainer/ContinueButton
@onready var h_separator: HSeparator = $PanelContainer/PanelMargin/VBoxContainer/HSeparator
@onready var level_up: Label = $PanelContainer/PanelMargin/VBoxContainer/LevelUp
@onready var spell_options_container: VBoxContainer = $PanelContainer/PanelMargin/VBoxContainer/SpellOptionsContainer

@export var SPELLS: Array[SpellData] = []
const SPELL_DIR := "res://resources/combat_spells/"
const CHOOSE_BUTTON_SCENE = preload("res://Scenes/combat/ui/ChooseNewAbilityButton.tscn")
const MAX_SPELL_SLOTS := 6

var _target_exp: int = 0
var _animation_start_exp: int = 0
var _animation_end_exp: int = 0
var _current_displayed_exp: int = 0
var _last_tick_exp: int = 0
var _exp_text_label: Label = null
var _did_level_up: bool = false
var _pending_level_ups: int = 0
var _all_spells: Array[SpellData] = []
var _selected_spell: SpellData = null
var _is_campfire_training: bool = false

func setup_campfire_training() -> void:
	_is_campfire_training = true
	if title:
		title.text = "Campfire Training"
	if exp_recieved:
		exp_recieved.hide()
	if current_level:
		current_level.get_parent().hide()
	if progress_bar:
		progress_bar.hide()
	
	_did_level_up = true
	_show_spell_options()

func _ready() -> void:
	if continue_button:
		continue_button.pressed.connect(_on_continue_button_pressed)
		continue_button.disabled = true
		
	if progress_bar:
		_exp_text_label = progress_bar.get_node("ExpText")
	
	_load_all_spells()

func setup(exp_gained: int) -> void:
	if exp_recieved:
		exp_recieved.text = "EXP Received: " + str(exp_gained)
		
	_target_exp = RunData.current_exp
	var starting_exp: int = max(0, _target_exp - exp_gained)
	_current_displayed_exp = starting_exp
	_animation_start_exp = starting_exp
	_animation_end_exp = _target_exp
	_last_tick_exp = starting_exp
	
	var start_lvl: int = _get_level_from_exp(starting_exp)
	var end_lvl: int = _get_level_from_exp(_target_exp)
	_did_level_up = end_lvl > start_lvl
	_pending_level_ups = max(0, end_lvl - start_lvl)
	_selected_spell = null
	
	_update_ui_for_exp(_current_displayed_exp)
	_animate_exp_bar(starting_exp, _target_exp)

func _load_all_spells() -> void:
	_all_spells = SPELLS
	return
	var dir = DirAccess.open(SPELL_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var spell = load(SPELL_DIR + file_name) as SpellData
			if spell != null:
				_all_spells.append(spell)
		file_name = dir.get_next()
	dir.list_dir_end()

func _get_level_from_exp(exp_amount: int) -> int:
	var lvl = 1
	while lvl < RunData.EXP_PER_LEVEL.size() - 1 and exp_amount >= RunData.EXP_PER_LEVEL[lvl + 1]:
		lvl += 1
	return lvl

func _update_ui_for_exp(exp_amount: float) -> void:
	var exp_value := int(floor(exp_amount))
	var lvl: int = _get_level_from_exp(exp_value)
	_play_expbar_ticks(exp_value)
	
	if current_level:
		current_level.text = "Lvl " + str(lvl)
		
	if next_level:
		if lvl >= RunData.EXP_PER_LEVEL.size() - 1:
			next_level.text = "Max"
		else:
			next_level.text = "Lvl " + str(lvl + 1)
			
	if progress_bar:
		var current_req: int = RunData.EXP_PER_LEVEL[lvl] if lvl < RunData.EXP_PER_LEVEL.size() else RunData.EXP_PER_LEVEL[-1]
		var next_req: int = RunData.EXP_PER_LEVEL[lvl + 1] if lvl + 1 < RunData.EXP_PER_LEVEL.size() else current_req
		
		if next_req == current_req:
			progress_bar.max_value = 1.0
			progress_bar.value = 1.0
			if _exp_text_label:
				_exp_text_label.text = "MAX LEVEL"
		else:
			progress_bar.max_value = next_req - current_req
			progress_bar.value = exp_value - current_req
			if _exp_text_label:
				_exp_text_label.text = str(exp_value - current_req) + " / " + str(next_req - current_req)

func _play_expbar_ticks(exp_value: int) -> void:
	var target_exp := clampi(exp_value, _animation_start_exp, _animation_end_exp)
	if target_exp <= _last_tick_exp:
		return

	var exp_span = max(1, _animation_end_exp - _animation_start_exp)
	while _last_tick_exp < target_exp:
		_last_tick_exp += 1
		if _last_tick_exp <= _animation_start_exp:
			continue

		var progress := float(_last_tick_exp - _animation_start_exp) / float(exp_span)
		SoundManager.play_xpbar_tick(lerpf(0.88, 1.22, clampf(progress, 0.0, 1.0)))

func _animate_exp_bar(from_exp: int, to_exp: int) -> void:
	var tween: Tween = create_tween()
	var start_lvl: int = _get_level_from_exp(from_exp)
	var end_lvl: int = _get_level_from_exp(to_exp)
	
	var current_anim_exp: int = from_exp
	
	for lvl in range(start_lvl, end_lvl):
		var level_up_exp: int = RunData.EXP_PER_LEVEL[lvl + 1]
		tween.tween_method(_update_ui_for_exp, current_anim_exp, level_up_exp, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func():
			pass
		).set_delay(0.5)
		current_anim_exp = level_up_exp
	
	if current_anim_exp < to_exp:
		tween.tween_method(_update_ui_for_exp, current_anim_exp, to_exp, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	tween.tween_callback(_on_animation_finished)

func _on_animation_finished() -> void:
	if _pending_level_ups > 0:
		_play_levelup_sfx()
		_show_spell_options()
	else:
		if continue_button:
			continue_button.disabled = false

func _play_levelup_sfx() -> void:
	SoundManager.play_levelup()

func _show_spell_options() -> void:
	_clear_spell_options()
	_selected_spell = null
	if continue_button:
		continue_button.disabled = true

	var combat_manager := get_parent() as CombatManager
	var shuffled_spells = _all_spells.duplicate()
	if _is_campfire_training:
		shuffled_spells = RunData.spells.duplicate()
		level_up.text = "Choose a spell to upgrade"
		
	shuffled_spells.shuffle()
	var can_unlock_new_spell := RunData.spells.size() < MAX_SPELL_SLOTS
	var options: Array[SpellData] = []
	for spell in shuffled_spells:
		if not can_unlock_new_spell:
			var existing_spell := RunData.get_spell_by_id(spell.spell_id)
			if existing_spell == null:
				continue
		if options.size() >= 3:
			break
		options.append(spell)
	
	if options.is_empty():
		if continue_button:
			continue_button.disabled = false
		return
	
	for spell in options:
		var button = CHOOSE_BUTTON_SCENE.instantiate() as ChooseNewAbilityButton
		var existing: SpellData = RunData.get_spell_by_id(spell.spell_id)
		
		button.setup(spell, existing != null)
		button.pressed.connect(func(): _on_spell_option_clicked(button))

		var spell_ref := spell
		button.mouse_entered.connect(func():
			if combat_manager != null and is_instance_valid(combat_manager):
				combat_manager.show_spell_tooltip(spell_ref, true)
			elif _is_campfire_training:
				button.show_campfire_tooltip()
		)
		button.mouse_exited.connect(func():
			if combat_manager != null and is_instance_valid(combat_manager):
				combat_manager.hide_spell_tooltip()
			elif _is_campfire_training:
				button.hide_campfire_tooltip()
		)

		spell_options_container.add_child(button)
	
	h_separator.visible = true
	level_up.visible = true
	spell_options_container.visible = true

func _clear_spell_options() -> void:
	for child in spell_options_container.get_children():
		child.queue_free()
	_selected_spell = null

func _on_spell_option_clicked(button: ChooseNewAbilityButton) -> void:
	var combat_manager := get_parent() as CombatManager
	if combat_manager != null and is_instance_valid(combat_manager):
		combat_manager.hide_spell_tooltip()
	elif _is_campfire_training:
		button.hide_campfire_tooltip()
	
	_selected_spell = button.spell_data
	
	for child in spell_options_container.get_children():
		if child is ChooseNewAbilityButton:
			child.set_selected(child == button)
			
	if continue_button:
		continue_button.disabled = false

func _on_continue_button_pressed() -> void:
	var combat_manager := get_parent() as CombatManager
	if combat_manager != null and is_instance_valid(combat_manager):
		combat_manager.hide_spell_tooltip()
		
	if _pending_level_ups > 0 and _selected_spell != null:
		var existing = RunData.get_spell_by_id(_selected_spell.spell_id)
		
		if existing:
			RunData.upgrade_spell(_selected_spell.spell_id)
		else:
			RunData.add_spell(_selected_spell)
		
		_pending_level_ups -= 1
		
		if _pending_level_ups > 0:
			_show_spell_options()
			return
		
		h_separator.visible = false
		level_up.visible = false
		spell_options_container.visible = false
		_clear_spell_options()
		_selected_spell = null
		
	continue_pressed.emit()
