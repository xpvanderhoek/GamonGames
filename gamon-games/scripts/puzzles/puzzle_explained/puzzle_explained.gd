extends Control

@onready var title: Label = $TextureRect/VBoxContainer/Title
@onready var description: Label = $TextureRect/VBoxContainer/Description
@onready var hints: Label = $TextureRect/VBoxContainer/Tips

func _ready() -> void:
	pass

func setup(title_text: String = "", description_text: String = "", tips: Array = []) -> void:
	title.text = title_text
	description.text = description_text
	var all_tips = "\n"

	for tip in tips:
		all_tips += tip + "\n"

	hints.text = all_tips
