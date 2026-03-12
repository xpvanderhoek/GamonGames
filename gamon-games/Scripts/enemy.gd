extends CharacterBody2D
class_name Enemy

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

const SPEED = 100.0

var last_direction: Vector2 = Vector2.DOWN

func _physics_process(delta: float) -> void:
	AnimationManager.process_animation(animated_sprite_2d, velocity, last_direction)
	move_and_slide()

func navigate_to(target_position: Vector2) -> void:
	nav_agent.target_position = target_position

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var next_pos := nav_agent.get_next_path_position()
	var direction := (next_pos - global_position).normalized()
	velocity = direction * SPEED
	last_direction = direction

func stop() -> void:
	velocity = Vector2.ZERO
