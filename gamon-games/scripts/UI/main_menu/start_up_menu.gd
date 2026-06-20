extends Control

var is_skip_busy : bool = false

func _ready() -> void:
	$GamonLogo.modulate.a = 0.0
	$GamonLogo.visible = true
	var tween = create_tween()
	tween.tween_property($GamonLogo, "modulate:a", 1.0, 1.0)
	await get_tree().create_timer(4.5).timeout
	_skip_intro()

func _skip_intro():
	
	if (!is_skip_busy):
		is_skip_busy = true
		TransitionManager.change_scene("res://scenes/UI/main_menu/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_skip_intro()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_skip_intro()
