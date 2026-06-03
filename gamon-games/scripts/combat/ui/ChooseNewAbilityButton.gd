extends Button
class_name ChooseNewAbilityButton

@export_category("Blue Theme")
@export var blue_normal: StyleBoxFlat
@export var blue_selected: StyleBoxFlat

@export_category("Gold Theme")
@export var gold_normal: StyleBoxFlat
@export var gold_selected: StyleBoxFlat

var spell_data: SpellData
var is_upgrade: bool = false
var is_selected: bool = false

func setup(spell: SpellData, upgrade: bool) -> void:
	spell_data = spell
	is_upgrade = upgrade
	
	if is_upgrade:
		text = spell.spell_name + " - Upgrade to Lvl " + str(RunData.get_spell_by_id(spell.spell_id).level + 1)
	else:
		text = spell.spell_name + " - Unlock new ability"
		
	if spell.icon:
		icon = spell.icon
		
	update_appearance()

func set_selected(selected: bool) -> void:
	is_selected = selected
	update_appearance()

func update_appearance() -> void:
	var target_style: StyleBoxFlat = null
	if is_upgrade:
		target_style = gold_selected if is_selected else gold_normal
	else:
		target_style = blue_selected if is_selected else blue_normal
		
	if target_style != null:
		add_theme_stylebox_override("normal", target_style)
		
		var hover_style := target_style.duplicate() as StyleBoxFlat
		hover_style.bg_color = target_style.bg_color.lightened(0.08)
		hover_style.border_color = target_style.border_color.lightened(0.15)
		add_theme_stylebox_override("hover", hover_style)
		
		var pressed_style := target_style.duplicate() as StyleBoxFlat
		pressed_style.bg_color = target_style.bg_color.darkened(0.1)
		add_theme_stylebox_override("pressed", pressed_style)
