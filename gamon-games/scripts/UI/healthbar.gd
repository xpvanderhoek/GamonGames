extends Control
@onready var health_label : Label = $HealthLabel

func _ready() -> void:
	RunData.health_changed.connect(update)
	PlayerStats.stats_changed.connect(_on_stats_changed)

func _on_stats_changed(stat_name: String, _new_value: float) -> void:
	if stat_name == "health":
		update()

func update():
	if RunData.current_health == null or RunData.max_health == null:
		return
	self.value = float(RunData.current_health) * 100.0 / float(RunData.max_health)
	health_label.text = str(RunData.current_health) + " / " + str(RunData.max_health)
