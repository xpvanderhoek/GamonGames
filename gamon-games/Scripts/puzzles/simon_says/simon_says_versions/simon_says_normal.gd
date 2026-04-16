extends SimonSays

func pulse_first_button():
	sequence.append(randi() % buttons.size())
	var idx = sequence[0]
	buttons[idx].disabled = false
	pulse_active = true
	
	while pulse_active:
		buttons[idx].modulate = Color(2, 2, 2)
		await get_tree().create_timer(0.2).timeout

func _ready():
	versionLabel.text = "Normal"
	super._ready()
	
