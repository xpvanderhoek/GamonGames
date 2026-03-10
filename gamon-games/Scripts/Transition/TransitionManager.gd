extends Node

# GUIDE FOR THE STUPID AH TRANSITIONS!!!!!
# Just use them whenever your changing from one scene to another, and they will handle the rest. 
# You can choose between fade, slide, or wipe transitions.
#
# Usage:
#   TransitionManager.change_scene("res://Scenes/your_scene.tscn", TransitionManager.TransitionType.FADE)
#   TransitionManager.change_scene("res://Scenes/your_scene.tscn", TransitionManager.TransitionType.SLIDE)
#   TransitionManager.change_scene("res://Scenes/your_scene.tscn", TransitionManager.TransitionType.WIPE)
#
# Transition Types:
#   FADE  - Fade to black
#   SLIDE - Slide in/out
#   WIPE  - Wipe effect


var transition_layer: CanvasLayer = null

enum TransitionType {
	FADE = 0,
	SLIDE = 1,
	WIPE = 2
}

## Paths to transition scenes
var transition_paths = {
	TransitionType.FADE: "res://Scenes/Transition/FadeTransition.tscn",
	TransitionType.SLIDE: "res://Scenes/Transition/SlideTransition.tscn",
	TransitionType.WIPE: "res://Scenes/Transition/WipeTransition.tscn"
}


func _ready() -> void:
	_setup_transition(TransitionType.FADE)

func _setup_transition(transition_type: int = TransitionType.FADE) -> void:
	if transition_layer:
		transition_layer.queue_free()

	var transition_scene_resource = load(transition_paths[transition_type])
	var new_transition_layer = transition_scene_resource.instantiate()

	get_tree().root.add_child(new_transition_layer)
	transition_layer = new_transition_layer

func change_scene(scene_path: String, transition_type: int = TransitionType.FADE) -> void:
	_setup_transition(transition_type)
	await get_tree().process_frame
	await transition_layer.fade_in()
	get_tree().change_scene_to_file(scene_path)
	await transition_layer.fade_out()
