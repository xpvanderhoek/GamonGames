extends Node2D

@onready var player_detection: Area2D = $PlayerDetection

signal state_changed(new_state)

enum State {
	PATROL,
	ENGAGE,
	IDLE
}

var current_state: int = State.IDLE
var enemy: Enemy
var target: Character = null
var direction: Vector2
var timer := 0.0
var patrol_target: Vector2 = Vector2.ZERO
var patrol_moves_left: int = 0

func _ready() -> void:
	enemy = get_parent() as Enemy

func _process(delta: float) -> void:
	match current_state:
		State.IDLE:
			enemy.stop()
			timer += delta
			if timer > randf_range(2.0, 6.0):
				timer = 0.0
				patrol_moves_left = randi_range(1, 5)
				set_state(State.PATROL)
		State.PATROL:
			if patrol_target == Vector2.ZERO or enemy.nav_agent.is_navigation_finished():
				if patrol_moves_left <= 0:
					set_state(State.IDLE)
				else:
					patrol_moves_left -= 1
					patrol_target = _get_random_patrol_point()
					enemy.navigate_to(patrol_target)
			else:
				enemy.navigate_to(patrol_target)
		State.ENGAGE:
			if target != null:
				enemy.navigate_to(target.global_position)
			else:
				set_state(State.IDLE)
		_:
			print("Error: state doesn't exist")

func _get_random_patrol_point() -> Vector2:
	var random_offset := Vector2(randf_range(-150, 150), randf_range(-150, 150))
	return enemy.global_position + random_offset

func set_state(new_state: int):
	if new_state == current_state:
		return
	
	current_state = new_state
	patrol_target = Vector2.ZERO
	emit_signal("state_changed", current_state)

func _on_player_detection_body_entered(body: Node2D) -> void:
	if body is Character:
		set_state(State.ENGAGE)
		target = body
