extends Control

const SAVE_DIR = "user://"
const STATS_TO_SHOW = [
	"health", "damage", "defence", "speed",
	"precision", "luck", "gold_gain",
	"energy_regen", "debuff_resistance",
	"magic_defense", "physical_defense"
]

@onready var tab_container: HBoxContainer = $PanelContainer/VBoxContainer/TabBar
@onready var entries_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/EntriesContainer
@onready var stat_label: Label = $PanelContainer/VBoxContainer/StatTitle

var current_stat: String = "health"
var profile_data: Array = [] 

func _ready() -> void:
	_load_all_profiles()
	_build_tabs()
	_show_leaderboard(current_stat)

func _load_all_profiles() -> void:
	profile_data.clear()
	for i in range(1, 4):
		var path = SAVE_DIR + "save_%d.tres" % i
		if FileAccess.file_exists(path):
			var data = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if data is SaveData:
				profile_data.append({
					"name": data.profile_name,
					"stats": data.stats.duplicate(),
					"slot": i
				})

func _build_tabs() -> void:
	for stat in STATS_TO_SHOW:
		var btn = Button.new()
		btn.text = _format_stat_name(stat)
		btn.pressed.connect(_show_leaderboard.bind(stat))
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_hover_color", Color(0.98, 0.77, 0.29, 1))
		btn.add_theme_color_override("font_focus_color", Color(0.98, 0.77, 0.29, 1))
		tab_container.add_child(btn)

func _show_leaderboard(stat: String) -> void:
	current_stat = stat
	stat_label.text = _format_stat_name(stat)

	for child in entries_container.get_children():
		child.queue_free()

	if profile_data.is_empty():
		var lbl = Label.new()
		lbl.text = "No profiles found."
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		entries_container.add_child(lbl)
		return

	var sorted = profile_data.duplicate()
	sorted.sort_custom(func(a, b):
		var av = a["stats"].get(stat, 0.0)
		var bv = b["stats"].get(stat, 0.0)
		return av > bv
	)

	var medals = ["🥇", "🥈", "🥉"]
	for i in range(sorted.size()):
		var profile = sorted[i]
		var val = profile["stats"].get(stat, 0.0)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)

		var rank_lbl = Label.new()
		rank_lbl.text = medals[i] if i < 3 else "#%d" % (i + 1)
		rank_lbl.custom_minimum_size.x = 50
		rank_lbl.add_theme_font_size_override("font_size", 28)
		row.add_child(rank_lbl)

		var name_lbl = Label.new()
		name_lbl.text = profile["name"]
		name_lbl.custom_minimum_size.x = 200
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		name_lbl.add_theme_font_size_override("font_size", 28)
		row.add_child(name_lbl)

		var val_lbl = Label.new()
		val_lbl.text = _format_value(stat, val)
		val_lbl.add_theme_color_override("font_color", Color(0.98, 0.77, 0.29, 1))
		val_lbl.add_theme_font_size_override("font_size", 28)
		row.add_child(val_lbl)

		entries_container.add_child(row)

func _format_stat_name(stat: String) -> String:
	return stat.replace("_", " ").capitalize()

func _format_value(stat: String, value: float) -> String:
	if value == int(value):
		return str(int(value))
	return "%.1f" % value

func _on_close_button_pressed() -> void:
	queue_free()
