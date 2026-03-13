extends Node2D

@onready var room_container: Node2D = $RoomContainer
@onready var character: Character = $Character

var current_room: Node = null
var combat_node: Node = null
var _combat_enemy: Node = null

func _ready() -> void:
	load_room(NavigationManager.current_room_path)

func load_room(scene_path: String) -> void:
	if current_room:
		room_container.remove_child(current_room)
		current_room.queue_free()
		current_room = null

	var room_scene = load(scene_path)
	current_room = room_scene.instantiate()
	room_container.add_child(current_room)

	var spawn = current_room.get_node_or_null("SpawnPoint")
	if spawn:
		character.global_position = spawn.global_position
	else:
		character.global_position = Vector2(400, 300)

func change_room(scene_path: String) -> void:
	load_room(scene_path)

func enter_combat(combat_scene_path: String, enemy: Node = null) -> void:
	if combat_node:
		combat_node.queue_free()
		combat_node = null
	_combat_enemy = enemy
	var combat_scene = load(combat_scene_path)
	combat_node = combat_scene.instantiate()
	room_container.visible = false
	character.visible = false
	character.set_physics_process(false)
	character.set_process_input(false)
	add_child(combat_node)

func exit_combat(enemy_killed: bool = false) -> void:
	if combat_node:
		remove_child(combat_node)
		combat_node.queue_free()
		combat_node = null
	if enemy_killed and _combat_enemy and is_instance_valid(_combat_enemy):
		_combat_enemy.queue_free()
	_combat_enemy = null
	room_container.visible = true
	character.visible = true
	character.set_physics_process(true)
	character.set_process_input(true)
