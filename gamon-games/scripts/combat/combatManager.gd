class_name CombatManager
extends CanvasLayer

const TURN_ORDER_ENTRY_SCENE := preload("res://Scenes/combat/ui/TurnOrderEntry.tscn")
const SPELL_BUTTON_SCENE := preload("res://Scenes/combat/ui/SpellButton.tscn")
const BUFF_ICON_SCENE := preload("res://Scenes/combat/ui/BuffIcon.tscn")

enum CombatState { 
	PLAYER_TURN,
	ENEMY_TURN,
	COMBAT_OVER,
}

enum CombatAction {
	ATTACK,
}

enum TargetScope {
	LIMB,
	WHOLE_ENEMY,
}

@export var player_base_damage: int = 25
@export var enemy_entity_path: NodePath
@export var enemy_container_path: NodePath = NodePath("HBoxContainer")
@export var ui_player: NodePath = NodePath("Player")
@export var turns_order_path: NodePath = NodePath("TurnsOrder")
@export var player_turn_icon: Texture2D
@export var turns_order_row_height: float = 24.0
@export var turns_order_min_visible_rows: int = 8
@export var player_max_health: int = 100
@export_range(0.0, 100.0, 0.1) var player_hit_chance_bonus_percent: float = 20.0
@export var attack_target_scope: TargetScope = TargetScope.LIMB
@export var debuff_target_scope: TargetScope = TargetScope.LIMB

var current_state: CombatState = CombatState.PLAYER_TURN
var selected_action: CombatAction = CombatAction.ATTACK
var enemy_entities: Array[CombatEntity] = []
var player_health: int = player_max_health
var _queued_encounter_scenes: Array[PackedScene] = []
var _enemy_targeting_enabled: bool = false
var _whole_enemy_highlight_enabled: bool = false
var _attack_selected: bool = false
var current_round: int = 1
var selected_spell: SpellData = null
var _player_effects: Array[Dictionary] = []
var _enemy_effects: Dictionary = {}
var _enemy_limb_effects: Dictionary = {}
var _spell_buttons: Array[Button] = []
var _button_spells: Dictionary = {}

signal enemy_targeting_changed(enabled: bool, highlight_whole_enemy: bool)

@onready var spells_panel: HBoxContainer = $SpellsPanel
@onready var lbl_player_health: Label = $PlayerHealth
@onready var lbl_turns_order: Label = $TurnsOrderInfo
@onready var turns_order_container: VBoxContainer = $TurnsOrder
@onready var player_buffs_panel: HBoxContainer = get_node_or_null("BuffsPanel") as HBoxContainer
@onready var attack_scope_option: OptionButton = get_node_or_null("TargetingPanel/AttackScopeOption") as OptionButton
@onready var debuff_scope_option: OptionButton = get_node_or_null("TargetingPanel/DebuffScopeOption") as OptionButton

func _ready() -> void:
	if _queued_encounter_scenes.size() > 0:
		_spawn_encounter_enemies(_queued_encounter_scenes)

	current_round = 1
	_refresh_enemy_entities()
	_reset_combat_effects()
	_refresh_enemy_buffs_ui()
	_refresh_player_buffs_ui()
	_update_player_health_label()
	_rebuild_spells_panel()
	_setup_target_scope_selectors()

	RunData.health_changed.connect(_update_player_health_label)
	_begin_player_turn()

func setup_encounter(encounter_enemy_scenes: Array[PackedScene]) -> void:
	_queued_encounter_scenes = encounter_enemy_scenes.duplicate()
	current_round = 1
	if not is_node_ready():
		return

	_spawn_encounter_enemies(_queued_encounter_scenes)
	_refresh_enemy_entities()
	_reset_combat_effects()
	_refresh_enemy_buffs_ui()
	_refresh_player_buffs_ui()
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

	var on_targeting_changed := Callable(entity, "set_targeting_mode")
	if not enemy_targeting_changed.is_connected(on_targeting_changed):
		enemy_targeting_changed.connect(on_targeting_changed)
	entity.set_targeting_mode(_enemy_targeting_enabled, _whole_enemy_highlight_enabled)

func _get_alive_enemies() -> Array[CombatEntity]:
	var alive_enemies: Array[CombatEntity] = []
	for entity in enemy_entities:
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() and entity.is_alive:
			alive_enemies.append(entity)
	return alive_enemies

func _has_alive_enemies() -> bool:
	return _get_alive_enemies().size() > 0

func select_attack() -> void:
	_select_spell(null)

func _select_spell(spell: SpellData) -> void:
	if current_state != CombatState.PLAYER_TURN or not _has_alive_enemies():
		return
	if spell != null and spell.spell_type == SpellData.SpellType.BUFF:
		_append_player_effect(spell)
		_play_attack_feedback(spell, null, null)
		_attack_selected = false
		selected_spell = null
		_end_player_turn()
		return
	if spell != null and spell.spell_type == SpellData.SpellType.HEAL:
		_apply_player_heal(spell.heal_amount)
		_play_attack_feedback(spell, null, null)
		_attack_selected = false
		selected_spell = null
		_end_player_turn()
		return

	selected_spell = spell
	selected_action = CombatAction.ATTACK
	_attack_selected = true
	_set_enemy_targeting_enabled(true)
	_update_button_states()

func _rebuild_spells_panel() -> void:
	for child in spells_panel.get_children():
		child.queue_free()

	_spell_buttons.clear()
	_button_spells.clear()

	for spell in RunData.spells:
		if spell == null:
			continue

		var spell_button := SPELL_BUTTON_SCENE.instantiate() as Button
		spell_button.name = "BtnSpell_%s" % (spell.spell_id if not spell.spell_id.is_empty() else str(_spell_buttons.size()))
		spells_panel.add_child(spell_button)
		_configure_spell_button(spell_button, spell)
		_spell_buttons.append(spell_button)
		_button_spells[spell_button] = spell

func _configure_spell_button(button: Button, spell: SpellData) -> void:
	button.text = spell.spell_name if spell != null and not spell.spell_name.is_empty() else "Attack"
	button.tooltip_text = button.text
	if spell != null and spell.icon != null:
		button.icon = spell.icon

	var on_pressed := Callable(self, "_on_spell_button_pressed").bind(button)
	if not button.pressed.is_connected(on_pressed):
		button.pressed.connect(on_pressed)

func _on_spell_button_pressed(button: Button) -> void:
	var spell := _button_spells.get(button, null) as SpellData
	_select_spell(spell)

func _update_button_states() -> void:
	var should_disable_buttons := current_state != CombatState.PLAYER_TURN or _attack_selected or not _has_alive_enemies()
	for spell_button in _spell_buttons:
		if is_instance_valid(spell_button):
			spell_button.disabled = should_disable_buttons

func _on_enemy_limb_clicked(limb: CombatLimb, source_enemy: CombatEntity) -> void:
	if current_state != CombatState.PLAYER_TURN:
		return
	if not _attack_selected:
		return
	if source_enemy == null or not is_instance_valid(source_enemy) or not source_enemy.is_alive:
		return
	if limb.is_destroyed:
		return

	var target_limbs := _get_target_limbs(source_enemy, limb, selected_spell)
	if target_limbs.is_empty():
		return

	var active_spell := selected_spell
	if _roll_player_hit_on_limb(limb):
		var spell_damage := 0
		var spell_type := SpellData.SpellType.ATTACK
		var attack_damage_type := SpellData.DamageType.PHYSICAL
		var can_deal_damage := true
		if active_spell != null:
			spell_damage = active_spell.damage
			spell_type = active_spell.spell_type
			attack_damage_type = active_spell.damage_type
			can_deal_damage = active_spell.damage > 0

		if can_deal_damage and (spell_type == SpellData.SpellType.ATTACK or spell_type == SpellData.SpellType.DEBUFF):
			var player_modifiers := _get_player_outgoing_modifiers()
			var outgoing_multiplier := float(player_modifiers.get("mult", 1.0))
			var outgoing_flat := int(player_modifiers.get("flat", 0))
			var raw_damage = RunData.get_stat("damage") + spell_damage + outgoing_flat
			for target_limb in target_limbs:
				if target_limb.is_destroyed:
					continue
				var incoming_multiplier := _get_enemy_incoming_multiplier(source_enemy, target_limb)
				var final_damage := int(round(float(raw_damage) * outgoing_multiplier * incoming_multiplier))
				var enemy_defense := _get_enemy_total_defense_for_damage_type(source_enemy, target_limb, attack_damage_type)
				final_damage = _apply_defense_to_damage(final_damage, enemy_defense)
				final_damage = max(0, final_damage)
				if final_damage > 0:
					source_enemy.take_damage(target_limb, final_damage)

		if active_spell != null and active_spell.spell_type == SpellData.SpellType.DEBUFF:
			_append_enemy_effect(source_enemy, active_spell, limb)

		if active_spell != null:
			_play_attack_feedback(active_spell, null, source_enemy)
	else:
		print("Player missed %s (%s%% hit chance)" % [limb.limb_name, snappedf(limb.hit_chance_percent, 0.1)])
		
		DialogueManager.start_dialogue([
			{
			"speaker": "System",
			"text": "Player missed %s (%s%% hit chance)" % [limb.limb_name, snappedf(limb.hit_chance_percent, 0.1)]	
			}
		], "combat")
	
		print("Player missed %s (%s%% hit chance)" % [limb.limb_name, snappedf(_get_adjusted_hit_chance_percent(limb), 0.1)])
	_attack_selected = false
	selected_spell = null
	source_enemy.clear_current_highlight()
	_end_player_turn()

func _get_adjusted_hit_chance_percent(limb: CombatLimb) -> float:
	if limb == null or not is_instance_valid(limb):
		return 0.0
	return clampf(limb.hit_chance_percent + player_hit_chance_bonus_percent, 0.0, 100.0)

func _roll_player_hit_on_limb(limb: CombatLimb) -> bool:
	return randf() * 100.0 < _get_adjusted_hit_chance_percent(limb)

func _on_enemy_died(_entity: CombatEntity) -> void:
	if _entity != null and is_instance_valid(_entity):
		_enemy_effects.erase(_entity.get_instance_id())
		_enemy_limb_effects.erase(_entity.get_instance_id())
		_refresh_enemy_buffs_ui()

	if _has_alive_enemies():
		_refresh_turns_order_ui()
		return

	current_state = CombatState.COMBAT_OVER
	_update_button_states()
	_refresh_turns_order_ui()
	NavigationManager.go_back_to_current_room()

func _setup_target_scope_selectors() -> void:
	if attack_scope_option != null:
		attack_scope_option.clear()
		attack_scope_option.add_item("Limb", TargetScope.LIMB)
		attack_scope_option.add_item("Whole Enemy", TargetScope.WHOLE_ENEMY)
		_select_option_by_id(attack_scope_option, int(attack_target_scope))
		var on_attack_scope_selected := Callable(self, "_on_attack_scope_selected")
		if not attack_scope_option.item_selected.is_connected(on_attack_scope_selected):
			attack_scope_option.item_selected.connect(on_attack_scope_selected)

	if debuff_scope_option != null:
		debuff_scope_option.clear()
		debuff_scope_option.add_item("Limb", TargetScope.LIMB)
		debuff_scope_option.add_item("Whole Enemy", TargetScope.WHOLE_ENEMY)
		_select_option_by_id(debuff_scope_option, int(debuff_target_scope))
		var on_debuff_scope_selected := Callable(self, "_on_debuff_scope_selected")
		if not debuff_scope_option.item_selected.is_connected(on_debuff_scope_selected):
			debuff_scope_option.item_selected.connect(on_debuff_scope_selected)

func _select_option_by_id(option_button: OptionButton, target_id: int) -> void:
	if option_button == null:
		return
	for index in range(option_button.item_count):
		if option_button.get_item_id(index) == target_id:
			option_button.select(index)
			return
	if option_button.item_count > 0:
		option_button.select(0)

func _on_attack_scope_selected(index: int) -> void:
	if attack_scope_option == null:
		return
	attack_target_scope = attack_scope_option.get_item_id(index) as TargetScope

func _on_debuff_scope_selected(index: int) -> void:
	if debuff_scope_option == null:
		return
	debuff_target_scope = debuff_scope_option.get_item_id(index) as TargetScope

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
		await _play_attack_feedback(attack, attacking_enemy, null)
		var outgoing_multiplier := _get_enemy_outgoing_multiplier(attacking_enemy)
		var damage: int = int(round(float(max(0, attack.damage)) * outgoing_multiplier))
		_apply_player_damage(damage, attack.damage_type)

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

func _reset_combat_effects() -> void:
	_player_effects.clear()
	_enemy_effects.clear()
	_enemy_limb_effects.clear()
	_refresh_enemy_buffs_ui()
	_refresh_player_buffs_ui()

func _get_effect_expiry_round(spell: SpellData) -> int:
	if spell == null:
		return current_round
	return current_round + max(1, spell.duration_rounds) - 1

func _extend_effect_expiry_round(existing_expires_round: int, spell: SpellData) -> int:
	if spell == null:
		return existing_expires_round
	var extension_rounds: int = maxi(1, spell.duration_rounds)
	var base_round: int = maxi(existing_expires_round, current_round - 1)
	return base_round + extension_rounds

func _is_same_player_effect(effect: Dictionary, spell: SpellData) -> bool:
	if effect.is_empty() or spell == null:
		return false
	if spell.spell_id.is_empty():
		return false
	return String(effect.get("spell_id", "")) == spell.spell_id

func _is_same_enemy_effect(effect: Dictionary, spell: SpellData) -> bool:
	if effect.is_empty() or spell == null:
		return false
	if spell.spell_id.is_empty():
		return false
	return String(effect.get("spell_id", "")) == spell.spell_id

func _cleanup_expired_effects() -> void:
	_player_effects = _filter_active_effects(_player_effects)

	var cleaned_enemy_effects: Dictionary = {}
	for enemy_id in _enemy_effects.keys():
		var enemy_effects: Array = _enemy_effects.get(enemy_id, [])
		var active_effects := _filter_active_effects(enemy_effects)
		if not active_effects.is_empty():
			cleaned_enemy_effects[enemy_id] = active_effects

	_enemy_effects = cleaned_enemy_effects

	var cleaned_enemy_limb_effects: Dictionary = {}
	for enemy_id in _enemy_limb_effects.keys():
		var raw_limb_effects := _enemy_limb_effects.get(enemy_id, {}) as Dictionary
		var cleaned_limb_effects: Dictionary = {}
		for limb_id in raw_limb_effects.keys():
			var limb_effects: Array = raw_limb_effects.get(limb_id, [])
			var active_limb_effects := _filter_active_effects(limb_effects)
			if not active_limb_effects.is_empty():
				cleaned_limb_effects[limb_id] = active_limb_effects
		if not cleaned_limb_effects.is_empty():
			cleaned_enemy_limb_effects[enemy_id] = cleaned_limb_effects

	_enemy_limb_effects = cleaned_enemy_limb_effects

func _filter_active_effects(effects: Array) -> Array[Dictionary]:
	var active_effects: Array[Dictionary] = []
	for raw_effect in effects:
		var effect := raw_effect as Dictionary
		if effect.is_empty():
			continue
		var expires_round := int(effect.get("expires_round", current_round))
		if current_round <= expires_round:
			active_effects.append(effect)
	return active_effects

func _append_player_effect(spell: SpellData) -> void:
	if spell == null:
		return

	var has_effect := spell.outgoing_damage_flat_bonus != 0 \
		or not is_zero_approx(spell.outgoing_damage_multiplier_delta) \
		or not is_zero_approx(spell.player_physical_defense_delta) \
		or not is_zero_approx(spell.player_magic_defense_delta)
	if not has_effect:
		return

	var effect_expires_round := _get_effect_expiry_round(spell)
	for index in range(_player_effects.size()):
		var existing_effect := _player_effects[index] as Dictionary
		if not _is_same_player_effect(existing_effect, spell):
			continue
		existing_effect["expires_round"] = _extend_effect_expiry_round(int(existing_effect.get("expires_round", current_round)), spell)
		_player_effects[index] = existing_effect
		_refresh_player_buffs_ui()
		return

	_player_effects.append({
		"expires_round": effect_expires_round,
		"spell_id": spell.spell_id,
		"spell_name": spell.spell_name,
		"spell_type": int(spell.spell_type),
		"icon": spell.icon,
		"outgoing_flat": spell.outgoing_damage_flat_bonus,
		"outgoing_mult_delta": spell.outgoing_damage_multiplier_delta,
		"physical_defense_delta": spell.player_physical_defense_delta,
		"magic_defense_delta": spell.player_magic_defense_delta,
	})

	_refresh_player_buffs_ui()

func _append_enemy_effect(target_enemy: CombatEntity, spell: SpellData, target_limb: CombatLimb = null) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy) or spell == null:
		return

	var has_effect := not is_zero_approx(spell.outgoing_damage_multiplier_delta) \
		or not is_zero_approx(spell.incoming_damage_multiplier_delta) \
		or not is_zero_approx(spell.target_physical_defense_delta) \
		or not is_zero_approx(spell.target_magic_defense_delta)
	if not has_effect:
		return

	var effect_expires_round := _get_effect_expiry_round(spell)

	var effect_data := {
		"expires_round": effect_expires_round,
		"spell_id": spell.spell_id,
		"outgoing_mult_delta": spell.outgoing_damage_multiplier_delta,
		"incoming_mult_delta": spell.incoming_damage_multiplier_delta,
		"physical_defense_delta": spell.target_physical_defense_delta,
		"magic_defense_delta": spell.target_magic_defense_delta,
		"spell_name": spell.spell_name,
		"spell_type": int(spell.spell_type),
		"icon": spell.icon,
	}

	var enemy_id := target_enemy.get_instance_id()
	if _resolve_target_scope(spell) == TargetScope.WHOLE_ENEMY:
		var enemy_effects: Array = _enemy_effects.get(enemy_id, [])
		for index in range(enemy_effects.size()):
			var existing_effect := enemy_effects[index] as Dictionary
			if not _is_same_enemy_effect(existing_effect, spell):
				continue
			existing_effect["expires_round"] = _extend_effect_expiry_round(int(existing_effect.get("expires_round", current_round)), spell)
			enemy_effects[index] = existing_effect
			_enemy_effects[enemy_id] = enemy_effects
			_refresh_enemy_buffs_ui()
			return
		enemy_effects.append(effect_data)
		_enemy_effects[enemy_id] = enemy_effects
		_refresh_enemy_buffs_ui()
		return

	if target_limb == null or not is_instance_valid(target_limb):
		return

	var limb_id := target_limb.get_instance_id()
	var limb_effects_by_enemy := _enemy_limb_effects.get(enemy_id, {}) as Dictionary
	var limb_effects: Array = limb_effects_by_enemy.get(limb_id, [])
	for index in range(limb_effects.size()):
		var existing_effect := limb_effects[index] as Dictionary
		if not _is_same_enemy_effect(existing_effect, spell):
			continue
		existing_effect["expires_round"] = _extend_effect_expiry_round(int(existing_effect.get("expires_round", current_round)), spell)
		limb_effects[index] = existing_effect
		limb_effects_by_enemy[limb_id] = limb_effects
		_enemy_limb_effects[enemy_id] = limb_effects_by_enemy
		_refresh_enemy_buffs_ui()
		return
	limb_effects.append(effect_data)
	limb_effects_by_enemy[limb_id] = limb_effects
	_enemy_limb_effects[enemy_id] = limb_effects_by_enemy
	_refresh_enemy_buffs_ui()

func _collect_enemy_effects_for_ui(enemy: CombatEntity) -> Array[Dictionary]:
	if enemy == null or not is_instance_valid(enemy):
		return []

	var all_effects: Array[Dictionary] = []
	var enemy_id := enemy.get_instance_id()

	var enemy_effects: Array = _enemy_effects.get(enemy_id, [])
	for raw_effect in enemy_effects:
		var effect := raw_effect as Dictionary
		if effect.is_empty():
			continue
		all_effects.append(effect)

	var limb_effects_by_enemy := _enemy_limb_effects.get(enemy_id, {}) as Dictionary
	for limb_id in limb_effects_by_enemy.keys():
		var limb_effects: Array = limb_effects_by_enemy.get(limb_id, [])
		for raw_effect in limb_effects:
			var effect := raw_effect as Dictionary
			if effect.is_empty():
				continue
			all_effects.append(effect)

	return all_effects

func _refresh_enemy_buffs_ui() -> void:
	for enemy in enemy_entities:
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue

		var buffs_panel := enemy.get_node_or_null("BuffsPanel") as HBoxContainer
		if buffs_panel == null:
			continue

		for child in buffs_panel.get_children():
			child.queue_free()

		for effect in _collect_enemy_effects_for_ui(enemy):
			var buff_icon := BUFF_ICON_SCENE.instantiate() as Panel
			if buff_icon == null:
				continue

			var icon_rect := buff_icon.get_node_or_null("Icon") as TextureRect
			if icon_rect == null:
				continue

			var count_label := buff_icon.get_node_or_null("Count") as Label
			if count_label == null:
				continue

			var icon_texture := effect.get("icon", null) as Texture2D
			if icon_texture != null and icon_rect != null:
				icon_rect.texture = icon_texture

			var effect_name := String(effect.get("spell_name", "Effect"))
			var expires_round := int(effect.get("expires_round", current_round))
			var turns_remaining: int = int(max(1, expires_round - current_round + 1))
			var turn_suffix := "s" if turns_remaining != 1 else ""
			buff_icon.tooltip_text = "%s (%d turn%s)" % [effect_name, turns_remaining, turn_suffix]
			if count_label != null:
				count_label.text = str(turns_remaining)

			if int(effect.get("spell_type", SpellData.SpellType.DEBUFF)) == int(SpellData.SpellType.DEBUFF):
				if icon_rect != null:
					icon_rect.modulate = Color(1.0, 0.85, 0.85, 1.0)
			else:
				if icon_rect != null:
					icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)

			buffs_panel.add_child(buff_icon)

func _refresh_player_buffs_ui() -> void:
	if player_buffs_panel == null:
		return

	for child in player_buffs_panel.get_children():
		child.queue_free()

	for effect in _player_effects:
		var buff_icon := BUFF_ICON_SCENE.instantiate() as Panel
		if buff_icon == null:
			continue

		var icon_rect := buff_icon.get_node_or_null("Icon") as TextureRect
		if icon_rect == null:
			continue

		var count_label := buff_icon.get_node_or_null("Count") as Label
		if count_label == null:
			continue

		var icon_texture := effect.get("icon", null) as Texture2D
		if icon_texture != null:
			icon_rect.texture = icon_texture

		var effect_name := String(effect.get("spell_name", "Effect"))
		var expires_round := int(effect.get("expires_round", current_round))
		var turns_remaining: int = int(max(1, expires_round - current_round + 1))
		var turn_suffix := "s" if turns_remaining != 1 else ""
		buff_icon.tooltip_text = "%s (%d turn%s)" % [effect_name, turns_remaining, turn_suffix]
		count_label.text = str(turns_remaining)
		icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)

		player_buffs_panel.add_child(buff_icon)

func _get_player_outgoing_modifiers() -> Dictionary:
	_cleanup_expired_effects()

	var total_flat := 0
	var total_multiplier := 1.0
	for effect in _player_effects:
		total_flat += int(effect.get("outgoing_flat", 0))
		total_multiplier += float(effect.get("outgoing_mult_delta", 0.0))

	return {
		"flat": total_flat,
		"mult": max(0.0, total_multiplier),
	}

func _get_enemy_outgoing_multiplier(source_enemy: CombatEntity) -> float:
	if source_enemy == null or not is_instance_valid(source_enemy):
		return 1.0

	_cleanup_expired_effects()

	var total_multiplier := 1.0
	var enemy_effects: Array = _enemy_effects.get(source_enemy.get_instance_id(), [])
	for raw_effect in enemy_effects:
		var effect := raw_effect as Dictionary
		total_multiplier += float(effect.get("outgoing_mult_delta", 0.0))

	return max(0.0, total_multiplier)

func _get_enemy_incoming_multiplier(source_enemy: CombatEntity, source_limb: CombatLimb = null) -> float:
	if source_enemy == null or not is_instance_valid(source_enemy):
		return 1.0

	_cleanup_expired_effects()

	var total_multiplier := 1.0
	var enemy_effects: Array = _enemy_effects.get(source_enemy.get_instance_id(), [])
	for raw_effect in enemy_effects:
		var effect := raw_effect as Dictionary
		total_multiplier += float(effect.get("incoming_mult_delta", 0.0))

	if source_limb != null and is_instance_valid(source_limb):
		var limb_effects_by_enemy := _enemy_limb_effects.get(source_enemy.get_instance_id(), {}) as Dictionary
		var limb_effects: Array = limb_effects_by_enemy.get(source_limb.get_instance_id(), [])
		for raw_effect in limb_effects:
			var effect := raw_effect as Dictionary
			total_multiplier += float(effect.get("incoming_mult_delta", 0.0))

	return max(0.0, total_multiplier)

func _resolve_target_scope(spell: SpellData) -> TargetScope:
	if spell != null:
		return spell.target_scope as TargetScope
	return attack_target_scope

func _is_whole_enemy_targeting() -> bool:
	if not _attack_selected:
		return false
	return _resolve_target_scope(selected_spell) == TargetScope.WHOLE_ENEMY

func _get_target_limbs(source_enemy: CombatEntity, hovered_limb: CombatLimb, spell: SpellData) -> Array[CombatLimb]:
	if source_enemy == null or not is_instance_valid(source_enemy):
		return []
	if hovered_limb == null or not is_instance_valid(hovered_limb):
		return []

	if _resolve_target_scope(spell) == TargetScope.LIMB:
		return [hovered_limb]

	var target_limbs: Array[CombatLimb] = []
	for limb in source_enemy.limbs:
		if limb != null and is_instance_valid(limb) and not limb.is_destroyed:
			target_limbs.append(limb)
	return target_limbs

func _apply_player_damage(amount: int, damage_type: SpellData.DamageType = SpellData.DamageType.PHYSICAL) -> void:
	if current_state == CombatState.COMBAT_OVER:
		return
	if amount <= 0:
		return
	var mitigated_amount := _apply_player_defense(amount, damage_type)
	if mitigated_amount <= 0:
		return
	_flash_player_hit()
	RunData.current_health -= mitigated_amount 
	if RunData.current_health <= 0:
		current_state = CombatState.COMBAT_OVER
	print("Player took %d damage — HP: %d/%d" % [amount, RunData.current_health, RunData.max_health])
	
	DialogueManager.start_dialogue([
		{
			"speaker": "System",
			"text": "Player took %d damage — HP: %d/%d" % [amount, RunData.current_health, RunData.max_health]
		}
	], "combat")
	print("Player took %d damage — HP: %d/%d" % [mitigated_amount, RunData.current_health, RunData.max_health])

func _apply_player_defense(amount: int, damage_type: SpellData.DamageType) -> int:
	var defense := _get_player_defense_for_damage_type(damage_type)
	return _apply_defense_to_damage(amount, defense)

func _get_player_defense_for_damage_type(damage_type: SpellData.DamageType) -> float:
	_cleanup_expired_effects()

	var total_defense := 0.0
	match damage_type:
		SpellData.DamageType.MAGIC:
			total_defense = float(RunData.get_stat("magic_defense"))
			for effect in _player_effects:
				var expires_round := int(effect.get("expires_round", current_round))
				if current_round <= expires_round:
					total_defense += float(effect.get("magic_defense_delta", 0.0))
		_:
			total_defense = float(RunData.get_stat("physical_defense"))
			for effect in _player_effects:
				var expires_round := int(effect.get("expires_round", current_round))
				if current_round <= expires_round:
					total_defense += float(effect.get("physical_defense_delta", 0.0))

	return max(0.0, total_defense)

func _get_enemy_total_defense_for_damage_type(source_enemy: CombatEntity, source_limb: CombatLimb, damage_type: SpellData.DamageType) -> float:
	if source_enemy == null or not is_instance_valid(source_enemy):
		return 0.0

	_cleanup_expired_effects()

	var total_defense := source_enemy.get_defense_for_damage_type(damage_type)
	if source_limb != null and is_instance_valid(source_limb):
		total_defense += source_limb.get_defense_for_damage_type(damage_type)

	var defense_key := "physical_defense_delta"
	if damage_type == SpellData.DamageType.MAGIC:
		defense_key = "magic_defense_delta"

	var enemy_effects: Array = _enemy_effects.get(source_enemy.get_instance_id(), [])
	for raw_effect in enemy_effects:
		var effect := raw_effect as Dictionary
		var expires_round := int(effect.get("expires_round", current_round))
		if current_round <= expires_round:
			total_defense += float(effect.get(defense_key, 0.0))

	if source_limb != null and is_instance_valid(source_limb):
		var limb_effects_by_enemy := _enemy_limb_effects.get(source_enemy.get_instance_id(), {}) as Dictionary
		var limb_effects: Array = limb_effects_by_enemy.get(source_limb.get_instance_id(), [])
		for raw_effect in limb_effects:
			var effect := raw_effect as Dictionary
			var expires_round := int(effect.get("expires_round", current_round))
			if current_round <= expires_round:
				total_defense += float(effect.get(defense_key, 0.0))

	return max(0.0, total_defense)

func _apply_defense_to_damage(raw_damage: int, defense: float) -> int:
	if raw_damage <= 0:
		return 0
	var defense_percent := clampf(defense, 0.0, 100.0)
	var mitigated := float(raw_damage) * (1.0 - (defense_percent / 100.0))
	return int(round(mitigated))

func _apply_player_heal(amount: int) -> void:
	if amount <= 0:
		return
	if current_state == CombatState.COMBAT_OVER:
		return
	var previous_health = RunData.current_health
	RunData.current_health = min(RunData.max_health, RunData.current_health + amount)
	var healed_amount = RunData.current_health - previous_health
	if healed_amount > 0:
		print("Player healed %d HP — HP: %d/%d" % [healed_amount, RunData.current_health, RunData.max_health])

func _flash_player_hit() -> void:
	var player_anchor := get_node_or_null(ui_player)
	if not (player_anchor is CanvasItem):
		return

	var player_canvas := player_anchor as CanvasItem
	var tween := create_tween()
	tween.tween_property(player_canvas, "modulate", Color(1.7, 1.7, 1.7, 1.0), 0.18)
	tween.tween_property(player_canvas, "modulate", Color(1, 1, 1, 1), 0.22)

func _play_attack_feedback(attack: SpellData, source_entity: Node = null, target_entity: Node = null) -> void:
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
		add_child(vfx)
		vfx.global_position = _resolve_vfx_position(attack, source_entity, target_entity) + attack.vfx_offset
		if attack.vfx_lifetime > 0.0:
			vfx_lifetime_timer = get_tree().create_timer(attack.vfx_lifetime)
			vfx_lifetime_timer.timeout.connect(vfx.queue_free)

	if vfx_lifetime_timer != null:
		await vfx_lifetime_timer.timeout

func _resolve_vfx_position(attack: SpellData, source_entity: Node = null, target_entity: Node = null) -> Vector2:
	match attack.vfx_anchor:
		SpellData.VfxAnchor.SELF:
			var source_position = _get_vfx_anchor_position(source_entity)
			if source_position != null:
				return source_position
		SpellData.VfxAnchor.TARGET:
			var target_position = _get_vfx_anchor_position(target_entity)
			if target_position != null:
				return target_position

	return get_viewport().get_visible_rect().size * 0.5

func _get_vfx_anchor_position(anchor_node: Node) -> Variant:
	if anchor_node == null or not is_instance_valid(anchor_node):
		var player_anchor := get_node_or_null(ui_player)
		if player_anchor is CanvasItem:
			return (player_anchor as CanvasItem).global_position
		return null

	if anchor_node is CanvasItem:
		return (anchor_node as CanvasItem).global_position

	if anchor_node is CombatEntity:
		return (anchor_node as CombatEntity).global_position

	return null

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
	_cleanup_expired_effects()
	_refresh_enemy_buffs_ui()
	_refresh_player_buffs_ui()
	_attack_selected = false
	selected_spell = null
	_set_enemy_targeting_enabled(false)
	_update_button_states()
	_refresh_turns_order_ui()

func _set_enemy_targeting_enabled(enabled: bool) -> void:
	var highlight_whole_enemy := enabled and _is_whole_enemy_targeting()
	if _enemy_targeting_enabled == enabled and _whole_enemy_highlight_enabled == highlight_whole_enemy:
		return
	_enemy_targeting_enabled = enabled
	_whole_enemy_highlight_enabled = highlight_whole_enemy
	enemy_targeting_changed.emit(enabled, highlight_whole_enemy)

func _update_player_health_label() -> void:
	lbl_player_health.text = "HP: %d/%d" % [RunData.current_health, RunData.max_health]

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
