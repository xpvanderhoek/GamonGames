extends Node

@export var test_scene_path: String = "res://Scenes/character.tscn" 
func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_T):
		TransitionManager.change_scene(test_scene_path)

func _ready() -> void:
	pass 
