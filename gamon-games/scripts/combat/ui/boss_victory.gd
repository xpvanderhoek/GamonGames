extends Control

var title: Label = null
var message: Label = null
var bg_panel: PanelContainer = null
var continue_button: Button = null
var stats_container: VBoxContainer = null
var _tween: Tween = null

func _ready() -> void:
	if RunData.run_active:
		RunData.end_run(true)
	get_tree().paused = true
	title = get_node_or_null("PanelContainer/VBoxContainer/Title")
	message = get_node_or_null("PanelContainer/VBoxContainer/Message")
	if message:
		message.text = get_highlight().title + ", " + "Thank you for playtesting!"
	continue_button = get_node_or_null("PanelContainer/VBoxContainer/ContinueButton")
	bg_panel = get_node_or_null("PanelContainer")

	if not continue_button:
		print("ERROR: continue_button not found!")

	if continue_button:
		get_tree().paused = false
		continue_button.pressed.connect(func():
			SoundManager.stop_combat_music()
			TransitionManager.change_scene("res://scenes/UI/main_menu/main_menu.tscn", TransitionManager.TransitionType.FADE)
		)
		continue_button.disabled = true
		continue_button.modulate.a = 0

	if bg_panel:
		bg_panel.modulate.a = 0
	if title:
		title.modulate.a = 0
	if message:
		message.modulate.a = 0

	_build_stats_panel()
	_play_victory_sequence()

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
		"value": safe_divide(float(RunData.combats_fought), floor * 1.2),
	},
	{
		"title": "Puzzle Master",
		"value": safe_divide(float(RunData.puzzles_solved), floor / 2.0),
	},
	{
		"title": "Puzzle Loser",
		"value": safe_divide(
			float(RunData.puzzles_failed),
			float(RunData.puzzles_solved + RunData.puzzles_failed) * 3
		),
	},
	{
		"title": "Merchant’s Friend",
		"value": safe_divide(float(RunData.shops_visited), floor / 4.0),
	},
	{
		"title": "Pack Rat",
		"value": safe_divide(float(RunData.items.size()), 8.0),
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
	sep1.color = Color(0.55, 0.50, 0.40, 0.4)
	sep1.custom_minimum_size = Vector2(0, 1)
	sep1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(sep1)

	var stats = [
		["Run Time",        _format_time(RunData.current_run_time)],
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
		name_lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.68, 1.0))
		name_lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(name_lbl)

		var val_lbl = Label.new()
		val_lbl.text = stat[1]
		val_lbl.custom_minimum_size.x = 60
		val_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72, 1.0))
		val_lbl.add_theme_font_size_override("font_size", 18)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_lbl)
		inner.add_child(row)

	var sep2 = ColorRect.new()
	sep2.color = Color(0.55, 0.50, 0.40, 0.4)
	sep2.custom_minimum_size = Vector2(0, 1)
	sep2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(sep2)

	stats_container.add_child(margin)

	var continue_index = continue_button.get_index() if continue_button else vbox.get_child_count()
	vbox.add_child(stats_container)
	vbox.move_child(stats_container, continue_index)

func _play_victory_sequence() -> void:
	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(bg_panel, "modulate:a", 1.0, 0.8)

	_tween.tween_callback(func():
		_animate_title()
	)
	_tween.tween_interval(0.6)

	_tween.tween_callback(func():
		_animate_message()
	)
	_tween.tween_interval(0.8)

	_tween.tween_callback(func():
		_animate_stats()
	)
	_tween.tween_interval(0.6)

	_tween.tween_callback(func():
		_show_continue_button()
	)

func _animate_title() -> void:
	if not title:
		return
	title.position.y -= 50
	title.modulate.a = 0
	title.scale = Vector2(0.8, 0.8)
	var local_tween = create_tween()
	local_tween.set_trans(Tween.TRANS_BACK)
	local_tween.set_ease(Tween.EASE_OUT)
	local_tween.set_parallel(true)
	local_tween.tween_property(title, "position:y", title.position.y + 50, 0.5)
	local_tween.tween_property(title, "scale", Vector2(1.0, 1.0), 0.5)
	local_tween.tween_property(title, "modulate:a", 1.0, 0.5)

func _animate_message() -> void:
	if not message:
		return
	var local_tween = create_tween()
	local_tween.set_trans(Tween.TRANS_SINE)
	local_tween.set_ease(Tween.EASE_OUT)
	message.modulate.a = 0
	local_tween.tween_property(message, "modulate:a", 1.0, 0.6).set_delay(0.3)

func _animate_stats() -> void:
	if not stats_container:
		return
	var local_tween = create_tween()
	local_tween.set_trans(Tween.TRANS_SINE)
	local_tween.set_ease(Tween.EASE_OUT)
	local_tween.tween_property(stats_container, "modulate:a", 1.0, 0.5)

func _show_continue_button() -> void:
	if not continue_button:
		return
	continue_button.scale = Vector2(1, 1)
	var button_tween = create_tween()
	button_tween.set_trans(Tween.TRANS_SINE)
	button_tween.set_ease(Tween.EASE_OUT)
	button_tween.tween_property(continue_button, "modulate:a", 1.0, 0.5)
	button_tween.tween_callback(func():
		if continue_button:
			continue_button.disabled = false
			var pulse_tween = create_tween()
			pulse_tween.set_loops()
			pulse_tween.set_trans(Tween.TRANS_SINE)
			pulse_tween.set_ease(Tween.EASE_IN_OUT)
			pulse_tween.tween_property(continue_button, "modulate:a", 0.7, 1.2)
			pulse_tween.tween_property(continue_button, "modulate:a", 1.0, 1.2)
	)

func _format_time(value: float) -> String:
	if value <= 0.0:
		return "--:--"
	var mins = int(value) / 60
	var secs = int(value) % 60
	var ms = int((value - int(value)) * 100)
	return "%02d:%02d.%02d" % [mins, secs, ms]
