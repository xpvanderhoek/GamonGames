class_name SettingsData
extends Resource

# Graphics
@export var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
@export var resolution: Vector2i = Vector2i(1280, 720)
@export var vsync: bool = true
@export var fps_limit: int = 0

# Sound
@export var master_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var music_volume: float = 1.0

# Accessibility
@export var colorblind_mode: int = 0
@export var font_index: int = 0
@export var show_speedrun_timer: bool = false

# Keybinds
@export var spell_keybinds: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]