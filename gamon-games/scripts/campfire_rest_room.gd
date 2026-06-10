extends Control
@onready var description_label: Label = $CanvasLayer/Window/DescriptionLabel
@onready var window: Control = $CanvasLayer/Window
@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var healed_up_label: Label = $CanvasLayer/HealedUpLabel
@onready var train_button: Button = $CanvasLayer/Window/HBoxContainer/TrainButton
@onready var rest_button: Button = $CanvasLayer/Window/HBoxContainer/RestButton

const UPGRADE_SCREEN = preload("res://scenes/UI/upgrade_screen.tscn")
const PAUSE_MENU := preload("res://scenes/UI/main_menu/settings/settings_menu.tscn")

func _ready() -> void:
	if !RunData.run_active:
		TransitionManager.change_scene("res://scenes/UI/main_menu/main_menu.tscn")
	
	description_label.hide()
	healed_up_label.modulate = Color(1.0, 1.0, 1.0, 0.0)

func _input(event):
	if event.is_action_pressed("escape"):
		canvas_layer.add_child(PAUSE_MENU.instantiate())

func _on_rest_button_mouse_entered() -> void:
	SoundManager.play_hover()
	var current_hp : int = RunData.current_health
	var max_hp : int = RunData.max_health
	var heal_mult : float = 0.3
	var new_hp : int = current_hp + (max_hp * heal_mult)
	if new_hp > max_hp:
		new_hp = max_hp
	description_label.text = "Rest: Heal 30% of Max HP\n (" + str(current_hp) + "HP -> " + str(new_hp) + "HP) "
	description_label.show()

func _on_button_mouse_exited() -> void:
	description_label.hide()

func _on_train_button_mouse_entered() -> void:
	SoundManager.play_hover()
	description_label.text = "Train: Upgrade 1 of 3 base stats"
	description_label.show()

func _on_rest_button_pressed() -> void:
	SoundManager.play_click()
	rest_button.disabled = true
	train_button.disabled = true
	animation_player.play("HealedUpAnimation")
	fade_out()
	var current_hp : int = RunData.current_health
	var max_hp : int = RunData.max_health
	var heal_mult : float = 0.3
	var new_hp : int = current_hp + (max_hp * heal_mult)
	if new_hp > max_hp:
		new_hp = max_hp
	RunData.current_health = new_hp
	await get_tree().create_timer(1.5).timeout
	TransitionManager.change_scene("res://scenes/map/map.tscn")

func _on_train_button_pressed() -> void:
	SoundManager.play_click()
	rest_button.disabled = true
	train_button.disabled = true
	fade_out()
	
	var upgrade_screen = preload("res://scenes/combat/ui/combat_summary.tscn").instantiate()
	canvas_layer.add_child(upgrade_screen)
	upgrade_screen.setup_campfire_training()
	await upgrade_screen.continue_pressed
	upgrade_screen.queue_free()
	
	TransitionManager.change_scene("res://scenes/map/map.tscn")
	

func fade_out() -> void:
	var fade_duration: float = 1 
	var _tween = create_tween()

	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_SINE)
	
	modulate.a = 1.0
	_tween.tween_property(window, "modulate:a", 0.0, fade_duration)
	_tween.tween_callback(window.queue_free)
