extends Node


func process_animation(
	sprite: AnimatedSprite2D, velocity: Vector2, last_direction: Vector2
) -> void:
	if velocity != Vector2.ZERO:
		play_animation(sprite, "Walk", last_direction)
	else:
		play_animation(sprite, "Idle", last_direction)


func play_animation(sprite: AnimatedSprite2D, prefix: String, dir: Vector2) -> void:
	if dir.x > 0:
		sprite.play(prefix + "_right")
	elif dir.x < 0:
		sprite.play(prefix + "_left")
	elif dir.y < 0:
		sprite.play(prefix + "_up")
	elif dir.y > 0:
		sprite.play(prefix + "_down")
