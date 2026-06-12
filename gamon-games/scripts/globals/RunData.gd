extends Node

const BASIC_ATTACK = preload("res://resources/combat_spells/basic_attack.tres")
const BLOCK = preload("res://resources/combat_spells/block.tres")
const STARTING_KIT_KEY := "starting_kit"
const STARTING_KIT_CONSUMABLES_DIR := "res://assets/ShopItems/Resources/Consumables"

var language = "EN"
var random_seed : int = 0
var rng : RandomNumberGenerator = RandomNumberGenerator.new()
var spells : Array[SpellData] = []

var run_active : bool = false

var max_health : int = 100:
	set (value):
		max_health = value
		health_changed.emit()

var marrow_shards : int = 0:# Placeholder testing amount, adjust as needed
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

var coins : int = 100: # Placeholder starting amount, adjust as needed
	set(value):
		coins = value
		coins_changed.emit(value)

var current_health : int = 100:
	set(value):
		current_health = value
		health_changed.emit()

var max_energy: int = 6:
	set(value):
		max_energy = maxi(0, value)
		if current_energy > max_energy:
			current_energy = max_energy
		energy_changed.emit(current_energy)

var current_energy: int = 6:
	set(value):
		current_energy = clampi(value, 0, max_energy)
		energy_changed.emit(current_energy)

var current_encounter: Array[PackedScene] = []
var map_data: Array = []
var floors_climbed: int = 0
var combats_fought: int = 0
var last_map_room: Room = null
var items : Array[ItemData] = [] 
var consumables : Array = [null, null, null, null, null, null, null, null, null]

# Values are placeholders for now, needs testing
var EXP_PER_LEVEL : Array = [0, 0, 100, 250, 450, 700, 1000, 1350, 1750, 2200, 2700, 3250, 3850, 4500, 5200, 5950, 6750, 7600, 8500, 9450, 10450]

signal coins_changed(new_amount)
signal health_changed(new_amount)
signal time_remaining_changed(new_amount)
signal exp_changed(new_amount)
signal level_changed(new_amount)
signal marrow_shards_changed(new_amount)
signal energy_changed(new_amount)
signal item_added(item: ItemData)

func new_run():
	random_seed = randi()
	rng.seed = random_seed
	coins = 100
	current_encounter.clear()
	map_data.clear()
	floors_climbed = 0
	last_map_room = null
	items.clear()
	consumables = [null, null, null, null, null, null, null, null, null]
	max_health = PlayerStats.stats["health"]
	current_health = max_health
	spells.clear()
	reset_energy()
	current_exp = 0
	run_active = true
	add_spell(BASIC_ATTACK)
	add_spell(BLOCK)
	_add_starting_kit_consumable()
	combats_fought = 0
	PuzzleData.pick_random_puzzle()

func reset_energy() -> void:
	max_energy = 6
	current_energy = max_energy

func _add_starting_kit_consumable() -> void:
	if int(PlayerStats.upgrade_levels.get(STARTING_KIT_KEY, 0)) <= 0:
		return
	var item := _get_random_consumable()
	if item != null:
		add_item(item)

func _get_random_consumable() -> ConsumableItemData:
	var dir := DirAccess.open(STARTING_KIT_CONSUMABLES_DIR)
	if dir == null:
		return null
	var candidates: Array[ConsumableItemData] = []
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var path := STARTING_KIT_CONSUMABLES_DIR + "/" + file_name
		var resource := load(path)
		if resource is ConsumableItemData:
			candidates.append(resource)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func end_run():
	run_active = false
	PlayerStats.marrow_shards = marrow_shards
	SaveLoad.record_run_stats() 
	SaveLoad.save_data()

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
		print("Picked up consumable '%s' in slot %d" % [item_data.item_name, slot_index + 1])
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
		print("Unknown stat '%s'" % buff_type)
		return 0

	var total = float(PlayerStats.stats[stat_key])
	
	var meta_stats = PlayerStats.get("meta_stats")
	if meta_stats != null:
		if stat_key == "precision" and meta_stats.has_method("get_base_precision_bonus"):
			total += meta_stats.get_base_precision_bonus()
		elif stat_key == "health" and meta_stats.has_method("get_bonus_hp_percent"):
			total += total * meta_stats.get_bonus_hp_percent()

	var buff_key := buff_type.to_lower()
	for item in items:
		if item != null and item.buff_type.to_lower() == buff_key:
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
	# Add any level up effects here

func get_exp_requirement(level: int) -> int:
	if level < 0 or level >= EXP_PER_LEVEL.size():
		return -1
	return EXP_PER_LEVEL[level]

func get_level_progress() -> float:
	var current_requirement = EXP_PER_LEVEL[current_level]
	var next_requirement = EXP_PER_LEVEL[current_level + 1] if current_level + 1 < EXP_PER_LEVEL.size() else EXP_PER_LEVEL[current_level]
	var progress = float(current_exp - current_requirement) / float(next_requirement - current_requirement)
	return clamp(progress, 0.0, 1.0)

func add_spell(spell: SpellData) -> bool:
	if not (spell is SpellData):
		return false

	for existing_spell in spells:
		if existing_spell.spell_id == spell.spell_id and not existing_spell.spell_id.is_empty():
			return false
	spells.append(spell.duplicate())
	return true

func get_spell_by_id(spell_id: String) -> SpellData:
	for spell in spells:
		if spell.spell_id == spell_id and not spell.spell_id.is_empty():
			return spell
	return null

func upgrade_spell(spell_id: String) -> void:
	var existing = get_spell_by_id(spell_id)
	if existing:
		existing.level += 1
		if existing.min_damage >= 0:
			existing.min_damage = int(round(existing.min_damage * 1.2))
		if existing.max_damage >= 0:
			existing.max_damage = int(round(existing.max_damage * 1.2))
		if existing.min_damage >= 0 and existing.max_damage >= 0 and existing.max_damage < existing.min_damage:
			existing.max_damage = existing.min_damage
		if existing.heal_amount > 0:
			existing.heal_amount = int(round(existing.heal_amount * 1.2))
