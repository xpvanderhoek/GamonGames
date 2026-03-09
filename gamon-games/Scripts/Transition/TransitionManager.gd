extends Node

var transition_layer: CanvasLayer = null


func _ready() -> void:
	_setup_transition()


func _setup_transition() -> void:
	if not transition_layer:
		var transition_scene = load("res://Scenes/Transition/Transition.tscn")
		transition_layer = transition_scene.instantiate()
		get_tree().root.add_child.call_deferred(transition_layer)


func change_scene(scene_path: String) -> void:
	_setup_transition()
	
	await transition_layer.fade_in()
	get_tree().change_scene_to_file(scene_path)
	await transition_layer.fade_out()
