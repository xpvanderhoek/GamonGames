extends Node

const BASIC_ATTACK = preload("res://resources/combat_spells/basic_attack.tres")
const BLOCK = preload("res://resources/combat_spells/block.tres")

var language = "EN"
const RUN_DURATION := 600.0

var random_seed : int = 0
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

var spells : Array[SpellData] = []

var run_active : bool = false

var time_remaining : float = RUN_DURATION:
	set (value):
		time_remaining = value
		time_remaining_changed.emit()

var max_health : int = 100:
	set (value):
		max_health = value
		health_changed.emit()

var marrow_shards : int = 10000:
	set(value):
		marrow_shards = value
		marrow_shards_changed.emit()

var current_exp : int = 0:
	set(value):
		current_exp = value
		exp_changed.emit(value)

var current_level : int = 1:
	set(value):
		current_level = value
		level_changed.emit(value)

var coins : int = 100:
	set(value):
		coins = value
		coins_changed.emit(value)

var current_health : int = 100:
	set(value):
		current_health = value
		health_changed.emit()

var max_energy: int = 10:
	set(value):
		max_energy = maxi(0, value)
		if current_energy > max_energy:
			current_energy = max_energy
		energy_changed.emit(current_energy)

var current_energy: int = 10:
	set(value):
		current_energy = clampi(value, 0, max_energy)
		energy_changed.emit(current_energy)

var current_map_node: MapNodeData = null
var map_nodes_data: Array[MapNodeData] = []
var current_encounter: Array[PackedScene] = []
var items : Array[ItemData] = [] 
var consumables : Array = [null, null, null, null, null, null, null, null, null]

var EXP_PER_LEVEL : Array = [0, 0, 100, 250, 450, 700, 1000]

signal coins_changed(new_amount)
signal health_changed(new_amount)
signal time_remaining_changed(new_amount)
signal exp_changed(new_amount)
signal level_changed(new_amount)
signal marrow_shards_changed(new_amount)
signal energy_changed(new_amount)
signal item_added(item: ItemData)

func calculate_score() -> int:
	return current_level * 100 + current_exp + coins * 2 + items.size() * 25

func new_run():
	random_seed = randi()
	rng.seed = random_seed

	coins = 100
	map_nodes_data.clear()
	current_map_node = null

	items.clear()
	consumables = [null, null, null, null, null, null, null, null, null]

	max_health = PlayerStats.stats["health"]
	current_health = max_health

	spells.clear()
	reset_energy()

	current_exp = 0
	current_level = 1

	run_active = true
	time_remaining = RUN_DURATION

	add_spell(BASIC_ATTACK)
	add_spell(BLOCK)

func reset_energy() -> void:
	max_energy = 10
	current_energy = max_energy

func end_run():
	run_active = false

	var ign = ProfileManager.active_ign
	if ign == "":
		print("No IGN set")
		return

	var score = calculate_score()

	var profile = ProfileManager.get_profile(ign)

	profile["best_level"] = max(profile["best_level"], current_level)
	profile["best_exp"] = max(profile["best_exp"], current_exp)
	profile["best_coins"] = max(profile["best_coins"], coins)
	profile["best_score"] = max(profile["best_score"], score)
	profile["most_items"] = max(profile["most_items"], items.size())

	ProfileManager.save_to_file()

	print("Saved profile:", ign)

func update_timer(delta):
	if run_active:
		time_remaining -= delta
		if time_remaining <= 0:
			time_remaining = 0
			end_run()

func add_item(item: Resource) -> bool:
	if not (item is ItemData):
		return false

	var item_data := item as ItemData

	if _is_consumable_item(item_data):
		var slot_index := _find_empty_consumable_slot()
		if slot_index == -1:
			print("Consumable slots are full.")
			return true
		consumables[slot_index] = item_data
		return true 

	if item_data.buff_type.to_lower() == "hp_max":
		max_health += int(item_data.buff_value)

	items.append(item_data)
	item_added.emit(item_data)
	return true

func get_stat(buff_type: String):
	var stat_key := buff_type.to_lower()

	if stat_key == "hp_max":
		stat_key = "health"
	elif stat_key == "defense":
		stat_key = "defence"
	elif stat_key == "cooldown":
		stat_key = "cooldown"

	if not PlayerStats.stats.has(stat_key):
		return 0

	var total = float(PlayerStats.stats[stat_key])

	for item in items:
		if item.buff_type.to_lower() == buff_type.to_lower():
			total += item.buff_value

	return total

func _is_consumable_item(item: ItemData) -> bool:
	return item is ConsumableItemData

func _find_empty_consumable_slot() -> int:
	for i in range(consumables.size()):
		if consumables[i] == null:
			return i
	return -1

func add_exp(amount: int) -> void:
	current_exp += amount
	while current_level < EXP_PER_LEVEL.size() - 1 and current_exp >= EXP_PER_LEVEL[current_level + 1]:
		level_up()

func level_up() -> void:
	current_level += 1

func add_spell(spell: SpellData) -> bool:
	for existing_spell in spells:
		if existing_spell.spell_id == spell.spell_id and not existing_spell.spell_id.is_empty():
			return false
	spells.append(spell.duplicate())
	return true
	
func _process(delta):
	if Input.is_action_just_pressed("ui_accept"):
		current_level += 1
		coins += 100
		current_exp += 50
		end_run()	
