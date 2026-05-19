extends Control

@onready var window_mode: OptionButton = $Window/Contents/GraphicsContainer/WindowMode/OptionButton

func _ready() -> void:
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	_sync_graphics()

func _sync_all_settings():
	pass

func _sync_graphics():
	var current_win_mode = DisplayServer.window_get_mode()
	match current_win_mode:
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			window_mode.select(1)
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			window_mode.select(2)
		DisplayServer.WINDOW_MODE_WINDOWED:
			window_mode.select(3)
	
	

func _on_back_pressed() -> void:
	await _fade_out()
	queue_free()

func _fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished

func _on_window_item_selected(index: int):
	var current_display : String = window_mode.get_item_text(index)
	
	if current_display == "Fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	elif current_display == "Borderless Fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif current_display == "Windowed":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_resolution_item_selected(index: int) -> void:
	match index:
		0:
			DisplayServer.window_set_size(Vector2i(1280,720))
		1:
			DisplayServer.window_set_size(Vector2i(1920,1080))
		2:
			DisplayServer.window_set_size(Vector2i(2560,1440))
