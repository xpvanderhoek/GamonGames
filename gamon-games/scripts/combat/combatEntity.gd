class_name CombatEntity
extends Node

@export_category("VFX-SFX")
@export var hit_sfx: AudioStream

@export var turn_order_icon: Texture2D
@export_category("Spawn")
@export var spawn_min_fights: int = 0
@export var spawn_max_fights: int = 999
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

var block_click_emit: bool = false
var single_highlight_enabled: bool = true
var whole_enemy_highlight_enabled: bool = false

var _limb_tooltip: PanelContainer = null
var _limb_tooltip_label: RichTextLabel = null
var _tooltip_limb: CombatLimb = null
var _was_shift_pressed: bool = false

signal entity_died(entity: CombatEntity)
signal entity_took_damage(entity: CombatEntity, limb: CombatLimb, damage: int)
signal highlighted_limb_clicked(limb: CombatLimb)

const DEATH_DISSOLVE_SHADER := preload("res://shaders/black_disintegrate.gdshader")

var exp_reward: int = 100
@export var marrow_shard_reward: int = 75
var combat_scaling_multiplier: float = 1.0

var _death_started: bool = false
var _death_materials: Array[ShaderMaterial] = []

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
		_find_limbs_recursive(child)

func _process(_delta: float) -> void:
	_update_limb_tooltip_position()
	if _tooltip_limb != null and _limb_tooltip != null and _limb_tooltip.visible:
		var shift_now := Input.is_key_pressed(KEY_SHIFT)
		if shift_now != _was_shift_pressed:
			_was_shift_pressed = shift_now
			_show_limb_tooltip(_tooltip_limb, self)

func _on_limb_mouse_entered(limb: CombatLimb) -> void:
	var hovered_limb := _resolve_hover_target(limb)
	if hovered_limb == null or hovered_limb.is_destroyed:
		return
	if not hovered_limb in _hovered_limbs:
		_hovered_limbs.append(hovered_limb)
	_refresh_highlight()
	var top := _top_hovered_limb()
	if top != null:
		_show_limb_tooltip(top)

func _on_limb_mouse_exited(limb: CombatLimb) -> void:
	var hovered_limb := _resolve_hover_target(limb)
	if hovered_limb != null:
		_hovered_limbs.erase(hovered_limb)
	_refresh_highlight()
	var top := _top_hovered_limb()
	if top != null:
		_show_limb_tooltip(top)
	else:
		_tooltip_limb = null
		_hide_limb_tooltip()
		
func _top_hovered_limb() -> CombatLimb:
	var top: CombatLimb = null
	for limb in _hovered_limbs:
		if top == null:
			top = limb
			continue
		
		if _is_descendant_of(limb, top):
			top = limb
		elif _is_descendant_of(top, limb):
			pass
		else:
			if _get_relative_draw_order(limb, top) > 0:
				top = limb
				
	return top				

func _is_descendant_of(node: Node, potential_parent: Node) -> bool:
	var curr = node.get_parent()
	while curr != null:
		if curr == potential_parent:
			return true
		curr = curr.get_parent()
	return false

func _get_relative_draw_order(node_a: Node, node_b: Node) -> int:
	var path_a = _get_path_to_root(node_a)
	var path_b = _get_path_to_root(node_b)
	
	var i = 0
	while i < path_a.size() and i < path_b.size():
		if path_a[i] != path_b[i]:
			return path_a[i].get_index() - path_b[i].get_index()
		i += 1
	return 0

func _get_path_to_root(node: Node) -> Array[Node]:
	var path: Array[Node] = []
	var curr = node
	while curr != null:
		path.insert(0, curr)
		curr = curr.get_parent()
	return path

func _resolve_hover_target(limb: CombatLimb) -> CombatLimb:
	if limb == null or not is_instance_valid(limb) or limb.is_destroyed:
		return null
	return limb

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
	_clear_current_highlight_visuals()
	_refresh_spell_targeting_visuals()

func set_spell_targeting_preview(enabled: bool, whole_enemy: bool, spell_icon: Texture2D = null) -> void:
	_spell_targeting_enabled = enabled
	_spell_targeting_whole_enemy = whole_enemy and enabled
	_spell_targeting_icon = spell_icon
	_refresh_spell_targeting_visuals()

func _get_whole_enemy_indicator_limb() -> CombatLimb:
	for limb in limbs:
		if "show_whole_enemy_indicator" in limb and limb.show_whole_enemy_indicator and not limb.is_destroyed:
			return limb
	for limb in limbs:
		if limb.limb_name.to_lower() == "torso" and not limb.is_destroyed:
			return limb
	for limb in limbs:
		if limb.is_vital and not limb.is_destroyed:
			return limb
	for limb in limbs:
		if not limb.is_destroyed:
			return limb
	return null

func _refresh_spell_targeting_visuals() -> void:
	var whole_enemy_limb: CombatLimb = null
	if _spell_targeting_whole_enemy:
		whole_enemy_limb = _get_whole_enemy_indicator_limb()

	for limb in limbs:
		if limb == null or not is_instance_valid(limb):
			continue
		if _spell_targeting_whole_enemy:
			if limb == whole_enemy_limb:
				limb.set_spell_targeting_preview(true, _highlighted_limb != null, _spell_targeting_icon)
			else:
				limb.set_spell_targeting_preview(false, false, null)
		else:
			limb.set_spell_targeting_preview(_spell_targeting_enabled and limb.can_be_targeted, limb == _highlighted_limb, _spell_targeting_icon)



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
	if limb == null or not is_instance_valid(limb) or amount <= 0:
		return

	var remaining_damage := amount
	for target_limb in _get_damage_resolution_chain(limb):
		if remaining_damage <= 0:
			break
		if target_limb == null or not is_instance_valid(target_limb) or target_limb.is_destroyed:
			continue

		var health_before := target_limb.current_health
		target_limb.take_damage(remaining_damage)
		var damage_dealt := health_before - target_limb.current_health
		if damage_dealt <= 0:
			continue

		remaining_damage = maxi(0, remaining_damage - damage_dealt)

		if hit_sfx != null:
			SoundManager.play_sfx(hit_sfx)

		entity_took_damage.emit(self, target_limb, damage_dealt)


func _get_damage_resolution_chain(limb: CombatLimb) -> Array[CombatLimb]:
	if limb == null or not is_instance_valid(limb) or limb.is_destroyed:
		return []

	var child_limb := _get_first_alive_child_limb(limb)
	if child_limb == null:
		return [limb]

	var chain := _get_damage_resolution_chain(child_limb)
	chain.append(limb)
	return chain

func _get_first_alive_child_limb(limb: CombatLimb) -> CombatLimb:
	if limb == null or not is_instance_valid(limb):
		return null

	for child in limb.get_children():
		var child_limb := child as CombatLimb
		if child_limb != null and is_instance_valid(child_limb) and not child_limb.is_destroyed:
			return child_limb

	return null

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
	_hide_limb_tooltip()	
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
			limb.mark_destroyed_silent()
	_hide_limb_tooltip()		
	var started_vfx := _start_death_disintegrate()
	entity_died.emit(self)
	RunData.add_exp(exp_reward)
	RunData.coins += 15
	RunData.marrow_shards += marrow_shard_reward
	if not started_vfx and has_method("hide"):
		call("hide")

func _start_death_disintegrate() -> bool:
	if _death_started:
		return true
	if DEATH_DISSOLVE_SHADER == null:
		return false
	_death_started = true
	_death_materials.clear()

	var sprites := _get_death_sprites()
	if sprites.is_empty():
		return false

	for sprite in sprites:
		var material := ShaderMaterial.new()
		material.shader = DEATH_DISSOLVE_SHADER
		material.set_shader_parameter("dissolve", 0.0)
		material.set_shader_parameter("time", 0.0)
		sprite.material = material
		_death_materials.append(material)

	var tween := create_tween()
	var duration := 0.9
	tween.set_parallel(true)
	for material in _death_materials:
		tween.tween_property(material, "shader_parameter/dissolve", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(material, "shader_parameter/time", 0.6, duration)
	tween.set_parallel(false)
	tween.tween_interval(0.08)
	
	tween.finished.connect(func():
		if not is_instance_valid(self):
			return
		if self is CombatEntity:
			(self as CombatEntity).visible = false
	)
	return true

func _get_death_sprites() -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var node = stack.pop_back()
		if node is Sprite2D:
			result.append(node)
		for child in node.get_children():
			stack.append(child)
	return result

func _ensure_limb_tooltip() -> void:
	if _limb_tooltip != null:
		return

	_limb_tooltip = PanelContainer.new()
	_limb_tooltip.name = "LimbTooltip"
	_limb_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_limb_tooltip.z_index = 100
	_limb_tooltip.top_level = true
	_limb_tooltip.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.96)
	style.border_width_left   = 1
	style.border_width_right  = 1
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.35, 0.45, 0.6)
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left   = 14.0
	style.content_margin_right  = 14.0
	style.content_margin_top    = 10.0
	style.content_margin_bottom = 10.0
	
	_limb_tooltip.add_theme_stylebox_override("panel", style)

	_limb_tooltip_label = RichTextLabel.new()
	_limb_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_limb_tooltip_label.fit_content = true
	_limb_tooltip_label.scroll_active = false
	_limb_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_limb_tooltip_label.custom_minimum_size = Vector2(0, 0)
	_limb_tooltip_label.bbcode_enabled = true
	_limb_tooltip_label.add_theme_font_size_override("normal_font_size", 13)
	_limb_tooltip_label.add_theme_font_size_override("bold_font_size", 14)
	_limb_tooltip_label.add_theme_color_override("default_color", Color(0.92, 0.92, 0.95, 1.0))
	_limb_tooltip.add_child(_limb_tooltip_label)

	add_child(_limb_tooltip)

func _show_limb_tooltip(limb: CombatLimb, source_enemy: CombatEntity = null) -> void:	
	_ensure_limb_tooltip()
	_tooltip_limb = limb
	_was_shift_pressed = Input.is_key_pressed(KEY_SHIFT)

	var hp_color := _hp_color_for_limb(limb)
	var hp_hex   := hp_color.to_html(false)

	var hit_chance := limb.hit_chance_percent
	var manager := _find_combat_manager()
	
	if manager != null and manager.has_method("_get_adjusted_hit_chance_percent"):
		hit_chance = manager._get_adjusted_hit_chance_percent(limb, source_enemy)

	var hit_color: Color
	if hit_chance >= 75.0:
		hit_color = Color(0.35, 1.0, 0.45, 1.0)
	elif hit_chance >= 45.0:
		hit_color = Color(1.0, 0.82, 0.22, 1.0)
	else:
		hit_color = Color(1.0, 0.38, 0.38, 1.0)
	var hit_hex := hit_color.to_html(false)

	var t := "[b][font_size=15]%s[/font_size][/b]" % limb.limb_name

	t += "\nHealth: [color=#%s]%d / %d[/color]" % [hp_hex, limb.current_health, limb.max_health]
	if _was_shift_pressed:
		t += "\n[color=#8a8a9e][font_size=11]  - Health of this limb. Breaks at 0 HP.[/font_size][/color]"

	t += "\nHit Chance: [color=#%s]%.0f%%[/color]" % [hit_hex, hit_chance]
	if _was_shift_pressed:
		t += "\n[color=#8a8a9e][font_size=11]  - Your chance to successfully hit this limb.[/font_size][/color]"

	if limb.physical_defense > 0.0:
		t += "\nPhys Def: [color=#cccccc]%.0f%%[/color]" % limb.physical_defense
		if _was_shift_pressed:
			t += "\n[color=#8a8a9e][font_size=11]  - Reduces incoming physical damage.[/font_size][/color]"

	if limb.magic_defense > 0.0:
		t += "\nMagic Def: [color=#cccccc]%.0f%%[/color]" % limb.magic_defense
		if _was_shift_pressed:
			t += "\n[color=#8a8a9e][font_size=11]  - Reduces incoming magic damage.[/font_size][/color]"

	if limb.is_vital:
		t += "\n[color=#ffaa00][b]VITAL[/b][/color]"
		if _was_shift_pressed:
			t += "\n[color=#8a8a9e][font_size=11]  - Destroying this limb kills the enemy instantly.[/font_size][/color]"
			t += "\n[color=#8a8a9e][font_size=11]  - If only vital limbs remain, all hit chances become 100%.[/font_size][/color]"

	if manager != null and manager.has_method("get_limb_intent_tooltip"):
		var intent_text: String = manager.get_limb_intent_tooltip(self, limb)
		if not intent_text.is_empty():
			t += intent_text


	if not _was_shift_pressed:
		t += "\n[color=#5a5a6a][font_size=10][i]Hold Shift for more info[/i][/font_size][/color]"

	_limb_tooltip_label.text = ""
	_limb_tooltip.reset_size()
	_limb_tooltip_label.text = t
	_limb_tooltip.visible = true
	_update_limb_tooltip_position()


func _hide_limb_tooltip() -> void:
	if _limb_tooltip != null:
		_limb_tooltip.visible = false

func _update_limb_tooltip_position() -> void:
	if _limb_tooltip == null or not _limb_tooltip.visible:
		return
	var vp_size  := get_viewport().get_visible_rect().size
	var mouse    := get_viewport().get_mouse_position()
	var tip_size := _limb_tooltip.size

	var has_spell_cursor := false
	var manager := _find_combat_manager()
	if manager != null:
		var overlay := manager.get_node_or_null("SpellCursorOverlay")
		if overlay is TextureRect and (overlay as TextureRect).visible:
			has_spell_cursor = true

	var pos: Vector2
	if has_spell_cursor:
		pos = mouse + Vector2(-tip_size.x * 0.5, -tip_size.y - 18.0)
	else:
		pos = mouse + Vector2(14.0, -8.0)

	pos.x = clamp(pos.x, 0.0, vp_size.x - tip_size.x)
	pos.y = clamp(pos.y, 0.0, vp_size.y - tip_size.y)
	_limb_tooltip.global_position = pos

func _find_combat_manager() -> Node:
	var node := get_parent()
	while node != null:
		if node is CombatManager:
			return node
		node = node.get_parent()
	return null
	
func _hp_color_for_limb(limb: CombatLimb) -> Color:
	var pct := limb.get_health_percent()
	if pct > 0.6:
		return Color(0.35, 1.0, 0.45, 1.0)  
	elif pct > 0.3:
		return Color(1.0, 0.82, 0.22, 1.0)   
	else:
		return Color(1.0, 0.28, 0.28, 1.0)
