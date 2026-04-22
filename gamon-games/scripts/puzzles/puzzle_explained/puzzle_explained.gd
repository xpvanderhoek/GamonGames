extends Control

@onready var title: Label = $TextureRect/VBoxContainer/Title
@onready var description: Label = $TextureRect/VBoxContainer/Description
@onready var hints: Label = $TextureRect/VBoxContainer/Tips
@onready var reward: Label = $TextureRect/VBoxContainer/Reward

func _ready() -> void:
	pass

func setup(title_text: String = "", description_text: String = "", tips: Array = [], reward_text: String = "") -> void:
	title.text = title_text
	description.text = description_text
	var all_tips = "\n"

	for tip in tips:
		all_tips += tip + "\n"

	hints.text = all_tips
	reward.text = reward_text
