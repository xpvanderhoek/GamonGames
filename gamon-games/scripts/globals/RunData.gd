extends Node

var random_seed : int = 0
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

var spells : Array[SpellData] = []

var max_health : int = 100:
	set (value):
		max_health = value
		health_changed.emit()

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

var current_corruption : int = 0:
	set(value):
		current_corruption = value
		corruption_changed.emit(value)

var entered_rooms : Array = []
var items : Array[ItemData] = [] 
var consumables : Array = [null, null, null, null, null]

# Values are placeholders for now, needs testing
var EXP_PER_LEVEL : Array = [0, 0, 100, 250, 450, 700, 1000]

signal coins_changed(new_amount)
signal health_changed(new_amount)
signal corruption_changed(new_amount)
signal exp_changed(new_amount)
signal level_changed(new_amount)

func _ready() -> void:
	_ensure_default_attack_spell()

func new_run():
	random_seed = randi()
	rng.seed = random_seed
	coins = 100
	entered_rooms.clear()
	spells.clear()
	_ensure_default_attack_spell()
	items.clear()
	consumables = [null, null, null, null, null]
	max_health = PlayerStats.stats["health"]
	current_health = max_health
	current_corruption = 10
	current_exp = 0

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
	return true

func get_stat(buff_type : String):
	var total = PlayerStats.stats[buff_type]
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

func add_spell(spell: Resource) -> bool:
	if not (spell is SpellData):
		return false
	_ensure_default_attack_spell()

	var spell_data := spell as SpellData
	for existing_spell in spells:
		if existing_spell.spell_id == spell_data.spell_id and not existing_spell.spell_id.is_empty():
			return false
	spells.append(spell_data)
	return true

func _ensure_default_attack_spell() -> void:
	if spells.is_empty():
		spells.append(_create_default_attack_spell())
		return

	for spell in spells:
		if spell != null:
			return

	spells.insert(0, _create_default_attack_spell())

func _create_default_attack_spell() -> SpellData:
	var spell := SpellData.new()
	spell.spell_id = "attack"
	spell.spell_name = "Attack"
	spell.attack_power = 0
	return spell