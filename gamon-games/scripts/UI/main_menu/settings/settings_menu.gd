extends Control

const ABANDON_SCREEN := preload("res://scenes/UI/main_menu/settings/abandon_confirm_window.tscn")

@onready var window_mode: OptionButton = $Window/Contents/TabContainer/Graphics/WindowMode/OptionButton
@onready var res_options: OptionButton = $Window/Contents/TabContainer/Graphics/Resolution/OptionButton
@onready var v_sync_button: CheckButton = $Window/Contents/TabContainer/Graphics/VSync/VSyncButton
@onready var fps_limit_button: OptionButton = $Window/Contents/TabContainer/Graphics/FPSLimit/OptionButton
@onready var speedrun_timer_button: CheckButton = $Window/Contents/TabContainer/Accessibility/SpeedrunTimer/SpeedrunTimerButton
@onready var colorblind_mode: OptionButton = $Window/Contents/TabContainer/Accessibility/ColorblindMode/OptionButton
@onready var font_option: OptionButton = $Window/Contents/TabContainer/Accessibility/FontFamily/OptionButton
@onready var title_label: Label = $Window/Title
@onready var abandon: Button = $Window/Contents/Abandon
@onready var master_slider: HSlider = $Window/Contents/TabContainer/Sound/Master/VolumeSlider
@onready var sfx_slider: HSlider = $Window/Contents/TabContainer/Sound/SFX/VolumeSlider
@onready var music_slider: HSlider = $Window/Contents/TabContainer/Sound/Music/VolumeSlider
@onready var master_label: Label = $Window/Contents/TabContainer/Sound/Master/ValueLabel
@onready var sfx_label: Label = $Window/Contents/TabContainer/Sound/SFX/ValueLabel
@onready var music_label: Label = $Window/Contents/TabContainer/Sound/Music/ValueLabel
@onready var keybinds_container: VBoxContainer = $Window/Contents/TabContainer/Keybinds
@onready var tab_container: TabContainer = $Window/Contents/TabContainer


@export var title : String
var last_resolution : Vector2i
var waiting_for_input_index: int = -1

func _ready() -> void:
	if RunData.run_active:
		abandon.visible = true
		title_label.text = "P A U S E D"
		get_tree().paused = true
	else:
		abandon.visible = false
		title_label.text = title
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	_fill_resolutions()
	_sync_graphics()
	_sync_accessibility()
	_sync_keybinds()
	
	tab_container.current_tab = Settings.last_settings_tab
	tab_container.tab_changed.connect(_on_tab_changed)

	master_slider.value_changed.connect(func(v): master_label.text = str(int(v*100)) + "%")
	sfx_slider.value_changed.connect(func(v): sfx_label.text = str(int(v*100)) + "%")
	music_slider.value_changed.connect(func(v): music_label.text = str(int(v*100)) + "%")
	master_label.text = str(int(master_slider.value*100)) + "%"
	sfx_label.text = str(int(sfx_slider.value*100)) + "%"
	music_label.text = str(int(music_slider.value*100)) + "%"

func _on_tab_changed(tab: int) -> void:
	Settings.last_settings_tab = tab

func _sync_keybinds():
	var index = 0
	for child in keybinds_container.get_children():
		if child is HBoxContainer:
			if index < Settings.data.spell_keybinds.size():
				var label := child.get_node("Label") as Label
				var button := child.get_node("Button") as Button
				
				var keycode = Settings.data.spell_keybinds[index]
				button.text = OS.get_keycode_string(keycode)
				
				# Ensure signals are connected only once
				if not button.pressed.is_connected(self._on_keybind_button_pressed):
					button.pressed.connect(self._on_keybind_button_pressed.bind(index, button))
				
				index += 1

func _on_keybind_button_pressed(index: int, button: Button):
	waiting_for_input_index = index
	button.text = "Press any key..."

var is_closing = false

func _input(event: InputEvent) -> void:
	if waiting_for_input_index != -1 and event is InputEventKey and event.pressed:
		var keycode = event.keycode
		if keycode != KEY_ESCAPE:
			Settings.data.spell_keybinds[waiting_for_input_index] = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			Settings.save_settings()
			Settings.keybinds_changed.emit()
		waiting_for_input_index = -1
		_sync_keybinds()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("escape"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

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
		
	# FPS Limit
	var fps_map = {0: 0, 30: 1, 60: 2, 120: 3, 144: 4, 200:5, 300:6}
	if fps_map.has(Settings.data.fps_limit):
		fps_limit_button.select(fps_map[Settings.data.fps_limit])
	else:
		fps_limit_button.select(0)
	
	speedrun_timer_button.button_pressed = Settings.data.show_speedrun_timer
	
	colorblind_mode.select(Settings.data.colorblind_mode)

func _sync_accessibility():
	font_option.clear()
	for font_name in Settings.FONT_NAMES:
		font_option.add_item(font_name)
	font_option.select(Settings.data.font_index)

func _on_back_pressed() -> void:
	if is_closing:
		return
	is_closing = true
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
	var resolutions := _get_resolutions()
	
	if current_display == "Fullscreen":
		res_options.disabled = true
		Settings.data.window_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		var current := DisplayServer.screen_get_size()
		if current in resolutions.values():
			var key : String = resolutions.find_key(current)
			res_options.select(resolutions.keys().find(key))
		else:
			res_options.select(-1)
	elif current_display == "Borderless Fullscreen":
		res_options.disabled = true
		Settings.data.window_mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		var current := DisplayServer.screen_get_size()
		if current in resolutions.values():
			var key : String = resolutions.find_key(current)
			res_options.select(resolutions.keys().find(key))
		else:
			res_options.select(-1)
	elif current_display == "Windowed":
		res_options.disabled = false
		Settings.data.window_mode = DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
		var res: Vector2i = Settings.data.resolution
		if res in resolutions.values():
			var key : String = resolutions.find_key(res)
			res_options.select(resolutions.keys().find(key))
			DisplayServer.window_set_size(res)
			get_window().move_to_center()
		else:
			res_options.select(-1)
		
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

func _on_fps_limit_item_selected(index: int) -> void:
	var fps_values = [0, 30, 60, 120, 144, 200, 300]
	if index >= 0 and index < fps_values.size():
		Settings.data.fps_limit = fps_values[index]
		Engine.max_fps = Settings.data.fps_limit
		Settings.save_settings()

func _on_speedrun_timer_button_pressed() -> void:
	Settings.data.show_speedrun_timer = speedrun_timer_button.button_pressed
	Settings.save_settings()

func _on_colorblind_item_selected(index: int) -> void:
	Settings.data.colorblind_mode = index
	Settings.apply_settings()
	Settings.save_settings()

func _on_font_item_selected(index: int) -> void:
	Settings.data.font_index = index
	Settings.apply_font_settings()
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
