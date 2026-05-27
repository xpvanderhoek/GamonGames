class_name VolumeSlider
extends HSlider

@export var bus_name : String

signal done_sliding(slider : VolumeSlider, value_changed : bool)

var bus_index : int
var bus_percentage : int

func _ready() -> void:
	bus_index = AudioServer.get_bus_index(bus_name)
	value_changed.connect(_on_value_changed)
	
	value = db_to_linear(
		AudioServer.get_bus_volume_db(bus_index)
	)

func _on_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(value)
	)
	
	bus_percentage = value * 100

func _on_drag_ended(value_changed: bool) -> void:
	done_sliding.emit(self, value_changed)
