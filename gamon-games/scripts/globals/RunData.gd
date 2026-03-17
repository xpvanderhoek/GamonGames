extends Node

var random_seed : int = 0
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

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

var current_hp : int = 0:
	set(value):
		current_hp = value
		hp_changed.emit(value)

var current_corruption : int = 0:
	set(value):
		current_corruption = value
		corruption_changed.emit(value)

var entered_rooms : Array = []
var buffs : Array = [] # This stores permanent run upgrades
var consumables : Array = [] # This stores single-use items

# Values are placeholders for now, needs testing
var EXP_PER_LEVEL : Array = [0, 0, 100, 250, 450, 700, 1000]

signal coins_changed(new_amount)
signal hp_changed(new_amount)
signal corruption_changed(new_amount)
signal exp_changed(new_amount)
signal level_changed(new_amount)

func new_run():
	random_seed = randi()
	rng.seed = random_seed
	coins = 100
	entered_rooms.clear()
	buffs.clear()
	consumables.clear() 
	current_hp = 100
	current_corruption = 10
	current_exp = 0

# Updated to handle logic for Consumables vs Upgrades
func add_buff(item : Resource):
	if item is ItemData:
		if item.category == "Consumable":
			consumables.append(item)
		else:
			buffs.append(item)
	else:
		buffs.append(item)

# Gets total flat damage bonus for a specific limb from items
func get_limb_damage_bonus(limb_name: String) -> float:
	var total = 0.0
	for item in buffs:
		if item is ItemData:
			if item.target_limb == limb_name or item.target_limb == "All":
				if item.buff_type == "Damage":
					total += item.buff_value
	return total

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