extends Node

const SAVE_PATH = "user://settings.tres"
var data: SettingsData

func _ready():
	load_settings()
	apply_settings()

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

	# Audio
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(data.master_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(data.sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(data.music_volume))

func save_settings():
	ResourceSaver.save(data, SAVE_PATH)
