class_name CombatEntity
extends Node

@export var turn_order_icon: Texture2D

var limbs: Array[CombatLimb] = []
var is_alive: bool = true

var _hovered_limbs: Array[CombatLimb] = []
var _highlighted_limb: CombatLimb = null
var _aoe_highlighted_limbs: Array[CombatLimb] = [] 

var block_click_emit: bool = false
var single_highlight_enabled: bool = true

signal entity_died(entity: CombatEntity)
signal entity_took_damage(entity: CombatEntity, limb: CombatLimb, damage: int)
signal highlighted_limb_clicked(limb: CombatLimb)

var exp_reward: int = 50

func _ready() -> void:
	_discover_limbs()

func _discover_limbs() -> void:
	_find_limbs_recursive(self)

func _find_limbs_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is CombatLimb:
			limbs.append(child)
			child.limb_destroyed.connect(_on_limb_destroyed)
			child.mouse_entered_limb.connect(_on_limb_mouse_entered.bind(child))
			child.mouse_exited_limb.connect(_on_limb_mouse_exited.bind(child))

func _on_limb_mouse_entered(limb: CombatLimb) -> void:
	if limb.is_destroyed:
		return
	if not limb in _hovered_limbs:
		_hovered_limbs.append(limb)
	_refresh_highlight()

func _on_limb_mouse_exited(limb: CombatLimb) -> void:
	_hovered_limbs.erase(limb)
	_refresh_highlight()

func _refresh_highlight() -> void:
	if not single_highlight_enabled:
		if _highlighted_limb != null:
			_highlighted_limb.set_unhighlighted()
			_highlighted_limb = null
		return

	var top_limb: CombatLimb = null
	for limb in _hovered_limbs:
		if top_limb == null or limb.get_index() > top_limb.get_index():
			top_limb = limb

	if top_limb == _highlighted_limb:
		return

	if _highlighted_limb != null:
		_highlighted_limb.set_unhighlighted()
	_highlighted_limb = top_limb
	if _highlighted_limb != null:
		_highlighted_limb.set_highlighted()

func clear_current_highlight() -> void:
	_hovered_limbs.clear()
	if _highlighted_limb != null:
		_highlighted_limb.set_unhighlighted()
		_highlighted_limb = null

func set_targeting_enabled(enabled: bool) -> void:
	block_click_emit = not enabled
	single_highlight_enabled = enabled
	if not enabled:
		clear_current_highlight()
		return
	_refresh_highlight()

func _unhandled_input(event: InputEvent) -> void:
	if block_click_emit or not is_alive or _highlighted_limb == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		highlighted_limb_clicked.emit(_highlighted_limb)
		get_viewport().set_input_as_handled()

func update_aoe_preview(world_pos: Vector2, radius: float) -> void:
	var next_aoe := get_aoe_limbs(world_pos, radius)
	update_aoe_preview_from_list(next_aoe)

## Update the AoE highlight from a pre-computed list of limbs (used by the spell system).
func update_aoe_preview_from_list(next_aoe) -> void:
	for limb in _aoe_highlighted_limbs:
		if not limb in next_aoe:
			limb.set_aoe_unhighlighted()

	for limb in next_aoe:
		if not limb in _aoe_highlighted_limbs:
			limb.set_aoe_highlighted()

	_aoe_highlighted_limbs = next_aoe

func clear_aoe_preview() -> void:
	for limb in _aoe_highlighted_limbs:
		limb.set_aoe_unhighlighted()
	_aoe_highlighted_limbs.clear()

func get_aoe_limbs(world_pos: Vector2, radius: float) -> Array[CombatLimb]:
	var result: Array[CombatLimb] = []
	for limb in limbs:
		if not limb.is_destroyed and limb.global_position.distance_to(world_pos) <= radius:
			result.append(limb)
	return result

func take_damage(limb: CombatLimb, amount: int) -> void:
	if not is_alive:
		return
	limb.take_damage(amount)
	entity_took_damage.emit(self, limb, amount)

func take_damage_all(target_limbs: Array[CombatLimb], amount: int) -> void:
	for limb in target_limbs:
		take_damage(limb, amount)

func _on_limb_destroyed(limb: CombatLimb) -> void:
	_hovered_limbs.erase(limb)
	_aoe_highlighted_limbs.erase(limb)
	if _highlighted_limb == limb:
		_highlighted_limb = null
		_refresh_highlight()
	if limb.is_vital:
		die()

func die() -> void:
	if not is_alive:
		return
	is_alive = false
	_hovered_limbs.clear()
	clear_aoe_preview()
	if _highlighted_limb != null:
		_highlighted_limb.set_unhighlighted()
		_highlighted_limb = null
	for limb in limbs:
		if not limb.is_destroyed:
			limb.destroy_limb()
	entity_died.emit(self)
	RunData.add_exp(exp_reward)
