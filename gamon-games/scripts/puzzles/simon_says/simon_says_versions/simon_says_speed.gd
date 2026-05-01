extends SimonSays

func get_puzzle_data() -> String:
	return "simon_says_speed"

func _ready():
	super._ready()

func show_sequence():
	can_click = false
	
	await get_tree().create_timer(0.5).timeout
	
	for idx in sequence:
		await buttons[idx].flash()
		await get_tree().create_timer(0.02).timeout
	
	can_click = true

func calculate_coins():
	coin_amount = coin_amount + 2
	show_coin_popup(2)
	print_coins(coin_amount)
