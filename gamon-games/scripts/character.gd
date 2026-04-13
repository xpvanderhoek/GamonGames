extends CharacterBody2D
class_name Character

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var last_direction: Vector2
var current_interactable = null

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_label : Label = $Camera2D/InteractionLabel
@onready var footstep_player: AudioStreamPlayer2D = $FootstepPlayer

@export var footstep_sounds: Array[AudioStream]
@export var combat_scene_path: String = "res://scenes/combat/combat.tscn"

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if current_interactable != null:
			current_interactable.interact()

func _physics_process(delta: float) -> void:
	if DialogueManager.is_in_dialogue:
		return
	delta = min(delta, 0.1)
	process_movement()
	AnimationManager.process_animation(animated_sprite_2d, velocity, last_direction)
	handle_footsteps()
	move_and_slide()

func process_movement() -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_direction != Vector2.ZERO:
		var speed = RunData.get_stat("speed")

		var isometric_direction = Vector2(
			input_direction.x,
			input_direction.y * 0.60
		)

		velocity = isometric_direction.normalized() * speed
		last_direction = isometric_direction.normalized()
	else:
		velocity = Vector2.ZERO

var last_frame := -1
var on_ground_frames = [5, 15]
func check_footstep_frame(frame: int):
		if frame in on_ground_frames:
			play_footstep()
			
func handle_footsteps():
	if animated_sprite_2d.animation.begins_with("Walk") and velocity.length() > 0:
		var current_frame = animated_sprite_2d.frame
		
		if current_frame != last_frame:
			check_footstep_frame(current_frame)
			last_frame = current_frame
	else:
		last_frame = -1
		
func play_footstep():
	var sound = footstep_sounds.pick_random()
	footstep_player.stream = sound
	footstep_player.pitch_scale = randf_range(0.95, 1.05)
	footstep_player.volume_db = randf_range(-2, 0)
	footstep_player.play()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		var game = get_tree().current_scene
		if game.has_method("enter_combat"):
			TransitionManager.transition_combat(true, combat_scene_path, TransitionManager.TransitionType.FADE, body)
