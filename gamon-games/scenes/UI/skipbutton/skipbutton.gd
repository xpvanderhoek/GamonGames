extends Control


func _on_button_pressed() -> void:
	TransitionManager.change_scene("res://scenes/map.tscn")
