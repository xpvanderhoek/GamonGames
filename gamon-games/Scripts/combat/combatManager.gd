class_name CombatManager
extends Node2D

enum CombatState { 
	PLAYER_TURN,
	ENEMY_TURN,
	COMBAT_OVER,
}

enum CombatAction {
	ATTACK,
	FIREBALL,
}

@export var player_base_damage: int = 25
@export var fireball_damage: int = 40
@export var fireball_radius: float = 100.0
@export var enemy_entity_path: NodePath
@export var enemy_container_path: NodePath = NodePath("UI/HBoxContainer")
@export var ui_player: NodePath = NodePath("UI/Player")
@export var player_max_health: int = 100
@export var exp_reward: int = 50

var current_state: CombatState = CombatState.PLAYER_TURN
var selected_action: CombatAction = CombatAction.ATTACK
var enemy_entities: Array[CombatEntity] = []
var player_health: int = player_max_health
var _queued_encounter_scenes: Array[PackedScene] = []

@onready var btn_attack: Button = $UI/Panel/BtnAttack
@onready var btn_fireball: Button = $UI/Panel/BtnFireball
@onready var lbl_player_health: Label = $UI/Panel/PlayerHealth
@onready var ui_layer: CanvasLayer = $UI

func _ready() -> void:
	if _queued_encounter_scenes.size() > 0:
		_spawn_encounter_enemies(_queued_encounter_scenes)

	_refresh_enemy_entities()
	_update_player_health_label()

	btn_attack.pressed.connect(select_attack)
	btn_fireball.pressed.connect(select_fireball)
	select_attack()

func setup_encounter(encounter_enemy_scenes: Array[PackedScene]) -> void:
	_queued_encounter_scenes = encounter_enemy_scenes.duplicate()
	if not is_node_ready():
		return

	_spawn_encounter_enemies(_queued_encounter_scenes)
	_refresh_enemy_entities()
	if selected_action == CombatAction.FIREBALL:
		select_fireball()
	else:
		select_attack()

func _spawn_encounter_enemies(encounter_enemy_scenes: Array[PackedScene]) -> void:
	var enemy_container := get_node_or_null(enemy_container_path)
	if enemy_container == null:
		return

	for child in enemy_container.get_children():
		if child is CombatEntity:
			child.queue_free()

	for enemy_scene in encounter_enemy_scenes:
		if enemy_scene == null:
			continue
		var enemy_instance := enemy_scene.instantiate()
		enemy_container.add_child(enemy_instance)

func _refresh_enemy_entities() -> void:
	enemy_entities.clear()

	var enemy_container := get_node_or_null(enemy_container_path)
	if enemy_container != null:
		for child in enemy_container.get_children():
			if child is CombatEntity:
				_register_enemy_entity(child as CombatEntity)

	if enemy_entities.size() == 0 and enemy_entity_path != NodePath("") and has_node(enemy_entity_path):
		var fallback_enemy := get_node(enemy_entity_path)
		if fallback_enemy is CombatEntity:
			_register_enemy_entity(fallback_enemy as CombatEntity)

func _register_enemy_entity(entity: CombatEntity) -> void:
	enemy_entities.append(entity)

	var on_died := Callable(self, "_on_enemy_died")
	if not entity.entity_died.is_connected(on_died):
		entity.entity_died.connect(on_died)

	var on_limb_clicked := Callable(self, "_on_enemy_limb_clicked").bind(entity)
	if not entity.highlighted_limb_clicked.is_connected(on_limb_clicked):
		entity.highlighted_limb_clicked.connect(on_limb_clicked)

func _get_alive_enemies() -> Array[CombatEntity]:
	var alive_enemies: Array[CombatEntity] = []
	for entity in enemy_entities:
		if is_instance_valid(entity) and entity.is_alive:
			alive_enemies.append(entity)
	return alive_enemies

func _has_alive_enemies() -> bool:
	return _get_alive_enemies().size() > 0

func _process(_delta: float) -> void:
	if current_state != CombatState.PLAYER_TURN or not _has_alive_enemies():
		return
	if selected_action == CombatAction.FIREBALL:
		for entity in _get_alive_enemies():
			entity.update_aoe_preview(get_global_mouse_position(), fireball_radius)
		queue_redraw()

func _draw() -> void:
	if selected_action != CombatAction.FIREBALL or current_state != CombatState.PLAYER_TURN:
		return
	var mouse_local := get_local_mouse_position()
	
	draw_circle(mouse_local, fireball_radius, Color(1.0, 0.35, 0.0, 0.12))
	draw_arc(mouse_local, fireball_radius, 0.0, TAU, 64, Color(1.0, 0.5, 0.0, 0.85), 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if current_state != CombatState.PLAYER_TURN or not _has_alive_enemies():
		return
	if selected_action == CombatAction.FIREBALL:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos := get_global_mouse_position()
			var did_hit_any_enemy := false
			for entity in _get_alive_enemies():
				var aoe_limbs := entity.get_aoe_limbs(mouse_pos, fireball_radius)
				if aoe_limbs.size() == 0:
					continue
				did_hit_any_enemy = true
				entity.take_damage_all(aoe_limbs, fireball_damage)

			if did_hit_any_enemy:
				get_viewport().set_input_as_handled()
				_end_player_turn()

func select_attack() -> void:
	selected_action = CombatAction.ATTACK
	for entity in enemy_entities:
		if not is_instance_valid(entity):
			continue
		entity.block_click_emit = false
		entity.single_highlight_enabled = true
		entity.clear_aoe_preview()
	queue_redraw()
	_update_button_states()

func select_fireball() -> void:
	selected_action = CombatAction.FIREBALL
	for entity in enemy_entities:
		if not is_instance_valid(entity):
			continue
		entity.block_click_emit = true
		entity.single_highlight_enabled = false
	_update_button_states()

func _update_button_states() -> void:
	if selected_action == CombatAction.ATTACK:
		btn_attack.grab_focus()
		btn_fireball.release_focus()
	elif selected_action == CombatAction.FIREBALL:
		btn_attack.release_focus()
		btn_fireball.grab_focus()

func _on_enemy_limb_clicked(limb: CombatLimb, source_enemy: CombatEntity) -> void:
	if current_state != CombatState.PLAYER_TURN:
		return
	if source_enemy == null or not is_instance_valid(source_enemy) or not source_enemy.is_alive:
		return
	source_enemy.take_damage(limb, player_base_damage)
	_end_player_turn()

func _on_enemy_died(_entity: CombatEntity) -> void:
	if _has_alive_enemies():
		return

	current_state = CombatState.COMBAT_OVER
	NavigationManager.go_back_to_current_room()

func _end_player_turn() -> void:
	if not _has_alive_enemies():
		return
	current_state = CombatState.ENEMY_TURN
	call_deferred("_perform_enemy_turn")

func _perform_enemy_turn() -> void:
	if current_state != CombatState.ENEMY_TURN:
		return

	var alive_enemies := _get_alive_enemies()
	if alive_enemies.size() == 0:
		_end_enemy_turn()
		return

	for attacking_enemy in alive_enemies:
		if not is_instance_valid(attacking_enemy) or not attacking_enemy.is_alive:
			continue

		var attack_limb := _choose_enemy_attack_limb(attacking_enemy)
		if attack_limb == null:
			continue

		var attack := attack_limb.choose_attack()
		if attack == null:
			continue

		await get_tree().create_timer(0.35).timeout
		_play_attack_feedback(attack, attacking_enemy)
		var damage: int = max(0, attack.damage)
		_apply_player_damage(damage)

	_end_enemy_turn()

func _choose_enemy_attack_limb(source_enemy: CombatEntity) -> CombatLimb:
	var candidates: Array[CombatLimb] = []
	for limb in source_enemy.limbs:
		if limb.is_destroyed:
			continue
		if limb.has_attack_options():
			candidates.append(limb)
	if candidates.size() == 0:
		return null
	return candidates[randi() % candidates.size()]

func _apply_player_damage(amount: int) -> void:
	if current_state == CombatState.COMBAT_OVER:
		return
	print("Player took %d damage — HP: %d/%d" % [amount, player_health, player_max_health])
	if amount <= 0:
		return
	player_health = max(0, player_health - amount)
	_update_player_health_label()
	if player_health <= 0:
		current_state = CombatState.COMBAT_OVER

func _play_attack_feedback(attack: CombatAttack, attacking_enemy: CombatEntity) -> void:
	if attack.sfx != null:
		var player := AudioStreamPlayer.new()
		player.stream = attack.sfx
		player.autoplay = false
		add_child(player)
		player.finished.connect(player.queue_free)
		player.play()

	if attack.vfx_scene != null:
		var vfx := attack.vfx_scene.instantiate()
		ui_layer.add_child(vfx)
		vfx.global_position = _resolve_vfx_position(attack, attacking_enemy) + attack.vfx_offset
		if attack.vfx_lifetime > 0.0:
			get_tree().create_timer(attack.vfx_lifetime).timeout.connect(vfx.queue_free)

func _resolve_vfx_position(attack: CombatAttack, attacking_enemy: CombatEntity) -> Vector2:
	match attack.vfx_anchor:
		CombatAttack.VfxAnchor.PLAYER:
			var player_anchor := get_node_or_null(ui_player)
			if player_anchor is CanvasItem:
				return (player_anchor as CanvasItem).global_position
		CombatAttack.VfxAnchor.ENEMY:
			if attacking_enemy is CombatEntity:
				return (attacking_enemy as CombatEntity).global_position

	return get_viewport_rect().size * 0.5

func _end_enemy_turn() -> void:
	if current_state == CombatState.COMBAT_OVER:
		return
	if not _has_alive_enemies():
		current_state = CombatState.COMBAT_OVER
		return
	current_state = CombatState.PLAYER_TURN

func _update_player_health_label() -> void:
	lbl_player_health.text = "HP: %d/%d" % [player_health, player_max_health]
	RunData.add_exp(exp_reward)
