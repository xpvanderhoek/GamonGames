extends Control

const SAVE_DIR = "user://"

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
const ROW_HEIGHT := 36
const FONT_SIZE := 18

const C_BG         := Color(0.10, 0.09, 0.08, 0.98)
const C_BORDER     := Color(0.38, 0.28, 0.18, 0.70)
const C_BACKDROP   := Color(0.03, 0.03, 0.02, 0.80)
const C_HEADER_BG  := Color(0.15, 0.12, 0.09, 1.0)
const C_ROW_ODD    := Color(0.12, 0.10, 0.08, 1.0)
const C_ROW_EVEN   := Color(0.09, 0.08, 0.06, 1.0)
const C_ROW_ACTIVE := Color(0.18, 0.13, 0.08, 1.0)
const C_DIVIDER    := Color(0.30, 0.22, 0.14, 0.28)
const C_ACCENT     := Color(0.72, 0.58, 0.40, 1.0)
const C_ACCENT_DIM := Color(0.45, 0.34, 0.22, 0.75)
const C_TEXT       := Color(0.85, 0.80, 0.72, 1.0)
const C_TEXT_DIM   := Color(0.45, 0.40, 0.34, 1.0)
const C_VALUE      := Color(0.78, 0.68, 0.52, 1.0)
const C_TAB_BG     := Color(0.13, 0.11, 0.08, 1.0)
const C_TAB_HOVER  := Color(0.20, 0.15, 0.10, 1.0)
const C_TAB_ACTIVE := Color(0.24, 0.17, 0.10, 1.0)

@onready var tab_container: HBoxContainer = $PanelContainer/VBoxContainer/TabBar
@onready var entries_container: VBoxContainer = $PanelContainer/VBoxContainer/ScrollContainer/EntriesContainer
@onready var stat_label: Label = $PanelContainer/VBoxContainer/StatTitle
@onready var panel: PanelContainer = $PanelContainer

var current_key: String = "best_level"
var profile_data: Array = []
var tab_buttons: Array = []
var local_name: String = ""
var cached_data: Dictionary = {}

var http_request: HTTPRequest
var api_url: String = "http://api.visionot.online/client_api/leaderboard.php"

func _make_stylebox(color: Color, pad_h := 12, pad_v := 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.content_margin_left   = pad_h
	s.content_margin_right  = pad_h
	s.content_margin_top    = pad_v
	s.content_margin_bottom = pad_v
	return s

func _make_row_style(color: Color) -> StyleBoxFlat:
	return _make_stylebox(color, 16, 0)

func _ready() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = C_BG
	panel_style.border_width_left   = 1
	panel_style.border_width_right  = 1
	panel_style.border_width_top    = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = C_BORDER
	panel_style.corner_radius_top_left     = 3
	panel_style.corner_radius_top_right    = 3
	panel_style.corner_radius_bottom_left  = 3
	panel_style.corner_radius_bottom_right = 3
	panel_style.content_margin_left   = 24
	panel_style.content_margin_right  = 24
	panel_style.content_margin_top    = 16
	panel_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", panel_style)

	panel.anchor_left   = 0.15
	panel.anchor_top    = 0.08
	panel.anchor_right  = 0.85
	panel.anchor_bottom = 0.92
	panel.offset_left   = 0
	panel.offset_top    = 0
	panel.offset_right  = 0
	panel.offset_bottom = 0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH

	var backdrop := ColorRect.new()
	backdrop.color = C_BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	move_child(backdrop, 0)

	stat_label.add_theme_color_override("font_color", C_TEXT_DIM)
	stat_label.add_theme_font_size_override("font_size", 13)

	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)

	_load_local_name()
	_build_tabs()
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

func _build_tabs() -> void:
	var normal_style := _make_stylebox(C_TAB_BG, 14, 7)
	var hover_style  := _make_stylebox(C_TAB_HOVER, 14, 7)
	var active_style := _make_stylebox(C_TAB_ACTIVE, 14, 7)
	active_style.border_width_bottom = 2
	active_style.border_color = C_ACCENT

	for category in STAT_CATEGORIES:
		var btn := Button.new()
		btn.text = category["label"]
		btn.pressed.connect(_on_tab_pressed.bind(category["key"], btn))
		btn.add_theme_color_override("font_color",       C_TEXT_DIM)
		btn.add_theme_color_override("font_hover_color", C_TEXT)
		btn.add_theme_color_override("font_focus_color", C_TEXT)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_stylebox_override("normal",  normal_style)
		btn.add_theme_stylebox_override("hover",   hover_style)
		btn.add_theme_stylebox_override("pressed", active_style)
		btn.add_theme_stylebox_override("focus",   normal_style)
		btn.set_meta("normal_style", normal_style)
		btn.set_meta("active_style", active_style)
		tab_container.add_child(btn)
		tab_buttons.append(btn)
		
		# Make the initial tab active visually
		if category["key"] == current_key:
			btn.add_theme_stylebox_override("normal", active_style)

func _on_tab_pressed(key: String, pressed_btn: Button) -> void:
	if current_key == key and not profile_data.is_empty():
		return # Already on this tab
		
	for btn in tab_buttons:
		var s: StyleBoxFlat = btn.get_meta("active_style") if btn == pressed_btn \
				else btn.get_meta("normal_style")
		btn.add_theme_stylebox_override("normal", s)
	_fetch_leaderboard(key)

func _fetch_leaderboard(key: String) -> void:
	current_key = key
	if cached_data.has(key):
		profile_data = cached_data[key]
		_show_leaderboard()
		return

	_show_loading_state(key)
	
	var url = api_url + "?category=" + key
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
			cached_data[current_key] = response
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
	lbl.horizontal_alignment = align
	return lbl

func _show_loading_state(key: String) -> void:
	var category: Dictionary = {}
	for c in STAT_CATEGORIES:
		if c["key"] == key:
			category = c
			break

	stat_label.text = category.get("label", key).to_upper()

	for child in entries_container.get_children():
		child.queue_free()
		
	var lbl := Label.new()
	lbl.text = "Fetching souls..."
	lbl.add_theme_color_override("font_color", C_TEXT_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entries_container.add_child(lbl)

func _show_error_state(msg: String) -> void:
	for child in entries_container.get_children():
		child.queue_free()
		
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entries_container.add_child(lbl)

func _show_leaderboard() -> void:
	for child in entries_container.get_children():
		child.queue_free()

	var header_bg := PanelContainer.new()
	header_bg.add_theme_stylebox_override("panel", _make_row_style(C_HEADER_BG))
	header_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 0)
	header_bg.add_child(header_row)
	header_row.add_child(_make_cell("RANK",  COL_RANK,  C_ACCENT, FONT_SIZE - 2))
	header_row.add_child(_make_cell("NAME",  COL_NAME,  C_ACCENT, FONT_SIZE - 2))
	header_row.add_child(_make_cell("VALUE", COL_VALUE, C_ACCENT, FONT_SIZE - 2,
			HORIZONTAL_ALIGNMENT_RIGHT))
	entries_container.add_child(header_bg)
	_add_separator(C_ACCENT_DIM)

	if profile_data.is_empty():
		var lbl := Label.new()
		lbl.text = "No souls found."
		lbl.add_theme_color_override("font_color", C_TEXT_DIM)
		entries_container.add_child(lbl)
		return

	# Data is already sorted by the SQL query
	var sorted := profile_data

	var medals: Array[String] = ["🥇", "🥈", "🥉"]

	for i in range(sorted.size()):
		var profile = sorted[i]
		var val: float = float(profile.get(current_key, 0))
		var profile_name: String = profile.get("name", "Unknown")
		var is_active: bool = (profile_name == local_name and local_name != "")

		var bg_color: Color = C_ROW_ACTIVE if is_active \
				else (C_ROW_ODD if i % 2 == 0 else C_ROW_EVEN)

		var row_bg := PanelContainer.new()
		row_bg.add_theme_stylebox_override("panel", _make_row_style(bg_color))
		row_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.custom_minimum_size.y = ROW_HEIGHT
		row_bg.add_child(row)

		var rank_text: String = medals[i] if i < 3 else "#%d" % (i + 1)
		row.add_child(_make_cell(rank_text, COL_RANK, C_TEXT, FONT_SIZE))

		var display_name: String = profile_name + (" ◀" if is_active else "")
		var name_color: Color = C_ACCENT if is_active else C_TEXT
		row.add_child(_make_cell(display_name, COL_NAME, name_color, FONT_SIZE))

		row.add_child(_make_cell(_format_value(val, current_key), COL_VALUE,
				C_VALUE, FONT_SIZE, HORIZONTAL_ALIGNMENT_RIGHT))

		entries_container.add_child(row_bg)
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
