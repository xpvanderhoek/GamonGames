extends Node

@export var test_scene_path: String = "res://Scenes/Transition/TransitionTest.tscn"


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_select"):  # Space
		TransitionManager.change_scene(test_scene_path, TransitionManager.TransitionType.FADE)
	
	if Input.is_key_pressed(KEY_T):
		# Fade transition
		TransitionManager.change_scene(test_scene_path, TransitionManager.TransitionType.FADE)
	
	if Input.is_key_pressed(KEY_Y):
		# Slide transition
		TransitionManager.change_scene(test_scene_path, TransitionManager.TransitionType.SLIDE)
	
	if Input.is_key_pressed(KEY_U):
		# Wipe transition
		TransitionManager.change_scene(test_scene_path, TransitionManager.TransitionType.WIPE)

