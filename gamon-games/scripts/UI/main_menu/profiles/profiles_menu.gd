extends Control
@export var title : String = "Profiles"

@onready var slot_1: Button = %Slot1
@onready var slot_2: Button = %Slot2
@onready var slot_3: Button = %Slot3
@onready var button: Button = $Button

func _ready() -> void:
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	$TitleLabel.text = title

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("escape"):
		queue_free()

func _on_profile_selected():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	queue_free()

func _on_back_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	await tween.finished
	queue_free()
