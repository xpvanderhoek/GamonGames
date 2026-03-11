extends Node
class_name State

func enter():
	pass

func exit():
	pass

func process_input(input:InputEvent) -> State:
	return null

func process_frame(delta: float) -> State:
	return null

func process_physics(delta: float) -> State:
	return null

func update_sprite_direction() -> void:
	
