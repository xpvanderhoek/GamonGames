extends Node

@onready var requirements_label : Label = $RequirementsLabel
@onready var lock_image : Sprite2D = $Lock

var enemy_requirement : int
var locked : bool
var fallen_enemy_count : int

func _ready() -> void:
	fallen_enemy_count = 0
	locked = true
	enemy_requirement = randi_range(1, 4) # Placeholder for until after enemies are added
	requirements_label.text = "Requirement: " + str (enemy_requirement) + " enemies"

func interact():
	NavigationManager.go_to_random_room(NavigationManager.current_room_path)

func _on_body_entered(body: Node2D) -> void:
	if body is Character:
		body = body as Character
		if locked:
			_set_fallen_enemy_count(fallen_enemy_count + 1) # Placeholder for until after enemies are added.
			if locked: # Check if _set_fallen_enemy_count unlocked the door 
				return
		
		body.current_interactable = self
		body.show_interaction_label("Enter")
	else:
		return

func _on_body_exited(body: Node2D):
	if body is Character:
		body = body as Character
		
		body.current_interactable = null
		body.hide_interaction_label()

func _set_fallen_enemy_count(value : int):
	fallen_enemy_count = value
	var enemies_left : int = enemy_requirement - fallen_enemy_count
	if enemy_requirement == fallen_enemy_count:
		locked = false
		lock_image.visible = false
		requirements_label.visible = false
	else:
		requirements_label.text = "Requirement: " + str (enemies_left) + " enemies"
