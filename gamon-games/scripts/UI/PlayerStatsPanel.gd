extends PanelContainer

signal panel_closed

var _stats_ref: Node = null

const STAT_META := {
	"health":            { "label": "Health",        "suffix": "" },
	"damage":            { "label": "Damage",        "suffix": "" },
	"energy_regen":      { "label": "Energy regen",  "suffix": "" },
	"precision":         { "label": "Precision",     "suffix": "" },
	"gold_gain":         { "label": "Gold gain",     "suffix": "×" },
	"debuff_resistance": { "label": "Debuff resist", "suffix": "%" },
	"luck":              { "label": "Luck",          "suffix": "" },
	"defense":           { "label": "Defense",       "suffix": "" },
}

@onready var profile_label : Label         = $MarginContainer/VBox/Header/ProfileLabel
@onready var close_button  : Button        = $MarginContainer/VBox/Header/CloseButton
@onready var stats_grid    : VBoxContainer = $MarginContainer/VBox/StatsSection/StatsGrid

func _ready() -> void:
	hide()
	close_button.pressed.connect(_on_close_pressed)

func set_stats(stats_node: Node) -> void:
	if _stats_ref != null and _stats_ref.stats_changed.is_connected(_on_stat_changed):
		_stats_ref.stats_changed.disconnect(_on_stat_changed)
	_stats_ref = stats_node
	if _stats_ref == null:
		return
	_stats_ref.stats_changed.connect(_on_stat_changed)
	_refresh_all()

func toggle() -> void:
	if visible:
		hide()
	else:
		_refresh_all()
		show()

func _refresh_all() -> void:
	if _stats_ref == null:
		return
	profile_label.text = _stats_ref.profile_name
	_build_stat_rows()

func _compute_item_bonuses() -> Dictionary:
	var bonuses := {}
	for key in STAT_META:
		bonuses[key] = 0.0
	for item in RunData.items:
		if item == null:
			continue
		var target_key : String = item.target_limb.to_lower().replace(" ", "")
		var is_global := target_key == "" or target_key == "none" or target_key == "all" or target_key == "alllimbs" or target_key == "self"
		if not is_global:
			continue
		var buff := item.buff_type.to_lower()
		if buff in bonuses:
			bonuses[buff] += item.buff_value
	return bonuses

func _build_stat_rows() -> void:
	for child in stats_grid.get_children():
		child.queue_free()
	var bonuses := _compute_item_bonuses()
	for stat_key in STAT_META:
		var meta  : Dictionary = STAT_META[stat_key]
		var base  : float      = _stats_ref.get_stat_value(stat_key)
		var bonus : float      = bonuses.get(stat_key, 0.0)
		var total : float      = base + bonus
		var level : int        = _stats_ref.get_upgrade_level(stat_key)
		var row   : HBoxContainer = _make_row(
			meta["label"],
			"%.1f%s" % [total, meta["suffix"]],
			bonus,
			meta["suffix"],
			"lvl %d" % level,
			stat_key
		)
		stats_grid.add_child(row)

func _make_row(stat_name: String, value: String, item_bonus: float, suffix: String, level_text: String, key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Row_" + key
	row.custom_minimum_size = Vector2(0, 32)
	row.add_theme_constant_override("separation", 8)

	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)

	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = stat_name
	name_lbl.add_theme_font_size_override("font_size", 13)
	info.add_child(name_lbl)

	var sub_line := HBoxContainer.new()
	sub_line.add_theme_constant_override("separation", 6)

	var lvl_lbl := Label.new()
	lvl_lbl.name = "LevelLabel"
	lvl_lbl.text = level_text
	lvl_lbl.add_theme_font_size_override("font_size", 10)
	lvl_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1))
	sub_line.add_child(lvl_lbl)

	if not is_zero_approx(item_bonus):
		var bonus_lbl := Label.new()
		bonus_lbl.name = "BonusLabel"
		bonus_lbl.text = "+%.1f%s items" % [item_bonus, suffix]
		bonus_lbl.add_theme_font_size_override("font_size", 10)
		bonus_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5, 1))
		sub_line.add_child(bonus_lbl)

	info.add_child(sub_line)
	row.add_child(info)

	var val_lbl := Label.new()
	val_lbl.name = "ValueLabel"
	val_lbl.text = value
	val_lbl.custom_minimum_size = Vector2(60, 0)
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 1))
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	return row

func _on_stat_changed(stat_name: String, _new_value: float) -> void:
	if not visible or not stat_name in STAT_META:
		return
	_build_stat_rows()

func _on_close_pressed() -> void:
	hide()
	panel_closed.emit()
