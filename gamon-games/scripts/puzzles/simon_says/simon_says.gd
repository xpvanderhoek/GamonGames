extends Node
class_name SimonSays
	
@onready var buttons: Array[TextureButton] = [$topleft, $topmid, $topright, $midleft, $midmid, $midright, $bottomleft, $bottommid, $bottomright]
@onready var roundLabel: Label = $RoundNumberLabel
@onready var versionLabel: Label = $VersionLabel
@onready var coinLabel: Label = $CoinLabel
@onready var totalCoins: Label = $TotalCoinsLabel
@onready var lives: TextureRect = $Lives

var coin_amount: int = 0
var sequence: Array[int] = []
var player_input: Array[int] = []
var pulse_active = false
var can_click := false

var data = PuzzleTexts.PUZZLES[get_puzzle_data()][RunData.language]
var puzzle_explained = preload("res://scenes/puzzles/puzzle_explained/puzzle_explained.tscn")


func get_puzzle_data() -> String:
	return "simon_says_normal"

func pulse_first_button(highlight_color: Color = Color(2, 2, 2)):
	var idx = sequence[0]
	buttons[idx].disabled = false
	pulse_active = true
	
	while pulse_active:
		buttons[idx].modulate = highlight_color
		await get_tree().create_timer(0.2).timeout
	buttons[idx].modulate = Color(1,1,1)
	await get_tree().create_timer(0.2).timeout

func open_explaination(puzzle = PuzzleData.knows_puzzles["simon_says_normal"]) -> void:
	var explanation = puzzle_explained.instantiate()
	get_tree().current_scene.add_child(explanation)
	explanation.setup(data.title, data.description, data.tips, data.reward)
	puzzle = true
	

func _ready():
	if !PuzzleData.knows_puzzles[get_puzzle_data()]:
		open_explaination(PuzzleData.knows_puzzles[get_puzzle_data()])
	var continue_button = PuzzleTexts.CONTINUE[RunData.language]
	$Button.text = continue_button
	versionLabel.text = data.title
	totalCoins.text = str(RunData.coins)
	switchDisabled(true)
	changeColor(Color(0.9, 0.9, 0.9))
	sequence.append(randi() % buttons.size())
	
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_on_button_pressed.bind(i))
	await pulse_first_button()
	next_round()
		
func next_round():
	calculate_coins()
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
		switchDisabled(true)
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
	if lives.visible == true:
		changeColor(Color(2, 0.5, 0.5))
		await get_tree().create_timer(0.4).timeout
		changeColor(Color(0.9, 0.9, 0.9))
		await get_tree().create_timer(0.2).timeout

		var tween = create_tween()

		var center = get_viewport().get_visible_rect().size / 2

		tween.tween_property(lives, "global_position", center, 3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(lives, "modulate:a", 0.0, 1.0)
		
		await tween.finished
		
		await get_tree().create_timer(0.4).timeout
		
		lives.visible = false
		player_input.clear()
		show_sequence()
		return
	animate_labels(coinLabel, totalCoins)
	
	switchDisabled(true)
	changeColor(Color(2, 0.5, 0.5))
	
	$Button.visible = true
	
func print_coins(coins: int):
	coinLabel.text = str(coins)
	
func calculate_coins():
	coin_amount = coin_amount + 1
	print_coins(coin_amount)
	
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
	
func _on_continue_pressed() -> void:
	TransitionManager.change_scene("res://scenes/map.tscn")
	queue_free()
	
func animate_labels(label_a: Label, label_b: Label):
	await get_tree().process_frame
	
	var tween = create_tween()
	
	label_b.pivot_offset = Vector2(label_b.size.x, label_b.size.y / 2)
	
	var target_pos = label_b.position
	
	tween.parallel().tween_property(
		label_a,
		"position",
		target_pos,
		0.5
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	
	tween.parallel().tween_property(label_a, "modulate:a", 0.0, 0.5)
	tween.parallel().tween_property(label_a, "scale", Vector2(0.6, 0.6), 0.5)
	
	tween.tween_callback(func():
		RunData.coins += coin_amount
		totalCoins.text = str(RunData.coins)
		label_a.queue_free()
	)
	
	tween.tween_property(label_b, "scale", Vector2(1.2, 0.8), 0.1)
	
	tween.tween_property(label_b, "scale", Vector2(1.5, 1.2), 0.15)
	
	tween.tween_property(label_b, "scale", Vector2(1, 1), 0.2)


func _on_explanation_pressed() -> void:
	open_explaination()
