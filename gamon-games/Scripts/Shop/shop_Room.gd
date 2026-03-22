extends Node2D

@export var item_scene: PackedScene 
@export_dir var resources_folder: String = "res://Assets/ShopItems/Resources"

# the weights and luck adjustments are placeholders for now, needs testing and tweaking to find good values, 
# but its just the higher the weights the more likely that tier will be chosen, and the higher the luck the more likely higher tiers will be chosen
const TIER_1_BASE_WEIGHT := 70.0
const TIER_2_BASE_WEIGHT := 20.0
const TIER_3_BASE_WEIGHT := 10.0

@onready var spawn_positions = [$Item1, $Item2, $Item3]

func _ready():
	spawn_shop_inventory()

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
