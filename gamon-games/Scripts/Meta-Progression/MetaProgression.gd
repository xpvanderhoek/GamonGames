extends Resource
class_name MetaStats

@export var marrow_shards: int = 0

# Permanent Upgrades (outside the runs themselves)
@export var hardened_flesh_lvl: int = 0
@export var anatomy_mastery_lvl: int = 0
@export var steady_hand_lvl: int = 0
@export var scavenger_eye_lvl: int = 0
@export var iron_will_lvl: int = 0
@export var quick_reflexes_lvl: int = 0
@export var starting_kit_unlocked: bool = false


func get_bonus_hp_percent() -> float:
	return hardened_flesh_lvl * 0.05


func get_base_precision_bonus() -> int:
	return steady_hand_lvl * 2
