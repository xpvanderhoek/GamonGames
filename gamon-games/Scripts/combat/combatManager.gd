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

var current_state: CombatState = CombatState.PLAYER_TURN
var selected_action: CombatAction = CombatAction.ATTACK
var enemy_entity: CombatEntity

@onready var btn_attack: Button = $UI/Actions/BtnAttack
@onready var btn_fireball: Button = $UI/Actions/BtnFireball

func _ready() -> void:
	enemy_entity = get_node(enemy_entity_path) as CombatEntity
	enemy_entity.entity_died.connect(_on_enemy_died)
	enemy_entity.highlighted_limb_clicked.connect(_on_enemy_limb_clicked)

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
	
	# Draw circle
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
	btn_attack.modulate = Color.WHITE if selected_action == CombatAction.ATTACK else Color(1, 1, 1, 0.5)
	btn_fireball.modulate = Color.WHITE if selected_action == CombatAction.FIREBALL else Color(1, 1, 1, 0.5)

func _on_enemy_limb_clicked(limb: CombatLimb) -> void:
	if current_state != CombatState.PLAYER_TURN:
		return
	if not enemy_entity.is_alive:
		return
	enemy_entity.take_damage(limb, player_base_damage)

func _on_enemy_died(_entity: CombatEntity) -> void:
	current_state = CombatState.COMBAT_OVER
