class_name CombatEntity
extends Node

@export_category("VFX-SFX")
@export var hit_sfx: AudioStream

@export var turn_order_icon: Texture2D
@export_range(0.0, 100.0, 0.1) var physical_defense: float = 0.0
@export_range(0.0, 100.0, 0.1) var magic_defense: float = 0.0

var limbs: Array[CombatLimb] = []
var is_alive: bool = true

var _hovered_limbs: Array[CombatLimb] = []
var _highlighted_limb: CombatLimb = null
var _aoe_highlighted_limbs: Array[CombatLimb] = [] 
var _group_highlighted_limbs: Array[CombatLimb] = []
var _spell_targeting_enabled: bool = false
var _spell_targeting_whole_enemy: bool = false
var _spell_targeting_icon: Texture2D = null
var _spell_targeting_center_frame: TextureRect = null
var _spell_targeting_center_icon: TextureRect = null

var block_click_emit: bool = false
var single_highlight_enabled: bool = true
var whole_enemy_highlight_enabled: bool = false

signal entity_died(entity: CombatEntity)
signal entity_took_damage(entity: CombatEntity, limb: CombatLimb, damage: int)
signal highlighted_limb_clicked(limb: CombatLimb)

var exp_reward: int = 100

func get_defense_for_damage_type(damage_type: SpellData.DamageType) -> float:
	match damage_type:
		SpellData.DamageType.MAGIC:
			return max(0.0, magic_defense)
		_:
			return max(0.0, physical_defense)

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
		_clear_current_highlight_visuals()
		_refresh_spell_targeting_visuals()
		return

	var top_limb: CombatLimb = null
	for limb in _hovered_limbs:
		if top_limb == null or limb.get_index() > top_limb.get_index():
			top_limb = limb

	if whole_enemy_highlight_enabled:
		if top_limb == null:
			_clear_current_highlight_visuals()
			_refresh_spell_targeting_visuals()
			return

		if top_limb == _highlighted_limb and not _group_highlighted_limbs.is_empty():
			_refresh_spell_targeting_visuals()
			return

		_clear_current_highlight_visuals()
		_highlighted_limb = top_limb
		for limb in limbs:
			if limb != null and is_instance_valid(limb) and not limb.is_destroyed:
				limb.set_highlighted()
				_group_highlighted_limbs.append(limb)
		_refresh_spell_targeting_visuals()
		return

	if top_limb == _highlighted_limb:
		_refresh_spell_targeting_visuals()
		return

	_clear_current_highlight_visuals()
	_highlighted_limb = top_limb
	if _highlighted_limb != null:
		_highlighted_limb.set_highlighted()

	_refresh_spell_targeting_visuals()

func _clear_current_highlight_visuals() -> void:
	if _highlighted_limb != null:
		_highlighted_limb.set_unhighlighted()
		_highlighted_limb = null

	for limb in _group_highlighted_limbs:
		if limb != null and is_instance_valid(limb):
			limb.set_unhighlighted()
	_group_highlighted_limbs.clear()

func clear_current_highlight() -> void:
	_hovered_limbs.clear()
	_clear_current_highlight_visuals()
	_refresh_spell_targeting_visuals()

func _create_spell_target_frame_texture() -> Texture2D:
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(48):
		for x in range(48):
			var is_border := x < 4 or x >= 44 or y < 4 or y >= 44
			if is_border:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.9))
	return ImageTexture.create_from_image(image)

func set_spell_targeting_preview(enabled: bool, whole_enemy: bool, spell_icon: Texture2D = null) -> void:
	_spell_targeting_enabled = enabled
	_spell_targeting_whole_enemy = whole_enemy and enabled
	_spell_targeting_icon = spell_icon
	_refresh_spell_targeting_visuals()

func _refresh_spell_targeting_visuals() -> void:
	_ensure_spell_targeting_center_visuals()
	_update_spell_targeting_center_visuals()

	for limb in limbs:
		if limb == null or not is_instance_valid(limb):
			continue
		if _spell_targeting_whole_enemy:
			limb.set_spell_targeting_preview(false, false, null)
		else:
			limb.set_spell_targeting_preview(_spell_targeting_enabled, limb == _highlighted_limb, _spell_targeting_icon)

func _ensure_spell_targeting_center_visuals() -> void:
	if _spell_targeting_center_frame == null:
		_spell_targeting_center_frame = TextureRect.new()
		_spell_targeting_center_frame.name = "SpellTargetCenterFrame"
		_spell_targeting_center_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spell_targeting_center_frame.z_index = 42
		_spell_targeting_center_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_spell_targeting_center_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_spell_targeting_center_frame.custom_minimum_size = Vector2(48.0, 48.0)
		_spell_targeting_center_frame.texture = _create_spell_target_frame_texture()
		_spell_targeting_center_frame.visible = false
		_spell_targeting_center_frame.top_level = true
		add_child(_spell_targeting_center_frame)

	if _spell_targeting_center_icon == null:
		_spell_targeting_center_icon = TextureRect.new()
		_spell_targeting_center_icon.name = "SpellTargetCenterIcon"
		_spell_targeting_center_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spell_targeting_center_icon.z_index = 43
		_spell_targeting_center_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_spell_targeting_center_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_spell_targeting_center_icon.custom_minimum_size = Vector2(48.0, 48.0)
		_spell_targeting_center_icon.visible = false
		_spell_targeting_center_icon.top_level = true
		add_child(_spell_targeting_center_icon)

func _update_spell_targeting_center_visuals() -> void:
	if _spell_targeting_center_frame == null or _spell_targeting_center_icon == null:
		return

	if not is_alive or not _spell_targeting_enabled or not _spell_targeting_whole_enemy:
		_spell_targeting_center_frame.visible = false
		_spell_targeting_center_icon.visible = false
		_spell_targeting_center_icon.texture = null
		return

	var center_position := _get_spell_targeting_center_position()
	_spell_targeting_center_frame.size = Vector2(48.0, 48.0)
	_spell_targeting_center_frame.global_position = center_position - (_spell_targeting_center_frame.size * 0.5)
	_spell_targeting_center_frame.visible = true

	_spell_targeting_center_icon.size = Vector2(48.0, 48.0)
	_spell_targeting_center_icon.global_position = _spell_targeting_center_frame.global_position
	_spell_targeting_center_icon.visible = _highlighted_limb != null and _spell_targeting_icon != null
	_spell_targeting_center_icon.texture = _spell_targeting_icon if _spell_targeting_center_icon.visible else null

func _get_spell_targeting_center_position() -> Vector2:
	var sum_position := Vector2.ZERO
	var count := 0
	for limb in limbs:
		if limb == null or not is_instance_valid(limb) or limb.is_destroyed:
			continue
		sum_position += limb.global_position
		count += 1
	if count > 0:
		return sum_position / float(count)
	if _highlighted_limb != null and is_instance_valid(_highlighted_limb):
		return _highlighted_limb.global_position
	return Vector2.ZERO

func set_targeting_enabled(enabled: bool) -> void:
	set_targeting_mode(enabled, false)

func set_targeting_mode(enabled: bool, highlight_whole_enemy: bool = false) -> void:
	block_click_emit = not enabled
	single_highlight_enabled = enabled
	whole_enemy_highlight_enabled = enabled and highlight_whole_enemy
	if not enabled:
		_clear_current_highlight_visuals()
		_refresh_spell_targeting_visuals()
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

	# Play hit SFX if provided
	if hit_sfx != null:
		var _player := AudioStreamPlayer.new()
		_player.stream = hit_sfx
		_player.autoplay = false
		add_child(_player)
		_player.finished.connect(_player.queue_free)
		_player.play()
	entity_took_damage.emit(self, limb, amount)

func take_damage_all(target_limbs: Array[CombatLimb], amount: int) -> void:
	for limb in target_limbs:
		take_damage(limb, amount)

func _on_limb_destroyed(limb: CombatLimb) -> void:
	_hovered_limbs.erase(limb)
	_aoe_highlighted_limbs.erase(limb)
	_group_highlighted_limbs.erase(limb)
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
	_group_highlighted_limbs.clear()
	clear_aoe_preview()
	if _highlighted_limb != null:
		_highlighted_limb.set_unhighlighted()
		_highlighted_limb = null
	for limb in limbs:
		if not limb.is_destroyed:
			limb.destroy_limb()
	entity_died.emit(self)
	RunData.add_exp(exp_reward)
	RunData.coins += 15
