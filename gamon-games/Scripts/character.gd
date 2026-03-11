extends CharacterBody2D
class_name Character


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var last_direction: Vector2

@export var combat_screen: CanvasLayer
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	process_movement()
	AnimationManager.process_animation(animated_sprite_2d, velocity, last_direction)
	move_and_slide()

func process_movement() -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		last_direction = direction
	else:
		velocity = Vector2.ZERO


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		combat_screen.visible = true
		get_tree().paused = true
