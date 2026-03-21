extends Control

signal upgrade_selected(stat)

@onready var panel_vbox = $Panel/VBoxContainer
@onready var button1: Button = $Panel/VBoxContainer/Label/Button1
@onready var button2: Button = $Panel/VBoxContainer/Label/Button2
@onready var button3: Button = $Panel/VBoxContainer/Label/Button3

var buttons: Array = []
var button_to_stat_map := {} 
var max_buttons := 3

func _ready():
	hide()
	buttons = [button1, button2, button3]

	process_mode = Node.PROCESS_MODE_ALWAYS
	for button in buttons:
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.pressed.connect(_on_button_pressed)

func show_random_options():
	var all_stats = PlayerStats.stats.keys()
	all_stats.shuffle()
	var chosen_stats = all_stats.slice(0, max_buttons)

	for button_index in range(max_buttons): 
		var current_button = buttons[button_index] 
		var corresponding_stat = chosen_stats[button_index]

		current_button.text = "%s (Lv %d)" % [corresponding_stat.capitalize(), PlayerStats.get_upgrade_level(corresponding_stat)]
		button_to_stat_map[current_button] = corresponding_stat  

	show()

func _on_button_pressed():
	var pressed_button = get_pressed_button()  
	if pressed_button and pressed_button in button_to_stat_map:
		var selected_stat = button_to_stat_map[pressed_button]
		print("Selected stat:", selected_stat)
		emit_signal("upgrade_selected", selected_stat)
		hide()

func get_pressed_button() -> Button:
	for button in buttons:
		if button.is_pressed():
			return button
	return null
