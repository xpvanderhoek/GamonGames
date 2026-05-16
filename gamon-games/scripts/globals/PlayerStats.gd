extends Node

var knows_combat : bool = false
var knows_avarus : bool = false
var knows_ghost : bool = true


signal stats_changed(stat_name: String, new_value: float)
signal upgrade_completed(stat_name: String, level: int)

var stats = {
	"health": 100.0,          # Hardened Flesh
	"damage": 0.0,      # Anatomy Mastery
	"energy_regen": 2.0,
	"precision": 100.0,       # Steady Hand
	"gold_gain": 1.0,         # Scavenger's Eye
	"debuff_resistance": 10.0, # Iron Will
	"luck": 1.0,               # Fortune's Blessing
	"physical_defense": 10.0, # Stoneguard
	"magic_defense": 10.0,
}

var base_stats = {
	"health": 100.0,
	"damage": 1000.0,
	"precision": 100.0,
	"gold_gain": 1.0,
	"debuff_resistance": 10.0,
	"luck": 1.0,
	"physical_defense": 10.0,
	"magic_defense": 10.0,
}

var upgrade_levels = {
	"health": 0,
	"damage": 0,
	"energy_regen": 0,
	"precision": 0,
	"gold_gain": 0,
	"debuff_resistance": 0,
	"luck": 0,
	"physical_defense": 0,
	"magic_defense": 0,
}

var upgrade_costs = {
	"health": {"min": 100, "max": 1000},
	"damage": {"min": 500, "max": 2500},
	"energy_regen": {"min": 200, "max": 1400},
	"precision": {"min": 150, "max": 1500},
	"gold_gain": {"min": 400, "max": 2000},
	"debuff_resistance": {"min": 300, "max": 1500},
	"luck": {"min": 200, "max": 1200},
	"physical_defense": {"min": 100, "max": 1000},
	"magic_defense": {"min": 100, "max": 1000},
}

func get_stat_value(stat_name: String) -> float:
	if stat_name in stats:
		return stats[stat_name]
	else:
		push_error("Stat '%s' does not exist" % stat_name)
		return 0.0

func update_stat(stat_name: String, value: float, level: int = 1) -> float:
	if not stat_name in stats:
		push_error("Stat '%s' does not exist" % stat_name)
		return 0.0
	
	var current_stat_value = get_stat_value(stat_name)
	var base_stat_value = base_stats[stat_name]
	var bonus = base_stat_value * (value / 100.0) * level
	var new_stat_value: float = base_stat_value + bonus
	
	stats[stat_name] = new_stat_value
	stats_changed.emit(stat_name, new_stat_value)
	print("Updated %s: %.2f to %.2f" % [stat_name, current_stat_value, new_stat_value])
	
	return new_stat_value

func get_upgrade_level(stat_name: String) -> int:
	if stat_name in upgrade_levels:
		return upgrade_levels[stat_name]
	return 0

func reset_stats() -> void:
	stats = base_stats.duplicate()
	
	for key in upgrade_levels:
		upgrade_levels[key] = 0

func apply_skill_bonuses(skills: Array) -> void:
	for skill in skills:
		if skill is SkillData and skill.current_level > 0 and skill.affected_stat != "":
			update_stat(skill.affected_stat, skill.stat_bonus_per_level, skill.current_level)
