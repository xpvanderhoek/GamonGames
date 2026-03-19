extends Control

signal upgrade_selected(stat)

@onready var panel_vbox = $Panel/VBoxContainer
@onready var button1: Button = $Panel/VBoxContainer/Label/Button1
@onready var button2: Button = $Panel/VBoxContainer/Label/Button2
@onready var button3: Button = $Panel/VBoxContainer/Label/Button3

var buttons: Array = []
var button_stat_map := {} 

func _ready():
	hide()
	buttons = [button1, button2, button3]

	button1.pressed.connect(_on_button_pressed)
	button2.pressed.connect(_on_button_pressed)
	button3.pressed.connect(_on_button_pressed)

func show_random_options():
	var all_stats = PlayerStats.stats.keys()
	all_stats.shuffle()
	var options = all_stats.slice(0, 3)

	for i in range(3):
		var btn = buttons[i]
		var stat_key = options[i]

		btn.text = "%s (Lv %d)" % [stat_key.capitalize(), PlayerStats.get_upgrade_level(stat_key)]
		button_stat_map[btn] = stat_key  

	show()

func _on_button_pressed():
	var btn = get_pressed_button()
	if btn and btn in button_stat_map:
		var stat = button_stat_map[btn]
		print("Selected stat:", stat)
		emit_signal("upgrade_selected", stat)
		hide()

func get_pressed_button() -> Button:
	for b in buttons:
		if b.is_pressed():
			return b
	return null
