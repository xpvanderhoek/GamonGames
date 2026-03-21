class_name Interactable
extends Node

@onready var interactable_area: Area2D = $InteractableArea


func _ready() -> void:
	assert(interactable_area != null, name + " is missing an 'InteractableArea' Area2D node!!!")
	interactable_area.body_entered.connect(_on_body_entered)
	interactable_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D):
	if body is Character:
		body.current_interactable = self
		body.show_interaction_label(get_prompt_text())


func _on_body_exited(body: Node2D):
	if body is Character:
		body.current_interactable = null
		body.hide_interaction_label()


func interact():
	push_error("interact() not implemented in: " + name)
	return


func get_prompt_text() -> String:
	return "Interact"
