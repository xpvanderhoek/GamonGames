class_name Room
extends Node2D

var possible_enemy_groups : Array = [
	["enemy", "enemy", "enemy"],
	["enemy", "enemy"],
	["enemy"]
]
var enemy_group : Array = []
var enemies_kill_count : int:
	set(value):
		enemies_kill_count = value
		if enemies_kill_count == enemy_group.size():
			_unlock_all_doors()

func _ready() -> void:
	RunData.entered_rooms.append(self.scene_file_path)
	var idx = RunData.rng.randi_range(0, possible_enemy_groups.size() - 1)
	enemy_group = possible_enemy_groups[idx]
	_spawn_enemies()
	_setup_doors()
	_unlock_all_doors()

func _spawn_enemies():
	var possible_enemy_spawns = $EnemySpawns.get_children().duplicate()
	if possible_enemy_spawns.size() <= 0:
		return
	for enemy_id in enemy_group:
		var enemy = load("res://scene/%s.tscn" % enemy_id).instantiate()
		var random_spawn_index = RunData.rng.randi_range(0, possible_enemy_spawns.size() - 1)
		var spawn = possible_enemy_spawns[random_spawn_index]
		enemy.position = spawn.position
		add_child(enemy)
		enemy.add_to_group("enemy")
		possible_enemy_spawns.remove_at(random_spawn_index)

func _setup_doors():
	var doors = $Doors.get_children()

	for door in doors:
		door.designated_room = NavigationManager.get_new_random_room()

func _unlock_all_doors():
	var doors = $Doors.get_children()
	
	for door in doors:
		door.locked = false
		door.lock_image.visible = false
