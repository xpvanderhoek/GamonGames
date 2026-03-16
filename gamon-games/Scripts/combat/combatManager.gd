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
@export var player_max_health: int = 100
@export var exp_reward: int = 50

var current_state: CombatState = CombatState.PLAYER_TURN
var selected_action: CombatAction = CombatAction.ATTACK
var enemy_entity: CombatEntity
var player_health: int = 0


@onready var btn_attack: Button = $UI/Panel/Actions/BtnAttack
@onready var btn_fireball: Button = $UI/Panel/Actions/BtnFireball
@onready var lbl_player_health: Label = $UI/Panel/PlayerHealth

func _ready() -> void:
	enemy_entity = get_node(enemy_entity_path) as CombatEntity
	enemy_entity.entity_died.connect(_on_enemy_died)
	enemy_entity.highlighted_limb_clicked.connect(_on_enemy_limb_clicked)
	player_health = player_max_health
	_update_player_health_label()

	btn_attack.pressed.connect(select_attack)
	btn_fireball.pressed.connect(select_fireball)
	select_attack()

func _process(_delta: float) -> void:
	if current_state != CombatState.PLAYER_TURN or not enemy_entity.is_alive:
		return
	if selected_action == CombatAction.FIREBALL:
		enemy_entity.update_aoe_preview(get_global_mouse_position(), fireball_radius)
		queue_redraw()

func _draw() -> void:
	if selected_action != CombatAction.FIREBALL or current_state != CombatState.PLAYER_TURN:
		return
	var mouse_local := get_local_mouse_position()
	
	draw_circle(mouse_local, fireball_radius, Color(1.0, 0.35, 0.0, 0.12))
	draw_arc(mouse_local, fireball_radius, 0.0, TAU, 64, Color(1.0, 0.5, 0.0, 0.85), 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if current_state != CombatState.PLAYER_TURN or not enemy_entity.is_alive:
		return
	if selected_action == CombatAction.FIREBALL:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var aoe_limbs := enemy_entity.get_aoe_limbs(get_global_mouse_position(), fireball_radius)
			if aoe_limbs.size() > 0:
				enemy_entity.take_damage_all(aoe_limbs, fireball_damage)
				get_viewport().set_input_as_handled()
				_end_player_turn()

func select_attack() -> void:
	selected_action = CombatAction.ATTACK
	enemy_entity.block_click_emit = false
	enemy_entity.single_highlight_enabled = true
	enemy_entity.clear_aoe_preview()
	queue_redraw()
	_update_button_states()

func select_fireball() -> void:
	selected_action = CombatAction.FIREBALL
	enemy_entity.block_click_emit = true
	enemy_entity.single_highlight_enabled = false
	_update_button_states()

func _update_button_states() -> void:
	if selected_action == CombatAction.ATTACK:
		btn_attack.grab_focus()
		btn_fireball.release_focus()
	elif selected_action == CombatAction.FIREBALL:
		btn_attack.release_focus()
		btn_fireball.grab_focus()

func _on_enemy_limb_clicked(limb: CombatLimb) -> void:
	if current_state != CombatState.PLAYER_TURN:
		return
	if not enemy_entity.is_alive:
		return
	enemy_entity.take_damage(limb, player_base_damage)
	_end_player_turn()

func _on_enemy_died(_entity: CombatEntity) -> void:
	current_state = CombatState.COMBAT_OVER

func _end_player_turn() -> void:
	if not enemy_entity.is_alive:
		return
	current_state = CombatState.ENEMY_TURN
	call_deferred("_perform_enemy_turn")

func _perform_enemy_turn() -> void:
	if current_state != CombatState.ENEMY_TURN:
		return
	if not enemy_entity.is_alive:
		return

	var attack_limb := _choose_enemy_attack_limb()
	if attack_limb == null:
		_end_enemy_turn()
		return

	await get_tree().create_timer(0.35).timeout
	var damage: int = max(0, attack_limb.attack_damage)
	_apply_player_damage(damage)
	_end_enemy_turn()

func _choose_enemy_attack_limb() -> CombatLimb:
	var candidates: Array[CombatLimb] = []
	for limb in enemy_entity.limbs:
		if limb.is_destroyed:
			continue
		if limb.attack_damage > 0:
			candidates.append(limb)
	if candidates.size() == 0:
		return null
	return candidates[randi() % candidates.size()]

func _apply_player_damage(amount: int) -> void:
	if current_state == CombatState.COMBAT_OVER:
		return
	player_health = max(0, player_health - amount)
	_update_player_health_label()
	if player_health <= 0:
		current_state = CombatState.COMBAT_OVER

func _end_enemy_turn() -> void:
	if current_state == CombatState.COMBAT_OVER:
		return
	current_state = CombatState.PLAYER_TURN

func _update_player_health_label() -> void:
	lbl_player_health.text = "HP: %d/%d" % [player_health, player_max_health]
	RunData.add_exp(exp_reward)
