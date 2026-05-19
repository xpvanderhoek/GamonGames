extends Node
 
const SAVE_DIR = "user://"
const META_PATH = "user://meta.json"
 
signal profile_changed
 
func _save_path(slot: int):
	return SAVE_DIR + "save_%d.tres" % slot
 
func save_data():
	var data = SaveData.new()
	data.slot = PlayerStats.slot
	data.profile_name = PlayerStats.profile_name
	data.knows_combat = PlayerStats.knows_combat
	data.knows_avarus = PlayerStats.knows_avarus
	data.stats = PlayerStats.stats.duplicate()
	data.upgrade_levels = PlayerStats.upgrade_levels.duplicate()
	data.marrow_shards = PlayerStats.marrow_shards
	data.best_level = PlayerStats.best_level
	data.total_runs = PlayerStats.total_runs
	data.total_coins_earned = PlayerStats.total_coins_earned
	data.best_items_collected = PlayerStats.best_items_collected
	data.best_spells_in_deck = PlayerStats.best_spells_in_deck
	data.best_marrow_shards_run = PlayerStats.best_marrow_shards_run
	ResourceSaver.save(data, _save_path(PlayerStats.slot))
 
func load_data(slot: int):
	if not FileAccess.file_exists(_save_path(slot)):
		push_error("Your save doesn't exist...")
		return
	var data = ResourceLoader.load(_save_path(slot), "", ResourceLoader.CACHE_MODE_IGNORE)
	if not data is SaveData:
		push_error("Corrupted save file")
		return
	PlayerStats.profile_name = data.profile_name
	PlayerStats.slot = data.slot
	PlayerStats.knows_combat = data.knows_combat
	PlayerStats.knows_avarus = data.knows_avarus
	PlayerStats.stats.merge(data.stats, true)
	PlayerStats.upgrade_levels.merge(data.upgrade_levels, true)
	PlayerStats.marrow_shards = data.marrow_shards
	PlayerStats.best_level = data.best_level
	PlayerStats.total_runs = data.total_runs
	PlayerStats.total_coins_earned = data.total_coins_earned
	PlayerStats.best_items_collected = data.best_items_collected
	PlayerStats.best_spells_in_deck = data.best_spells_in_deck
	PlayerStats.best_marrow_shards_run = data.best_marrow_shards_run
	save_meta()
 
func save_meta() -> void:
	var file = FileAccess.open(META_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"last_slot": PlayerStats.slot}))
	file.close()
 
func load_on_start() -> void:
	if not FileAccess.file_exists(META_PATH):
		return
	var file = FileAccess.open(META_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data:
		load_data(data["last_slot"])
 
func switch_profile(slot: int) -> void:
	save_data()
	load_data(slot)
	profile_changed.emit()
 
func create_profile(slot: int, name: String = "Knight") -> void:
	if PlayerStats.slot != 0:
		save_data()
	PlayerStats.slot = slot
	PlayerStats.reset_stats()
	PlayerStats.profile_name = name
	PlayerStats.knows_avarus = false
	PlayerStats.knows_combat = false
	PlayerStats.marrow_shards = 0
	PlayerStats.best_level = 0
	PlayerStats.total_runs = 0
	PlayerStats.total_coins_earned = 0
	PlayerStats.best_items_collected = 0
	PlayerStats.best_spells_in_deck = 0
	PlayerStats.best_marrow_shards_run = 0
	save_data()
	save_meta()
	profile_changed.emit()
 
func get_profile_name(slot: int) -> String:
	if not FileAccess.file_exists(_save_path(slot)):
		return ""
	var data = ResourceLoader.load(_save_path(slot), "", ResourceLoader.CACHE_MODE_IGNORE)
	return data.profile_name
 
func do_any_saves_exist() -> bool:
	var result = false
	for i in range(1, 4):
		if FileAccess.file_exists(_save_path(i)):
			result = true
	return result
 
func record_run_end() -> void:
	PlayerStats.total_runs += 1
	PlayerStats.total_coins_earned += RunData.coins
	if RunData.current_level > PlayerStats.best_level:
		PlayerStats.best_level = RunData.current_level
	if RunData.items.size() > PlayerStats.best_items_collected:
		PlayerStats.best_items_collected = RunData.items.size()
	if RunData.spells.size() > PlayerStats.best_spells_in_deck:
		PlayerStats.best_spells_in_deck = RunData.spells.size()
	var shards_this_run = RunData.marrow_shards - PlayerStats.marrow_shards
	if shards_this_run > PlayerStats.best_marrow_shards_run:
		PlayerStats.best_marrow_shards_run = shards_this_run
	save_data()
