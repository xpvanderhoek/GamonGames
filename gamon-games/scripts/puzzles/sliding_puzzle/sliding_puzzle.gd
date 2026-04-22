extends Control

var GRID_SIZE     := PuzzleData.slide_puzzle_size
const TILE_SIZE     := 100
const TILE_GAP      := 6
const SHUFFLE_MOVES := 400000
const ANIM_TIME     := 0.12

@onready var grid_container : GridContainer = $GridContainer
@onready var status_label   : Label         = $StatusLabel
@onready var coin_amount	: Label 		= $CoinLabel
@onready var total_coins	: Label			= $TotalCoinLabel

var tile_values : Array = []
var tile_buttons : Array = []
var tile_labels : Array = []
var air_index   : int = 0

@export var all_puzzle_textures: Array[Texture2D]
var puzzle_texture: Texture2D

var move_count  : int = 0
var solved      : bool = false
var animating   : bool = false

var time_elapsed : float = 0.0
var timer_running : bool = false

var coins: int = int(3.125 * pow(PuzzleData.slide_puzzle_size, 3))
var last_coin_tick : int = 0

var piece_size: Texture2D

var move_tween : Tween
var shake_intensity : float = 0.0
var base_coin_pos : Vector2

var data = PuzzleTexts.PUZZLES["slide"][RunData.language]
var puzzle_explained = preload("res://scenes/puzzles/puzzle_explained/puzzle_explained.tscn")

func _ready() -> void:
	var continue_button = PuzzleTexts.CONTINUE[RunData.language]
	$Button.text = continue_button
	if !PuzzleData.knows_slide_puzzle:
		PuzzleData.knows_slide_puzzle = true
		var explanation = puzzle_explained.instantiate()
		get_tree().current_scene.add_child(explanation)
		explanation.setup(data.title, data.description, data.tips, data.reward)
	total_coins.text = str(RunData.coins)
	coin_amount.text = str(coins)
	base_coin_pos = coin_amount.position
	puzzle_texture = all_puzzle_textures[randi_range(0, all_puzzle_textures.size() - 1)]
	_create_buttons()
	_setup_grid()
	_shuffle_solvable()
	_refresh_tiles()

func _decrease_coins() -> void:
	if coins > 0:
		coins -= 1
		coin_amount.text = str(coins)
		
func _process(delta: float) -> void:
	if coins == 0:
		$Button.visible = true
		PuzzleData.decrease_grid_size()
	if timer_running and not solved:
		time_elapsed += delta
		
		var current_second := int(time_elapsed)
		
		if current_second > last_coin_tick:
			last_coin_tick = current_second
			_decrease_coins()
			shake_intensity = min(3.00 / coins, 10.0)
		if coins != 0:
			_animate_coin_label(delta)
		else: 
			shake_intensity = 0
			_animate_coin_label(delta)
		
		
		
		_update_ui()

func _create_buttons() -> void:
	var total := GRID_SIZE * GRID_SIZE
	var total_px := GRID_SIZE * TILE_SIZE + (GRID_SIZE - 1) * TILE_GAP

	grid_container.columns = GRID_SIZE
	grid_container.add_theme_constant_override("h_separation", TILE_GAP)
	grid_container.add_theme_constant_override("v_separation", TILE_GAP)

	grid_container.position = Vector2(
		576 - total_px / 2.0,
		324 - total_px / 2.0
	)

	for i in range(total):
		var btn := Button.new()
		btn.expand_icon = true
		btn.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.set_meta("slot", i)
		btn.pressed.connect(_on_tile_pressed.bind(i))

		grid_container.add_child(btn)
		tile_buttons.append(btn)

		var label := Label.new()
		label.name = "NumberLabel"
		label.text = str(i + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(TILE_SIZE, TILE_SIZE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		btn.add_child(label)

		tile_labels.append(label)


func _setup_grid() -> void:
	tile_values.clear()

	var total := GRID_SIZE * GRID_SIZE

	for i in range(1, total):
		tile_values.append(i)

	tile_values.append(0)
	air_index = total - 1

	move_count = 0
	solved = false
	timer_running = false
	time_elapsed = 0.0

func _shuffle_solvable() -> void:
	while _check_win(true):
		randomize()
		for _i in range(SHUFFLE_MOVES):
			var neighbors := _get_neighbors(air_index)
			var pick: int = neighbors[randi() % neighbors.size()]
			_swap(air_index, pick)


func _on_tile_pressed(slot: int) -> void:
	if solved or animating or slot == air_index:
		return

	if not timer_running:
		timer_running = true

	if slot in _get_neighbors(air_index):
		_animate_swap(slot, air_index)

		_animate_move_counter()
		move_count += 1

func _animate_coin_label(delta: float) -> void:
	if not timer_running or solved:
		coin_amount.position = base_coin_pos
		coin_amount.scale = Vector2.ONE
		return
	
	var strength = shake_intensity
	
	var offset_x = randf_range(-1, 1) * strength
	var offset_y = randf_range(-1, 1) * strength
	

	coin_amount.position = base_coin_pos + Vector2(offset_x, offset_y)
	
	var scale_amount = 1.0 + (strength * 0.02)
	coin_amount.scale = Vector2(scale_amount, scale_amount)
	
	
func _animate_swap(from_idx: int, to_idx: int) -> void:
	animating = true

	var btn_from : Button = tile_buttons[from_idx]
	var btn_to   : Button = tile_buttons[to_idx]

	var pos_from := btn_from.global_position
	var pos_to   := btn_to.global_position

	move_tween = create_tween()
	move_tween.set_parallel(true)

	move_tween.tween_property(btn_from, "global_position", pos_to, ANIM_TIME)
	move_tween.tween_property(btn_to, "global_position", pos_from, ANIM_TIME)

	await move_tween.finished

	_swap(from_idx, to_idx)
	_refresh_tiles()

	btn_from.global_position = pos_from
	btn_to.global_position   = pos_to

	animating = false
	solved = _check_win()
	_update_ui()


func _animate_move_counter() -> void:
	var start := move_count
	var target := move_count + 1

	var t := 0.0
	var duration := 0.15

	while t < duration:
		t += get_process_delta_time()
		var alpha := t / duration
		var value: float = lerp(float(start), float(target), alpha)
		status_label.text = "Moves: %d | Time: %.1fs" % [int(value), time_elapsed]
		await get_tree().process_frame

	move_count = target
	_update_ui()

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
		RunData.coins += coins
		total_coins.text = str(RunData.coins)
		label_a.queue_free()
	)
	
	tween.tween_property(label_b, "scale", Vector2(1.2, 0.8), 0.1)
	
	tween.tween_property(label_b, "scale", Vector2(1.5, 1.2), 0.15)
	
	tween.tween_property(label_b, "scale", Vector2(1, 1), 0.2)


func _swap(a: int, b: int) -> void:
	var tmp = tile_values[a]
	tile_values[a] = tile_values[b]
	tile_values[b] = tmp

	if tile_values[a] == 0:
		air_index = a
	else:
		air_index = b


func _refresh_tiles() -> void:
	if puzzle_texture == null:
		return
	
	var size = puzzle_texture.get_size()
	var square_size = min(size.x, size.y)

	var offset = Vector2(
		(size.x - square_size) / 2,
		(size.y - square_size) / 2
	)

	var piece_size = Vector2(square_size, square_size) / GRID_SIZE

	for i in range(tile_values.size()):
		var btn : Button = tile_buttons[i]
		var label : Label = tile_labels[i]
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		label.add_theme_constant_override("outline_size", 2)

		btn.disabled = false
		btn.icon = null
		label.visible = true

		if tile_values[i] == 0:
			btn.disabled = true
			btn.icon = null
			label.visible = false
			continue

		label.text = str(tile_values[i])

		var value = tile_values[i] - 1
		var row = value / GRID_SIZE
		var col = value % GRID_SIZE

		var atlas := AtlasTexture.new()
		atlas.atlas = puzzle_texture
		atlas.region = Rect2(
			offset + Vector2(col, row) * piece_size,
			piece_size
		)

		btn.icon = atlas

func _update_ui() -> void:
	status_label.text = "Moves: %d | Time: %.1fs" % [move_count, time_elapsed]


func _get_neighbors(flat_idx: int) -> Array:
	var row : int = flat_idx / GRID_SIZE
	var col : int = flat_idx % GRID_SIZE

	var result : Array = []

	if row > 0: result.append(flat_idx - GRID_SIZE)
	if row < GRID_SIZE - 1: result.append(flat_idx + GRID_SIZE)
	if col > 0: result.append(flat_idx - 1)
	if col < GRID_SIZE - 1: result.append(flat_idx + 1)

	return result

func _animate_gap_to_zero() -> void:
	var tween = create_tween()

	var start_gap := TILE_GAP
	var end_gap := 0.0

	tween.tween_method(func(value):
		grid_container.add_theme_constant_override("h_separation", int(value))
		grid_container.add_theme_constant_override("v_separation", int(value))
	, start_gap, end_gap, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
func _check_win(checkSolved: bool = false) -> bool:
	for i in range(tile_values.size() - 1):
		if tile_values[i] != i + 1:
			return false

	timer_running = false

	if !checkSolved:
		PuzzleData.increase_grid_size()
		_animate_gap_to_zero()
		animate_labels(coin_amount, total_coins)
		$Button.visible = true
	
	
	status_label.text = "Solved in %d moves | %.1fs" % [move_count, time_elapsed]
	
	return true

func _on_button_pressed() -> void:
	TransitionManager.change_scene("res://scenes/map.tscn")
	await get_tree().create_timer(2.0).timeout
	queue_free()
