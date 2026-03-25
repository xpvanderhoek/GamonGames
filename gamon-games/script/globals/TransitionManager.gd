extends Node

# Transition usage
# TRANSITIONS - Just use change_scene() with a scene path and transition type (FADE, SLIDE, WIPE)
# Example: TransitionManager.change_scene("res://scene/your_scene.tscn", TransitionManager.TransitionType.FADE)

var _game_node: Node = null
var transition_layer: CanvasLayer = null

func _get_game() -> Node:
	if _game_node and is_instance_valid(_game_node):
		return _game_node
	_game_node = get_tree().current_scene
	return _game_node

enum TransitionType {
	FADE = 0,
	SLIDE = 1,
	WIPE = 2
}

var transition_paths = {
	TransitionType.FADE: "res://scene/Transition/FadeTransition.tscn",
	TransitionType.SLIDE: "res://scene/Transition/SlideTransition.tscn",
	TransitionType.WIPE: "res://scene/Transition/WipeTransition.tscn"
}


func _ready() -> void:
	_setup_transition.call_deferred(TransitionType.FADE)

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

func transition_room(scene_path: String, transition_type: int = TransitionType.FADE) -> void:
	_setup_transition(transition_type)
	print("Transitioning room: " + scene_path)
	await get_tree().process_frame
	await transition_layer.fade_in()
	var game = _get_game()
	if game.has_method("change_room"):
		game.change_room(scene_path)
	await transition_layer.fade_out()

func transition_combat(enter: bool, combat_path: String = "", transition_type: int = TransitionType.FADE, enemy: Node = null) -> void:
	_setup_transition(transition_type)
	await get_tree().process_frame
	await transition_layer.fade_in()
	var game = _get_game()
	if enter and game.has_method("enter_combat"):
		game.enter_combat(combat_path, enemy)
	elif not enter and game.has_method("exit_combat"):
		game.exit_combat(true)
	else:
		push_warning("transition_combat: game scene missing expected method. enter=" + str(enter) + " scene=" + str(game))
	await transition_layer.fade_out()

func exit_combat_deferred() -> void:
	await get_tree().create_timer(0.1).timeout
	await transition_combat(false, "", TransitionType.FADE, null)
