extends HBoxContainer
class_name SkillListLine

signal tooltip_requested(text: String)
signal tooltip_cleared

@onready var skill_texture: TextureRect = $SkillTexture
@onready var skill_name: Label = $SkillName
@onready var buff_amount: Label = $BuffAmount
@onready var marrow_shards_amount_label: Label = $MarrowShardsAmountLabel
@onready var buy_button: Button = $BuyButton

var current_skill: SkillData

func _ready() -> void:
	if buy_button:
		if not buy_button.mouse_entered.is_connected(_on_buy_button_mouse_entered):
			buy_button.mouse_entered.connect(_on_buy_button_mouse_entered)
		if not buy_button.mouse_exited.is_connected(_on_buy_button_mouse_exited):
			buy_button.mouse_exited.connect(_on_buy_button_mouse_exited)
	if not mouse_entered.is_connected(_on_line_mouse_entered):
		mouse_entered.connect(_on_line_mouse_entered)
	if not mouse_exited.is_connected(_on_line_mouse_exited):
		mouse_exited.connect(_on_line_mouse_exited)

func setup_skill(skill_data: SkillData):
	current_skill = skill_data
	skill_name.text= str(skill_data.skill_name)
	skill_texture.texture = skill_data.texture
	buy_button.tooltip_text = ""
	
	if current_skill.affected_stat != "" and current_skill.affected_stat in PlayerStats.upgrade_levels:
		current_skill.current_level = int(PlayerStats.upgrade_levels[current_skill.affected_stat])
	elif _is_starting_kit():
		current_skill.current_level = int(PlayerStats.upgrade_levels.get("starting_kit", 0))
	
	if current_skill.stat_bonus_per_level == 0 and current_skill.max_level == 1:
		buff_amount.text = "Bought" if current_skill.current_level > 0 else "Locked"
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
	
	SoundManager.play_purchase()
	RunData.marrow_shards -= cost
	current_skill.current_level += 1
	if current_skill.affected_stat != "":
		PlayerStats.upgrade_levels[current_skill.affected_stat] = current_skill.current_level
		SaveLoad.save_data()
	elif _is_starting_kit():
		PlayerStats.upgrade_levels["starting_kit"] = current_skill.current_level
		SaveLoad.save_data()
	
	if current_skill.affected_stat != "" and current_skill.stat_bonus_per_level > 0:
		PlayerStats.update_stat(current_skill.affected_stat, current_skill.stat_bonus_per_level, current_skill.current_level)
	
	if current_skill.stat_bonus_per_level == 0 and current_skill.max_level == 1:
		buff_amount.text = "Bought"
	else:
		buff_amount.text = "Lvl %d" % [current_skill.current_level]
	
	marrow_shards_amount_label.text = str(current_skill.get_level_cost())
	
	print(current_skill.skill_name + " leveled up to " + str(current_skill.current_level))

func _on_buy_button_mouse_entered() -> void:
	var text := ""
	if current_skill != null:
		text = current_skill.tooltip_text.strip_edges()
	if text == "":
		tooltip_cleared.emit()
		return
	tooltip_requested.emit(text)

func _on_buy_button_mouse_exited() -> void:
	tooltip_cleared.emit()

func _on_line_mouse_entered() -> void:
	_on_buy_button_mouse_entered()

func _on_line_mouse_exited() -> void:
	_on_buy_button_mouse_exited()

func _is_starting_kit() -> bool:
	return current_skill != null and current_skill.skill_name == "Starting Kit"
