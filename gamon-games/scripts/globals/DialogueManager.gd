extends Node

var dialogue_data: Dictionary = {}
var dialogue_ui: Node = null
var pending_dialogue_key = null

signal dialogue_finished

const DIALOGUE_JSON_PATH := "res://data/dialogue.json"
const DIALOGUE_UI_SCENE := "res://scenes/UI/dialogueUI.tscn"

func _ready() -> void:
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
		get_tree().root.call_deferred("add_child", ui_instance)
	else:
		push_error("Failed to load DialogueUI scene")

func register_ui(ui: Node) -> void:
	dialogue_ui = ui
	if pending_dialogue_key != null:
		start_dialogue(pending_dialogue_key)
		pending_dialogue_key = null

func start_dialogue(key: String) -> void:
	if dialogue_ui == null:
		pending_dialogue_key = key
		return

	if not dialogue_data.has(key):
		push_error("Dialogue key not found: %s" % key)
		return

	dialogue_ui.show()
	await dialogue_ui.start_dialogue(dialogue_data[key])
	dialogue_finished.emit()

func has_dialogue(key: String) -> bool:
	return dialogue_data.has(key)
