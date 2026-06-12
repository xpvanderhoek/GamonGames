class_name SaveData
extends Resource
 
@export var slot: int
@export var profile_name: String = ""
@export var knows_combat: bool = false
@export var knows_avarus: bool = false
@export var knows_puzzles: Dictionary = {}
@export var marrow_shards: int = 0
@export var stats: Dictionary = {}
@export var upgrade_levels: Dictionary = {}
 
@export var best_level: int = 0
@export var total_runs: int = 0
@export var total_coins_earned: int = 0
@export var best_items_collected: int = 0
@export var best_spells_in_deck: int = 0
@export var best_marrow_shards_run: int = 0
@export var floors_climbed_best: int = 0
@export var combats_fought_total: int = 0
