extends Control
@onready var window_button: OptionButton = $Menu/VBoxContainer/WindowMode

func _on_window_item_selected(index: int) -> void:
	var current_display : String = window_button.get_item_text(index)
	
	if current_display == "Fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	elif current_display == "Borderless Fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		
	elif current_display == "Windowed":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_back_pressed() -> void:
	queue_free()
