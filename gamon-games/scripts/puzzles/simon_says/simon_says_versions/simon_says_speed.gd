extends SimonSays

func _ready():
	versionLabel.text = "Speedy Says"
	super._ready()

func show_sequence():
	can_click = false
	
	await get_tree().create_timer(0.5).timeout
	
	for idx in sequence:
		await buttons[idx].flash()
		await get_tree().create_timer(0.02).timeout
	
	can_click = true
