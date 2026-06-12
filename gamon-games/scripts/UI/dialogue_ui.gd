extends CanvasLayer

var current_dialogue = []
var index = 0
var char_index = 0

var typing_speed := 0.03
var typing_timer: Timer

var auto_skip := false
var auto_skip_delay := 1.0
var auto_skip_timer: Timer

signal dialogue_completed

@onready var name_label = $Panel/Label
@onready var text_label = $Panel/RichTextLabel
@onready var auto_skip_toggle = $Panel/AutoSkipToggle

func _ready():
	hide()

	typing_timer = Timer.new()
	typing_timer.wait_time = typing_speed
	typing_timer.one_shot = false
	typing_timer.timeout.connect(_typewriter_step)
	add_child(typing_timer)

	auto_skip_timer = Timer.new()
	auto_skip_timer.wait_time = auto_skip_delay
	auto_skip_timer.one_shot = true
	auto_skip_timer.timeout.connect(_on_auto_skip_timeout)
	add_child(auto_skip_timer)

	auto_skip_toggle.toggled.connect(_on_auto_skip_toggled)

	DialogueManager.register_ui(self)

	_apply_font_settings()
	Settings.font_settings_changed.connect(_apply_font_settings)

func start_dialogue(dialogue):
	current_dialogue = dialogue
	index = 0
	show_line()

func show_line():
	auto_skip_timer.stop()

	if index >= current_dialogue.size():
		hide()
		dialogue_completed.emit()
		return

	var line = current_dialogue[index]

	name_label.text = line["speaker"]
	text_label.text = ""
	char_index = 0

	typing_timer.start()

func _typewriter_step():
	var line = current_dialogue[index]

	if char_index < line["text"].length():
		text_label.text += line["text"][char_index]
		char_index += 1
	else:
		typing_timer.stop()

		if auto_skip:
			auto_skip_timer.wait_time = max(0.5, line["text"].length() * 0.03)
			auto_skip_timer.start()

func next_line():
	auto_skip_timer.stop()

	if not typing_timer.is_stopped():
		var line = current_dialogue[index]
		text_label.text = line["text"]
		char_index = line["text"].length()
		typing_timer.stop()
	else:
		index += 1
		show_line()

func previous_line():
	if index > 0:
		auto_skip_timer.stop()
		index -= 1
		show_line()

func _input(event):
	if not is_visible():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_accept"):
			next_line()
		elif event.is_action_pressed("ui_text_backspace"):
			previous_line()

	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			next_line()

func _on_auto_skip_toggled(button_pressed):
	auto_skip = button_pressed

func _on_auto_skip_timeout():
	next_line()

func force_close_dialogue() -> void:
	if typing_timer:
		typing_timer.stop()
	if auto_skip_timer:
		auto_skip_timer.stop()

	current_dialogue = []
	index = 0
	char_index = 0

	hide()
	dialogue_completed.emit()

func _apply_font_settings() -> void:
	var bold_font := Settings.get_bold_font()
	var medium_font := Settings.get_medium_font()

	name_label.add_theme_font_override("font", bold_font)

	text_label.add_theme_font_override("normal_font",  medium_font)
	text_label.add_theme_font_override("bold_font",    bold_font)
	text_label.add_theme_font_override("italics_font", medium_font)
