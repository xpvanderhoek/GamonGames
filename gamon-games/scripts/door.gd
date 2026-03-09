extends Node

@onready var requirements_label : Label = $RequirementsLabel
@onready var lock_image : Sprite2D = $Lock

var enemy_requirement : int
var locked : bool
var fallen_enemy_count : int

func _ready() -> void:
	fallen_enemy_count = 0
	locked = true
	enemy_requirement = randi_range(1, 4)
	requirements_label.text = "Requirement: " + str (enemy_requirement) + " enemies"

func _on_body_entered(body: Node2D) -> void:
	if locked:
		set_fallen_enemy_count(fallen_enemy_count + 1)
		return
	
	NavigationManager.go_to_random_room()

func set_fallen_enemy_count(value : int):
	fallen_enemy_count = value
	var enemies_left : int = enemy_requirement - fallen_enemy_count
	if enemy_requirement == fallen_enemy_count:
		locked = false
		lock_image.visible = false
		requirements_label.text = "Door Unlocked!"
	else:
		requirements_label.text = "Requirement: " + str (enemies_left) + " enemies"
	
