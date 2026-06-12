extends Control
 
var title: Label = null
var message: Label = null
var bg_panel: PanelContainer = null
var retry_button: Button = null
var menu_button: Button = null
var stats_container: VBoxContainer = null
var _tween: Tween = null
 
func _ready() -> void:
	title = get_node_or_null("PanelContainer/VBoxContainer/Title")
	message = get_node_or_null("PanelContainer/VBoxContainer/Message")
	message.text = get_highlight().title + "! " + "You have fallen in battle..."
	retry_button = get_node_or_null("PanelContainer/VBoxContainer/ButtonContainer/RetryButton")
	menu_button = get_node_or_null("PanelContainer/VBoxContainer/ButtonContainer/MenuButton")
	bg_panel = get_node_or_null("PanelContainer")
 
	if not retry_button:
		print("ERROR: retry_button not found!")
	if not menu_button:
		print("ERROR: menu_button not found!")
 
	if retry_button:
		retry_button.pressed.connect(func():
			SoundManager.stop_combat_music()
			SaveLoad.record_run_stats()
			RunData.end_run()
			RunData.new_run()
			SaveLoad.save_data()
			TransitionManager.change_scene("res://scenes/map/map.tscn", TransitionManager.TransitionType.FADE)
		)
		retry_button.disabled = true
		retry_button.modulate.a = 0
 
	if menu_button:
		menu_button.pressed.connect(func():
			SoundManager.stop_combat_music()
			SaveLoad.record_run_stats()
			RunData.end_run()
			SaveLoad.save_data()
			TransitionManager.change_scene("res://scenes/UI/main_menu/main_menu.tscn", TransitionManager.TransitionType.FADE)
		)
		menu_button.disabled = true
		menu_button.modulate.a = 0
 
	if bg_panel:
		bg_panel.modulate.a = 0
	if title:
		title.modulate.a = 0
	if message:
		message.modulate.a = 0
 
	_build_stats_panel()
	_play_defeat_sequence()

func safe_divide(a: float, b: float) -> float:
	if b == 0.0:
		return 0.0
	return a / b
	
func get_highlight() -> Dictionary:
	var floor: int = RunData.floors_climbed
	if floor <= 4:
		return {
		"title": "An early death",
	}
	var highlights = [
	{
		"title": "Relentless Fighter",
		"value": safe_divide(float(RunData.combats_fought), floor * 1.5),
	},
	{
		"title": "Puzzle Master",
		"value": safe_divide(float(RunData.puzzles_solved), floor / 2.0),
	},
	{
		"title": "Puzzle Loser",
		"value": safe_divide(
			float(RunData.puzzles_failed),
			float(RunData.puzzles_solved + RunData.puzzles_failed)
		),
	},
	{
		"title": "Merchant’s Friend",
		"value": safe_divide(float(RunData.shops_visited), floor / 3.0),
	},
	{
		"title": "Pack Rat",
		"value": safe_divide(float(RunData.items.size()), 10.0),
	},
	{
		"title": "Treasure Keeper",
		"value": safe_divide(float(RunData.coins), 400.0),
	},
	{
		"title": "Restful Wanderer",
		"value": safe_divide(
			float(RunData.camps_visited),
			float(RunData.total_resting_camps) - 3
		),
	}
	]
	print(highlights)
	var best = highlights[0]
	var best_score = float(best.value)

	for h in highlights:
		var score = float(h.value)
		if score > best_score:
			best = h
			best_score = score

	return best
	
	
func _build_stats_panel() -> void:
	var vbox = get_node_or_null("PanelContainer/VBoxContainer")
	if vbox == null:
		return

	stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 8)
	stats_container.modulate.a = 0

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	margin.add_child(inner)

	var sep1 = ColorRect.new()
	sep1.color = Color(0.6, 0.2, 0.2, 0.4)
	sep1.custom_minimum_size = Vector2(0, 1)
	sep1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(sep1)

	var stats = [
		["Level Reached",   str(RunData.current_level)],
		["Combats Fought",  str(RunData.combats_fought)],
		["Items Collected", str(RunData.items.size())],
		["Spells in Deck",  str(RunData.spells.size())],
		["Coins Remaining", str(RunData.coins)],
	]

	for stat in stats:
		var row = HBoxContainer.new()
		var name_lbl = Label.new()
		name_lbl.text = stat[0]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(0.80, 0.65, 0.65, 1.0))
		name_lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(name_lbl)

		var val_lbl = Label.new()
		val_lbl.text = stat[1]
		val_lbl.custom_minimum_size.x = 60
		val_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75, 1.0))
		val_lbl.add_theme_font_size_override("font_size", 18)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_lbl)
		inner.add_child(row)

	var sep2 = ColorRect.new()
	sep2.color = Color(0.6, 0.2, 0.2, 0.4)
	sep2.custom_minimum_size = Vector2(0, 1)
	sep2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(sep2)

	stats_container.add_child(margin)

	var button_container = get_node_or_null("PanelContainer/VBoxContainer/ButtonContainer")
	var insert_index = button_container.get_index() if button_container else vbox.get_child_count()
	vbox.add_child(stats_container)
	vbox.move_child(stats_container, insert_index)
 
func _play_defeat_sequence() -> void:
	if _tween:
		_tween.kill()
 
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(bg_panel, "modulate:a", 1.0, 1.0)
 
	_tween.tween_callback(func():
		_animate_title()
	)
	_tween.tween_interval(0.8)
 
	_tween.tween_callback(func():
		_animate_message()
	)
	_tween.tween_interval(1.0)
 
	_tween.tween_callback(func():
		_animate_stats()
	)
	_tween.tween_interval(0.6)
 
	_tween.tween_callback(func():
		_show_buttons()
	)
 
func _animate_title() -> void:
	if not title:
		return
	title.position.y += 50
	title.modulate.a = 0
	title.scale = Vector2(1.2, 1.2)
	var local_tween = create_tween()
	local_tween.set_trans(Tween.TRANS_BACK)
	local_tween.set_ease(Tween.EASE_OUT)
	local_tween.set_parallel(true)
	local_tween.tween_property(title, "position:y", title.position.y - 50, 0.6)
	local_tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.6)
	local_tween.tween_property(title, "modulate:a", 1.0, 0.6)
 
func _animate_message() -> void:
	if not message:
		return
	var local_tween = create_tween()
	local_tween.set_trans(Tween.TRANS_SINE)
	local_tween.set_ease(Tween.EASE_OUT)
	message.modulate.a = 0
	local_tween.tween_property(message, "modulate:a", 1.0, 0.8).set_delay(0.2)
 
func _animate_stats() -> void:
	if not stats_container:
		return
	var local_tween = create_tween()
	local_tween.set_trans(Tween.TRANS_SINE)
	local_tween.set_ease(Tween.EASE_OUT)
	local_tween.tween_property(stats_container, "modulate:a", 1.0, 0.5)
 
func _show_buttons() -> void:
	if not retry_button or not menu_button:
		return
	retry_button.scale = Vector2(1, 1)
	menu_button.scale = Vector2(1, 1)
	var button_tween = create_tween()
	button_tween.set_trans(Tween.TRANS_SINE)
	button_tween.set_ease(Tween.EASE_OUT)
	button_tween.set_parallel(true)
	button_tween.tween_property(retry_button, "modulate:a", 1.0, 0.5)
	button_tween.tween_property(menu_button, "modulate:a", 1.0, 0.5)
	button_tween.tween_callback(func():
		if retry_button and menu_button:
			retry_button.disabled = false
			menu_button.disabled = false
			_add_pulse_effect(retry_button)
	)
 
func _add_pulse_effect(button: Button) -> void:
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.8)
	pulse_tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.8)
