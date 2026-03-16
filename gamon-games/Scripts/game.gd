extends Node2D

@onready var room_container: Node2D = $RoomContainer
@onready var character: Character = $Character
@onready var level_label: Label = $CanvasLayer/VBoxContainer/LevelLabel
@onready var exp_label: Label = $CanvasLayer/VBoxContainer/ExpLabel


var current_room: Node = null
var combat_node: Node = null
var _combat_enemy: Node = null

func _ready() -> void:
	# Connect to RunData signals to update labels
	RunData.level_changed.connect(_on_level_changed)
	RunData.exp_changed.connect(_on_exp_changed)
	
	# Update labels with current values
	_on_level_changed(RunData.current_level)
	_on_exp_changed(RunData.current_exp)
	
	load_room(NavigationManager.current_room_path)

func load_room(scene_path: String) -> void:
	if current_room:
		room_container.remove_child(current_room)
		current_room.queue_free()
		current_room = null

	var room_scene = load(scene_path)
	current_room = room_scene.instantiate()
	room_container.add_child(current_room)
	current_room.add_to_group("room")

	var spawn = current_room.get_node_or_null("SpawnPoint")
	if spawn:
		character.global_position = spawn.global_position
	else:
		character.global_position = Vector2(400, 300)

func change_room(scene_path: String) -> void:
	load_room(scene_path)

func _on_level_changed(new_level: int) -> void:
	level_label.text = "Current level: " + str(new_level)

func _on_exp_changed(new_exp: int) -> void:
	exp_label.text = "Current exp: " + str(new_exp)

func enter_combat(combat_scene_path: String, enemy: Node = null) -> void:
	if combat_node:
		combat_node.queue_free()
		combat_node = null
	
	# Delete these 2 lines when UI is made
	level_label.visible = false
	exp_label.visible = false
	
	_combat_enemy = enemy
	get_tree().paused = true
	var combat_scene = load(combat_scene_path)
	combat_node = combat_scene.instantiate()
	room_container.visible = false
	character.visible = false
	character.set_physics_process(false)
	character.set_process_input(false)
	add_child(combat_node)

func exit_combat(enemy_killed: bool = false) -> void:
	if combat_node:
		# Delete these 2 lines when UI is made
		level_label.visible = true
		exp_label.visible = true
		
		remove_child(combat_node)
		combat_node.queue_free()
		combat_node = null
	if enemy_killed and _combat_enemy and is_instance_valid(_combat_enemy):
		_combat_enemy.queue_free()
		signal_kill_to_room()
	_combat_enemy = null
	get_tree().paused = false
	room_container.visible = true
	character.visible = true
	character.set_physics_process(true)
	character.set_process_input(true)

func signal_kill_to_room():
	var room = room_container.get_tree().get_first_node_in_group("room")
	room.enemies_kill_count += 1
