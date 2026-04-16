extends Node
class_name SimonSays
	
@export var buttons: Array[TextureButton] = []
@onready var roundLabel: Label = $RoundNumberLabel
@onready var versionLabel: Label = $VersionLabel

var sequence: Array[int] = []
var player_input: Array[int] = []
var pulse_active = false
var can_click := false


func pulse_first_button(highlight_color: Color = Color(2, 2, 2)):
	var idx = sequence[0]
	buttons[idx].disabled = false
	pulse_active = true
	
	while pulse_active:
		buttons[idx].modulate = highlight_color
		await get_tree().create_timer(0.2).timeout
	buttons[idx].modulate = Color(1,1,1)
	await get_tree().create_timer(0.2).timeout

func _ready():
	switchDisabled(true)
	changeColor(Color(0.9, 0.9, 0.9))
	sequence.append(randi() % buttons.size())
	
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
	can_click = false
	
	await get_tree().create_timer(0.5).timeout
	
	for idx in sequence:
		await buttons[idx].flash()
		await get_tree().create_timer(0.2).timeout
	
	can_click = true


func checkCorrect(clicked_button: int, click_position: int):
	if sequence[click_position] != clicked_button:
		await fail()
		can_click = false
		return
	
	if player_input.size() == sequence.size():
		changeColor(Color(0.267, 0.667, 0.268, 1.0))
		await get_tree().create_timer(0.4).timeout
		can_click = false
		
		next_round()
		return


func changeColor(color: Color):
	for b in buttons:
		b.self_modulate = color

func switchDisabled(variable: bool):
	for b in buttons:
		b.disabled = variable
	
	
func fail():
	switchDisabled(true)
	changeColor(Color(2, 0.5, 0.5))
	
	
func _on_button_pressed(idx):
	pulse_active = false
	if !can_click:
		return
	
	can_click = false
	
	await buttons[idx].flash()
	player_input.append(idx)
	var pos = player_input.size() - 1
	
	checkCorrect(idx, pos)
	
	can_click = true
