class_name CombatManager
extends Node2D

const TURN_ORDER_ENTRY_SCENE := preload("res://Scenes/combat/TurnOrderEntry.tscn")

enum CombatState { 
	PLAYER_TURN,
	ENEMY_TURN,
	COMBAT_OVER,
}

enum CombatAction {
	ATTACK,
}

@export var player_base_damage: int = 25
@export var enemy_entity_path: NodePath
@export var enemy_container_path: NodePath = NodePath("UI/HBoxContainer")
@export var ui_player: NodePath = NodePath("UI/Player")
@export var turns_order_path: NodePath = NodePath("UI/TurnsOrder")
@export var player_turn_icon: Texture2D
@export var turns_order_row_height: float = 24.0
@export var turns_order_min_visible_rows: int = 8
@export var player_max_health: int = 100
@export var exp_reward: int = 50

var current_state: CombatState = CombatState.PLAYER_TURN
var selected_action: CombatAction = CombatAction.ATTACK
var enemy_entities: Array[CombatEntity] = []
var player_health: int = player_max_health
var _queued_encounter_scenes: Array[PackedScene] = []
var _enemy_targeting_enabled: bool = false
var _attack_selected: bool = false
var current_round: int = 1

signal enemy_targeting_changed(enabled: bool)

@onready var btn_attack: Button = $UI/BtnAttack
@onready var lbl_player_health: Label = $UI/PlayerHealth
@onready var lbl_turns_order: Label = $UI/TurnsOrderInfo
@onready var ui_layer: CanvasLayer = $UI
@onready var turns_order_container: VBoxContainer = $UI/TurnsOrder

func _ready() -> void:
	if _queued_encounter_scenes.size() > 0:
		_spawn_encounter_enemies(_queued_encounter_scenes)

	current_round = 1
	_refresh_enemy_entities()
	_update_player_health_label()

	btn_attack.pressed.connect(select_attack)
	_begin_player_turn()

func setup_encounter(encounter_enemy_scenes: Array[PackedScene]) -> void:
	_queued_encounter_scenes = encounter_enemy_scenes.duplicate()
	current_round = 1
	if not is_node_ready():
		return

	_spawn_encounter_enemies(_queued_encounter_scenes)
	_refresh_enemy_entities()
	_begin_player_turn()

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
			if child is CombatEntity and not child.is_queued_for_deletion():
				_register_enemy_entity(child as CombatEntity)

	if enemy_entities.is_empty() and has_node(enemy_entity_path):
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

	var on_targeting_changed := Callable(entity, "set_targeting_enabled")
	if not enemy_targeting_changed.is_connected(on_targeting_changed):
		enemy_targeting_changed.connect(on_targeting_changed)
	entity.set_targeting_enabled(_enemy_targeting_enabled)

func _get_alive_enemies() -> Array[CombatEntity]:
	var alive_enemies: Array[CombatEntity] = []
	for entity in enemy_entities:
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() and entity.is_alive:
			alive_enemies.append(entity)
	return alive_enemies

func _has_alive_enemies() -> bool:
	return _get_alive_enemies().size() > 0

func select_attack() -> void:
	if current_state != CombatState.PLAYER_TURN or not _has_alive_enemies():
		return
	selected_action = CombatAction.ATTACK
	_attack_selected = true
	_set_enemy_targeting_enabled(true)
	_update_button_states()

func _update_button_states() -> void:
	btn_attack.disabled = current_state != CombatState.PLAYER_TURN or _attack_selected or not _has_alive_enemies()
	if selected_action == CombatAction.ATTACK and not btn_attack.disabled:
		btn_attack.grab_focus()

func _on_enemy_limb_clicked(limb: CombatLimb, source_enemy: CombatEntity) -> void:
	if current_state != CombatState.PLAYER_TURN:
		return
	if not _attack_selected:
		return
	if source_enemy == null or not is_instance_valid(source_enemy) or not source_enemy.is_alive:
		return
	if limb.is_destroyed:
		return

	if limb.roll_hit():
		source_enemy.take_damage(limb, player_base_damage)
	else:
		print("Player missed %s (%s%% hit chance)" % [limb.limb_name, snappedf(limb.hit_chance_percent, 0.1)])

	_attack_selected = false
	source_enemy.clear_current_highlight()
	_end_player_turn()

func _on_enemy_died(_entity: CombatEntity) -> void:
	if _has_alive_enemies():
		_refresh_turns_order_ui()
		return

	current_state = CombatState.COMBAT_OVER
	_update_button_states()
	_refresh_turns_order_ui()
	NavigationManager.go_back_to_current_room()

func _end_player_turn() -> void:
	if not _has_alive_enemies():
		return
	_set_enemy_targeting_enabled(false)
	current_state = CombatState.ENEMY_TURN
	_update_button_states()
	_refresh_turns_order_ui()
	call_deferred("_perform_enemy_turn")

func _perform_enemy_turn() -> void:
	if current_state != CombatState.ENEMY_TURN:
		return

	var alive_enemies := _get_alive_enemies()
	if alive_enemies.is_empty():
		_end_enemy_turn()
		return

	for attacking_enemy in alive_enemies:
		if not is_instance_valid(attacking_enemy) or not attacking_enemy.is_alive:
			continue

		_refresh_turns_order_ui(attacking_enemy)

		var attack_limb := _choose_enemy_attack_limb(attacking_enemy)
		if attack_limb == null:
			continue

		var attack := attack_limb.choose_attack()
		if attack == null:
			continue

		await get_tree().create_timer(0.35).timeout
		await _play_attack_feedback(attack, attacking_enemy)
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
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

func _apply_player_damage(amount: int) -> void:
	if current_state == CombatState.COMBAT_OVER:
		return
	print("Player took %d damage — HP: %d/%d" % [amount, player_health, player_max_health])
	if amount <= 0:
		return
	_flash_player_hit()
	player_health = max(0, player_health - amount)
	_update_player_health_label()
	if player_health <= 0:
		current_state = CombatState.COMBAT_OVER

func _flash_player_hit() -> void:
	var player_anchor := get_node_or_null(ui_player)
	if not (player_anchor is CanvasItem):
		return

	var player_canvas := player_anchor as CanvasItem
	var tween := create_tween()
	tween.tween_property(player_canvas, "modulate", Color(1.7, 1.7, 1.7, 1.0), 0.18)
	tween.tween_property(player_canvas, "modulate", Color(1, 1, 1, 1), 0.22)

func _play_attack_feedback(attack: CombatAttack, attacking_enemy: CombatEntity) -> void:
	var vfx_lifetime_timer: SceneTreeTimer = null

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
			vfx_lifetime_timer = get_tree().create_timer(attack.vfx_lifetime)
			vfx_lifetime_timer.timeout.connect(vfx.queue_free)

	if vfx_lifetime_timer != null:
		await vfx_lifetime_timer.timeout

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
		_refresh_turns_order_ui()
		return
	if not _has_alive_enemies():
		current_state = CombatState.COMBAT_OVER
		_update_button_states()
		_refresh_turns_order_ui()
		return
	current_round += 1
	current_state = CombatState.PLAYER_TURN
	_begin_player_turn()

func _begin_player_turn() -> void:
	_attack_selected = false
	_set_enemy_targeting_enabled(false)
	_update_button_states()
	_refresh_turns_order_ui()

func _set_enemy_targeting_enabled(enabled: bool) -> void:
	if _enemy_targeting_enabled == enabled:
		return
	_enemy_targeting_enabled = enabled
	enemy_targeting_changed.emit(enabled)

func _update_player_health_label() -> void:
	lbl_player_health.text = "HP: %d/%d" % [player_health, player_max_health]
	RunData.add_exp(exp_reward)

func _refresh_turns_order_ui(current_enemy_actor: CombatEntity = null) -> void:
	if turns_order_container == null:
		return

	for child in turns_order_container.get_children():
		child.queue_free()

	var alive_enemies := _get_alive_enemies()
	var preview_state: CombatState = current_state
	var preview_active_enemy: CombatEntity = current_enemy_actor
	if preview_state == CombatState.ENEMY_TURN and (preview_active_enemy == null or not is_instance_valid(preview_active_enemy)) and not alive_enemies.is_empty():
		preview_active_enemy = alive_enemies[0]

	if preview_state == CombatState.COMBAT_OVER:
		return

	var remaining_enemies := _build_remaining_turn_entities(preview_state, alive_enemies, preview_active_enemy)
	if preview_state == CombatState.ENEMY_TURN and remaining_enemies.is_empty():
		return

	lbl_turns_order.text = "%d" % current_round

	if preview_state == CombatState.PLAYER_TURN:
		turns_order_container.add_child(_create_turn_icon_entry(_get_player_turn_icon(), "Player"))

	for i in range(remaining_enemies.size()):
		var enemy := remaining_enemies[i]
		turns_order_container.add_child(
			_create_turn_icon_entry(
				_get_enemy_turn_icon(enemy),
				_format_turn_name(enemy)
			)
		)

func _build_remaining_turn_entities(state: CombatState, alive_enemies: Array[CombatEntity], active_enemy: CombatEntity = null) -> Array[CombatEntity]:
	var turn_entities: Array[CombatEntity] = []

	match state:
		CombatState.PLAYER_TURN:
			turn_entities.append_array(alive_enemies)
		CombatState.ENEMY_TURN:
			var start_index := 0
			if active_enemy != null and is_instance_valid(active_enemy) and active_enemy.is_alive:
				var active_index := alive_enemies.find(active_enemy)
				if active_index >= 0:
					start_index = active_index

			for i in range(start_index, alive_enemies.size()):
				turn_entities.append(alive_enemies[i])

	return turn_entities

func _create_turn_icon_entry(icon: Texture2D, tooltip: String) -> TextureRect:
	var icon_rect := TURN_ORDER_ENTRY_SCENE.instantiate() as TextureRect
	icon_rect.texture = icon
	icon_rect.tooltip_text = tooltip
	return icon_rect

func _get_enemy_turn_icon(entity: CombatEntity) -> Texture2D:
	if entity == null or not is_instance_valid(entity):
		return null
	return entity.turn_order_icon

func _get_player_turn_icon() -> Texture2D:
	if player_turn_icon != null:
		return player_turn_icon

	var player_anchor := get_node_or_null(ui_player)
	if player_anchor is Sprite2D:
		return (player_anchor as Sprite2D).texture

	return null

func _format_turn_name(entity: CombatEntity) -> String:
	if entity == null or not is_instance_valid(entity):
		return "Enemy"

	var raw_name := entity.name.strip_edges()
	if raw_name.is_empty():
		return "Enemy"

	return raw_name.capitalize()
