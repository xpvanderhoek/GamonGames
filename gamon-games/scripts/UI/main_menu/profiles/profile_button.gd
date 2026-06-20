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
		
	# Setup signals for mobile/keyboard input handling without await
	enter_name.text_submitted.connect(func(t): _on_name_submitted(t, false))
	enter_name.focus_exited.connect(_on_name_focus_exited)
	
	delete_confirm.text_submitted.connect(func(t): _on_delete_submitted(t, false))
	delete_confirm.focus_exited.connect(_on_delete_focus_exited)

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
	enter_name.text = ""
	enter_name.placeholder_text = "Enter Name"
	enter_name.visible = true
	enter_name.call_deferred("grab_focus")

func _on_name_focus_exited() -> void:
	if enter_name.visible:
		if enter_name.text.strip_edges() != "":
			_on_name_submitted(enter_name.text, true)
		else:
			if not (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
				enter_name.visible = false

func _on_name_submitted(new_name: String, from_focus_loss: bool) -> void:
	if not enter_name.visible:
		return
		
	if not from_focus_loss:
		SoundManager.play_click()
		
	if _is_name_valid(new_name):
		text = str(slot_nr) + ". " + new_name
		SaveLoad.create_profile(slot_nr, new_name)
		has_profile = true
		enter_name.visible = false
		profile_selected.emit()
	else:
		if from_focus_loss:
			enter_name.visible = false
		else:
			enter_name.text = ""
			enter_name.placeholder_text = "Invalid name!"

func _is_name_valid(name: String) -> bool:
	if name.length() < 3 or name.length() > 14:
		return false
		
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9 ]+$")
	if regex.search(name) == null:
		return false
		
	var clean_name = name.to_lower().strip_edges()
	var words = clean_name.split(" ", false)
	
	var invalid_tags = ["admin", "moderator", "system"]
	for tag in invalid_tags:
		if clean_name.find(tag) != -1:
			return false
			
	var exact_blocked = ["shit", "fuck", "bitch"]
	for word in words:
		if word in exact_blocked:
			return false
		if word.length() == 1:
			return false
			
	return true


func _on_delete_pressed() -> void:
	if !has_profile:
		return
	SoundManager.play_click()
	delete_confirm.clear()
	delete_confirm.placeholder_text = "Type 'delete'"
	delete_confirm.visible = true
	delete_confirm.call_deferred("grab_focus")

func _on_delete_focus_exited() -> void:
	if delete_confirm.visible:
		if delete_confirm.text.strip_edges() != "":
			_on_delete_submitted(delete_confirm.text, true)
		else:
			if not (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")):
				delete_confirm.visible = false

func _on_delete_submitted(delete_text: String, from_focus_loss: bool) -> void:
	if not delete_confirm.visible:
		return
		
	if not from_focus_loss:
		SoundManager.play_click()
		
	if delete_text.to_lower() == "delete":
		SaveLoad.delete_save(slot_nr)
		profile_deleted.emit(slot_nr)
		text = str(slot_nr) + ". Empty"
		has_profile = false
		delete.visible = false
		delete_confirm.visible = false
	else:
		if from_focus_loss:
			delete_confirm.visible = false
		else:
			delete_confirm.text = ""
			delete_confirm.placeholder_text = "Type 'delete'"
