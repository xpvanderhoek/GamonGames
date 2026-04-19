class_name Interactable
extends Node2D

@onready var interactable_area: Area2D = $InteractableArea
@onready var interaction_label: Label = $InteractionLabel

@export var prompt_text : String = "Interact"

var is_busy : bool = false

func _ready() -> void:
	assert(interactable_area != null, name + " is missing an 'InteractableArea' Area2D node!!!")
	assert(interaction_label != null, name + " is missing an 'InteractionLabel' Label node!!!")
	interaction_label.text = prompt_text.to_upper()
	interaction_label.visible = false
	interactable_area.mouse_entered.connect(_on_mouse_hovered)
	interactable_area.mouse_exited.connect(_on_mouse_exit)
	interactable_area.input_event.connect(_on_input_event)

func _on_mouse_hovered():
	if !is_busy:
		interaction_label.visible = true

func _on_mouse_exit():
	interaction_label.visible = false

func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			interaction_label.visible = false
			interact()

func interact(): 
	push_error("interact() not implemented in: " + name)
	return
