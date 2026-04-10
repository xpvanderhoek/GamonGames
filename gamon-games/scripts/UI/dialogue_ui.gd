extends CanvasLayer

var current_dialogue = []
var index = 0
var char_index = 0
var typing_speed := 0.03
var typing_timer: Timer

signal dialogue_completed

@onready var name_label = $Panel/Label
@onready var text_label = $Panel/RichTextLabel

func _ready():
	DialogueManager.register_ui(self)
	hide()
	typing_timer = Timer.new()
	typing_timer.wait_time = typing_speed
	typing_timer.one_shot = false
	typing_timer.connect("timeout", Callable(self, "_typewriter_step"))
	add_child(typing_timer)

func start_dialogue(dialogue):
	current_dialogue = dialogue
	index = 0
	show_line()
	await dialogue_completed

func show_line():
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
		text_label.append_text(line["text"][char_index])
		char_index += 1
	else:
		typing_timer.stop()

func next_line():
	if not typing_timer.is_stopped():
		var line = current_dialogue[index]
		text_label.text = line["text"]
		typing_timer.stop()
	else:
		index += 1
		show_line()

func previous_line():
	if index > 0:
		index -= 1
		show_line()

func _input(event):
	if is_visible() and event is InputEventKey and event.pressed:
		if event.is_action_pressed("ui_accept"):
			next_line()
		elif event.is_action_pressed("ui_text_backspace"):
			previous_line()
