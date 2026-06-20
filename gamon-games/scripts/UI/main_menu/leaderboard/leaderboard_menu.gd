extends Control

const SAVE_DIR = "user://"

const ALEGREYA_FONT = preload("res://assets/fonts/AlegreyaSans-Bold.ttf")

const STAT_CATEGORIES = [
	{ "key": "best_level",            "label": "Best Level"         },
	{ "key": "total_runs",            "label": "Total Runs"         },
	{ "key": "total_coins_earned",    "label": "Total Coins"        },
	{ "key": "best_spells_in_deck",   "label": "Best Spell Deck"    },
	{ "key": "floors_climbed_best",   "label": "Best Floors"        },
	{ "key": "combats_fought_total",  "label": "Total Combats"      },
	{ "key": "best_speedrun_time",    "label": "Best Time"          },
]

const COL_RANK  := 50
const COL_NAME  := 200
const COL_VALUE := 130
const ROW_HEIGHT := 40
const FONT_SIZE := 20

const C_DIVIDER    := Color(1.0, 1.0, 1.0, 0.2)
const C_ACCENT     := Color(0.98, 0.77, 0.29, 1.0)
const C_ACCENT_DIM := Color(0.98, 0.77, 0.29, 0.5)
const C_TEXT       := Color(1.0, 1.0, 1.0, 1.0)
const C_TEXT_DIM   := Color(0.7, 0.7, 0.7, 1.0)
const C_VALUE      := Color(1.0, 1.0, 1.0, 1.0)

@onready var tab_bar: TabBar = $Window/Contents/VBoxContainer/TabBar
@onready var header_container: HBoxContainer = $Window/Contents/VBoxContainer/HeaderContainer
@onready var entries_container: VBoxContainer = $Window/Contents/VBoxContainer/ScrollContainer/EntriesContainer

@onready var prev_button: Button = $Window/Contents/VBoxContainer/Pagination/PrevButton
@onready var next_button: Button = $Window/Contents/VBoxContainer/Pagination/NextButton
@onready var page_label: Label = $Window/Contents/VBoxContainer/Pagination/PageLabel

const PAGE_LIMIT: int = 20
var current_page: int = 1

var current_key: String = "best_level"
var profile_data: Array = []
var local_name: String = ""
var cached_data: Dictionary = {}

var http_request: HTTPRequest
var api_url: String = "" # disabled

var loading_timer: Timer
var loading_dots: int = 0

func _ready() -> void:

	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)

	loading_timer = Timer.new()
	loading_timer.wait_time = 0.4
	loading_timer.timeout.connect(_on_loading_timer_timeout)
	add_child(loading_timer)

	_load_local_name()
	_build_tabs()
	_build_header()
	_fetch_leaderboard(current_key)

func _load_local_name() -> void:
	if PlayerStats and typeof(PlayerStats.slot) == TYPE_INT:
		var paths = [
			SAVE_DIR + "save_%d.tres" % PlayerStats.slot,
			SAVE_DIR + "leaderboard_%d.tres" % PlayerStats.slot,
		]
		for path in paths:
			if FileAccess.file_exists(path):
				var data = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
				if data and "profile_name" in data:
					local_name = data.profile_name
					break

func _build_header() -> void:
	header_container.add_child(_make_cell("RANK",  COL_RANK,  C_ACCENT, FONT_SIZE - 2))
	header_container.add_child(_make_cell("NAME",  COL_NAME,  C_ACCENT, FONT_SIZE - 2))
	header_container.add_child(_make_cell("VALUE", COL_VALUE, C_ACCENT, FONT_SIZE - 2,
			HORIZONTAL_ALIGNMENT_RIGHT))

func _build_tabs() -> void:
	tab_bar.add_theme_font_override("font", ALEGREYA_FONT)
	tab_bar.add_theme_font_size_override("font_size", 14)
	
	# Duplicate default Godot styles to perfectly match Settings, but reduce horizontal padding to fit
	var selected_style = tab_bar.get_theme_stylebox("tab_selected").duplicate()
	selected_style.content_margin_left = 6
	selected_style.content_margin_right = 6
	
	var unselected_style = tab_bar.get_theme_stylebox("tab_unselected").duplicate()
	unselected_style.content_margin_left = 6
	unselected_style.content_margin_right = 6
	
	tab_bar.add_theme_stylebox_override("tab_selected", selected_style)
	tab_bar.add_theme_stylebox_override("tab_unselected", unselected_style)
	tab_bar.add_theme_stylebox_override("tab_hovered", unselected_style)
	
	for category in STAT_CATEGORIES:
		tab_bar.add_tab(category["label"])
	
	tab_bar.tab_selected.connect(_on_tab_selected)
	
	var current_index = 0
	for i in range(STAT_CATEGORIES.size()):
		if STAT_CATEGORIES[i]["key"] == current_key:
			current_index = i
			break
	tab_bar.current_tab = current_index

func _on_tab_selected(index: int) -> void:
	var key = STAT_CATEGORIES[index]["key"]
	if current_key == key and current_page == 1 and not profile_data.is_empty():
		return
	current_page = 1
	_fetch_leaderboard(key)

func _fetch_leaderboard(key: String) -> void:
	current_key = key
	var cache_key = key + "_" + str(current_page)
	if cached_data.has(cache_key):
		profile_data = cached_data[cache_key]
		_show_leaderboard()
		return

	_show_loading_state(key)
	
	# Assuming backend supports page & limit or will just ignore it
	var url = api_url + "?category=" + key + "&page=" + str(current_page) + "&limit=" + str(PAGE_LIMIT)
	http_request.cancel_request()
	var error = http_request.request(url)
	if error != OK:
		_show_error_state("Failed to create HTTP request.")

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_show_error_state("Connection error.")
		return
		
	if response_code != 200:
		_show_error_state("Server error (Code: %d)" % response_code)
		return
		
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	if parse_result == OK:
		var response = json.data
		if typeof(response) == TYPE_ARRAY:
			profile_data = response
			var cache_key = current_key + "_" + str(current_page)
			cached_data[cache_key] = response
			_show_leaderboard()
		elif typeof(response) == TYPE_DICTIONARY and response.has("error"):
			_show_error_state(response["error"])
		else:
			_show_error_state("Invalid data format received.")
	else:
		_show_error_state("Failed to parse server response.")

func _add_separator(color: Color = C_DIVIDER) -> void:
	var sep := ColorRect.new()
	sep.color = color
	sep.custom_minimum_size = Vector2(0, 1)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_container.add_child(sep)

func _make_cell(text: String, min_w: int, color: Color, size: int,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = min_w
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_font_override("font", ALEGREYA_FONT)
	lbl.horizontal_alignment = align
	return lbl

func _show_loading_state(key: String) -> void:
	for child in entries_container.get_children():
		child.queue_free()
		
	var lbl := Label.new()
	lbl.name = "LoadingLabel"
	lbl.text = "Fetching souls..."
	lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	lbl.add_theme_font_override("font", ALEGREYA_FONT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entries_container.add_child(lbl)
	
	loading_dots = 0
	loading_timer.start()

func _show_error_state(msg: String) -> void:
	loading_timer.stop()
	for child in entries_container.get_children():
		child.queue_free()
		
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	lbl.add_theme_font_override("font", ALEGREYA_FONT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entries_container.add_child(lbl)

func _show_leaderboard() -> void:
	loading_timer.stop()
	for child in entries_container.get_children():
		child.queue_free()
	
	page_label.text = "Page " + str(current_page)
	prev_button.disabled = (current_page <= 1)

	if profile_data.is_empty():
		var lbl := Label.new()
		lbl.text = "No souls found."
		lbl.add_theme_color_override("font_color", C_TEXT_DIM)
		lbl.add_theme_font_override("font", ALEGREYA_FONT)
		entries_container.add_child(lbl)
		next_button.disabled = true
		return

	# Data is already sorted by the SQL query
	var sorted := profile_data
	next_button.disabled = (sorted.size() < PAGE_LIMIT)

	var medals: Array[String] = ["🥇", "🥈", "🥉"]

	for i in range(sorted.size()):
		var profile = sorted[i]
		var val: float = float(profile.get(current_key, 0))
		var profile_name: String = profile.get("name", "Unknown")
		var is_active: bool = (profile_name == local_name and local_name != "")

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.custom_minimum_size.y = ROW_HEIGHT
		
		var global_rank = (current_page - 1) * PAGE_LIMIT + i + 1
		var rank_text: String = medals[global_rank - 1] if global_rank <= 3 else "#%d" % global_rank
		row.add_child(_make_cell(rank_text, COL_RANK, C_TEXT, FONT_SIZE))

		var display_name: String = profile_name
		var name_color: Color = C_ACCENT if is_active else C_TEXT
		row.add_child(_make_cell(display_name, COL_NAME, name_color, FONT_SIZE))

		row.add_child(_make_cell(_format_value(val, current_key), COL_VALUE,
				C_VALUE, FONT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT))

		entries_container.add_child(row)
		if i < sorted.size() - 1:
			_add_separator()

func _format_value(value: float, key: String = "") -> String:
	if key == "best_speedrun_time":
		if value <= 0.0:
			return "--:--"
		var mins = int(value) / 60
		var secs = int(value) % 60
		var ms = int((value - int(value)) * 100)
		return "%02d:%02d.%02d" % [mins, secs, ms]
	if value == int(value):
		return str(int(value))
	return "%.1f" % value

func _on_close_button_pressed() -> void:
	queue_free()

func _on_prev_button_pressed() -> void:
	if current_page > 1:
		current_page -= 1
		_fetch_leaderboard(current_key)

func _on_next_button_pressed() -> void:
	if profile_data.size() == PAGE_LIMIT:
		current_page += 1
		_fetch_leaderboard(current_key)

func _on_loading_timer_timeout() -> void:
	loading_dots = (loading_dots + 1) % 4
	var texts = ["Fetching souls", "Fetching souls.", "Fetching souls..", "Fetching souls..."]
	if entries_container.has_node("LoadingLabel"):
		entries_container.get_node("LoadingLabel").text = texts[loading_dots]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		_on_close_button_pressed()
		get_viewport().set_input_as_handled()
