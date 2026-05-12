extends Control

var is_skip_busy : bool = false

func _ready() -> void:
	$GamonLogo.visible = false
	TransitionManager.change_scene(self.get_path())
	await get_tree().create_timer(0.5).timeout
	$GamonLogo.visible = true
	await get_tree().create_timer(4).timeout
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
