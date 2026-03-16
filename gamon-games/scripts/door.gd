extends Interactable

@onready var requirements_label : Label = $RequirementsLabel
@onready var lock_image : Sprite2D = $Lock

var locked : bool
var designated_room : String

func _ready() -> void:
	super._ready()
	locked = true
	lock_image.visible = true

func get_prompt_text() -> String:
	return "Enter"

func interact():
	NavigationManager.go_to_room(designated_room)

func _on_body_entered(body: Node2D) -> void:
	if body is Character:
		body = body as Character
		if locked:
			return
		body.current_interactable = self
		body.show_interaction_label(get_prompt_text())
	else:
		return
