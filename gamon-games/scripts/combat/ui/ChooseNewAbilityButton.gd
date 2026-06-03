extends Button
class_name ChooseNewAbilityButton

enum SpellCategory { PHYSICAL_ATTACK, MAGIC_ATTACK, BLOCK, BUFF_HEAL, DEBUFF }

@export_category("Normal Styles (.tres)")
@export var physical_normal: StyleBoxFlat
@export var magic_normal: StyleBoxFlat
@export var block_normal: StyleBoxFlat
@export var buff_normal: StyleBoxFlat
@export var debuff_normal: StyleBoxFlat

@export_category("Selected Styles (.tres)")
@export var physical_selected: StyleBoxFlat
@export var magic_selected: StyleBoxFlat
@export var block_selected: StyleBoxFlat
@export var buff_selected: StyleBoxFlat
@export var debuff_selected: StyleBoxFlat

var spell_data: SpellData
var is_upgrade: bool = false
var is_selected: bool = false

func setup(spell: SpellData, upgrade: bool) -> void:
	spell_data = spell
	is_upgrade = upgrade
	
	if is_upgrade:
		text = "Upgrade " + spell.spell_name + " to Lvl " + str(RunData.get_spell_by_id(spell.spell_id).level + 1)
	else:
		text = "Unlock " + spell.spell_name
		
	if spell.icon:
		icon = spell.icon
		
	update_appearance()

func set_selected(selected: bool) -> void:
	is_selected = selected
	update_appearance()

func _get_spell_category(spell: SpellData) -> int:
	if spell.player_physical_defense_delta > 0.0 or spell.player_magic_defense_delta > 0.0:
		return SpellCategory.BLOCK
	if spell.spell_type == SpellData.SpellType.ATTACK:
		if spell.damage_type == SpellData.DamageType.MAGIC:
			return SpellCategory.MAGIC_ATTACK
		else:
			return SpellCategory.PHYSICAL_ATTACK
	if spell.spell_type == SpellData.SpellType.BUFF or spell.spell_type == SpellData.SpellType.HEAL:
		return SpellCategory.BUFF_HEAL
	return SpellCategory.DEBUFF

func update_appearance() -> void:
	if spell_data == null:
		return
		
	var category := _get_spell_category(spell_data)
	
	var base_style: StyleBoxFlat = null
	if is_selected:
		match category:
			SpellCategory.PHYSICAL_ATTACK: base_style = physical_selected
			SpellCategory.MAGIC_ATTACK: base_style = magic_selected
			SpellCategory.BLOCK: base_style = block_selected
			SpellCategory.BUFF_HEAL: base_style = buff_selected
			SpellCategory.DEBUFF: base_style = debuff_selected
	else:
		match category:
			SpellCategory.PHYSICAL_ATTACK: base_style = physical_normal
			SpellCategory.MAGIC_ATTACK: base_style = magic_normal
			SpellCategory.BLOCK: base_style = block_normal
			SpellCategory.BUFF_HEAL: base_style = buff_normal
			SpellCategory.DEBUFF: base_style = debuff_normal
		
	if base_style != null:
		var style := base_style.duplicate() as StyleBoxFlat
		
		if is_upgrade:
			style.border_color = Color(1.0, 0.85, 0.4) if is_selected else Color(0.85, 0.65, 0.12)
			
		add_theme_stylebox_override("normal", style)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		
		var hover_style := style.duplicate() as StyleBoxFlat
		hover_style.bg_color = style.bg_color.lightened(0.08)
		add_theme_stylebox_override("hover", hover_style)
		
		var pressed_style := style.duplicate() as StyleBoxFlat
		pressed_style.bg_color = style.bg_color.darkened(0.1)
		add_theme_stylebox_override("pressed", pressed_style)
