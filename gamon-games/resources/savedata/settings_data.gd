class_name SettingsData
extends Resource

# Graphics
@export var window_mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
@export var resolution: Vector2i = Vector2i(1280, 720)
@export var vsync: bool = true
@export var colorblind_mode: int = 0

# Sound
@export var master_volume: float = 1.0
@export var sfx_volume: float = 1.0
@export var music_volume: float = 1.0
