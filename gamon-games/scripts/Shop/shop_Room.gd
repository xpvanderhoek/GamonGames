extends Node2D

@export var item_scene: PackedScene 
@export_dir var resources_folder: String = "res://Assets/ShopItems/Resources"
@export var mouse_parallax_strength := Vector2(18.0, 10.0)
@export_range(1.0, 30.0, 0.1) var mouse_parallax_smoothing := 8.0

const TIER_1_BASE_WEIGHT := 70.0
const TIER_2_BASE_WEIGHT := 20.0
const TIER_3_BASE_WEIGHT := 10.0

@onready var spawn_positions = [$Parallax2D2/Item1, $Parallax2D2/Item2, $Parallax2D2/Item3]
@onready var parallax_layers = [$Parallax2D, $Parallax2D2]

var _parallax_offset := Vector2.ZERO

func _ready():
	spawn_shop_inventory()

func _process(delta: float):
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

func _exit_shop(): #Temporary
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

		# Pass the specific resource data to the item
		new_item.item_data = selected_item
		new_item._on_item_data_assigned()

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
