extends HBoxContainer
class_name SkillListLine

@onready var skill_texture: TextureRect = $SkillTexture
@onready var skill_name: Label = $SkillName
@onready var buff_amount: Label = $BuffAmount
@onready var marrow_shards_amount_label: Label = $MarrowShardsAmountLabel
@onready var buy_button: Button = $BuyButton

var current_skill: SkillData

func _ready() -> void:
	pass # Replace with function body.

func setup_skill(skill_data: SkillData):
	current_skill = skill_data
	skill_name.text= str(skill_data.skill_name)
	skill_texture.texture = skill_data.texture
	buy_button.tooltip_text = skill_data.tooltip_text
	
	if current_skill.stat_bonus_per_level == 0 and current_skill.max_level == 1:
		buff_amount.text = "Locked"
	else:
		buff_amount.text = "Lvl %d" % [skill_data.current_level]
	marrow_shards_amount_label.text = str(skill_data.get_level_cost())


func _on_buy_button_pressed() -> void:
	if current_skill.current_level == current_skill.max_level:
		print("Already max level")
		return
	
	var cost = current_skill.get_level_cost()
	if RunData.marrow_shards < cost:
		print("Not enough marrow shards")
		return
	
	RunData.marrow_shards -= cost
	current_skill.current_level += 1
	
	if current_skill.affected_stat != "" and current_skill.stat_bonus_per_level > 0:
		PlayerStats.update_stat(current_skill.affected_stat, current_skill.stat_bonus_per_level, current_skill.current_level)
	
	if current_skill.stat_bonus_per_level == 0 and current_skill.max_level == 1:
		buff_amount.text = "Bought"
	else:
		buff_amount.text = "Lvl %d" % [current_skill.current_level]
	
	marrow_shards_amount_label.text = str(current_skill.get_level_cost())
	
	print(current_skill.skill_name + " leveled up to " + str(current_skill.current_level))
