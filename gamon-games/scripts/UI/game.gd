extends Node2D

@onready var level_label: Label = $CanvasLayer/VBoxContainer/LevelLabel
@onready var exp_label: Label = $CanvasLayer/VBoxContainer/ExpLabel
@onready var health_label : Label = $CanvasLayer/VBoxContainer/HealthLabel
@onready var upgrade_screen = $CanvasLayer/UpgradeScreen

var skill_tree_overlay = null
var combat_node: Node = null
var _combat_enemy: Node = null
var last_level: int = 1

func _ready() -> void:
	RunData.level_changed.connect(_on_level_changed)
	RunData.exp_changed.connect(_on_exp_changed)
	RunData.health_changed.connect(_on_health_changed)
	PlayerStats.stats_changed.connect(_on_stats_changed)
	
	_on_level_changed(RunData.current_level)
	_on_exp_changed(RunData.current_exp)
	_on_health_changed()
	
	_apply_skill_tree_bonuses()

func _on_level_changed(new_level: int) -> void:
	level_label.text = "Current level: " + str(new_level)

	if new_level > last_level:
		_on_player_leveled_up()

	last_level = new_level

func _on_exp_changed(new_exp: int) -> void:
	exp_label.text = "Current exp: " + str(new_exp)

func _on_health_changed() -> void:
	health_label.text = str(RunData.current_health) + " HP / " + str(RunData.max_health) + " HP"

func _on_stats_changed(stat_name: String, new_value: float) -> void:
	if stat_name == "health":
		RunData.max_health = int(new_value)
		if RunData.current_health > RunData.max_health:
			RunData.current_health = RunData.max_health
		_on_health_changed()

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
	add_child(combat_node)

	var encounter_enemies: Array = []
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
	_combat_enemy = null
	get_tree().paused = false

func _on_player_leveled_up():
	if combat_node != null:
		return
		
func _show_upgrade_screen():
	get_tree().paused = true
	upgrade_screen.show_random_options()
	
	
func _input(event):
	if event.is_action_pressed("ui_page_down"): 
		RunData.add_exp(1000) 
		 
	if event.is_action("ui_text_delete_word"):
		DialogueManager.start_dialogue("intro")


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
