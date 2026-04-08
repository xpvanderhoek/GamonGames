extends Node2D

@onready var room_container: Node2D = $RoomContainer
@onready var character: Character = $Character
@onready var level_label: Label = get_node_or_null("CanvasLayer/VBoxContainer/LevelLabel")
@onready var exp_label: Label = get_node_or_null("CanvasLayer/VBoxContainer/ExpLabel")
@onready var health_label: Label = get_node_or_null("CanvasLayer/VBoxContainer/HealthLabel")
@onready var upgrade_screen = get_node_or_null("CanvasLayer/UpgradeScreen")


var current_room: Node = null
var combat_node: Node = null
var _combat_enemy: Node = null
var last_level: int = 1

func _ready() -> void:
	RunData.level_changed.connect(_on_level_changed)
	RunData.exp_changed.connect(_on_exp_changed)
	RunData.health_changed.connect(_on_health_changed)
	
	_on_level_changed(RunData.current_level)
	_on_exp_changed(RunData.current_exp)
	_on_health_changed()
	
	if upgrade_screen:
		upgrade_screen.upgrade_selected.connect(_on_upgrade_selected)

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
	if level_label:
		level_label.text = "Current level: " + str(new_level)

	if new_level > last_level:
		_on_player_leveled_up()

	last_level = new_level

func _on_exp_changed(new_exp: int) -> void:
	if exp_label:
		exp_label.text = "Current exp: " + str(new_exp)

func _on_health_changed() -> void:
	if health_label:
		health_label.text = str(RunData.current_health) + " HP / " + str(RunData.max_health) + " HP"

func enter_combat(combat_scene_path: String, enemy: Node = null) -> void:
	if combat_node:
		combat_node.queue_free()
		combat_node = null
	
	# Delete these 2 lines when UI is made
	if level_label:
		level_label.visible = false
	if exp_label:
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

	var encounter_enemies: Array[PackedScene] = []
	if enemy != null and enemy.has_method("get_encounter_enemies"):
		encounter_enemies = enemy.get_encounter_enemies()

	if combat_node.has_method("setup_encounter"):
		combat_node.setup_encounter(encounter_enemies)

func exit_combat(enemy_killed: bool = false) -> void:
	if combat_node:
		# Delete these 2 lines when UI is made
		if level_label:
			level_label.visible = true
		if exp_label:
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

func _on_player_leveled_up():
	character.set_process_input(false)
	character.set_physics_process(false)
	
	call_deferred("_show_upgrade_screen")
		
func _show_upgrade_screen():
	get_tree().paused = true
	if upgrade_screen:
		upgrade_screen.show_random_options()
	
func _on_upgrade_selected(stat: String):
	print("Selected:", stat)
	PlayerStats.upgrade_stat(stat)

	if upgrade_screen:
		upgrade_screen.hide()
	get_tree().paused = false
	
	character.set_process_input(true)
	character.set_physics_process(true)
	
func _input(event):
	if event.is_action_pressed("ui_page_up"):
		_on_player_leveled_up()
		
	if event.is_action_pressed("ui_page_down"): 
		RunData.add_exp(1000) 
		 
	if event.is_action("ui_text_delete_word"):
		DialogueManager.start_dialogue("intro")

func _process(delta: float) -> void:
	RunData.update_timer(delta)
