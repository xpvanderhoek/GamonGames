extends Control

@onready var title: Label = $TextureRect/VBoxContainer/Title
@onready var description: Label = $TextureRect/VBoxContainer/Description
@onready var hints: RichTextLabel = $TextureRect/VBoxContainer/Tips
@onready var reward: RichTextLabel = $TextureRect/VBoxContainer/Reward

func _ready() -> void:
	modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)

func setup(title_text: String = "", description_text: String = "", tips: Array = [], reward_text: String = "", color = null) -> void:
	title.text = title_text
	description.text = description_text
	var all_tips = ""
	for tip in tips:
		all_tips += "\n" + tip
	if color != null:
		var color_hex = color.to_html(false)
		all_tips += "[color=%s]■[/color]" % color_hex
	all_tips += "\n\n"
	hints.text = all_tips
	reward.text = reward_text


func _on_continue_button_pressed() -> void:
	PlayerStats.knows_puzzles["slide"] = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	
	await tween.finished
	queue_free()
