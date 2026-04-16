extends SimonSays

func _ready():
	versionLabel.text = "Mirrored"
	super._ready()
	
	
func pulse_first_button():
	sequence.append(randi() % buttons.size())
	print(sequence[0])
	var idx = sequence[0]
	
	buttons[buttons.size() - 1 - idx].disabled = false
	pulse_active = true
	
	while pulse_active:
		buttons[idx].modulate = Color(2, 2, 2)
		await get_tree().create_timer(0.2).timeout
		
func _on_button_pressed(idx):
	pulse_active = false
	if is_showing or input_locked:
		return
	
	input_locked = true
	
	await buttons[buttons.size() - 1 - idx].flash()
	player_input.append(idx)
	var pos = player_input.size() - 1
	
	checkCorrect(buttons.size() - 1 - idx, pos)
	
	input_locked = false
	
	
