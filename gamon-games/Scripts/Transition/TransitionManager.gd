extends Node

var transition_layer: CanvasLayer = null

enum TransitionType {
	FADE = 0,
	SLIDE = 1,
	WIPE = 2
}

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
	
	var transition_scene = load(transition_paths[transition_type])
	transition_layer = transition_scene.instantiate()
	get_tree().root.add_child(transition_layer)


func change_scene(scene_path: String, transition_type: int = TransitionType.FADE) -> void:
	_setup_transition(transition_type)
	await get_tree().process_frame
	
	await transition_layer.fade_in()
	get_tree().change_scene_to_file(scene_path)
	await transition_layer.fade_out()
