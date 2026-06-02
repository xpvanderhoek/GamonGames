extends Button

@export var slot_nr = 0
var has_profile : bool = false

signal profile_selected
signal profile_deleted(slot_nr : int)

@onready var enter_name: LineEdit = $EnterName
@onready var delete: Button = $Delete
@onready var delete_confirm: LineEdit = $DeleteConfirm

func _ready() -> void:
	var name = SaveLoad.get_profile_name(slot_nr)
	if name != "":
		text = str(slot_nr) + ". " + name
		has_profile = true
	else:
		text = str(slot_nr) + ". Empty"
		has_profile = false
	
	if !has_profile || PlayerStats.slot == slot_nr:
		delete.hide()
	
	if PlayerStats.slot == slot_nr:
		add_theme_color_override("font_color", Color("fac54bff"))

func _on_hovered():
	SoundManager.play_hover()

func _on_pressed() -> void:
	if has_profile:
		SaveLoad.switch_profile(slot_nr)
		profile_selected.emit()
	else:
		_create_profile()
	
	SoundManager.play_click()

func _create_profile() -> void:
	enter_name.visible = true
	enter_name.grab_focus()
	
	var name
	await enter_name.text_submitted
	SoundManager.play_click()
	name = enter_name.text
	text = str(slot_nr) + ". " + name
	SaveLoad.create_profile(slot_nr, name)
	has_profile = true
	
	enter_name.visible = false
	profile_selected.emit()


func _on_delete_pressed() -> void:
	if !has_profile:
		return
	SoundManager.play_click()
	delete_confirm.clear()
	var delete_text
	delete_confirm.visible = true
	await delete_confirm.text_submitted
	SoundManager.play_click()
	delete_text = delete_confirm.text
	if delete_text.to_lower() == "delete":
		SaveLoad.delete_save(slot_nr)
		profile_deleted.emit(slot_nr)
		text = str(slot_nr) + ". Empty"
		has_profile = false
		delete.visible = false
	delete_confirm.visible = false
