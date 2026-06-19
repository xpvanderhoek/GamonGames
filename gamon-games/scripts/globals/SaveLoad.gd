extends Node

const SAVE_DIR = "user://"
const META_PATH = "user://meta.json"

signal profile_changed

var http_request: HTTPRequest

func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http_request)
	http_request.request_completed.connect(_on_submit_completed)

func _on_submit_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("Leaderboard save failed! Code: ", response_code)
		if body.size() > 0:
			print("Response: ", body.get_string_from_utf8())
	else:
		print("Leaderboard save successful!")

func _submit_online_leaderboard(data) -> void:
	if not http_request:
		return
	var api_url: String = "http://api.visionot.online/client_api/leaderboard.php"
	var payload: Dictionary = {
		"name": data.profile_name,
		"best_level": data.best_level,
		"total_runs": data.total_runs,
		"total_coins_earned": data.total_coins_earned,
		"best_spells_in_deck": data.best_spells_in_deck,
		"floors_climbed_best": data.floors_climbed_best,
		"combats_fought_total": data.combats_fought_total,
		"best_speedrun_time": data.best_speedrun_time
	}
	var json = JSON.stringify(payload)
	var headers = ["Content-Type: application/json"]
	http_request.request(api_url, headers, HTTPClient.METHOD_POST, json)

func _save_path(slot: int):
	return SAVE_DIR + "save_%d.tres" % slot


func _leaderboard_path(slot: int):
	return SAVE_DIR + "leaderboard_%d.tres" % slot

func save_data():
	var data = SaveData.new()
	PlayerStats.marrow_shards = RunData.marrow_shards
	data.slot = PlayerStats.slot
	data.profile_name = PlayerStats.profile_name
	data.knows_combat = PlayerStats.knows_combat
	data.knows_avarus = PlayerStats.knows_avarus
	data.knows_puzzles = PlayerStats.knows_puzzles.duplicate()
	data.stats = PlayerStats.stats.duplicate()
	data.upgrade_levels = PlayerStats.upgrade_levels.duplicate()
	data.marrow_shards = PlayerStats.marrow_shards
	data.best_level = PlayerStats.best_level
	data.total_runs = PlayerStats.total_runs
	data.total_coins_earned = PlayerStats.total_coins_earned
	data.best_items_collected = PlayerStats.best_items_collected
	data.best_spells_in_deck = PlayerStats.best_spells_in_deck
	data.best_marrow_shards_run = PlayerStats.best_marrow_shards_run
	data.floors_climbed_best = PlayerStats.floors_climbed_best
	data.combats_fought_total = PlayerStats.combats_fought_total
	data.best_speedrun_time = PlayerStats.best_speedrun_time
	ResourceSaver.save(data, _save_path(PlayerStats.slot))
	ResourceSaver.save(data, _leaderboard_path(PlayerStats.slot))
	_submit_online_leaderboard(data)

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
	PlayerStats.knows_puzzles.merge(data.knows_puzzles, true)
	PlayerStats.stats.merge(data.stats, true)
	PlayerStats.upgrade_levels.merge(data.upgrade_levels, true)
	PlayerStats.marrow_shards = data.marrow_shards
	RunData.marrow_shards = PlayerStats.marrow_shards
	PlayerStats.best_level = data.best_level
	PlayerStats.total_runs = data.total_runs
	PlayerStats.total_coins_earned = data.total_coins_earned
	PlayerStats.best_items_collected = data.best_items_collected
	PlayerStats.best_spells_in_deck = data.best_spells_in_deck
	PlayerStats.best_marrow_shards_run = data.best_marrow_shards_run
	PlayerStats.floors_climbed_best = data.floors_climbed_best
	PlayerStats.combats_fought_total = data.combats_fought_total
	PlayerStats.best_speedrun_time = data.best_speedrun_time
	save_meta()

func record_run_stats(is_win: bool = false) -> void:
	PlayerStats.total_runs += 1
	PlayerStats.total_coins_earned += RunData.coins
	PlayerStats.combats_fought_total += RunData.combats_fought
	if RunData.current_level > PlayerStats.best_level:
		PlayerStats.best_level = RunData.current_level
	if RunData.items.size() > PlayerStats.best_items_collected:
		PlayerStats.best_items_collected = RunData.items.size()
	if RunData.spells.size() > PlayerStats.best_spells_in_deck:
		PlayerStats.best_spells_in_deck = RunData.spells.size()
	if RunData.floors_climbed > PlayerStats.floors_climbed_best:
		PlayerStats.floors_climbed_best = RunData.floors_climbed
	var shards_gained: int = RunData.marrow_shards - PlayerStats.marrow_shards
	if shards_gained > PlayerStats.best_marrow_shards_run:
		PlayerStats.best_marrow_shards_run = shards_gained
	if is_win:
		if PlayerStats.best_speedrun_time == 0.0 or RunData.current_run_time < PlayerStats.best_speedrun_time:
			PlayerStats.best_speedrun_time = RunData.current_run_time

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
	PlayerStats.reset_tutorials()
	PlayerStats.marrow_shards = 0
	PlayerStats.best_level = 0
	PlayerStats.total_runs = 0
	PlayerStats.total_coins_earned = 0
	PlayerStats.best_items_collected = 0
	PlayerStats.best_spells_in_deck = 0
	PlayerStats.best_marrow_shards_run = 0
	PlayerStats.floors_climbed_best = 0
	PlayerStats.combats_fought_total = 0
	PlayerStats.best_speedrun_time = 0.0
	RunData.marrow_shards = 0
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

func delete_save(slot : int) -> void:
	var save_path = _save_path(slot)
	if FileAccess.file_exists(save_path):
		var err = DirAccess.remove_absolute(save_path)
		if err == OK:
			print("Slot " + str(slot) + " deleted")
		else:
			print("Failed to delete file, error:", err)
