extends Node
class_name SimonSays
	
@export var buttons: Array[TextureButton] = []
@onready var roundLabel: Label = $RoundNumberLabel
@onready var versionLabel: Label = $VersionLabel

var sequence: Array[int] = []
var player_input: Array[int] = []
var pulse_active = false
var is_showing := false
var input_locked := false


func pulse_first_button():
	pass

func _ready():
	switchDisabled(true)
	changeColor(Color(0.9, 0.9, 0.9))
	
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_button_pressed.bind(i))
	await pulse_first_button()
	next_round()
		
func next_round():
	changeColor(Color(0.9, 0.9, 0.9))
	switchDisabled(true)
		
	roundLabel.text = str(sequence.size() + 1)
	sequence.append(randi() % buttons.size())
	
	await show_sequence()
	changeColor(Color(1, 1, 1))
	switchDisabled(false)
	
	player_input.clear()

func show_sequence():
	is_showing = true
	
	await get_tree().create_timer(0.5).timeout
	
	for idx in sequence:
		await buttons[idx].flash()
		await get_tree().create_timer(0.2).timeout
	
	is_showing = false


func checkCorrect(clicked_button: int, click_position: int):
	print(clicked_button, sequence[click_position])
	if sequence[click_position] != clicked_button:
		await fail()
		input_locked = false
		return
	
	if player_input.size() == sequence.size():
		changeColor(Color(0.267, 0.667, 0.268, 1.0))
		await get_tree().create_timer(0.4).timeout
		input_locked = false
		
		next_round()
		return


func changeColor(color: Color):
	for b in buttons:
		b.self_modulate = color

func switchDisabled(variable: bool):
	for b in buttons:
		b.disabled = variable
	
	
func fail():
	is_showing = true
	
	switchDisabled(true)
	changeColor(Color(2, 0.5, 0.5))
	
	
func _on_button_pressed(idx):
	pulse_active = false
	if is_showing or input_locked:
		return
	
	input_locked = true
	
	await buttons[idx].flash()
	player_input.append(idx)
	var pos = player_input.size() - 1
	
	checkCorrect(idx, pos)
	
	input_locked = false
