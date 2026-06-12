extends Node

const SAVE_PATH = "user://settings.tres"
var data: SettingsData
var last_settings_tab: int = 0

signal font_settings_changed
signal keybinds_changed

const FONT_FAMILIES: Array = [
	["Alegreya Sans","res://assets/fonts/AlegreyaSans-Bold.ttf", "res://assets/fonts/AlegreyaSans-Medium.ttf"],
	["Atkinson Hyperlegible", "res://assets/fonts/AtkinsonHyperlegible-Bold.ttf", "res://assets/fonts/AtkinsonHyperlegible-Regular.ttf"],
	["Comic Neue", "res://assets/fonts/ComicNeue-Bold.ttf","res://assets/fonts/ComicNeue-Regular.ttf"],
	["Andika", "res://assets/fonts/Andika-Bold.ttf", "res://assets/fonts/Andika-Regular.ttf"],
	["Roboto", "res://assets/fonts/Roboto-Bold.ttf", "res://assets/fonts/Roboto-Regular.ttf"],
]

const FONT_NAMES: Array[String] = [
	"Alegreya Sans",
	"Atkinson Hyperlegible",
	"Comic Neue",
	"Andika",
	"Roboto",
]

const _CAESAR_PATH  := "res://assets/fonts/CaesarDressing-Regular.ttf"
const _BOLD_MARKER  := "Bold"
const _MEDIUM_MARKER := "Medium"

func _ready():
	load_settings()
	get_tree().node_added.connect(_on_node_added)
	apply_settings()

func _on_node_added(node: Node) -> void:
	_apply_to_node(node)

func load_settings():
	if ResourceLoader.exists(SAVE_PATH):
		data = ResourceLoader.load(SAVE_PATH)
	else:
		data = SettingsData.new()  # first launch, use defaults

func apply_settings():
	# Video
	print(data.window_mode)
	print(data.resolution)
	DisplayServer.window_set_mode(data.window_mode)
	DisplayServer.window_set_size(data.resolution)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = data.fps_limit

	if ColorblindFilter.has_method("set_mode"):
		ColorblindFilter.set_mode(data.colorblind_mode)

	# Audio
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(data.master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(data.sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(data.music_volume))

	# Accessibility
	apply_font_settings()

func apply_font_settings() -> void:
	if get_tree() != null:
		_traverse(get_tree().root)
	font_settings_changed.emit()


func _traverse(node: Node) -> void:
	_apply_to_node(node)
	for child in node.get_children():
		_traverse(child)

func _apply_to_node(node: Node) -> void:
	if node is Label:
		var n := node as Label
		if not n.has_meta(&"_orig_font"):
			n.set_meta(&"_orig_font", n.get_theme_font("font"))

		var orig_font: Variant = n.get_meta(&"_orig_font")
		if _is_titleFont(orig_font):
			return

		n.add_theme_font_override("font", _pick_font(orig_font))

	elif node is RichTextLabel:
		var n := node as RichTextLabel
		if not n.has_meta(&"_orig_font"):
			n.set_meta(&"_orig_font", n.get_theme_font("normal_font"))

		var orig_font: Variant = n.get_meta(&"_orig_font")
		var bold_font   := get_bold_font()
		var medium_font := get_medium_font()
		n.add_theme_font_override("normal_font",  medium_font)
		n.add_theme_font_override("bold_font",    bold_font)
		n.add_theme_font_override("italics_font", medium_font)

	elif node is Button:
		var n := node as Button
		if not n.has_meta(&"_orig_font"):
			n.set_meta(&"_orig_font", n.get_theme_font("font"))

		var orig_font: Variant = n.get_meta(&"_orig_font")
		if _is_titleFont(orig_font):
			return

		n.add_theme_font_override("font", _pick_font(orig_font))

func _pick_font(orig_font: Variant) -> FontFile:
	if orig_font is FontFile:
		var path: String = (orig_font as FontFile).resource_path
		if _MEDIUM_MARKER in path:
			return get_medium_font()
	return get_bold_font()

func _is_titleFont(font: Variant) -> bool:
	if font is FontFile:
		return (font as FontFile).resource_path == _CAESAR_PATH
	return false

func get_bold_font() -> FontFile:
	var idx: int = clamp(data.font_index, 0, FONT_FAMILIES.size() - 1)
	return load(FONT_FAMILIES[idx][1] as String) as FontFile

func get_medium_font() -> FontFile:
	var idx: int = clamp(data.font_index, 0, FONT_FAMILIES.size() - 1)
	return load(FONT_FAMILIES[idx][2] as String) as FontFile

func save_settings():
	ResourceSaver.save(data, SAVE_PATH)
