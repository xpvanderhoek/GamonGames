extends Control

@onready var stats_panel = $StatsPanel
@onready var stats_container = $StatsPanel/StatsContainer
@onready var stats_button = $Button_ShowStats

func _ready():
	stats_panel.visible = false
	stats_button.connect("pressed", Callable(self, "_on_stats_button_pressed"))

func _on_stats_button_pressed():
	stats_panel.visible = !stats_panel.visible
	if stats_panel.visible:
		update_stats_display()

func update_stats_display():
	if stats_container == null:
		push_error("StatsContainer not found!")
		return

	for child in stats_container.get_children():
		child.queue_free()

	for stat_name in PlayerStats.stats.keys():
		var value = PlayerStats.stats[stat_name]
		var upgrade_level = PlayerStats.get_upgrade_level(stat_name)
		var label = Label.new()
		label.text = "%s: %.2f (Level %d)" % [stat_name.capitalize().replace("_", " "), value, upgrade_level]
		stats_container.add_child(label)
