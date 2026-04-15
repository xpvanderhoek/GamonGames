extends Control

@export var buttons: Array[Control] = []

var sequence = []        
var player_input = []      
var is_showing = false    

func _ready():
	for i in buttons.size():
		buttons[i].button_pressed.connect(_on_button_pressed.bind(i))
	
	await get_tree().create_timer(1.0).timeout
	next_round()

func next_round():
	player_input.clear()

	sequence.append(randi() % buttons.size())

	await show_sequence()

func show_sequence():
	is_showing = true
	
	await get_tree().create_timer(0.5).timeout
	
	for idx in sequence:
		buttons[idx].flash()
		await get_tree().create_timer(0.8).timeout
	
	is_showing = false

func _on_button_pressed(idx):
	if is_showing:
		return
	
	buttons[idx].flash()
	player_input.append(idx)
	
	var pos = player_input.size() - 1
	if player_input[pos] != sequence[pos]:
		fail()
		return
	
	if player_input.size() == sequence.size():
		await get_tree().create_timer(1.0).timeout
		next_round()

func fail():
	print("Wrong! Restarting")
	sequence.clear()
	await get_tree().create_timer(1.0).timeout
	next_round()
