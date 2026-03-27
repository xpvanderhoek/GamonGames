extends Control
@onready var texture_health_bar : TextureProgressBar = $HBoxContainer/TextureHealthBar
@onready var health_label : Label = $HBoxContainer/HealthLabel

func _ready() -> void:
	RunData.health_changed.connect(update)

func update():
	if RunData.current_health == null or RunData.max_health == null:
		return
	texture_health_bar.value = RunData.current_health * 100 / RunData.max_health
	health_label.text = str(RunData.current_health) + " / " + str(RunData.max_health)
