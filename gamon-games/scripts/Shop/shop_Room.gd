extends Node2D

@export var item_scene: PackedScene 
@export_dir var resources_folder: String = "res://assets/ShopItems/Resources"
@export var mouse_parallax_strength := Vector2(18.0, 10.0)
@export_range(1.0, 30.0, 0.1) var mouse_parallax_smoothing := 8.0

const TIER_1_BASE_WEIGHT := 70.0
const TIER_2_BASE_WEIGHT := 20.0
const TIER_3_BASE_WEIGHT := 10.0

@onready var spawn_positions = [$Parallax2D2/Item1, $Parallax2D2/Item2, $Parallax2D2/Item3]
@onready var parallax_layers = [$Parallax2D, $Parallax2D2]
@onready var exit_button = [$Parallax2D2/ExitButton/Button]
@onready var item_tooltip_panel: Panel = $CanvasLayer/ItemTooltipPanel
@onready var item_tooltip_label: Label = $CanvasLayer/ItemTooltipPanel/TooltipLabel
@onready var coins: Label = $Parallax2D2/Sprite2D/CoinLabel

var _parallax_offset := Vector2.ZERO
var _shop_chatter_timer: Timer

const SHOP_CHATTER_MIN_SEC := 10.0
const SHOP_CHATTER_MAX_SEC := 25.0

func _ready():
	if exit_button != null:
		var on_exit_pressed := Callable(self, "_exit_shop")
		if not exit_button[0].pressed.is_connected(on_exit_pressed):
			exit_button[0].pressed.connect(on_exit_pressed)

	if item_tooltip_panel:
		item_tooltip_panel.visible = false

	coins.text = str(RunData.coins)
	spawn_shop_inventory()
	_setup_shop_dialogue_flow()

func _setup_shop_dialogue_flow() -> void:
	if not PlayerStats.knows_avarus and DialogueManager.has_dialogue("Avarus_intro"):
		DialogueManager.start_dialogue("Avarus_intro")
		PlayerStats.knows_avarus = true

	_setup_shop_chatter_timer()

func _setup_shop_chatter_timer() -> void:
	_shop_chatter_timer = Timer.new()
	_shop_chatter_timer.one_shot = true
	_shop_chatter_timer.wait_time = randf_range(SHOP_CHATTER_MIN_SEC, SHOP_CHATTER_MAX_SEC)
	_shop_chatter_timer.timeout.connect(_on_shop_chatter_timeout)
	add_child(_shop_chatter_timer)
	_shop_chatter_timer.start()

func _on_shop_chatter_timeout() -> void:
	if DialogueManager.has_dialogue("Avarus_idle") and not DialogueManager.is_in_dialogue:
		DialogueManager.start_random_line_dialogue("Avarus_idle")

	if _shop_chatter_timer != null:
		_shop_chatter_timer.wait_time = randf_range(SHOP_CHATTER_MIN_SEC, SHOP_CHATTER_MAX_SEC)
		_shop_chatter_timer.start()

func _process(delta: float):
	coins.text = str(RunData.coins)
	var half := get_viewport_rect().size * 0.5
	if half.x == 0.0 or half.y == 0.0:
		return

	var mouse := get_viewport().get_mouse_position()
	var offset := Vector2(
		(mouse.x - half.x) / half.x,
		(mouse.y - half.y) / half.y
	) * mouse_parallax_strength

	_parallax_offset = _parallax_offset.lerp(offset, mouse_parallax_smoothing * delta)
	for layer in parallax_layers:
		layer.scroll_offset = _parallax_offset * layer.scroll_scale

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_exit_shop()

func _exit_shop(): 
	DialogueManager.cancel_dialogue()
	TransitionManager.change_scene("res://scenes/map.tscn", TransitionManager.TransitionType.FADE)

func spawn_shop_inventory():
	var item_pool := _load_shop_items()
	if item_pool.is_empty():
		push_warning("You donkey, You didn't put any resources in %s" % resources_folder)
		return

	var luck_value := _get_total_luck()

	for i in range(spawn_positions.size()):
		if item_pool.is_empty():
			break

		var selected_item := _roll_item_from_pool(item_pool, luck_value)
		if selected_item == null:
			break

		item_pool.erase(selected_item)

		var new_item = item_scene.instantiate()
		spawn_positions[i].add_child(new_item)
		new_item.position = Vector2.ZERO
		if new_item.has_signal("item_hover_started"):
			new_item.item_hover_started.connect(_on_item_hover_started)
		if new_item.has_signal("item_hover_ended"):
			new_item.item_hover_ended.connect(_on_item_hover_ended)

		# Pass the specific resource data to the item
		new_item.item_data = selected_item
		new_item._on_item_data_assigned()

func _on_item_hover_started(item_data: ItemData) -> void:
	if item_data == null or item_tooltip_panel == null or item_tooltip_label == null:
		return

	var lines: Array[String] = []
	if item_data.item_name.strip_edges() != "":
		lines.append(item_data.item_name)

	if item_data.effect.strip_edges() != "":
		lines.append(item_data.effect)
	elif item_data.lore.strip_edges() != "":
		lines.append(item_data.lore)

	item_tooltip_label.text = "\n".join(lines)
	item_tooltip_panel.visible = lines.size() > 0

func _on_item_hover_ended() -> void:
	if item_tooltip_panel:
		item_tooltip_panel.visible = false

func _load_shop_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	var dir = DirAccess.open(resources_folder)
	for file in dir.get_files():
		items.append(load("%s/%s" % [resources_folder, file]) as ItemData)
	return items

func _roll_item_from_pool(pool: Array[ItemData], luck_value: float) -> ItemData:
	if pool.is_empty():
		return null

	var total_weight := 0.0
	for item in pool:
		total_weight += _get_weight_for_item(item, luck_value)

	if total_weight <= 0.0:
		return pool[RunData.rng.randi_range(0, pool.size() - 1)]

	var roll := RunData.rng.randf_range(0.0, total_weight)
	var running_weight := 0.0
	for item in pool:
		running_weight += _get_weight_for_item(item, luck_value)
		if roll <= running_weight:
			return item

	return pool[pool.size() - 1]

func _get_weight_for_item(item: ItemData, luck_value: float) -> float:
	var luck : Variant= clamp(luck_value, 0.0, 100.0)

	match item.category:
		"Tier I":
			return max(1.0, TIER_1_BASE_WEIGHT - (luck * 0.6))
		"Tier II":
			return TIER_2_BASE_WEIGHT + (luck * 0.4)
		"Tier III":
			return TIER_3_BASE_WEIGHT + (luck * 0.2)
		_:
			return 1.0

func _get_total_luck() -> float:
	return PlayerStats.stats.luck
