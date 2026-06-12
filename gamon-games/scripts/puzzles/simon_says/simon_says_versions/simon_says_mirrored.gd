extends SimonSays

func _ready():
	if !PlayerStats.knows_puzzles[get_puzzle_data()]:
		PlayerStats.knows_puzzles[get_puzzle_data()] = true
		$TutorialOverlay3.visible = true
	super._ready()
	
func get_puzzle_data() -> String:
	return "simon_says_mirror"
	
func pulse_first_button(highlight_color: Color = Color(2, 2, 2)):
	var idx = sequence[0]
	
	buttons[buttons.size() - 1 - idx].disabled = false
	pulse_active = true
	
	while pulse_active:
		buttons[idx].modulate = highlight_color
		await get_tree().create_timer(0.2).timeout
	buttons[idx].modulate = Color(1, 1, 1)
		
func _on_button_pressed(idx):
	pulse_active = false
	if !can_click:
		switchDisabled(true)
		return
	
	can_click = false
	
	await buttons[idx].flash()
	player_input.append(idx)
	var pos = player_input.size() - 1
	
	checkCorrect(buttons.size() - 1 - idx, pos)
	
	can_click = true

func calculate_coins():
	coin_amount = coin_amount + 7
	show_coin_popup(7)
	print_coins(coin_amount)
