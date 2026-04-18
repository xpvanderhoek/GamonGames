extends Control

signal continue_pressed

@onready var exp_recieved: Label = $PanelContainer/VBoxContainer/ExpRecieved
@onready var current_level: Label = $PanelContainer/VBoxContainer/LevelContainer/CurrentLevel
@onready var next_level: Label = $PanelContainer/VBoxContainer/LevelContainer/NextLevel
@onready var progress_bar: ProgressBar = $PanelContainer/VBoxContainer/LevelContainer/ProgressBar
@onready var continue_button: Button = $PanelContainer/VBoxContainer/MarginContainer/ContinueButton

var _target_exp: int = 0
var _current_displayed_exp: int = 0
var _exp_text_label: Label = null

func _ready() -> void:
	if continue_button:
		continue_button.pressed.connect(func(): continue_pressed.emit())
		
	if progress_bar:
		_exp_text_label = Label.new()
		_exp_text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_exp_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_exp_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_exp_text_label.add_theme_constant_override("outline_size", 4)
		_exp_text_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		progress_bar.add_child(_exp_text_label)
		continue_button.disabled = true 

func setup(exp_gained: int) -> void:
	if exp_recieved:
		exp_recieved.text = "EXP Received: " + str(exp_gained)
		
	_target_exp = RunData.current_exp
	var starting_exp = max(0, _target_exp - exp_gained)
	_current_displayed_exp = starting_exp
	
	_update_ui_for_exp(_current_displayed_exp)
	_animate_exp_bar(starting_exp, _target_exp)

func _get_level_from_exp(exp_amount: int) -> int:
	var lvl = 1
	while lvl < RunData.EXP_PER_LEVEL.size() - 1 and exp_amount >= RunData.EXP_PER_LEVEL[lvl + 1]:
		lvl += 1
	return lvl

func _update_ui_for_exp(exp_amount: int) -> void:
	var lvl = _get_level_from_exp(exp_amount)
	
	if current_level:
		current_level.text = "Lvl " + str(lvl)
		
	if next_level:
		if lvl >= RunData.EXP_PER_LEVEL.size() - 1:
			next_level.text = "Max"
		else:
			next_level.text = "Lvl " + str(lvl + 1)
			
	if progress_bar:
		var current_req = RunData.EXP_PER_LEVEL[lvl] if lvl < RunData.EXP_PER_LEVEL.size() else RunData.EXP_PER_LEVEL[-1]
		var next_req = RunData.EXP_PER_LEVEL[lvl + 1] if lvl + 1 < RunData.EXP_PER_LEVEL.size() else current_req
		
		if next_req == current_req:
			progress_bar.max_value = 1.0
			progress_bar.value = 1.0
			if _exp_text_label:
				_exp_text_label.text = "MAX LEVEL"
		else:
			progress_bar.max_value = next_req - current_req
			progress_bar.value = exp_amount - current_req
			if _exp_text_label:
				_exp_text_label.text = str(exp_amount - current_req) + " / " + str(next_req - current_req)

func _animate_exp_bar(from_exp: int, to_exp: int) -> void:
	var tween = create_tween()
	var start_lvl = _get_level_from_exp(from_exp)
	var end_lvl = _get_level_from_exp(to_exp)
	
	var current_anim_exp = from_exp
	
	
	for lvl in range(start_lvl, end_lvl):
		var level_up_exp = RunData.EXP_PER_LEVEL[lvl + 1]
		tween.tween_method(_update_ui_for_exp, current_anim_exp, level_up_exp, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(func():
			
			pass
		).set_delay(0.2)
		current_anim_exp = level_up_exp
		
	
	if current_anim_exp < to_exp:
		tween.tween_method(_update_ui_for_exp, current_anim_exp, to_exp, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
	tween.tween_callback(func():
		if continue_button:
			continue_button.disabled = false
	)
