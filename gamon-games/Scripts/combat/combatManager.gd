class_name CombatManager
extends Node2D

enum CombatState { 
	PLAYER_TURN,
	ENEMY_TURN,
	COMBAT_OVER,
}

@export var player_base_damage: int = 25
@export var enemy_entity_path: NodePath

var current_state: CombatState = CombatState.PLAYER_TURN
var enemy_entity: CombatEntity

func _ready() -> void:
	enemy_entity = get_node(enemy_entity_path) as CombatEntity
	enemy_entity.entity_died.connect(_on_enemy_died)

	# Connect limb click signals for enemy limbs
	for limb in enemy_entity.limbs:
		limb.limb_clicked.connect(_on_enemy_limb_clicked)

func _on_enemy_limb_clicked(limb: CombatLimb) -> void:
	if current_state != CombatState.PLAYER_TURN:
		return
	if not enemy_entity.is_alive:
		return

	enemy_entity.take_damage(limb, player_base_damage)

func _on_enemy_died(_entity: CombatEntity) -> void:
	current_state = CombatState.COMBAT_OVER