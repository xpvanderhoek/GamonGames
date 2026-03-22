extends Node

var stats = {
	"health": 100.0,          # Hardened Flesh
	"limb_damage": 20.0,      # Anatomy Mastery
	"precision": 100.0,       # Steady Hand
	"gold_gain": 1.0,         # Scavenger's Eye
	"debuff_resistance": 10.0, # Iron Will
	"speed": 100.0,           # Quick Reflexes
	"defence": 10.0,          # Stoneguard
	"luck": 0.0               # Fortune's Blessing
}

var upgrade_levels = {
	"health": 0,
	"limb_damage": 0,
	"precision": 0,
	"gold_gain": 0,
	"debuff_resistance": 0,
	"speed": 0,
	"defence": 0,
	"luck": 0
}

var upgrade_costs = {
	"health": {"min": 100, "max": 1000},
	"limb_damage": {"min": 500, "max": 2500},
	"precision": {"min": 150, "max": 1500},
	"gold_gain": {"min": 400, "max": 2000},
	"debuff_resistance": {"min": 300, "max": 1500},
	"speed": {"min": 400, "max": 2000},
	"defence": {"min": 100, "max": 1000},
	"luck": {"min": 200, "max": 1200}
}

func get_stat_value(stat_name: String) -> float:
	if stat_name in stats:
		return stats[stat_name]
	else:
		push_error("Stat '%s' does not exist" % stat_name)
		return 0.0

func update_stat(stat_name: String, value: float) -> float:
	if not stat_name in stats:
		push_error("Stat '%s' does not exist" % stat_name)
		return 0.0
	
	var current_stat_value = get_stat_value(stat_name)
	var multiplier = 1.0 + (value / 100.0)
	var new_stat_value: float = current_stat_value * multiplier
	
	stats[stat_name] = new_stat_value
	print("Updated %s: %.2f to %.2f" % [stat_name, current_stat_value, new_stat_value])
	
	return new_stat_value

func upgrade_stat(stat_name: String) -> bool:
	if not stat_name in upgrade_levels:
		push_error("Cannot upgrade stat '%s'" % stat_name)
		return false
	
	var upgrade_config = {
		"health": {"max": 10, "percent": 5.0},
		"limb_damage": {"max": 5, "percent": 3.0},
		"precision": {"max": 10, "percent": 2.0},
		"gold_gain": {"max": 5, "percent": 5.0},
		"debuff_resistance": {"max": 5, "percent": 5.0},
		"speed": {"max": 5, "percent": 2.0},
		"defence": {"max": 10, "percent": 5.0},
		"luck": {"max": 10, "percent": 5.0}
	}
	
	var config = upgrade_config[stat_name]
	
	if upgrade_levels[stat_name] >= config.max:
		print("Stat '%s' is already at max level (%d)" % [stat_name, config.max])
		return false
	
	update_stat(stat_name, config.percent)
	upgrade_levels[stat_name] += 1
	print("Upgraded %s to level %d" % [stat_name, upgrade_levels[stat_name]])
	
	return true

func get_upgrade_level(stat_name: String) -> int:
	if stat_name in upgrade_levels:
		return upgrade_levels[stat_name]
	return 0

func reset_stats() -> void:
	stats = {
		"health": 100.0,
		"limb_damage": 20.0,
		"precision": 100.0,
		"gold_gain": 1.0,
		"debuff_resistance": 10.0,
		"speed": 100.0,
		"defence": 10.0,
		"luck": 0.0
	}
	
	for key in upgrade_levels:
		upgrade_levels[key] = 0
