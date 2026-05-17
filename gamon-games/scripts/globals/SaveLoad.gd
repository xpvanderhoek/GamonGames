extends Node

const SAVE_DIR = "user://saves/"

func _save_path(slot : int):
	return SAVE_DIR + "save_%d.tres" % slot

func save_data(stats : PlayerStats):
	var data = SaveData.new()
	data.slot = stats.slot
	data.profile_name = stats.profile_name
	data.knows_combat = stats.knows_combat
	data.knows_avarus = stats.knows_avarus
	data.stats = stats.stats.duplicate()
	data.upgrade_levels = stats.upgrade_levels.duplicate()
	data.marrow_shards = stats.marrow_shards
	ResourceSaver.save(data, _save_path(stats.slot))

func load_data(slot : int):
	#save_data(PlayerStats.self)
	if not FileAccess.file_exists(_save_path(slot)):
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
	
	print(PlayerStats.knows_avarus)
	print(PlayerStats.knows_tutorial)

#const SAVE_DIR = "user://saves/"
#const META_PATH = "user://meta.json"
#
#var active_slot : int = 0
## Saving & Loading Data
#
#func _ready() -> void:
	##load_meta()
	#pass
#
#func save_meta() -> void:
	#var file = FileAccess.open(META_PATH, FileAccess.WRITE)
	#file.store_string(JSON.stringify({"last_slot": active_slot}))
	#file.close()
#
#func load_meta() -> void:
	#if not FileAccess.file_exists(META_PATH):
		#return
	#var file = FileAccess.open(META_PATH, FileAccess.READ)
	#var data = JSON.parse_string(file.get_as_text())
	#file.close()
	#if data:
		#active_slot = data["last_slot"]
#
#func _save_path() -> String:
	#return SAVE_DIR + "slot_%d.tres" % active_slot
#
#func slot_exists(slot: int) -> bool:
	#return FileAccess.file_exists(SAVE_DIR + "slot_%d.tres" % slot)
#
#func save(stats : PlayerStats):
	#DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	#var data = SaveData.new()
	#data.profile_name = stats.profile_name
	#data.knows_combat = stats.knows_combat
	#data.knows_avarus = stats.knows_avarus
	#data.stats = stats.stats.duplicate()
	#data.upgrade_levels = stats.upgrade_levels.duplicate()
	#data.marrow_shards = stats.marrow_shards
	#ResourceSaver.save(data, _save_path())
	#
#func load_data(stats : PlayerStats):
	#if not FileAccess.file_exists(_save_path()):
		#return
	#var data = ResourceLoader.load(_save_path(), "", ResourceLoader.CACHE_MODE_IGNORE)
	#if not data is SaveData:
		#push_error("Corrupted save file")
		#return
	#
	#stats.profile_name = data.profile_name
	#stats.knows_combat = data.knows_combat
	#stats.knows_avarus = data.knows_avarus
	#stats.stats.merge(data.stats, true)
	#stats.upgrade_levels.merge(data.upgrade_levels, true)
	#stats.marrow_shards = data.marrow_shards
#
#func get_profiles() -> Array[String]:
	#var profiles : Array[String] = []
	#var dir = DirAccess.open("user://saves/")
	#
	#if dir == null:
		#return profiles
	#
	#dir.list_dir_begin()
	#var file = dir.get_next()
	#
	#while file != "":
		#if file.ends_with(".tres"):
			#profiles.append(file.trim_suffix(".tres"))
		#file = dir.get_next()
	#
	#dir.list_dir_end()
	#return profiles
#
#func new_save(slot : int, stats : PlayerStats, name : String):
	#save(stats)
	#active_slot = slot
	#save_meta()
	#stats.reset_stats()
	#stats.profile_name = name
	#stats.knows_avarus = false
	#stats.knows_combat = false
	#stats.marrow_shards = 0
	#save(stats)
#
#func switch_slot(slot: int, stats: PlayerStats) -> void:
	#save(stats)
	#active_slot = slot
	#save_meta()
	#load_data(stats)
#
#func delete_slot(slot: int, stats: PlayerStats) -> void:
	#var path = SAVE_DIR + "slot_%d.tres" % slot
	#if FileAccess.file_exists(path):
		#DirAccess.remove_absolute(path)
	#if active_slot == slot:
		#for i in range(3):
			#if slot_exists(i):
				#active_slot = i
				#save_meta()
				#load_data(stats)
				#return
		#active_slot = 0
		#stats.reset_stats()
		#stats.knows_combat = false
		#stats.knows_avarus = false
