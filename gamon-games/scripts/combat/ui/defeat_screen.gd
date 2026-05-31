extends Control

var title: Label = null
var message: Label = null
var bg_panel: PanelContainer = null
var retry_button: Button = null
var menu_button: Button = null
var _tween: Tween = null

func _ready() -> void:
	title = get_node_or_null("PanelContainer/VBoxContainer/Title")
	message = get_node_or_null("PanelContainer/VBoxContainer/Message")
	retry_button = get_node_or_null("PanelContainer/VBoxContainer/ButtonContainer/RetryButton")
	menu_button = get_node_or_null("PanelContainer/VBoxContainer/ButtonContainer/MenuButton")
	bg_panel = get_node_or_null("PanelContainer")
	
	if not retry_button:
		print("ERROR: retry_button not found!")
	
	if not menu_button:
		print("ERROR: menu_button not found!")
	
	if retry_button:
		retry_button.pressed.connect(func(): 
			RunData.end_run()
			RunData.new_run()
			SaveLoad.save_data()
			TransitionManager.change_scene("res://scenes/map/map.tscn", TransitionManager.TransitionType.FADE)
		)
		retry_button.disabled = true
		retry_button.modulate.a = 0
	
	if menu_button:
		menu_button.pressed.connect(func():
			RunData.end_run()
			SaveLoad.save_data()
			TransitionManager.change_scene("res://scenes/UI/main_menu/main_menu.tscn", TransitionManager.TransitionType.FADE)
		)
		menu_button.disabled = true
		menu_button.modulate.a = 0
	
	if bg_panel:
		bg_panel.modulate.a = 0
	
	if title:
		title.modulate.a = 0
	
	if message:
		message.modulate.a = 0
	
	_play_defeat_sequence()

func _play_defeat_sequence() -> void:
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(bg_panel, "modulate:a", 1.0, 1.0)
	
	_tween.tween_callback(func():
		_animate_title()
	)
	_tween.tween_interval(0.8)  
	
	_tween.tween_callback(func():
		_animate_message()
	)
	_tween.tween_interval(1.0)  
	
	_tween.tween_callback(func():
		_show_buttons()
	)

func _animate_title() -> void:
	if not title:
		return
	
	title.position.y += 50
	title.modulate.a = 0
	title.scale = Vector2(1.2, 1.2)
	
	var local_tween = create_tween()
	local_tween.set_trans(Tween.TRANS_BACK)
	local_tween.set_ease(Tween.EASE_OUT)
	local_tween.set_parallel(true)
	
	local_tween.tween_property(title, "position:y", title.position.y - 50, 0.6)
	local_tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.6)
	local_tween.tween_property(title, "modulate:a", 1.0, 0.6)

func _animate_message() -> void:
	if not message:
		return
	
	var local_tween = create_tween()
	local_tween.set_trans(Tween.TRANS_SINE)
	local_tween.set_ease(Tween.EASE_OUT)
	
	message.modulate.a = 0
	local_tween.tween_property(message, "modulate:a", 1.0, 0.8).set_delay(0.2)

func _show_buttons() -> void:
	if not retry_button or not menu_button:
		return
	
	retry_button.scale = Vector2(1, 1)
	menu_button.scale = Vector2(1, 1)
	
	var button_tween = create_tween()
	button_tween.set_trans(Tween.TRANS_SINE)
	button_tween.set_ease(Tween.EASE_OUT)
	button_tween.set_parallel(true)
	button_tween.tween_property(retry_button, "modulate:a", 1.0, 0.5)
	button_tween.tween_property(menu_button, "modulate:a", 1.0, 0.5)
	
	button_tween.tween_callback(func():
		if retry_button and menu_button:
			retry_button.disabled = false
			menu_button.disabled = false
			_add_pulse_effect(retry_button)
	)

func _add_pulse_effect(button: Button) -> void:
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.8)
	pulse_tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.8)
