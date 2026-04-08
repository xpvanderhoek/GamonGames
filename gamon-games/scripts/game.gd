extends Node2D

@onready var room_container: Node2D = $RoomContainer
@onready var character: Character = $Character
@onready var level_label: Label = $CanvasLayer/VBoxContainer/LevelLabel
@onready var exp_label: Label = $CanvasLayer/VBoxContainer/ExpLabel
@onready var health_label : Label = $CanvasLayer/VBoxContainer/HealthLabel
@onready var upgrade_screen = $CanvasLayer/UpgradeScreen

var skill_tree_overlay = null
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
	
	_setup_skill_tree_overlay()
	_apply_skill_tree_bonuses()
	
	upgrade_screen.upgrade_selected.connect(_on_upgrade_selected)
	
	load_room(NavigationManager.get_new_random_room())

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

	if new_level > last_level:
		_on_player_leveled_up()

	last_level = new_level

func _on_exp_changed(new_exp: int) -> void:
	exp_label.text = "Current exp: " + str(new_exp)

func _on_health_changed() -> void:
	health_label.text = str(RunData.current_health) + " HP / " + str(RunData.max_health) + " HP"

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

	var encounter_enemies: Array[PackedScene] = []
	if enemy != null and enemy.has_method("get_encounter_enemies"):
		encounter_enemies = enemy.get_encounter_enemies()

	if combat_node.has_method("setup_encounter"):
		combat_node.setup_encounter(encounter_enemies)

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

func _on_player_leveled_up():
	character.set_process_input(false)
	character.set_physics_process(false)
	
	call_deferred("_show_upgrade_screen")
		
func _show_upgrade_screen():
	get_tree().paused = true
	upgrade_screen.show_random_options()
	
func _on_upgrade_selected(stat: String):
	print("Selected:", stat)
	PlayerStats.upgrade_stat(stat)
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
	
	# Debug for now, because limbo world doesn't exist
	if event.is_action_pressed("open_skill_tree_debug"):
		_toggle_skill_tree()

func _process(delta: float) -> void:
	RunData.update_timer(delta)

func _setup_skill_tree_overlay() -> void:
	var skill_tree_scene = load("res://scenes/skilltree/skill_tree_screen.tscn")
	skill_tree_overlay = skill_tree_scene.instantiate()
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)
	canvas_layer.add_child(skill_tree_overlay)
	
	skill_tree_overlay.visible = false

func _toggle_skill_tree() -> void:
	if skill_tree_overlay == null:
		return
	
	skill_tree_overlay.visible = !skill_tree_overlay.visible
	get_tree().paused = skill_tree_overlay.visible

func _apply_skill_tree_bonuses() -> void:
	var skills: Array = []
	
	var skill_paths = [
		"res://scripts/skilltree/skill_resources/anatomy_mastery.tres",
		"res://scripts/skilltree/skill_resources/fortune's_blessing.tres",
		"res://scripts/skilltree/skill_resources/hardened_flesh.tres",
		"res://scripts/skilltree/skill_resources/iron_will.tres",
		"res://scripts/skilltree/skill_resources/quick_reflexes.tres",
		"res://scripts/skilltree/skill_resources/scavengers_eye.tres",
		"res://scripts/skilltree/skill_resources/starting_kit.tres",
		"res://scripts/skilltree/skill_resources/steady_hand.tres",
		"res://scripts/skilltree/skill_resources/stone_guard.tres",
	]
	
	for path in skill_paths:
		var skill = load(path) as SkillData
		if skill:
			skills.append(skill)
	
	PlayerStats.apply_skill_bonuses(skills)
