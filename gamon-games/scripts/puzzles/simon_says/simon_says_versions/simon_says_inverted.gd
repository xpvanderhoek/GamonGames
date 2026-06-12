extends SimonSays

func _ready():
	if !PuzzleData.knows_puzzles[get_puzzle_data()]:
		PuzzleData.knows_puzzles[get_puzzle_data()] = true
		$TutorialOverlay5.visible = true
	super._ready()
	
func get_puzzle_data() -> String:
	return "simon_says_inverted"

func show_sequence():
	can_click = false
	
	await get_tree().create_timer(0.5).timeout
	
	for idx in sequence:
		for i in range(buttons.size()):
			if i != idx:
				buttons[i].flash()
		await get_tree().create_timer(0.5).timeout
			
	
	can_click = true
	
func calculate_coins():
	coin_amount = coin_amount + 6
	show_coin_popup(6)
	print_coins(coin_amount)
