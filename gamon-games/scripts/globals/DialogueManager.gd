extends Node

var dialogue_data: Dictionary = {}
var dialogue_ui: Node = null
var pending_dialogue_key = null
var is_in_dialogue: bool = false

signal dialogue_finished

const DIALOGUE_JSON_PATH := "res://data/dialogue.json"
const DIALOGUE_UI_SCENE := "res://scenes/UI/dialogueUI.tscn"

func _ready() -> void:
	await get_tree().process_frame
	_load_dialogue_json()
	_spawn_dialogue_ui()

func _load_dialogue_json() -> void:
	if not FileAccess.file_exists(DIALOGUE_JSON_PATH):
		push_error("Dialogue file not found at path: %s" % DIALOGUE_JSON_PATH)
		return

	var file = FileAccess.open(DIALOGUE_JSON_PATH, FileAccess.READ)
	var result = JSON.parse_string(file.get_as_text())
	if result:
		dialogue_data = result
	else:
		push_error("Failed to parse dialogue JSON")

func _spawn_dialogue_ui() -> void:
	var ui_scene_res = preload(DIALOGUE_UI_SCENE)
	if ui_scene_res is PackedScene:
		var ui_instance = ui_scene_res.instantiate()
		get_tree().current_scene.add_child.call_deferred(ui_instance)
	else:
		push_error("Failed to load DialogueUI scene")

func register_ui(ui: Node) -> void:
	dialogue_ui = ui
	if pending_dialogue_key != null:
		start_dialogue(pending_dialogue_key)
		pending_dialogue_key = null

func start_dialogue(data, dialogue_mode := "normal") -> void:
	if dialogue_ui == null:
		pending_dialogue_key = data
		return

	var dialogue_to_play = null

	if data is String:
		if not dialogue_data.has(data):
			push_error("Dialogue key not found: %s" % data)
			return
		dialogue_to_play = dialogue_data[data]

	elif data is Array:
		dialogue_to_play = data

	else:
		push_error("Invalid dialogue data passed")
		return

	is_in_dialogue = true
	dialogue_ui.show()

	if dialogue_mode == "normal":
		await dialogue_ui.start_dialogue(dialogue_to_play, dialogue_mode)
		is_in_dialogue = false
		dialogue_finished.emit()
	else:
		dialogue_ui.start_dialogue(dialogue_to_play, dialogue_mode)
		is_in_dialogue = false


func has_dialogue(key: String) -> bool:
	return dialogue_data.has(key)
