extends Control

@export var buttons: Array[TextureButton] = []
@onready var roundLabel: Label = $RoundLabel

var sequence: Array[int] = []
var player_input: Array[int] = []
var pulse_active = false
var is_showing := false
var input_locked := false

func _ready():
	for b in buttons:
		b.disabled = true
		b.self_modulate = Color(0.9, 0.9, 0.9)
	
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_button_pressed.bind(i))
	await pulse_first_button()
	next_round()
	
func pulse_first_button():
	sequence.append(randi() % buttons.size())
	var idx = sequence[0]
	buttons[idx].disabled = false
	pulse_active = true
	
	while pulse_active:
		buttons[idx].modulate = Color(2, 2, 2)
		await get_tree().create_timer(0.2).timeout
		
func next_round():
	for b in buttons:
		b.disabled = true
		b.self_modulate = Color(0.9, 0.9, 0.9)
		
	roundLabel.text = "Round " + str(sequence.size() + 1)
	sequence.append(randi() % buttons.size())
	
	await show_sequence()
	for b in buttons:
		b.disabled = false
		b.self_modulate = Color(1, 1, 1)
	player_input.clear()

func show_sequence():
	is_showing = true
	
	await get_tree().create_timer(0.5).timeout
	
	for idx in sequence:
		await buttons[idx].flash()
		await get_tree().create_timer(0.2).timeout
	
	is_showing = false

func _on_button_pressed(idx):
	pulse_active = false
	if is_showing or input_locked:
		return
	
	input_locked = true
	
	await buttons[idx].flash()
	player_input.append(idx)
	
	var pos = player_input.size() - 1
	if player_input[pos] != sequence[pos]:
		await fail()
		input_locked = false
		return
	
	if player_input.size() == sequence.size():
		for b in buttons:
			b.self_modulate = Color(0.267, 0.667, 0.268, 1.0)
		await get_tree().create_timer(0.4).timeout
		input_locked = false
		
		next_round()
		return
	
	input_locked = false

func fail():
	is_showing = true
	
	for b in buttons:
		b.self_modulate = Color(2, 0.5, 0.5)
	
	await get_tree().create_timer(0.5).timeout
	
	for b in buttons:
		b.self_modulate = Color(1, 1, 1)
	
	sequence.clear()
	player_input.clear()
	
	await get_tree().create_timer(0.5).timeout
	
	is_showing = false
	next_round()
