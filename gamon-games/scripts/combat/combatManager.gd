class_name CombatManager
extends CanvasLayer

const TURN_ORDER_ENTRY_SCENE := preload("res://scenes/combat/ui/TurnOrderEntry.tscn")
const SPELL_BUTTON_SCENE := preload("res://scenes/combat/ui/SpellButton.tscn")
const BUFF_ICON_SCENE := preload("res://scenes/combat/ui/BuffIcon.tscn")
const COMBAT_SUMMARY_SCENE := preload("res://scenes/combat/ui/combat_summary.tscn")

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
	ALL_ENEMIES,
}

@export var player_base_damage: int = 25
@export var enemy_entity_path: NodePath
@export var enemy_container_path: NodePath = NodePath("EnemyContainer")
@export var ui_player: NodePath = NodePath("Player")
@export var turns_order_path: NodePath = NodePath("TurnsOrder")
@export var player_turn_icon: Texture2D
@export var turns_order_row_height: float = 24.0
@export var turns_order_min_visible_rows: int = 8
@export var player_max_health: int = 100
@export_range(0.0, 100.0, 0.1) var player_hit_chance_bonus_percent: float = 20.0
@export_range(0.0, 200.0, 1.0) var attack_lunge_distance: float = 42.0
@export_range(0.0, 1.0, 0.01) var multi_hit_delay_seconds: float = 0.1
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
var _is_exiting_combat: bool = false
var _spell_cursor_overlay: TextureRect = null
var _exp_gained_this_combat: int = 0

signal enemy_targeting_changed(enabled: bool, highlight_whole_enemy: bool)

@onready var spells_panel: HBoxContainer = $SpellsPanel/Container
@onready var lbl_player_health: Label = $HealthBar/HealthLabel
@onready var lbl_player_energy: Label = $EnergyPanel/Value
@onready var lbl_turns_order: Label = $TurnsOrderUI/RoundValue
@onready var turns_order_container: VBoxContainer = $TurnsOrderUI/Panel
@onready var player_buffs_panel: HBoxContainer = get_node_or_null("BuffsPanel") as HBoxContainer
@onready var attack_scope_option: OptionButton = get_node_or_null("TargetingPanel/AttackScopeOption") as OptionButton
@onready var debuff_scope_option: OptionButton = get_node_or_null("TargetingPanel/DebuffScopeOption") as OptionButton

func _ready() -> void:
	if _queued_encounter_scenes.size() > 0:
		_spawn_encounter_enemies(_queued_encounter_scenes)
	elif RunData.current_encounter.size() > 0:
		_spawn_encounter_enemies(RunData.current_encounter)

	current_round = 1
	_refresh_enemy_entities()
	_reset_combat_effects()
	_refresh_enemy_buffs_ui()
	_refresh_player_buffs_ui()
	RunData.reset_energy()
	_update_player_health_label()
	_update_player_energy_label()
	_setup_spell_cursor_overlay()
	_rebuild_spells_panel()
	_setup_target_scope_selectors()

	RunData.health_changed.connect(_update_player_health_label)
	RunData.energy_changed.connect(_update_player_energy_label)
	_begin_player_turn()

func _input(event): #Temporary
	if event.is_action_pressed("ui_cancel"):
		if _attack_selected:
			_cancel_selected_spell()
			get_viewport().set_input_as_handled()
			return
		# _exit_combat()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			var spell_index := _get_spell_index_from_key_event(key_event)
			if spell_index >= 0:
				_select_spell_by_index(spell_index)
				get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	_update_spell_cursor_overlay_position()

func _exit_combat():
	if _is_exiting_combat:
		return
	_is_exiting_combat = true
	# Temporary
	TransitionManager.change_scene("res://scenes/map.tscn", TransitionManager.TransitionType.FADE)

func _on_combat_victory() -> void:
	if current_state == CombatState.COMBAT_OVER:
		return
	current_state = CombatState.COMBAT_OVER
	_set_enemy_targeting_enabled(false)
	_update_button_states()
	_refresh_turns_order_ui()
	await get_tree().create_timer(1.2).timeout
	_show_victory_summary()

func _show_victory_summary() -> void:
	if COMBAT_SUMMARY_SCENE == null:
		_exit_combat()
		return
		
	var summary = COMBAT_SUMMARY_SCENE.instantiate()
	summary.continue_pressed.connect(_exit_combat)
	add_child(summary)
	summary.setup(_exp_gained_this_combat)

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
	RunData.reset_energy()
	_update_player_energy_label()
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

	var on_took_damage := Callable(self, "_on_enemy_took_damage")
	if not entity.entity_took_damage.is_connected(on_took_damage):
		entity.entity_took_damage.connect(on_took_damage)

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
	if spell != null and not _can_afford_spell(spell):
		return
	if spell != null and spell.spell_type == SpellData.SpellType.BUFF:
		if not _spend_spell_energy(spell):
			return
		_append_player_effect(spell)
		_play_attack_feedback(spell, null, null)
		_attack_selected = false
		selected_spell = null
		_end_player_turn()
		return
	if spell != null and spell.spell_type == SpellData.SpellType.HEAL:
		if not _spend_spell_energy(spell):
			return
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
	_update_enemy_spell_targeting_preview()
	_update_spell_cursor_overlay()
	_update_button_states()
	_refresh_limb_highlighting_from_mouse()

func _rebuild_spells_panel() -> void:
	_spell_buttons.clear()
	_button_spells.clear()

	var existing_buttons := spells_panel.get_children()
	
	for slot_index in range(6):
		var spell_button: Button = null
		
		if slot_index < existing_buttons.size():
			spell_button = existing_buttons[slot_index] as Button
		else:
			spell_button = SPELL_BUTTON_SCENE.instantiate() as Button
			spell_button.name = "Action%d" % (slot_index + 1)
			spells_panel.add_child(spell_button)
		
		_spell_buttons.append(spell_button)
		
		if slot_index < RunData.spells.size() and RunData.spells[slot_index] != null:
			var spell := RunData.spells[slot_index]
			_configure_spell_button(spell_button, spell)
			_button_spells[spell_button] = spell
		else:
			_configure_empty_spell_button(spell_button)

func _configure_spell_button(button: Button, spell: SpellData) -> void:
	var bind_label = button.get_node_or_null("Bind") as Label
	var slot_index := _spell_buttons.find(button)
	if bind_label != null:
		bind_label.text = str(slot_index + 1)

	button.tooltip_text = _build_spell_tooltip(spell)
	if spell != null and spell.icon != null:
		button.icon = spell.icon
	
	button.disabled = false
	button.modulate = Color.WHITE

	var on_pressed := Callable(self, "_on_spell_button_pressed").bind(button)
	if not button.pressed.is_connected(on_pressed):
		button.pressed.connect(on_pressed)

func _configure_empty_spell_button(button: Button) -> void:
	var bind_label = button.get_node_or_null("Bind") as Label
	var slot_index := _spell_buttons.find(button)
	if bind_label != null:
		bind_label.text = str(slot_index + 1)
	
	button.icon = null
	button.tooltip_text = ""
	button.disabled = true
	
	var on_pressed := Callable(self, "_on_spell_button_pressed").bind(button)
	if button.pressed.is_connected(on_pressed):
		button.pressed.disconnect(on_pressed)

func _build_spell_tooltip(spell: SpellData) -> String:
	if spell == null:
		return ""

	var lines: Array[String] = []
	lines.append(spell.spell_name)
	lines.append("Type: %s" % _spell_type_to_text(spell.spell_type))
	lines.append("Target: %s" % _target_scope_to_text(spell.target_scope))

	if spell.energy > 0:
		lines.append("Energy: %d" % spell.energy)
	if spell.accuracy > 0.0:
		lines.append("Accuracy: %s%%" % str(snappedf(spell.accuracy, 0.1)))
	if spell.has_damage():
		var min_damage := spell.get_min_damage()
		var max_damage := spell.get_max_damage()
		var attacks := spell.get_attack_count()
		if min_damage == max_damage:
			lines.append("Damage: %d (%s)" % [min_damage, _damage_type_to_text(spell.damage_type)])
		else:
			lines.append("Damage: %d-%d (%s)" % [min_damage, max_damage, _damage_type_to_text(spell.damage_type)])
		if attacks > 1:
			lines.append("Hits: %d" % attacks)
	if spell.heal_amount > 0:
		lines.append("Heal: %d" % spell.heal_amount)

	var effect_lines: Array[String] = []
	if spell.outgoing_damage_flat_bonus != 0:
		effect_lines.append("Outgoing Damage: %s" % _format_signed_int(spell.outgoing_damage_flat_bonus))
	if not is_zero_approx(spell.outgoing_damage_multiplier_delta):
		effect_lines.append("Outgoing Damage Mult: %s%%" % _format_signed_percent(spell.outgoing_damage_multiplier_delta * 100.0))
	if not is_zero_approx(spell.incoming_damage_multiplier_delta):
		effect_lines.append("Incoming Damage Mult: %s%%" % _format_signed_percent(spell.incoming_damage_multiplier_delta * 100.0))
	if not is_zero_approx(spell.player_physical_defense_delta):
		effect_lines.append("Player Phys Def: %s%%" % _format_signed_percent(spell.player_physical_defense_delta))
	if not is_zero_approx(spell.player_magic_defense_delta):
		effect_lines.append("Player Magic Def: %s%%" % _format_signed_percent(spell.player_magic_defense_delta))
	if not is_zero_approx(spell.target_physical_defense_delta):
		effect_lines.append("Target Phys Def: %s%%" % _format_signed_percent(spell.target_physical_defense_delta))
	if not is_zero_approx(spell.target_magic_defense_delta):
		effect_lines.append("Target Magic Def: %s%%" % _format_signed_percent(spell.target_magic_defense_delta))
	if spell.damage_over_time != 0:
		effect_lines.append("Damage Over Time: %s/turn" % _format_signed_int(spell.damage_over_time))
	if spell.stun_turns:
		effect_lines.append("Applies Stun")

	if not effect_lines.is_empty():
		lines.append("Duration: %d turn%s" % [spell.duration_rounds, "" if spell.duration_rounds == 1 else "s"])
		for effect_line in effect_lines:
			lines.append(effect_line)

	return "\n".join(lines)

func _spell_type_to_text(spell_type: SpellData.SpellType) -> String:
	match spell_type:
		SpellData.SpellType.ATTACK:
			return "Attack"
		SpellData.SpellType.BUFF:
			return "Buff"
		SpellData.SpellType.DEBUFF:
			return "Debuff"
		SpellData.SpellType.HEAL:
			return "Heal"
		_:
			return "Unknown"

func _target_scope_to_text(target_scope: SpellData.TargetScope) -> String:
	match target_scope:
		SpellData.TargetScope.LIMB:
			return "Limb"
		SpellData.TargetScope.WHOLE_ENEMY:
			return "Whole Enemy"
		SpellData.TargetScope.ALL_ENEMIES:
			return "All Enemies"
		_:
			return "Unknown"

func _damage_type_to_text(damage_type: SpellData.DamageType) -> String:
	match damage_type:
		SpellData.DamageType.PHYSICAL:
			return "Physical"
		SpellData.DamageType.MAGIC:
			return "Magic"
		_:
			return "Unknown"

func _format_signed_int(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return "%d" % value

func _format_signed_percent(value: float) -> String:
	var rounded := snappedf(value, 0.1)
	if rounded > 0.0:
		return "+%s" % str(rounded)
	return str(rounded)

func _on_spell_button_pressed(button: Button) -> void:
	var spell := _button_spells.get(button, null) as SpellData
	_select_spell(spell)

func _cancel_selected_spell() -> void:
	if current_state != CombatState.PLAYER_TURN or not _attack_selected:
		return

	_attack_selected = false
	selected_spell = null
	_update_enemy_spell_targeting_preview()
	_set_enemy_targeting_enabled(false)
	_clear_spell_cursor_overlay()
	_update_button_states()

func _select_spell_by_index(index: int) -> void:
	if index < 0 or index >= mini(6, _spell_buttons.size()):
		return

	var spell_button := _spell_buttons[index]
	if spell_button == null or not is_instance_valid(spell_button) or spell_button.disabled:
		return

	_on_spell_button_pressed(spell_button)

func _get_spell_index_from_key_event(event: InputEventKey) -> int:
	match event.keycode:
		KEY_1, KEY_KP_1:
			return 0
		KEY_2, KEY_KP_2:
			return 1
		KEY_3, KEY_KP_3:
			return 2
		KEY_4, KEY_KP_4:
			return 3
		KEY_5, KEY_KP_5:
			return 4
		KEY_6, KEY_KP_6:
			return 5
		_:
			return -1

func _update_button_states() -> void:
	var should_disable_buttons := current_state != CombatState.PLAYER_TURN or _attack_selected or not _has_alive_enemies()
	for spell_button in _spell_buttons:
		if is_instance_valid(spell_button):
			if spell_button not in _button_spells:
				spell_button.disabled = true
				spell_button.modulate = Color(0.4, 0.4, 0.4, 1.0)
			else:
				var spell := _button_spells.get(spell_button, null) as SpellData
				var lacks_energy := spell != null and not _can_afford_spell(spell)
				spell_button.disabled = should_disable_buttons or lacks_energy
				if should_disable_buttons or lacks_energy:
					spell_button.modulate = Color(0.4, 0.4, 0.4, 1.0)
				else:
					spell_button.modulate = Color.WHITE

func _get_spell_energy_cost(spell: SpellData) -> int:
	if spell == null:
		return 0
	return maxi(0, spell.energy)

func _can_afford_spell(spell: SpellData) -> bool:
	return RunData.current_energy >= _get_spell_energy_cost(spell)

func _spend_spell_energy(spell: SpellData) -> bool:
	var spell_cost := _get_spell_energy_cost(spell)
	if spell_cost <= 0:
		return true
	if RunData.current_energy < spell_cost:
		return false
	RunData.current_energy -= spell_cost
	_update_button_states()
	return true

func _on_enemy_limb_clicked(limb: CombatLimb, source_enemy: CombatEntity) -> void:
	if current_state != CombatState.PLAYER_TURN:
		return
	if not _attack_selected:
		return
	if source_enemy == null or not is_instance_valid(source_enemy) or not source_enemy.is_alive:
		return
	if limb.is_destroyed:
		return

	var resolved_scope := _resolve_target_scope(selected_spell)
	var target_enemies: Array[CombatEntity] = []
	if resolved_scope == TargetScope.ALL_ENEMIES:
		target_enemies = _get_alive_enemies()
	else:
		target_enemies.append(source_enemy)

	if target_enemies.is_empty():
		return

	var active_spell := selected_spell
	if active_spell != null and not _spend_spell_energy(active_spell):
		return
	if _roll_player_hit_on_limb(limb):
		var spell_damage := 0
		var spell_type := SpellData.SpellType.ATTACK
		var attack_damage_type := SpellData.DamageType.PHYSICAL
		var can_deal_damage := true
		var attack_count := 1
		if active_spell != null:
			spell_damage = active_spell.roll_damage()
			spell_type = active_spell.spell_type
			attack_damage_type = active_spell.damage_type
			can_deal_damage = active_spell.has_damage()
			attack_count = active_spell.get_attack_count()

		if can_deal_damage and (spell_type == SpellData.SpellType.ATTACK or spell_type == SpellData.SpellType.DEBUFF):
			var player_modifiers := _get_player_outgoing_modifiers()
			var outgoing_multiplier := float(player_modifiers.get("mult", 1.0))
			var outgoing_flat := int(player_modifiers.get("flat", 0))
			for _attack_iteration in range(attack_count):
				if active_spell != null:
					spell_damage = active_spell.roll_damage()
				var raw_damage = RunData.get_stat("damage") + spell_damage + outgoing_flat
				for target_enemy in target_enemies:
					if target_enemy == null or not is_instance_valid(target_enemy) or not target_enemy.is_alive:
						continue
					var target_limbs := _get_target_limbs(target_enemy, limb, selected_spell)
					for target_limb in target_limbs:
						if target_limb.is_destroyed:
							continue
						var incoming_multiplier := _get_enemy_incoming_multiplier(target_enemy, target_limb)
						var final_damage := int(round(float(raw_damage) * outgoing_multiplier * incoming_multiplier))
						var enemy_defense := _get_enemy_total_defense_for_damage_type(target_enemy, target_limb, attack_damage_type)
						final_damage = _apply_defense_to_damage(final_damage, enemy_defense)
						final_damage = max(0, final_damage)
						if final_damage > 0:
							target_enemy.take_damage(target_limb, final_damage)
				if _attack_iteration < attack_count - 1 and multi_hit_delay_seconds > 0.0:
					await get_tree().create_timer(multi_hit_delay_seconds).timeout

		if active_spell != null and active_spell.spell_type == SpellData.SpellType.DEBUFF:
			for target_enemy in target_enemies:
				if target_enemy == null or not is_instance_valid(target_enemy) or not target_enemy.is_alive:
					continue
				_append_enemy_effect(target_enemy, active_spell, limb)

		if active_spell != null:
			_play_attack_feedback(active_spell, get_node_or_null(ui_player), source_enemy)
	else:
		var miss_position := limb.global_position if limb != null and is_instance_valid(limb) else get_viewport().get_visible_rect().size * 0.5
		_spawn_floating_damage_number(0, miss_position, false, false, "MISS")
		print("Player missed %s (%s%% hit chance)" % [limb.limb_name, snappedf(_get_adjusted_hit_chance_percent(limb), 0.1)])
	_attack_selected = false
	selected_spell = null
	_clear_spell_cursor_overlay()
	_update_enemy_spell_targeting_preview()
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
		_exp_gained_this_combat += _entity.exp_reward
		_enemy_effects.erase(_entity.get_instance_id())
		_enemy_limb_effects.erase(_entity.get_instance_id())
		_refresh_enemy_buffs_ui()

	if _has_alive_enemies():
		_refresh_turns_order_ui()
		return

	_on_combat_victory()

func _on_enemy_took_damage(entity: CombatEntity, limb: CombatLimb, damage: int) -> void:
	if damage <= 0:
		return

	var hit_position := Vector2.ZERO
	if limb != null and is_instance_valid(limb):
		hit_position = limb.global_position
	elif entity != null and is_instance_valid(entity):
		var fallback_limb := _get_first_alive_enemy_limb(entity)
		if fallback_limb != null:
			hit_position = fallback_limb.global_position
		else:
			hit_position = get_viewport().get_visible_rect().size * 0.5
	else:
		hit_position = get_viewport().get_visible_rect().size * 0.5

	_play_enemy_impact_pulse(limb, entity)
	_spawn_floating_damage_number(damage, hit_position, false)

func _play_enemy_impact_pulse(limb: CombatLimb, entity: CombatEntity) -> void:
	var impact_node: Node2D = null
	if limb != null and is_instance_valid(limb):
		impact_node = limb
	elif entity != null and is_instance_valid(entity):
		impact_node = _get_first_alive_enemy_limb(entity)

	if impact_node == null:
		return

	if impact_node.has_meta("impact_tween"):
		var existing_tween = impact_node.get_meta("impact_tween")
		if existing_tween is Tween:
			(existing_tween as Tween).kill()
		impact_node.remove_meta("impact_tween")

	var base_scale := impact_node.scale
	var base_position := impact_node.position
	var knock_offset := Vector2(randf_range(-5.0, 5.0), randf_range(-3.0, 1.5))

	var tween := create_tween()
	impact_node.set_meta("impact_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(impact_node, "scale", base_scale * 1.1, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(impact_node, "position", base_position + knock_offset, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_property(impact_node, "scale", base_scale, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(impact_node, "position", base_position, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		if is_instance_valid(impact_node):
			impact_node.remove_meta("impact_tween")
	)

func _setup_target_scope_selectors() -> void:
	if attack_scope_option != null:
		attack_scope_option.clear()
		attack_scope_option.add_item("Limb", TargetScope.LIMB)
		attack_scope_option.add_item("Whole Enemy", TargetScope.WHOLE_ENEMY)
		attack_scope_option.add_item("All Enemies", TargetScope.ALL_ENEMIES)
		_select_option_by_id(attack_scope_option, int(attack_target_scope))
		var on_attack_scope_selected := Callable(self, "_on_attack_scope_selected")
		if not attack_scope_option.item_selected.is_connected(on_attack_scope_selected):
			attack_scope_option.item_selected.connect(on_attack_scope_selected)

	if debuff_scope_option != null:
		debuff_scope_option.clear()
		debuff_scope_option.add_item("Limb", TargetScope.LIMB)
		debuff_scope_option.add_item("Whole Enemy", TargetScope.WHOLE_ENEMY)
		debuff_scope_option.add_item("All Enemies", TargetScope.ALL_ENEMIES)
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

		_apply_enemy_damage_over_time(attacking_enemy)
		if not is_instance_valid(attacking_enemy) or not attacking_enemy.is_alive:
			continue

		if _is_enemy_stunned(attacking_enemy):
			continue

		_refresh_turns_order_ui(attacking_enemy)

		var attack_limb := _choose_enemy_attack_limb(attacking_enemy)
		if attack_limb == null:
			continue

		var attack := attack_limb.choose_attack()
		if attack == null:
			continue

		await get_tree().create_timer(0.35).timeout
		await _play_attack_feedback(attack, attacking_enemy, get_node_or_null(ui_player))
		var outgoing_multiplier := _get_enemy_outgoing_multiplier(attacking_enemy)
		var attack_count := attack.get_attack_count()
		for _attack_iteration in range(attack_count):
			if current_state == CombatState.COMBAT_OVER:
				return
			var damage: int = int(round(float(attack.roll_damage()) * outgoing_multiplier))
			_apply_player_damage(damage, attack.damage_type)
			if current_state == CombatState.COMBAT_OVER:
				return
			if _attack_iteration < attack_count - 1 and multi_hit_delay_seconds > 0.0:
				await get_tree().create_timer(multi_hit_delay_seconds).timeout

	_end_enemy_turn()

func _choose_enemy_attack_limb(source_enemy: CombatEntity) -> CombatLimb:
	var candidates: Array[CombatLimb] = []
	for limb in source_enemy.limbs:
		if limb.is_destroyed:
			continue
		if _is_enemy_limb_stunned(source_enemy, limb):
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
		or spell.damage_over_time != 0 \
		or spell.stun_turns \
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
		"damage_over_time": spell.damage_over_time,
		"stun_turns": bool(spell.stun_turns),
		"damage_type": int(spell.damage_type),
		"target_scope": int(spell.target_scope),
		"physical_defense_delta": spell.player_physical_defense_delta,
		"magic_defense_delta": spell.player_magic_defense_delta,
	})

	_refresh_player_buffs_ui()

func _append_enemy_effect(target_enemy: CombatEntity, spell: SpellData, target_limb: CombatLimb = null) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy) or spell == null:
		return

	var has_effect := not is_zero_approx(spell.outgoing_damage_multiplier_delta) \
		or not is_zero_approx(spell.incoming_damage_multiplier_delta) \
		or spell.damage_over_time != 0 \
		or spell.stun_turns \
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
		"damage_over_time": spell.damage_over_time,
		"stun_turns": bool(spell.stun_turns),
		"damage_type": int(spell.damage_type),
		"target_scope": int(spell.target_scope),
		"physical_defense_delta": spell.target_physical_defense_delta,
		"magic_defense_delta": spell.target_magic_defense_delta,
		"spell_name": spell.spell_name,
		"spell_type": int(spell.spell_type),
		"icon": spell.icon,
	}

	var enemy_id := target_enemy.get_instance_id()
	if _resolve_target_scope(spell) != TargetScope.LIMB:
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

func _apply_enemy_damage_over_time(target_enemy: CombatEntity) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy) or not target_enemy.is_alive:
		return

	_cleanup_expired_effects()

	var enemy_id := target_enemy.get_instance_id()
	var enemy_effects: Array = _enemy_effects.get(enemy_id, [])
	for raw_effect in enemy_effects:
		var effect := raw_effect as Dictionary
		if effect.is_empty():
			continue
		_apply_enemy_effect_damage_over_time(target_enemy, effect, null)

	var limb_effects_by_enemy := _enemy_limb_effects.get(enemy_id, {}) as Dictionary
	for limb_id in limb_effects_by_enemy.keys():
		var target_limb := instance_from_id(int(limb_id)) as CombatLimb
		if target_limb == null or not is_instance_valid(target_limb) or target_limb.is_destroyed:
			continue

		var limb_effects: Array = limb_effects_by_enemy.get(limb_id, [])
		for raw_effect in limb_effects:
			var effect := raw_effect as Dictionary
			if effect.is_empty():
				continue
			_apply_enemy_effect_damage_over_time(target_enemy, effect, target_limb)

func _apply_enemy_effect_damage_over_time(target_enemy: CombatEntity, effect: Dictionary, target_limb: CombatLimb = null) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy) or effect.is_empty():
		return

	var damage_over_time := int(effect.get("damage_over_time", 0))
	if damage_over_time <= 0:
		return

	var damage_type := int(effect.get("damage_type", int(SpellData.DamageType.PHYSICAL))) as SpellData.DamageType
	var target_scope := int(effect.get("target_scope", int(TargetScope.LIMB))) as TargetScope
	var target_limbs: Array[CombatLimb] = []

	if target_limb != null and is_instance_valid(target_limb) and not target_limb.is_destroyed:
		target_limbs.append(target_limb)
	elif target_scope == TargetScope.WHOLE_ENEMY or target_scope == TargetScope.ALL_ENEMIES:
		for limb in target_enemy.limbs:
			if limb != null and is_instance_valid(limb) and not limb.is_destroyed:
				target_limbs.append(limb)
	else:
		var first_alive_limb := _get_first_alive_enemy_limb(target_enemy)
		if first_alive_limb != null:
			target_limbs.append(first_alive_limb)

	if target_limbs.is_empty():
		return

	for affected_limb in target_limbs:
		var incoming_multiplier := _get_enemy_incoming_multiplier(target_enemy, affected_limb)
		var final_damage := int(round(float(damage_over_time) * incoming_multiplier))
		var enemy_defense := _get_enemy_total_defense_for_damage_type(target_enemy, affected_limb, damage_type)
		final_damage = _apply_defense_to_damage(final_damage, enemy_defense)
		final_damage = max(0, final_damage)
		if final_damage > 0:
			target_enemy.take_damage(affected_limb, final_damage)

func _is_enemy_stunned(target_enemy: CombatEntity) -> bool:
	if target_enemy == null or not is_instance_valid(target_enemy):
		return false

	_cleanup_expired_effects()

	var enemy_effects: Array = _enemy_effects.get(target_enemy.get_instance_id(), [])
	for raw_effect in enemy_effects:
		var effect := raw_effect as Dictionary
		if effect.is_empty():
			continue
		if bool(effect.get("stun_turns", false)):
			return true

	return false

func _is_enemy_limb_stunned(target_enemy: CombatEntity, target_limb: CombatLimb) -> bool:
	if target_enemy == null or not is_instance_valid(target_enemy):
		return false
	if target_limb == null or not is_instance_valid(target_limb):
		return false

	_cleanup_expired_effects()

	var limb_effects_by_enemy := _enemy_limb_effects.get(target_enemy.get_instance_id(), {}) as Dictionary
	var limb_effects: Array = limb_effects_by_enemy.get(target_limb.get_instance_id(), [])
	for raw_effect in limb_effects:
		var effect := raw_effect as Dictionary
		if effect.is_empty():
			continue
		if bool(effect.get("stun_turns", false)):
			return true

	return false

func _get_first_alive_enemy_limb(target_enemy: CombatEntity) -> CombatLimb:
	if target_enemy == null or not is_instance_valid(target_enemy):
		return null

	for limb in target_enemy.limbs:
		if limb != null and is_instance_valid(limb) and not limb.is_destroyed:
			return limb

	return null

func _resolve_target_scope(spell: SpellData) -> TargetScope:
	if spell != null:
		return spell.target_scope as TargetScope
	return attack_target_scope

func _is_whole_enemy_targeting() -> bool:
	if not _attack_selected:
		return false
	var scope := _resolve_target_scope(selected_spell)
	return scope == TargetScope.WHOLE_ENEMY or scope == TargetScope.ALL_ENEMIES

func _get_target_limbs(source_enemy: CombatEntity, hovered_limb: CombatLimb, spell: SpellData) -> Array[CombatLimb]:
	if source_enemy == null or not is_instance_valid(source_enemy):
		return []
	var resolved_scope := _resolve_target_scope(spell)
	if resolved_scope == TargetScope.LIMB:
		if hovered_limb == null or not is_instance_valid(hovered_limb):
			return []
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
	var player_hit_position = _get_vfx_anchor_position(null)
	_flash_player_hit()
	RunData.current_health -= mitigated_amount 
	if player_hit_position is Vector2:
		_spawn_floating_damage_number(mitigated_amount, player_hit_position as Vector2, true)
	if RunData.current_health <= 0:
		current_state = CombatState.COMBAT_OVER
		_restart_run_on_player_death()
	print("Player took %d damage — HP: %d/%d" % [mitigated_amount, RunData.current_health, RunData.max_health])

func _restart_run_on_player_death() -> void:
	if _is_exiting_combat:
		return
	_is_exiting_combat = true
	RunData.end_run()
	TransitionManager.change_scene("res://scenes/map.tscn", TransitionManager.TransitionType.FADE)

func _spawn_floating_damage_number(amount: int, world_position: Vector2, hit_player: bool, is_heal: bool = false, custom_text: String = "") -> void:
	var is_custom_text := not custom_text.is_empty()
	if amount <= 0 and not is_custom_text:
		return
	var is_enemy_damage := not hit_player and not is_heal

	var damage_label := Label.new()
	damage_label.text = custom_text if is_custom_text else ("+%d" % amount if is_heal else "-%d" % amount)
	damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	damage_label.z_index = 500
	damage_label.add_theme_font_size_override("font_size", 34 if is_custom_text else (38 if hit_player else (36 if is_enemy_damage else 34)))
	if is_custom_text:
		damage_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1.0))
	elif is_heal:
		damage_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.62, 1.0))
	else:
		damage_label.add_theme_color_override("font_color", Color(1.0, 0.33, 0.28, 1.0) if hit_player else Color(1.0, 0.82, 0.22, 1.0))
	damage_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	damage_label.add_theme_constant_override("outline_size", 6)
	add_child(damage_label)

	var start_position := world_position + Vector2(randf_range(-24.0, 24.0), randf_range(-12.0, 8.0))
	var rise_amount := -84.0
	var travel_time := 0.58
	if is_enemy_damage:
		rise_amount = -102.0
		travel_time = 0.66
	var end_position := start_position + Vector2(randf_range(-16.0, 16.0), rise_amount)

	damage_label.global_position = start_position
	damage_label.scale = Vector2(0.55, 0.55) if is_enemy_damage else Vector2(0.65, 0.65)
	damage_label.rotation_degrees = randf_range(-8.0, 8.0) if is_enemy_damage else 0.0
	damage_label.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "global_position", end_position, travel_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_label, "scale", Vector2(1.22, 0.94) if is_enemy_damage else Vector2.ONE, 0.14 if is_enemy_damage else 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_label, "modulate:a", 1.0, 0.08)
	if is_enemy_damage:
		tween.tween_property(damage_label, "rotation_degrees", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.12 if is_enemy_damage else 0.14)
	tween.set_parallel(true)
	tween.tween_property(damage_label, "scale", Vector2(0.9, 0.9), 0.32 if is_enemy_damage else 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.32 if is_enemy_damage else 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(damage_label.queue_free)

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
		var heal_position = _get_vfx_anchor_position(null)
		if heal_position is Vector2:
			_spawn_floating_damage_number(healed_amount, heal_position as Vector2, true, true)
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
	await _play_attack_lunge(source_entity, target_entity)

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

func _play_attack_lunge(source_entity: Node, target_entity: Node) -> void:
	if source_entity == null or target_entity == null:
		return
	if not is_instance_valid(source_entity) or not is_instance_valid(target_entity):
		return
	if not (source_entity is CanvasItem):
		return

	var source_canvas := source_entity as CanvasItem
	var raw_target_position: Variant = _get_vfx_anchor_position(target_entity)
	if not (raw_target_position is Vector2):
		return

	var start_position: Vector2 = source_canvas.global_position
	var target_position := raw_target_position as Vector2
	var attack_direction := target_position - start_position
	if attack_direction.length_squared() <= 0.01:
		return

	var lunge_distance := minf(attack_lunge_distance, attack_direction.length() * 0.45)
	if lunge_distance <= 0.0:
		return

	var lunge_position := start_position + attack_direction.normalized() * lunge_distance
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(source_canvas, "global_position", lunge_position, 0.09)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(source_canvas, "global_position", start_position, 0.12)
	await tween.finished

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
		_on_combat_victory()
		return
	current_round += 1
	current_state = CombatState.PLAYER_TURN
	_begin_player_turn()

func _begin_player_turn() -> void:
	_cleanup_expired_effects()
	_refresh_enemy_buffs_ui()
	_refresh_player_buffs_ui()
	if _is_player_stunned():
		var player_anchor = _get_vfx_anchor_position(null)
		if player_anchor is Vector2:
			_spawn_floating_damage_number(0, player_anchor as Vector2, true, false, "DISABLED")
		_attack_selected = false
		selected_spell = null
		_update_enemy_spell_targeting_preview()
		_set_enemy_targeting_enabled(false)
		_clear_spell_cursor_overlay()
		_update_button_states()
		_refresh_turns_order_ui()
		_end_player_turn()
		return
	var regen_amount: int = maxi(0, int(round(float(RunData.get_stat("energy_regen")))))
	_regenerate_player_energy(regen_amount)
	_attack_selected = false
	selected_spell = null
	_update_enemy_spell_targeting_preview()
	_set_enemy_targeting_enabled(false)
	_clear_spell_cursor_overlay()
	_update_button_states()
	_refresh_turns_order_ui()
	
	for enemy in enemy_entities:
		if enemy != null and is_instance_valid(enemy):
			enemy._refresh_highlight()

func _is_player_stunned() -> bool:
	for effect in _player_effects:
		if bool(effect.get("stun_turns", false)):
			return true
	return false

func _regenerate_player_energy(amount: int) -> void:
	if amount <= 0:
		return
	var previous_energy := RunData.current_energy
	RunData.current_energy = mini(RunData.max_energy, RunData.current_energy + amount)
	var gained_energy := RunData.current_energy - previous_energy
	if gained_energy <= 0:
		return
	var energy_position = _get_energy_label_world_position()
	if energy_position != null:
		_spawn_floating_damage_number(gained_energy, energy_position as Vector2, true, true)

func _get_energy_label_world_position() -> Variant:
	if lbl_player_energy == null or not is_instance_valid(lbl_player_energy):
		return null
	return lbl_player_energy.global_position + (lbl_player_energy.size * 0.5)

func _update_enemy_spell_targeting_preview() -> void:
	var spell_icon: Texture2D = null
	var use_whole_enemy_preview := false
	if _attack_selected and selected_spell != null:
		spell_icon = selected_spell.icon
		var resolved_scope := _resolve_target_scope(selected_spell)
		use_whole_enemy_preview = resolved_scope == TargetScope.WHOLE_ENEMY or resolved_scope == TargetScope.ALL_ENEMIES

	for enemy in enemy_entities:
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.has_method("set_spell_targeting_preview"):
			enemy.set_spell_targeting_preview(_attack_selected, use_whole_enemy_preview, spell_icon)

func _setup_spell_cursor_overlay() -> void:
	if _spell_cursor_overlay != null:
		return

	_spell_cursor_overlay = TextureRect.new()
	_spell_cursor_overlay.name = "SpellCursorOverlay"
	_spell_cursor_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_cursor_overlay.visible = false
	_spell_cursor_overlay.z_index = 1000
	_spell_cursor_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spell_cursor_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spell_cursor_overlay.custom_minimum_size = Vector2(28.0, 28.0)
	add_child(_spell_cursor_overlay)

func _update_spell_cursor_overlay() -> void:
	if _spell_cursor_overlay == null:
		return

	if selected_spell == null or selected_spell.icon == null:
		_clear_spell_cursor_overlay()
		return

	_spell_cursor_overlay.texture = selected_spell.icon
	_spell_cursor_overlay.visible = true
	_update_spell_cursor_overlay_position()

func _update_spell_cursor_overlay_position() -> void:
	if _spell_cursor_overlay == null or not _spell_cursor_overlay.visible:
		return

	var icon_size := _spell_cursor_overlay.texture.get_size() if _spell_cursor_overlay.texture != null else Vector2(28.0, 28.0)
	_spell_cursor_overlay.size = icon_size
	_spell_cursor_overlay.position = get_viewport().get_mouse_position() + Vector2(18.0, 18.0)

func _clear_spell_cursor_overlay() -> void:
	if _spell_cursor_overlay == null:
		return

	_spell_cursor_overlay.visible = false
	_spell_cursor_overlay.texture = null

func _set_enemy_targeting_enabled(enabled: bool) -> void:
	var highlight_whole_enemy := enabled and _is_whole_enemy_targeting()
	if _enemy_targeting_enabled == enabled and _whole_enemy_highlight_enabled == highlight_whole_enemy:
		return
	_enemy_targeting_enabled = enabled
	_whole_enemy_highlight_enabled = highlight_whole_enemy
	enemy_targeting_changed.emit(enabled, highlight_whole_enemy)

func _refresh_limb_highlighting_from_mouse() -> void:
	if not _attack_selected or not _enemy_targeting_enabled:
		return

	var mouse_pos := get_viewport().get_mouse_position()

	for enemy in enemy_entities:
		if enemy == null or not is_instance_valid(enemy):
			continue
		for limb in enemy.limbs:
			if limb == null or not is_instance_valid(limb) or limb.is_destroyed:
				continue
			if limb is Sprite2D and limb.texture != null:
				var texture_size := limb.texture.get_size()
				var limb_rect := Rect2(limb.global_position - texture_size * 0.5, texture_size)
				if limb_rect.has_point(mouse_pos):
					if limb.has_method("set_current_highlight"):
						limb.set_current_highlight()
					return

func _update_player_health_label() -> void:
	lbl_player_health.text = "HP: %d/%d" % [RunData.current_health, RunData.max_health]

func _update_player_energy_label(_new_value: int = 0) -> void:
	lbl_player_energy.text = "%d/%d" % [RunData.current_energy, RunData.max_energy]

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
