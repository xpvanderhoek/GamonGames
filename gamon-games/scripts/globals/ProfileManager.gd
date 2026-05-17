extends Node

var SAVE_PATH := "user://profiles.json"

var active_ign := ""
var profiles := {}

func _ready():
	load_from_file()

func set_ign(ign: String) -> void:
	active_ign = ign

	if not profiles.has(ign):
		profiles[ign] = {
			"best_level": 1,
			"best_exp": 0,
			"best_coins": 0,
			"best_score": 0,
			"most_items": 0
		}

	save_to_file()

func get_profile(ign: String) -> Dictionary:
	if not profiles.has(ign):
		profiles[ign] = {
			"best_level": 1,
			"best_exp": 0,
			"best_coins": 0,
			"best_score": 0,
			"most_items": 0
		}
	return profiles[ign]

func update_profile(ign: String, data: Dictionary) -> void:
	if not profiles.has(ign):
		get_profile(ign)

	var profile = profiles[ign]

	for key in data.keys():
		profile[key] = data[key]

	profiles[ign] = profile
	save_to_file()

func get_sorted_by(stat: String) -> Array:
	var list := []

	for ign in profiles.keys():
		var p = profiles[ign]

		if p.has(stat):
			list.append({
				"ign": ign,
				"value": p[stat]
			})

	list.sort_custom(func(a, b):
		return a["value"] > b["value"]
	)

	return list

func save_to_file() -> void:
	var data = {
		"active_ign": active_ign,
		"profiles": profiles
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_from_file() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var result = JSON.parse_string(content)
	if result == null:
		return

	active_ign = result.get("active_ign", "")
	profiles = result.get("profiles", {})

	print("Loaded profiles:", profiles.keys())
