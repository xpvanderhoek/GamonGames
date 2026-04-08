extends Room

@onready var portal : Interactable = $Doors/Door
@onready var ghost : Interactable = $Ghost

func _ready() -> void:
	if !PlayerStats.knows_ghost:
		portal.visible = false
	_unlock_all_doors()

func _on_ghost_open_portal() -> void:
	portal.visible = true
