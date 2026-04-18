extends Control

const GRID_SIZE     := 4
const TILE_SIZE     := 100
const TILE_GAP      := 6
const SHUFFLE_MOVES := 1
const ANIM_TIME     := 0.12

@onready var grid_container : GridContainer = $GridContainer
@onready var status_label   : Label         = $StatusLabel
@onready var coin_amount	: Label 		= $CoinLabel
@onready var total_coins	: Label			= $TotalCoinLabel

var tile_values : Array = []
var tile_buttons : Array = []
var air_index   : int = 0

var move_count  : int = 0
var solved      : bool = false
var animating   : bool = false

var time_elapsed : float = 0.0
var timer_running : bool = false

var coins = 200
var last_coin_tick : int = 0

var move_tween : Tween
var shake_intensity : float = 0.0
var base_coin_pos : Vector2

func _ready() -> void:
	total_coins.text = str(RunData.coins)
	coin_amount.text = str(coins)
	base_coin_pos = coin_amount.position
	_create_buttons()
	_setup_grid()
	_shuffle_solvable()
	_refresh_tiles()	

func _decrease_coins() -> void:
	if coins > 0:
		coins -= 1
		coin_amount.text = str(coins)
		
func _process(delta: float) -> void:
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
		btn.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
		btn.set_meta("slot", i)
		btn.pressed.connect(_on_tile_pressed.bind(i))
		grid_container.add_child(btn)

		tile_buttons.append(btn)


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
	
	# random shake
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
	_check_win()
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
	var neighbors = _get_neighbors(air_index)

	for i in range(tile_values.size()):
		var btn : Button = tile_buttons[i]

		if tile_values[i] == 0:
			btn.text = ""
			btn.disabled = true
		else:
			btn.text = str(tile_values[i])
			btn.disabled = false


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

func _check_win() -> void:
	for i in range(tile_values.size() - 1):
		if tile_values[i] != i + 1:
			return

	solved = true
	timer_running = false
	animate_labels(coin_amount, total_coins)
	status_label.text = "Solved in %d moves | %.1fs" % [move_count, time_elapsed]
