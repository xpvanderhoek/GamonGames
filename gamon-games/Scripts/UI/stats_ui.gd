extends CanvasLayer

@onready var stats_panel = $StatsPanel
@onready var stats_container = $StatsPanel/StatsContainer
@onready var stats_button = $Button_ShowStats 

func _ready():
	stats_panel.visible = false       
	stats_button.visible = true       
	stats_button.connect("pressed", Callable(self, "_on_stats_button_pressed"))
	update_stats_display()          

func _on_stats_button_pressed():
	stats_panel.visible = !stats_panel.visible  

func update_stats_display():
	if stats_container == null:
		push_error("StatsContainer not found!")
		return

	for child in stats_container.get_children():
		child.queue_free()

	for stat_name in PlayerStats.stats.keys():
		var value = PlayerStats.stats[stat_name]
		var label = Label.new()
		label.text = "%s: %s" % [stat_name.capitalize().replace("_", " "), str(value)]
		stats_container.add_child(label)

func set_stat(stat_name: String, value):
	if PlayerStats.stats.has(stat_name):
		PlayerStats.stats[stat_name] = value
		update_stats_display()
