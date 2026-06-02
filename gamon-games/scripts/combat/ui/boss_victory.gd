extends Control

var title: Label = null
var message: Label = null
var bg_panel: PanelContainer = null
var continue_button: Button = null
var _tween: Tween = null

func _ready() -> void:
	if RunData.run_active:
		RunData.end_run()
	get_tree().paused = true
	title = get_node_or_null("PanelContainer/VBoxContainer/Title")
	message = get_node_or_null("PanelContainer/VBoxContainer/Message")
	continue_button = get_node_or_null("PanelContainer/VBoxContainer/ContinueButton")
	bg_panel = get_node_or_null("PanelContainer")
	
	if not continue_button:
		print("ERROR: continue_button not found!")
	
	if continue_button:
		get_tree().paused = false
		continue_button.pressed.connect(func(): 
			TransitionManager.change_scene("res://scenes/UI/main_menu/main_menu.tscn", TransitionManager.TransitionType.FADE)
		)
		continue_button.disabled = true
		continue_button.modulate.a = 0
	
	if bg_panel:
		bg_panel.modulate.a = 0
	
	if title:
		title.modulate.a = 0
	
	if message:
		message.modulate.a = 0
	
	_play_victory_sequence()

func _play_victory_sequence() -> void:
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(bg_panel, "modulate:a", 1.0, 0.8)
	
	_tween.tween_callback(func():
		_animate_title()
	)
	_tween.tween_interval(0.6)  
	
	_tween.tween_callback(func():
		_animate_message()
	)
	_tween.tween_interval(0.8)  
	
	_tween.tween_callback(func():
		_show_continue_button()
	)

func _animate_title() -> void:
	if not title:
		return
	
	title.position.y -= 50
	title.modulate.a = 0
	title.scale = Vector2(0.8, 0.8)
	
	var local_tween = create_tween()
	local_tween.set_trans(Tween.TRANS_BACK)
	local_tween.set_ease(Tween.EASE_OUT)
	local_tween.set_parallel(true)
	
	local_tween.tween_property(title, "position:y", title.position.y + 50, 0.5)
	local_tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.5)
	local_tween.tween_property(title, "modulate:a", 1.0, 0.5)

func _animate_message() -> void:
	if not message:
		return
	
	var local_tween = create_tween()
	local_tween.set_trans(Tween.TRANS_SINE)
	local_tween.set_ease(Tween.EASE_OUT)
	
	message.modulate.a = 0
	local_tween.tween_property(message, "modulate:a", 1.0, 0.6).set_delay(0.3)

func _show_continue_button() -> void:
	if not continue_button:
		return
	
	continue_button.scale = Vector2(1, 1)
	var button_tween = create_tween()
	button_tween.set_trans(Tween.TRANS_SINE)
	button_tween.set_ease(Tween.EASE_OUT)
	button_tween.tween_property(continue_button, "modulate:a", 1.0, 0.5)
	button_tween.tween_callback(func():
		if continue_button:
			continue_button.disabled = false
			var pulse_tween = create_tween()
			pulse_tween.set_loops()
			pulse_tween.set_trans(Tween.TRANS_SINE)
			pulse_tween.set_ease(Tween.EASE_IN_OUT)
			pulse_tween.tween_property(continue_button, "modulate:a", 0.7, 1.2)
			pulse_tween.tween_property(continue_button, "modulate:a", 1.0, 1.2)
	)
