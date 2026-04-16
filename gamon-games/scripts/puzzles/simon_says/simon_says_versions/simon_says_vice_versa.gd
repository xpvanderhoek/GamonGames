extends SimonSays

func _ready():
	versionLabel.text = "Says Simon"
	$Bone.visible = true
	$Vice_versa_hint.visible = true
	super._ready()

func checkCorrect(clicked_button: int, click_position: int):
	var reversed_index = sequence.size() - 1 - click_position
	
	if sequence[reversed_index] != clicked_button:
		await fail()
		can_click = false
		return
	
	if player_input.size() == sequence.size():
		changeColor(Color(0.267, 0.667, 0.268, 1.0))
		await get_tree().create_timer(0.4).timeout
		can_click = false
		
		next_round()
		return
