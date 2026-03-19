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

	for button in buttons:
		button.pressed.connect(_on_button_pressed)

func show_random_options():
	var all_stats = PlayerStats.stats.keys()
	all_stats.shuffle()
	var max_buttons = all_stats.slice(0, 3) 

	for active_stat in range(3):  
		var active_button = buttons[active_stat] 
		var stat_key = max_buttons[active_stat]

		active_button.text = "%s (Lv %d)" % [stat_key.capitalize(), PlayerStats.get_upgrade_level(stat_key)]
		button_stat_map[active_button] = stat_key  

	show()

func _on_button_pressed():
	var pressed_button = get_pressed_button()  
	if pressed_button and pressed_button in button_stat_map:
		var stat = button_stat_map[pressed_button]
		print("Selected stat:", stat)
		emit_signal("upgrade_selected", stat)
		hide()

func get_pressed_button() -> Button:
	for button in buttons:
		if button.is_pressed():
			return button
	return null
