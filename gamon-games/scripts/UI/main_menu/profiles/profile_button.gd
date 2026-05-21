extends Button

@export var slot_nr = 0
var has_profile : bool = false

signal profile_selected

@onready var enter_name: LineEdit = $EnterName

func _ready() -> void:
	var name = SaveLoad.get_profile_name(slot_nr)
	if name != "":
		text = str(slot_nr) + ". " + name
		has_profile = true
	else:
		text = str(slot_nr) + ". Empty"
		has_profile = false

func _on_pressed() -> void:
	if has_profile:
		SaveLoad.switch_profile(slot_nr)
		profile_selected.emit()
	else:
		_create_profile()

func _create_profile() -> void:
	enter_name.visible = true
	
	var name
	await enter_name.text_submitted
	name = enter_name.text
	text = str(slot_nr) + ". " + name
	SaveLoad.create_profile(slot_nr, name)
	has_profile = true
	
	enter_name.visible = false
	profile_selected.emit()
