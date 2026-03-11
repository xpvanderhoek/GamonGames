class_name Character
extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var last_direction: Vector2

var current_interactable = null

@export var combat_screen: CanvasLayer
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_label : Label = $Camera2D/InteractionLabel

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"): # I'll change this to E when I work on InputMap
		if current_interactable != null:
			current_interactable.interact()

func show_interaction_label(text : String):
	interaction_label.visible = true
	interaction_label.text = text

func hide_interaction_label():
	interaction_label.visible = false
	interaction_label.text = ""

func _physics_process(delta: float) -> void:
	process_movement()
	process_animation()
	move_and_slide()

func process_movement() -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		last_direction = direction
	else:
		velocity = Vector2.ZERO

func process_animation() -> void:
	if velocity != Vector2.ZERO:
		play_animation("Walk", last_direction)
	else:
		play_animation("Idle", last_direction)

func play_animation (prefix: String, dir: Vector2) -> void:
	if dir.x > 0:
		animated_sprite_2d.play(prefix + "_right")
	elif dir.x < 0:
		animated_sprite_2d.play(prefix + "_left")
	elif dir.y < 0:
		animated_sprite_2d.play(prefix + "_up")
	elif dir.y > 0:
		animated_sprite_2d.play(prefix + "_down")
		
	


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		combat_screen.visible = true
		get_tree().paused = true
