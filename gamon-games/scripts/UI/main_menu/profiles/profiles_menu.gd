extends Control
@export var title : String = "Profiles"

@onready var slot_1: Button = %Slot1
@onready var slot_2: Button = %Slot2
@onready var slot_3: Button = %Slot3

func _ready() -> void:
	$TitleLabel.text = title

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("escape"):
		queue_free()

func _on_profile_selected():
	queue_free()
