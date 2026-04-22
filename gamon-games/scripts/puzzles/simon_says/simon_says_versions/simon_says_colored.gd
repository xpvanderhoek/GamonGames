extends SimonSays

var good_color: Color = Color(0.95, 0.95, 0.95)
var all_colors: Array[Color] = []
var colored_sequence: Array[Dictionary] = []

func get_puzzle_data() -> String:
	return "simon says color"

func _ready():
	totalCoins.text = str(RunData.coins)
	all_colors.append(Color(0.0, 0.0, 0.616, 1.0))
	all_colors.append(Color(0.514, 0.514, 0.0, 1.0))
	all_colors.append(Color(0.549, 0.0, 0.549, 1.0))
	good_color = all_colors[randi() % all_colors.size()]
	$MouseLeftButton.visible = true
	$Arrow.visible = true
	$ColorRect.color = good_color
	$ColorRect.visible = true
	sequence.append(randi() % buttons.size())
	versionLabel.text = "Colors Says"
	switchDisabled(true)
	changeColor(Color(0.9, 0.9, 0.9))
	colored_sequence.append({
		"index": sequence[sequence.size() - 1],
		"color": good_color
	})
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_button_pressed.bind(i))
	await pulse_first_button(good_color)
	next_round()
	

func next_round():
	calculate_coins()
	var show_bad_color: bool = true
	changeColor(Color(0.9, 0.9, 0.9))
	switchDisabled(true)
		
	roundLabel.text = str(colored_sequence.filter(func(step): return step.color == good_color).size() + 1)
	sequence.append(randi() % buttons.size())
	colored_sequence.append({
		"index": sequence[sequence.size() - 1],
		"color": all_colors[randi() % all_colors.size()]
	})
	
	while show_bad_color:
		if colored_sequence[colored_sequence.size() - 1].color == good_color:
			show_bad_color = false
		else:
			sequence.append(randi() % buttons.size())
			colored_sequence.append({
				"index": sequence[sequence.size() - 1],
				"color": all_colors[randi() % all_colors.size()]
			})
	
	
	await show_sequence()
	changeColor(Color(1, 1, 1))
	switchDisabled(false)
	
	player_input.clear()
	
	
func show_sequence():
	can_click = false
	
	await get_tree().create_timer(0.5).timeout
	
	for idx in colored_sequence:
		await buttons[idx.index].flash(idx.color)
		await get_tree().create_timer(0.2).timeout
	
	can_click = true

func checkCorrect(clicked_button: int, click_position: int):
	var colorlist = colored_sequence.filter(func(step): return step.color == good_color)
	if click_position >= colorlist.size():
		return
	if colorlist[click_position].color != good_color or colorlist[click_position].index != clicked_button:
		await fail()
		return
	
	if player_input.size() == colorlist.size():
		switchDisabled(true)
		changeColor(Color(0.267, 0.667, 0.268, 1.0))
		await get_tree().create_timer(0.4).timeout
		can_click = false
		
		next_round()
		return

func calculate_coins():
	coin_amount = coin_amount + 2
	print_coins(coin_amount)
	
	
