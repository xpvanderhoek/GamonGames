extends Control

const ABANDON_SCREEN := preload("res://scenes/UI/main_menu/settings/abandon_confirm_window.tscn")

@onready var window_mode: OptionButton = $Window/Contents/GraphicsContainer/WindowMode/OptionButton
@onready var res_options: OptionButton = $Window/Contents/GraphicsContainer/Resolution/OptionButton
@onready var v_sync_button: CheckBox = $Window/Contents/GraphicsContainer/VSyncButton
@onready var title_label: Label = $Window/Title
@onready var abandon: Button = $Window/Contents/Abandon
@onready var master_slider: HSlider = $Window/Contents/SoundContainer/Master/VolumeSlider
@onready var sfx_slider: HSlider = $Window/Contents/SoundContainer/SFX/VolumeSlider
@onready var music_slider: HSlider = $Window/Contents/SoundContainer/Music/VolumeSlider

@export var title : String
var last_resolution : Vector2i

func _ready() -> void:
	if RunData.run_active:
		abandon.visible = true
		title_label.text = "P A U S E D"
	else:
		abandon.visible = false
		title_label.text = title
	get_tree().paused = true
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	_fill_resolutions()
	_sync_graphics()

func _fill_resolutions():
	var resolutions := _get_resolutions()
	res_options.clear()
	
	for key in resolutions.keys():
		res_options.add_item(key)

func _get_resolutions() -> Dictionary:
	var resolutions : Dictionary = {
		"1280x720": Vector2i(1280, 720),
		"1600x900": Vector2i(1600, 900),
		"1920x1080": Vector2i(1920, 1080),
		"2560x1440": Vector2i(2560, 1440)
	}
	
	return resolutions

func _sync_graphics():
	# Window mode
	var current_win_mode = DisplayServer.window_get_mode()
	match current_win_mode:
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			window_mode.select(0)
			res_options.disabled = true
		DisplayServer.WINDOW_MODE_FULLSCREEN:
			window_mode.select(2)
			res_options.disabled = true
		DisplayServer.WINDOW_MODE_WINDOWED:
			window_mode.select(1)
			res_options.disabled = false
	
	# Resolution
	var current : Vector2i = DisplayServer.window_get_size()
	var resolutions : Dictionary = _get_resolutions()
	
	if current in resolutions.values():
		var key : String = resolutions.find_key(current)
		res_options.select(resolutions.keys().find(key))
	else:
		res_options.select(-1)
	
	#VSync
	if DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED:
		v_sync_button.button_pressed = true
	else:
		v_sync_button.button_pressed = false

func _on_back_pressed() -> void:
	SoundManager.play_click()
	await _fade_out()
	get_tree().paused = false
	queue_free()

func _on_back_hover() -> void:
	SoundManager.play_hover()

func _fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished

func _on_window_item_selected(index: int):
	var current_display : String = window_mode.get_item_text(index)
	
	if current_display == "Fullscreen":
		res_options.disabled = true
		res_options.select(-1)
		Settings.data.window_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	elif current_display == "Borderless Fullscreen":
		res_options.disabled = true
		res_options.select(-1)
		Settings.data.window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif current_display == "Windowed":
		res_options.disabled = false
		Settings.data.window_mode = DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if OS.has_feature("macos"): # fix for mac being buggy with res changes
			get_window().move_to_center()
			var pos := DisplayServer.window_get_position()
			DisplayServer.window_set_position(pos + Vector2i(0, 1))
	Settings.save_settings()

func _on_resolution_item_selected(index: int) -> void:
	var resolutions := _get_resolutions()
	var res: Vector2i = resolutions.values()[index]
	last_resolution = res
	DisplayServer.window_set_size(res)
	get_window().move_to_center()
	Settings.data.resolution = res
	Settings.save_settings()

func _on_v_sync_button_pressed() -> void:
	if v_sync_button.button_pressed:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		Settings.data.vsync = true
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Settings.data.vsync = false
	Settings.save_settings()

func _on_abandon_pressed() -> void:
	SoundManager.play_click()
	add_sibling(ABANDON_SCREEN.instantiate())

func _on_abandon_hover():
	SoundManager.play_hover()

func _on_volume_slider_done_sliding(slider: VolumeSlider, value_changed: bool) -> void:
	if !value_changed:
		return
	else:
		match slider.bus_name:
			"Master":
				Settings.data.master_volume = slider.value
			"SFX":
				Settings.data.sfx_volume = slider.value
			"Music":
				Settings.data.music_volume = slider.value
		Settings.save_settings()
