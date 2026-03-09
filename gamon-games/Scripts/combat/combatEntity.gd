class_name CombatEntity
extends Node

var limbs: Array[CombatLimb] = []
var is_alive: bool = true

signal entity_died(entity: CombatEntity)
signal entity_took_damage(entity: CombatEntity, limb: CombatLimb, damage: int)

func _ready() -> void:
	_discover_limbs()

func _discover_limbs() -> void:
	_find_limbs_recursive(self)

func _find_limbs_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is CombatLimb:
			limbs.append(child)
			child.limb_destroyed.connect(_on_limb_destroyed)

func take_damage(limb: CombatLimb, amount: int) -> void:
	if not is_alive:
		return

	limb.take_damage(amount)
	entity_took_damage.emit(self, limb, amount)

func _on_limb_destroyed(limb: CombatLimb) -> void:
	if limb.is_vital:
		die()

func die() -> void:
	is_alive = false
	# Destroy all remaining limbs
	for limb in limbs:
		if not limb.is_destroyed:
			limb.destroy_limb()
	entity_died.emit(self)