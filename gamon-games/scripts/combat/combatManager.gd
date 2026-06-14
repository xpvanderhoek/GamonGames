class_name CombatManager
extends CanvasLayer

const PAUSE_MENU := preload("res://scenes/UI/main_menu/settings/settings_menu.tscn")
const TURN_ORDER_ENTRY_SCENE := preload("res://scenes/combat/ui/TurnOrderEntry.tscn")
const SPELL_BUTTON_SCENE := preload("res://scenes/combat/ui/SpellButton.tscn")
const BUFF_ICON_SCENE := preload("res://scenes/combat/ui/BuffIcon.tscn")
const COMBAT_SUMMARY_SCENE := preload("res://scenes/combat/ui/combat_summary.tscn")
const BOSS_VICTORY_SCENE := preload("res://scenes/combat/ui/boss_victory.tscn")
const DEFEAT_SCREEN_SCENE := preload("res://scenes/combat/ui/defeat_screen.tscn")
const COMBAT_ITEM_EFFECTS_SCRIPT := preload("res://scripts/combat/combat_item_effects.gd")

@onready var tutorial_overlay: CanvasLayer = $CanvasLayer/TutorialOverlay
@onready var canvas_layer: CanvasLayer = $CanvasLayer

const MAX_ENEMY_COUNT = 3

var enemy_pool : Array[PackedScene] = [
	preload("res://scenes/combat/enemies/skeleton_weak.tscn"),
	preload("res://scenes/combat/enemies/skeleton_weak2.tscn"),
	preload("res://scenes/combat/enemies/skeleton_weak3.tscn"),
	preload("res://scenes/combat/enemies/skeleton_weak4.tscn"),
	preload("res://scenes/combat/enemies/skeleton_full.tscn"),
	preload("res://scenes/combat/enemies/mimic.tscn"),
	preload("res://scenes/combat/enemies/ttt.tscn"),
]

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
@export var boss_container_path: NodePath = NodePath("BossContainer")
@export var background_rect_path: NodePath = NodePath("Background")
@export var ui_player: NodePath = NodePath("Player")
@export var turns_order_path: NodePath = NodePath("TurnsOrder")
@export var player_turn_icon: Texture2D
@export var turns_order_row_height: float = 24.0
@export var turns_order_min_visible_rows: int = 8
@export var player_max_health: int = 100
@export_range(0.0, 100.0, 0.1) var player_hit_chance_bonus_percent: float = 20.0
@export_range(0.0, 200.0, 1.0) var attack_lunge_distance: float = 42.0
@export_range(0.0, 1.0, 0.01) var multi_hit_delay_seconds: float = 0.1
@export_range(0.0, 1.0, 0.01) var enemy_attack_telegraph_seconds: float = 0.4
@export_range(1.0, 1.5, 0.01) var enemy_attack_telegraph_scale: float = 1.14
@export var attack_target_scope: TargetScope = TargetScope.LIMB
@export var debuff_target_scope: TargetScope = TargetScope.LIMB
@export var debug_round_stats: bool = true

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
var _consumable_buttons: Array = []
var _pending_consumable_status: Dictionary = {}
var _item_effects = null
var _enemy_intents: Dictionary = {}
var _intent_labels: Array[Label] = []
var _intent_limb_refs: Array[CombatLimb] = []
var _intent_pulsing_tweens: Array[Tween] = []

var _spell_tooltip: PanelContainer = null
var _spell_tooltip_label: RichTextLabel = null
var _spell_tooltip_spell: SpellData = null
var _spell_tooltip_was_shift_pressed: bool = false
var _spell_tooltip_show_upgrade_comparison: bool = false


var _item_tooltip: PanelContainer = null
var _item_tooltip_label: RichTextLabel = null
var _item_tooltip_item: ItemData = null
var _item_tooltip_was_shift_pressed: bool = false

signal enemy_targeting_changed(enabled: bool, highlight_whole_enemy: bool)

@onready var spells_panel: HBoxContainer = $SpellsPanel/Container
@onready var lbl_player_health: Label = $HealthBar/HealthLabel
@onready var lbl_player_energy: Label = $EnergyPanel/Value
@onready var lbl_turns_order: Label = $TurnsOrderUI/RoundValue
@onready var turns_order_container: VBoxContainer = $TurnsOrderUI/Panel
@onready var player_buffs_panel: HBoxContainer = get_node_or_null("BuffsPanel") as HBoxContainer
@onready var attack_scope_option: OptionButton = get_node_or_null("TargetingPanel/AttackScopeOption") as OptionButton
@onready var debuff_scope_option: OptionButton = get_node_or_null("TargetingPanel/DebuffScopeOption") as OptionButton
@onready var consumables_grid: GridContainer = get_node_or_null("Panel/GridContainer") as GridContainer
@onready var items_container: HBoxContainer = get_node_or_null("ItemPanel/Container") as HBoxContainer
@onready var end_turn_button: Button = get_node_or_null("EndTurn") as Button

func _ready() -> void:
	SoundManager.play_combat_music()
	if _queued_encounter_scenes.size() <= 0:
		if RunData.current_encounter.size() > 0:
			_queued_encounter_scenes = RunData.current_encounter.duplicate()
			RunData.current_encounter.clear()
		else:
			_get_random_encounters()
	
	if _queued_encounter_scenes.size() > 0:
		_spawn_encounter_enemies(_queued_encounter_scenes)

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
	_item_effects = COMBAT_ITEM_EFFECTS_SCRIPT.new(self)
	_setup_consumable_buttons()

	RunData.health_changed.connect(_update_player_health_label)
	RunData.energy_changed.connect(_update_player_energy_label)
	RunData.item_added.connect(_on_item_added)
	_populate_existing_items()
	if end_turn_button != null:
		end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	Settings.keybinds_changed.connect(_on_keybinds_changed)
	_begin_player_turn()
	
	if PlayerStats.knows_combat:
		tutorial_overlay.visible = false
	else:
		tutorial_overlay.visible = true

func _on_keybinds_changed() -> void:
	for i in range(_spell_buttons.size()):
		var button = _spell_buttons[i]
		if is_instance_valid(button):
			var bind_label = button.get_node_or_null("Bind") as Label
			if bind_label != null:
				var keycode = Settings.data.spell_keybinds[i]
				bind_label.text = OS.get_keycode_string(keycode)

func _get_random_encounters() -> void:
	if RunData.last_map_room != null and RunData.last_map_room.type == Room.Type.BOSS:
		_queued_encounter_scenes.append(preload("res://scenes/combat/enemies/boss.tscn"))
		return

	var count_range := _get_enemy_count_range_for_progress()
	var enemy_count : int = RunData.rng.randi_range(int(count_range[0]), int(count_range[1]))

	for i in range(enemy_count):
		var chosen_scene := _pick_enemy_by_spawn_ranges(RunData.combats_fought)
		_queued_encounter_scenes.append(chosen_scene)

func _get_enemy_count_range_for_progress() -> Array:
	var k := int(RunData.combats_fought / 3)
	var min_count := clampi(1 + int(maxi(0, k - 1)), 1, MAX_ENEMY_COUNT)
	var max_count := clampi(1 + k, 1, MAX_ENEMY_COUNT)
	return [min_count, max_count]

func _scene_allows_spawn(scene: PackedScene, combats_fought: int) -> bool:
	if scene == null:
		return false
	var inst := scene.instantiate()
	if inst == null:
		return true
	var allowed := true
	if inst is CombatEntity:
		var entity := inst as CombatEntity
		var minv := int(entity.spawn_min_fights)
		var maxv := int(entity.spawn_max_fights)
		allowed = combats_fought >= minv and combats_fought <= maxv
	if is_instance_valid(inst):
		inst.queue_free()
	return allowed

func _pick_enemy_by_spawn_ranges(combats_fought: int) -> PackedScene:
	var allowed: Array[PackedScene] = []
	for scene in enemy_pool:
		if _scene_allows_spawn(scene, combats_fought):
			allowed.append(scene)

	if allowed.is_empty():
		allowed = enemy_pool.duplicate()

	var idx := RunData.rng.randi_range(0, allowed.size() - 1)
	return allowed[idx]

func _apply_enemy_scaling(enemy: Node) -> void:
	if not (enemy is CombatEntity):
		return
	
	var combat_entity := enemy as CombatEntity
	var scaling_multiplier := 1.0 + (RunData.combats_fought * 0.1)
	combat_entity.combat_scaling_multiplier = scaling_multiplier
	
	for limb in combat_entity.limbs:
		if limb is CombatLimb:
			limb.max_health = int(round(float(limb.max_health) * scaling_multiplier))
			limb.current_health = limb.max_health

func _input(event): #Temporary
	if current_state == CombatState.COMBAT_OVER:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if _attack_selected:
				_cancel_selected_spell()
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("escape") or event.is_action_pressed("ui_cancel"):
		if _attack_selected:
			_cancel_selected_spell()
			get_viewport().set_input_as_handled()
			return
		canvas_layer.add_child(PAUSE_MENU.instantiate())
		get_viewport().set_input_as_handled()
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
	_update_spell_tooltip_position()
	_update_item_tooltip_position()
	if _spell_tooltip_spell != null and _spell_tooltip != null and _spell_tooltip.visible:
		var shift_now := Input.is_key_pressed(KEY_SHIFT)
		if shift_now != _spell_tooltip_was_shift_pressed:
			_spell_tooltip_was_shift_pressed = shift_now
			_show_spell_tooltip(_spell_tooltip_spell)
	if _item_tooltip_item != null and _item_tooltip != null and _item_tooltip.visible:
		var item_shift_now := Input.is_key_pressed(KEY_SHIFT)
		if item_shift_now != _item_tooltip_was_shift_pressed:
			_item_tooltip_was_shift_pressed = item_shift_now
			_show_item_tooltip(_item_tooltip_item)

func _exit_combat():
	if _is_exiting_combat:
		return
	_is_exiting_combat = true
	SoundManager.stop_combat_music()
	# Temporary
	if PuzzleData.from_puzzle:
		print(PuzzleData.puzzle_coins)
		PuzzleData.chest_open = true
		PuzzleData.from_puzzle = false
		TransitionManager.change_scene("res://scenes/puzzles/Chest_room.tscn", TransitionManager.TransitionType.FADE)
	else:
		TransitionManager.change_scene("res://scenes/map/map.tscn", TransitionManager.TransitionType.FADE)

func _on_combat_victory() -> void:
	if current_state == CombatState.COMBAT_OVER:
		return
	current_state = CombatState.COMBAT_OVER
	_set_enemy_targeting_enabled(false)
	_update_button_states()
	_refresh_turns_order_ui()
	await get_tree().create_timer(1.2).timeout
	RunData.combats_fought += 1
	_show_victory_summary()

func _show_victory_summary() -> void:
	# Check if this was a boss fight
	var is_boss_fight := false
	if RunData.last_map_room != null and RunData.last_map_room.type == Room.Type.BOSS:
		is_boss_fight = true
	
	if is_boss_fight:
		_setup_boss_statue_interact()
	else:
		if COMBAT_SUMMARY_SCENE == null:
			_exit_combat()
			return
			
		var summary = COMBAT_SUMMARY_SCENE.instantiate()
		summary.continue_pressed.connect(_exit_combat)
		add_child(summary)
		summary.setup(_exp_gained_this_combat)

func _setup_boss_statue_interact() -> void:
	var boss_container := get_node_or_null(boss_container_path)
	if boss_container == null:
		_show_boss_victory_screen()
		return
	
	var statue = boss_container.get_node_or_null("Statue")
	if statue == null:
		_show_boss_victory_screen()
		return
		
	var interact_button = TextureButton.new()
	if statue is Sprite2D:
		interact_button.texture_normal = statue.texture
		interact_button.pivot_offset = statue.texture.get_size() / 2.0
		interact_button.position = statue.position - interact_button.pivot_offset
		interact_button.scale = statue.scale
		interact_button.z_index = statue.z_index
	
	var tween = create_tween().set_loops()
	tween.tween_property(interact_button, "modulate", Color(2.0, 1.8, 1.2, 1.0), 0.8)
	tween.tween_property(interact_button, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8)
	
	interact_button.pressed.connect(func():
		interact_button.disabled = true
		tween.kill()
		interact_button.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_show_boss_victory_screen()
	)
	
	interact_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	boss_container.add_child(interact_button)
	statue.visible = false

func _show_boss_victory_screen() -> void:
	if BOSS_VICTORY_SCENE == null:
		_exit_combat()
		return
	var victory_screen = BOSS_VICTORY_SCENE.instantiate()
	add_child(victory_screen)

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
	_setup_consumable_buttons()
	_begin_player_turn()

func _spawn_encounter_enemies(encounter_enemy_scenes: Array[PackedScene]) -> void:
	var enemy_container := get_node_or_null(enemy_container_path)
	var boss_container := get_node_or_null(boss_container_path)
	var bg_rect := get_node_or_null(background_rect_path) as TextureRect

	var is_boss_fight := false
	if RunData.last_map_room != null and RunData.last_map_room.type == Room.Type.BOSS:
		is_boss_fight = true

	var active_container = boss_container if is_boss_fight and boss_container else enemy_container

	if bg_rect:
		if is_boss_fight:
			bg_rect.texture = preload("res://assets/enemies/boss/backgroundboss.png")
		else:
			bg_rect.texture = preload("res://assets/Placeholders/backgrounds/combatbg.png")

	var player_anchor = get_node_or_null(ui_player)
	if player_anchor != null:
		var inner_sprite = player_anchor.get_node_or_null("Player")
		if inner_sprite is Sprite2D:
			if is_boss_fight:
				var mat = ShaderMaterial.new()
				mat.shader = preload("res://shaders/grayscale.gdshader")
				inner_sprite.material = mat
			else:
				inner_sprite.material = null

	if enemy_container:
		for child in enemy_container.get_children():
			child.queue_free()
				
	if boss_container:
		for child in boss_container.get_children():
			child.queue_free()

	if active_container == null:
		return

	for enemy_scene in encounter_enemy_scenes:
		if enemy_scene == null:
			continue
		var enemy_instance := enemy_scene.instantiate()
		active_container.add_child(enemy_instance)
		_apply_enemy_scaling(enemy_instance)
		
		var statue_thing = enemy_instance.get_node_or_null("StatueThing")
		if statue_thing:
			var gp = statue_thing.global_position
			enemy_instance.remove_child(statue_thing)
			active_container.add_child(statue_thing)
			statue_thing.global_position = gp
			active_container.move_child(statue_thing, enemy_instance.get_index())
			
		var statue = enemy_instance.get_node_or_null("Statue")
		if statue:
			var gp = statue.global_position
			enemy_instance.remove_child(statue)
			active_container.add_child(statue)
			statue.global_position = gp

func _refresh_enemy_entities() -> void:
	enemy_entities.clear()

	var enemy_container := get_node_or_null(enemy_container_path)
	if enemy_container != null:
		for child in enemy_container.get_children():
			if child is CombatEntity and not child.is_queued_for_deletion():
				_register_enemy_entity(child as CombatEntity)

	var boss_container := get_node_or_null(boss_container_path)
	if boss_container != null:
		for child in boss_container.get_children():
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
		_update_button_states()
		return
	if spell != null and spell.spell_type == SpellData.SpellType.HEAL:
		if not _spend_spell_energy(spell):
			return
		_apply_player_heal(spell.heal_amount)
		_play_attack_feedback(spell, null, null)
		_attack_selected = false
		selected_spell = null
		_update_button_states()
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
		var keycode = Settings.data.spell_keybinds[slot_index]
		bind_label.text = OS.get_keycode_string(keycode)

	button.tooltip_text = ""
	if spell != null:
		if spell.icon != null:
			button.icon = spell.icon
		
		var panel := button.get_node_or_null("Panel") as Panel
		if panel != null:
			var sb := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			if sb != null:
				sb.border_width_left = 0
				sb.border_width_right = 0
				sb.border_width_top = 0
				sb.border_width_bottom = 0
				sb.border_color = spell.get_tier_color()
				sb.corner_radius_top_left = 2
				sb.corner_radius_top_right = 2
				sb.corner_radius_bottom_left = 2
				sb.corner_radius_bottom_right = 2
				panel.add_theme_stylebox_override("panel", sb)
		
		button.add_theme_color_override("icon_normal_color", spell.icon_color)
		button.add_theme_color_override("icon_pressed_color", spell.icon_color)
		button.add_theme_color_override("icon_hover_color", spell.icon_color)
		button.add_theme_color_override("icon_hover_pressed_color", spell.icon_color)
		button.add_theme_color_override("icon_focus_color", spell.icon_color)
	
	button.disabled = false
	button.modulate = Color.WHITE

	var on_pressed := Callable(self, "_on_spell_button_pressed").bind(button)
	if not button.pressed.is_connected(on_pressed):
		button.pressed.connect(on_pressed)

	var on_mouse_entered := Callable(self, "_on_spell_button_mouse_entered").bind(button)
	if not button.mouse_entered.is_connected(on_mouse_entered):
		button.mouse_entered.connect(on_mouse_entered)

	var on_mouse_exited := Callable(self, "_on_spell_button_mouse_exited").bind(button)
	if not button.mouse_exited.is_connected(on_mouse_exited):
		button.mouse_exited.connect(on_mouse_exited)

func _configure_empty_spell_button(button: Button) -> void:
	var bind_label = button.get_node_or_null("Bind") as Label
	var slot_index := _spell_buttons.find(button)
	if bind_label != null:
		var keycode = Settings.data.spell_keybinds[slot_index]
		bind_label.text = OS.get_keycode_string(keycode)
	
	button.icon = null
	button.tooltip_text = ""
	button.disabled = true
	
	var on_pressed := Callable(self, "_on_spell_button_pressed").bind(button)
	if button.pressed.is_connected(on_pressed):
		button.pressed.disconnect(on_pressed)

	var on_mouse_entered := Callable(self, "_on_spell_button_mouse_entered").bind(button)
	if button.mouse_entered.is_connected(on_mouse_entered):
		button.mouse_entered.disconnect(on_mouse_entered)

	var on_mouse_exited := Callable(self, "_on_spell_button_mouse_exited").bind(button)
	if button.mouse_exited.is_connected(on_mouse_exited):
		button.mouse_exited.disconnect(on_mouse_exited)

func build_spell_tooltip_bbcode(spell: SpellData, shift_pressed: bool = false, show_upgrade_comparison: bool = false) -> String:
	if spell == null:
		return ""

	var existing: SpellData = RunData.get_spell_by_id(spell.spell_id)
	var is_upgrade := (show_upgrade_comparison and existing != null)

	var type_color := _spell_type_color(spell.spell_type)
	var type_hex := type_color.to_html(false)

	var spell_display_name := spell.spell_name
	if is_upgrade:
		spell_display_name += " (Lvl %d → %d)" % [existing.level, existing.level + 1]

	var t := "[b][font_size=15]%s[/font_size][/b]" % spell_display_name
	var tier_hex := spell.get_tier_color().to_html(false)
	var tier_name := "Tier " + str(int(spell.tier) + 1)
	t += "\n[color=#%s]%s[/color]  •  [color=#%s]%s[/color]" % [type_hex, _spell_type_to_text(spell.spell_type), tier_hex, tier_name]
	t += "\nTarget: [color=#cccccc]%s[/color]" % _target_scope_to_text(spell.target_scope)

	if spell.energy > 0:
		var can_afford := RunData.current_energy >= _get_spell_energy_cost(spell)
		var energy_color := "64e06e" if can_afford else "e06464"
		t += "\nEnergy: [color=#%s]%d[/color]" % [energy_color, _get_spell_energy_cost(spell)]
		if shift_pressed:
			t += "\n[color=#8a8a9e][font_size=11]  - Energy cost to use this spell.[/font_size][/color]"

	if spell.has_damage():
		var min_damage := spell.get_min_damage()
		var max_damage := spell.get_max_damage()
		var attacks := spell.get_attack_count()
		var dmg_color := "ffcca0"
		
		if is_upgrade:
			var curr_min := existing.get_min_damage()
			var curr_max := existing.get_max_damage()
			var next_min := int(round(curr_min * 1.2))
			var next_max := int(round(curr_max * 1.2))
			if next_max < next_min:
				next_max = next_min
			
			if curr_min == curr_max:
				t += "\nDamage: [color=#%s]%d[/color] → [color=#90d080]%d[/color]" % [dmg_color, curr_min, next_min]
			else:
				t += "\nDamage: [color=#%s]%d-%d[/color] → [color=#90d080]%d-%d[/color]" % [dmg_color, curr_min, curr_max, next_min, next_max]
		else:
			if min_damage == max_damage:
				t += "\nDamage: [color=#%s]%d[/color]" % [dmg_color, min_damage]
			else:
				t += "\nDamage: [color=#%s]%d-%d[/color]" % [dmg_color, min_damage, max_damage]
		if attacks > 1:
			t += "\nHits: [color=#e0d080]%d[/color]" % attacks
			if shift_pressed:
				t += "\n[color=#8a8a9e][font_size=11]  - This spell strikes multiple times.[/font_size][/color]"

	if spell.heal_amount > 0 or (is_upgrade and existing.heal_amount > 0):
		if is_upgrade:
			var curr_heal := existing.heal_amount
			var next_heal := int(round(curr_heal * 1.2))
			t += "\nHeal: [color=#64e09e]%d[/color] → [color=#90d080]%d[/color]" % [curr_heal, next_heal]
		else:
			t += "\nHeal: [color=#64e09e]%d[/color]" % spell.heal_amount

	var effect_lines: Array[String] = []
	if spell.outgoing_damage_flat_bonus != 0:
		effect_lines.append("Outgoing Damage: [color=#e0d080]%s[/color]" % _format_signed_int(spell.outgoing_damage_flat_bonus))
	if not is_zero_approx(spell.outgoing_damage_multiplier_delta):
		effect_lines.append("Outgoing Damage Mult: [color=#e0d080]%s%%[/color]" % _format_signed_percent(spell.outgoing_damage_multiplier_delta * 100.0))
	if not is_zero_approx(spell.incoming_damage_multiplier_delta):
		effect_lines.append("Incoming Damage Mult: [color=#e09080]%s%%[/color]" % _format_signed_percent(spell.incoming_damage_multiplier_delta * 100.0))
	if not is_zero_approx(spell.player_defense_delta):
		effect_lines.append("Player Defense: [color=#80c8e0]%s%%[/color]" % _format_signed_percent(spell.player_defense_delta))
	if not is_zero_approx(spell.target_defense_delta):
		effect_lines.append("Target Defense: [color=#cccccc]%s%%[/color]" % _format_signed_percent(spell.target_defense_delta))
	if spell.damage_over_time != 0:
		effect_lines.append("Damage Over Time: [color=#e07060]%s/turn[/color]" % _format_signed_int(spell.damage_over_time))
	if spell.stun_turns:
		effect_lines.append("[color=#e0a030]Applies Stun[/color]")

	if not effect_lines.is_empty():
		var dur_suffix := "turn" if spell.duration_rounds == 1 else "turns"
		t += "\nDuration: [color=#c8c8c8]%d %s[/color]" % [spell.duration_rounds, dur_suffix]
		for effect_line in effect_lines:
			t += "\n%s" % effect_line
			if shift_pressed:
				t += "\n [color=#8a8a9e][font_size=11]  - Active for %d turn%s.[/font_size][/color]" % [spell.duration_rounds, "" if spell.duration_rounds == 1 else "s"]

	if not shift_pressed:
		t += "\n[color=#5a5a6a][font_size=10][i]Hold Shift for more info[/i][/font_size][/color]"

	return t

func _spell_type_color(spell_type: SpellData.SpellType) -> Color:
	match spell_type:
		SpellData.SpellType.ATTACK:
			return Color(1.0, 0.48, 0.38, 1.0)
		SpellData.SpellType.BUFF:
			return Color(0.38, 0.82, 0.52, 1.0)
		SpellData.SpellType.DEBUFF:
			return Color(0.82, 0.52, 1.0, 1.0)
		SpellData.SpellType.HEAL:
			return Color(0.38, 0.88, 0.62, 1.0)
		_:
			return Color(0.7, 0.7, 0.7, 1.0)

func _on_spell_button_mouse_entered(button: Button) -> void:
	var spell := _button_spells.get(button, null) as SpellData
	if spell != null:
		_show_spell_tooltip(spell)

func _on_spell_button_mouse_exited(_button: Button) -> void:
	_spell_tooltip_spell = null
	_hide_spell_tooltip()

func _ensure_spell_tooltip() -> void:
	if _spell_tooltip != null:
		return

	_spell_tooltip = PanelContainer.new()
	_spell_tooltip.name = "SpellTooltip"
	_spell_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_tooltip.z_index = 200
	_spell_tooltip.top_level = true
	_spell_tooltip.visible = false

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

	_spell_tooltip.add_theme_stylebox_override("panel", style)

	_spell_tooltip_label = RichTextLabel.new()
	_spell_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spell_tooltip_label.fit_content = true
	_spell_tooltip_label.scroll_active = false
	_spell_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_spell_tooltip_label.custom_minimum_size = Vector2(0, 0)
	_spell_tooltip_label.bbcode_enabled = true
	_spell_tooltip_label.add_theme_font_size_override("normal_font_size", 13)
	_spell_tooltip_label.add_theme_font_size_override("bold_font_size", 14)
	_spell_tooltip_label.add_theme_color_override("default_color", Color(0.92, 0.92, 0.95, 1.0))
	_spell_tooltip.add_child(_spell_tooltip_label)

	add_child(_spell_tooltip)

func _show_spell_tooltip(spell: SpellData, show_upgrade_comparison: bool = false) -> void:
	_ensure_spell_tooltip()
	_spell_tooltip_spell = spell
	_spell_tooltip_was_shift_pressed = Input.is_key_pressed(KEY_SHIFT)
	_spell_tooltip_show_upgrade_comparison = show_upgrade_comparison

	var bbcode := build_spell_tooltip_bbcode(spell, _spell_tooltip_was_shift_pressed, show_upgrade_comparison)
	_spell_tooltip_label.text = ""
	_spell_tooltip.reset_size()
	_spell_tooltip_label.text = bbcode
	_spell_tooltip.visible = true
	_update_spell_tooltip_position()

func _hide_spell_tooltip() -> void:
	if _spell_tooltip != null:
		_spell_tooltip.visible = false

## Public wrappers — safe to call from external scripts (e.g. combat_summary)
func show_spell_tooltip(spell: SpellData, show_upgrade_comparison: bool = false) -> void:
	_show_spell_tooltip(spell, show_upgrade_comparison)

func hide_spell_tooltip() -> void:
	_hide_spell_tooltip()

func _update_spell_tooltip_position() -> void:
	if _spell_tooltip == null or not _spell_tooltip.visible:
		return
	var vp_size  := get_viewport().get_visible_rect().size
	var mouse    := get_viewport().get_mouse_position()
	var tip_size := _spell_tooltip.size

	# Show tooltip above the mouse, slightly offset
	var pos := mouse + Vector2(-tip_size.x * 0.5, -tip_size.y - 14.0)
	pos.x = clamp(pos.x, 0.0, vp_size.x - tip_size.x)
	pos.y = clamp(pos.y, 0.0, vp_size.y - tip_size.y)
	_spell_tooltip.global_position = pos

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
	for i in range(Settings.data.spell_keybinds.size()):
		var keycode = Settings.data.spell_keybinds[i]
		if event.physical_keycode == keycode or event.keycode == keycode:
			return i
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
	if end_turn_button != null:
		var can_end_turn := current_state == CombatState.PLAYER_TURN and not _attack_selected and _has_alive_enemies()
		end_turn_button.disabled = not can_end_turn
		end_turn_button.modulate = Color.WHITE if can_end_turn else Color(0.4, 0.4, 0.4, 1.0)

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

func _setup_consumable_buttons() -> void:
	_consumable_buttons.clear()
	if consumables_grid == null:
		return
	for idx in range(consumables_grid.get_child_count()):
		var button = consumables_grid.get_child(idx)
		if button == null:
			continue
		_consumable_buttons.append(button)
		if button.has_signal("item_pressed"):
			var on_pressed := Callable(self, "_on_consumable_pressed")
			if not button.item_pressed.is_connected(on_pressed):
				button.item_pressed.connect(on_pressed)
	_refresh_consumable_buttons()

func _refresh_consumable_buttons() -> void:
	if _consumable_buttons.is_empty():
		return
	for idx in range(_consumable_buttons.size()):
		var button = _consumable_buttons[idx]
		var item: ItemData = null
		if idx < RunData.consumables.size():
			item = RunData.consumables[idx]
		if button.has_method("set_item"):
			button.set_item(item, idx)

func _on_consumable_pressed(slot_index: int) -> void:
	SoundManager.play_potion()
	if current_state != CombatState.PLAYER_TURN:
		return
	if slot_index < 0 or slot_index >= RunData.consumables.size():
		return
	if _item_effects.has_item_named("The Hollow Heart"):
		print("Cannot use consumables while The Hollow Heart is active.")
		return
	var item := RunData.consumables[slot_index] as ItemData
	if item == null:
		return
	_item_effects.apply_consumable_item(item)
	RunData.consumables[slot_index] = null
	_refresh_consumable_buttons()
	_update_button_states()

func _get_spell_energy_cost(spell: SpellData) -> int:
	if spell == null:
		return 0
		
	var reduction: int = _item_effects.get_item_cooldown_reduction() + _item_effects.get_temp_cooldown_reduction()
	if spell.energy >= 3 and _item_effects.has_item_named("Vial of Stagnant Time"):
		reduction += 1
	
	return maxi(0, spell.energy - reduction)

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
	if debug_round_stats:
		var limb_label: String = _item_effects.get_limb_label(limb)
		var hit_chance := _get_adjusted_hit_chance_percent(limb, source_enemy)
		var item_damage_bonus: int = _item_effects.get_item_damage_bonus(limb)
		var item_precision_bonus: float = _item_effects.get_item_precision_bonus(limb)
		var status_effects: Array[String] = _item_effects.get_item_statuses_for_limb(limb)
		var limb_name := "" if limb_label == "" else limb_label
		var lines: Array[String] = []
		lines.append("Hit chance vs %s: %.1f%%" % [limb_name, hit_chance])
		if item_damage_bonus != 0:
			lines.append("Item Damage Bonus: %+d" % item_damage_bonus)
		if not is_zero_approx(item_precision_bonus):
			lines.append("Item Precision Bonus: %+0.1f" % item_precision_bonus)
		if not status_effects.is_empty():
			lines.append("Item Statuses: %s" % ", ".join(status_effects))
		if lines.size() > 1:
			print("\n".join(lines))
		else:
			print(lines[0])

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
	if _roll_player_hit_on_limb(limb, source_enemy):
		var spell_damage := 0
		var spell_type := SpellData.SpellType.ATTACK
		var can_deal_damage := true
		var attack_count := 1
		if active_spell != null:
			spell_damage = active_spell.roll_damage()
			spell_type = active_spell.spell_type
			can_deal_damage = active_spell.has_damage()
			attack_count = active_spell.get_attack_count()

		if can_deal_damage and (spell_type == SpellData.SpellType.ATTACK or spell_type == SpellData.SpellType.DEBUFF):
			var player_modifiers := _get_player_outgoing_modifiers()
			var outgoing_multiplier := float(player_modifiers.get("mult", 1.0))
			var outgoing_flat := int(player_modifiers.get("flat", 0))
			for _attack_iteration in range(attack_count):
				if active_spell != null:
					spell_damage = active_spell.roll_damage()
				var base_damage = RunData.get_stat("damage") + spell_damage + outgoing_flat
				for target_enemy in target_enemies:
					if target_enemy == null or not is_instance_valid(target_enemy) or not target_enemy.is_alive:
						continue
					var target_limbs := _get_target_limbs(target_enemy, limb, selected_spell)
					for target_limb in target_limbs:
						if target_limb.is_destroyed:
							continue
						var item_damage_bonus: int = _item_effects.get_item_damage_bonus(target_limb)
						var raw_damage = base_damage + item_damage_bonus
						var incoming_multiplier := _get_enemy_incoming_multiplier(target_enemy, target_limb)
						var final_damage := int(round(float(raw_damage) * outgoing_multiplier * incoming_multiplier))
						var enemy_defense := _get_enemy_total_defense(target_enemy, target_limb)
						final_damage = _apply_defense_to_damage(final_damage, enemy_defense)
						final_damage = max(0, final_damage)
						if debug_round_stats:
							var limb_label: String = _item_effects.get_limb_label(target_limb)
							var limb_name := "" if limb_label == "" else limb_label.capitalize()
							var spell_name := "Attack" if active_spell == null else active_spell.spell_name
							var pre_defense_damage := int(round(float(raw_damage) * outgoing_multiplier * incoming_multiplier))
							print("\nDamage Calculation for %s -> %s (%s):" % [spell_name, target_enemy.name, limb_name])
							print("  Base: %d (player: %d, spell: %d, bonus: %+d)" % [base_damage, RunData.get_stat("damage"), spell_damage, outgoing_flat])
							print("  Raw: %d (base: %d, item bonus: %+d)" % [raw_damage, base_damage, item_damage_bonus])
							print("  Pre-Defense: %d (raw: %d, outgoing mult: %.2f, incoming mult: %.2f)" % [pre_defense_damage, raw_damage, outgoing_multiplier, incoming_multiplier])
							print("  After Defense: %d (defense: %.1f%%)" % [final_damage, enemy_defense])
						if final_damage > 0:
							target_enemy.take_damage(target_limb, final_damage)
							_item_effects.apply_item_status_on_hit(target_enemy, target_limb)
							_item_effects.apply_pending_consumable_status(target_enemy, target_limb)
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
		SoundManager.play_miss()
	_attack_selected = false
	selected_spell = null
	_clear_spell_cursor_overlay()
	_update_enemy_spell_targeting_preview()
	source_enemy.clear_current_highlight()
	_update_button_states()

func _only_vital_limbs_remain(source_enemy: CombatEntity) -> bool:
	if source_enemy == null or not is_instance_valid(source_enemy):
		return false
	for limb in source_enemy.limbs:
		if limb != null and is_instance_valid(limb) and not limb.is_destroyed and not limb.is_vital:
			return false
	return true

func _get_adjusted_hit_chance_percent(limb: CombatLimb, source_enemy: CombatEntity = null) -> float:
	if limb == null or not is_instance_valid(limb):
		return 0.0
	if source_enemy != null and _only_vital_limbs_remain(source_enemy):
		return 100.0
		
	var precision_multiplier: float = RunData.get_stat("precision") / 100.0
	var item_precision_bonus: float = _item_effects.get_item_precision_bonus(limb)
	var temp_precision_bonus: float = _item_effects.get_temp_precision_bonus()
	
	var final_chance := (limb.hit_chance_percent * precision_multiplier) + item_precision_bonus + temp_precision_bonus
	return clampf(final_chance, 0.0, 100.0)

func _roll_player_hit_on_limb(limb: CombatLimb, source_enemy: CombatEntity = null) -> bool:
	return randf() * 100.0 < _get_adjusted_hit_chance_percent(limb, source_enemy)

func _on_enemy_died(_entity: CombatEntity) -> void:
	if _entity != null and is_instance_valid(_entity):
		_exp_gained_this_combat += _entity.exp_reward
		_enemy_effects.erase(_entity.get_instance_id())
		_enemy_limb_effects.erase(_entity.get_instance_id())
		_enemy_intents.erase(_entity.get_instance_id())
		_refresh_enemy_buffs_ui()
		if current_state == CombatState.PLAYER_TURN:
			_clear_enemy_intent_visuals()
			_show_enemy_intent_visuals()
		if _item_effects.has_item_named("The Hollow Heart"):
			var heal_amount := int(_item_effects.get_item_value_by_name("The Hollow Heart", 15.0))
			_apply_player_heal(heal_amount)

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
	if limb != null and is_instance_valid(limb) and limb.is_destroyed:
		_item_effects.apply_item_status_on_break(entity, limb)
		if current_state == CombatState.PLAYER_TURN:
			_refresh_intent_after_limb_destroyed(entity, limb)

func _refresh_intent_after_limb_destroyed(entity: CombatEntity, destroyed_limb: CombatLimb) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	var entity_id := entity.get_instance_id()
	var intent := _enemy_intents.get(entity_id, {}) as Dictionary
	var intent_limb := intent.get("limb") as CombatLimb
	if intent_limb == null or not is_instance_valid(intent_limb) or intent_limb == destroyed_limb:
		var new_attack_limb := _choose_enemy_attack_limb(entity)
		if new_attack_limb != null:
			var new_attack := new_attack_limb.choose_attack()
			if new_attack != null:
				_enemy_intents[entity_id] = {
					"enemy": entity,
					"limb": new_attack_limb,
					"attack": new_attack,
				}
			else:
				_enemy_intents.erase(entity_id)
		else:
			_enemy_intents.erase(entity_id)

	_clear_enemy_intent_visuals()
	_show_enemy_intent_visuals()

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

	var base_scale: Vector2
	if impact_node.has_meta("impact_base_scale"):
		base_scale = impact_node.get_meta("impact_base_scale")
	else:
		base_scale = impact_node.scale
		impact_node.set_meta("impact_base_scale", base_scale)

	var base_position: Vector2
	if impact_node.has_meta("impact_base_position"):
		base_position = impact_node.get_meta("impact_base_position")
	else:
		base_position = impact_node.position
		impact_node.set_meta("impact_base_position", base_position)

	impact_node.scale = base_scale
	impact_node.position = base_position

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
			impact_node.remove_meta("impact_base_scale")
			impact_node.remove_meta("impact_base_position")
	)


func _apply_raw_player_damage(amount: int) -> void:
	if amount <= 0 or current_state == CombatState.COMBAT_OVER:
		return
	RunData.current_health = max(0, RunData.current_health - amount)
	var player_hit_position = _get_vfx_anchor_position(null)
	if player_hit_position is Vector2:
		_spawn_floating_damage_number(amount, player_hit_position as Vector2, true)
	if RunData.current_health <= 0:
		current_state = CombatState.COMBAT_OVER
		_restart_run_on_player_death()

func _on_end_turn_button_pressed() -> void:
	if current_state != CombatState.PLAYER_TURN or _attack_selected:
		return
	_end_player_turn()

func _end_player_turn() -> void:
	if not _has_alive_enemies():
		return
	_clear_enemy_intent_visuals()
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

		var attack_limb: CombatLimb = null
		var attack: SpellData = null
		var _intent := _enemy_intents.get(attacking_enemy.get_instance_id(), {}) as Dictionary
		if not _intent.is_empty():
			attack_limb = _intent.get("limb") as CombatLimb
			attack = _intent.get("attack") as SpellData
			if attack_limb == null or not is_instance_valid(attack_limb) or attack_limb.is_destroyed:
				attack_limb = _choose_enemy_attack_limb(attacking_enemy)
				attack = null
			if attack_limb != null and attack == null:
				attack = attack_limb.choose_attack()
		else:
			attack_limb = _choose_enemy_attack_limb(attacking_enemy)
			if attack_limb == null:
				continue
			attack = attack_limb.choose_attack()
		if attack_limb == null or attack == null:
			continue

		await _telegraph_enemy_attack(attacking_enemy, attack_limb, attack)
		await _play_attack_feedback(attack, attacking_enemy, get_node_or_null(ui_player))
		var outgoing_multiplier := _get_enemy_outgoing_multiplier(attacking_enemy)
		var attack_count := attack.get_attack_count()
		for _attack_iteration in range(attack_count):
			if current_state == CombatState.COMBAT_OVER:
				return
			var base_damage := attack.roll_damage()
			var damage: int = int(round(float(base_damage) * outgoing_multiplier))
			if debug_round_stats and _attack_iteration == 0:
				print("\nEnemy Attack from %s:" % attacking_enemy.name)
				print("  Base: %d (rolled damage, outgoing mult: %.2f)" % [base_damage, outgoing_multiplier])
				print("  Final Pre-Defense: %d (defense will reduce this)" % damage)
			_apply_player_damage(damage, attacking_enemy, attack_limb)
			if current_state == CombatState.COMBAT_OVER:
				return
			if _attack_iteration < attack_count - 1 and multi_hit_delay_seconds > 0.0:
				await get_tree().create_timer(multi_hit_delay_seconds).timeout

	_end_enemy_turn()

func _choose_enemy_attack_limb(source_enemy: CombatEntity) -> CombatLimb:
	var best_candidate: CombatLimb = null
	var best_weight := -1.0
	for limb in source_enemy.limbs:
		if limb.is_destroyed:
			continue
		if _is_enemy_limb_stunned(source_enemy, limb):
			continue
		if limb.has_attack_options():
			var limb_weight := 0.0
			for attack in limb.get_attack_options():
				limb_weight += maxf(0.0, attack.weight)
			if limb_weight > best_weight:
				best_weight = limb_weight
				best_candidate = limb
	return best_candidate

func _telegraph_enemy_attack(source_enemy: CombatEntity, attack_limb: CombatLimb, attack: SpellData) -> void:
	if enemy_attack_telegraph_seconds <= 0.0:
		return
	if source_enemy == null or not is_instance_valid(source_enemy):
		return
	if attack_limb == null or not is_instance_valid(attack_limb) or attack_limb.is_destroyed:
		return

	var highlighted_limbs: Array[CombatLimb] = []
	var highlight_whole_enemy := false
	if attack != null:
		highlight_whole_enemy = attack.target_scope == SpellData.TargetScope.WHOLE_ENEMY or attack.target_scope == SpellData.TargetScope.ALL_ENEMIES

	if highlight_whole_enemy:
		for limb in source_enemy.limbs:
			if limb != null and is_instance_valid(limb) and not limb.is_destroyed:
				limb.set_highlighted(Color(1.0, 0.2, 0.2, 1.0))
				highlighted_limbs.append(limb)
	else:
		attack_limb.set_highlighted(Color(1.0, 0.2, 0.2, 1.0))
		highlighted_limbs.append(attack_limb)

	var original_scales: Array[Vector2] = []
	for limb in highlighted_limbs:
		if limb == null or not is_instance_valid(limb):
			original_scales.append(Vector2.ONE)
			continue
		original_scales.append(limb.scale)
		limb.modulate = Color(1.0, 0.14, 0.14, 1.0)
		var pulse_tween := create_tween()
		pulse_tween.set_parallel(true)
		pulse_tween.tween_property(limb, "modulate", Color(1.0, 0.08, 0.08, 1.0), enemy_attack_telegraph_seconds * 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		pulse_tween.tween_property(limb, "scale", limb.scale * enemy_attack_telegraph_scale, enemy_attack_telegraph_seconds * 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pulse_tween.set_parallel(false)
		pulse_tween.set_parallel(true)
		pulse_tween.tween_property(limb, "modulate", Color(1.0, 0.18, 0.18, 1.0), enemy_attack_telegraph_seconds * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		pulse_tween.tween_property(limb, "scale", original_scales[-1], enemy_attack_telegraph_seconds * 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await get_tree().create_timer(enemy_attack_telegraph_seconds).timeout

	for idx in range(highlighted_limbs.size()):
		var limb := highlighted_limbs[idx]
		if limb != null and is_instance_valid(limb):
			limb.scale = original_scales[idx]
			limb.set_unhighlighted()

func _pre_roll_enemy_intents() -> void:
	_enemy_intents.clear()
	for enemy in _get_alive_enemies():
		if not is_instance_valid(enemy) or _is_enemy_stunned(enemy):
			continue
		var attack_limb := _choose_enemy_attack_limb(enemy)
		if attack_limb == null or not is_instance_valid(attack_limb):
			continue
		var attack := attack_limb.choose_attack()
		if attack == null:
			continue
		_enemy_intents[enemy.get_instance_id()] = {
			"enemy": enemy,
			"limb": attack_limb,
			"attack": attack,
		}

func _show_enemy_intent_visuals() -> void:
	_clear_enemy_intent_visuals()
	for enemy_id in _enemy_intents.keys():
		var intent := _enemy_intents[enemy_id] as Dictionary
		var enemy := intent.get("enemy") as CombatEntity
		var attack_limb := intent.get("limb") as CombatLimb
		var attack := intent.get("attack") as SpellData
		if attack_limb == null or not is_instance_valid(attack_limb) or attack_limb.is_destroyed:
			continue
		if attack == null or enemy == null or not is_instance_valid(enemy):
			continue

		_start_intent_limb_pulse(attack_limb)
		_intent_limb_refs.append(attack_limb)

		var outgoing_mult := _get_enemy_outgoing_multiplier(enemy)
		var count := attack.get_attack_count()
		var min_dmg := int(round(float(attack.get_min_damage()) * outgoing_mult)) * count
		var max_dmg := int(round(float(attack.get_max_damage()) * outgoing_mult)) * count
		var dmg_text: String
		if min_dmg == max_dmg:
			dmg_text = str(min_dmg)
		else:
			dmg_text = "%d-%d" % [min_dmg, max_dmg]

		var label := Label.new()
		label.text = dmg_text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.z_index = 300
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		label.add_theme_constant_override("outline_size", 8)
		add_child(label)
		label.global_position = attack_limb.global_position + Vector2(-16.0, -52.0)
		_intent_labels.append(label)

func _start_intent_limb_pulse(limb: CombatLimb) -> void:
	if limb == null or not is_instance_valid(limb) or limb.is_destroyed:
		return
	limb.modulate = Color(1.0, 0.55, 0.1, 1.0)
	var tween := create_tween().set_loops()
	tween.tween_property(limb, "modulate", Color(1.0, 0.28, 0.0, 1.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(limb, "modulate", Color(1.0, 0.55, 0.1, 1.0), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_intent_pulsing_tweens.append(tween)

func _clear_enemy_intent_visuals() -> void:
	for tween in _intent_pulsing_tweens:
		if tween != null and is_instance_valid(tween):
			tween.kill()
	_intent_pulsing_tweens.clear()
	for limb in _intent_limb_refs:
		if limb != null and is_instance_valid(limb) and not limb.is_destroyed:
			limb.modulate = Color.WHITE
	_intent_limb_refs.clear()
	for label in _intent_labels:
		if label != null and is_instance_valid(label):
			label.queue_free()
	_intent_labels.clear()

func get_limb_intent_tooltip(enemy: CombatEntity, limb: CombatLimb) -> String:
	if enemy == null or limb == null or not is_instance_valid(enemy) or not is_instance_valid(limb):
		return ""
	var intent := _enemy_intents.get(enemy.get_instance_id(), {}) as Dictionary
	if intent.is_empty():
		return ""
	var attack_limb := intent.get("limb") as CombatLimb
	if attack_limb != limb:
		return ""
		
	var attack := intent.get("attack") as SpellData
	if attack == null:
		return ""

	var outgoing_mult := _get_enemy_outgoing_multiplier(enemy)
	var count := attack.get_attack_count()
	var min_dmg := int(round(float(attack.get_min_damage()) * outgoing_mult)) * count
	var max_dmg := int(round(float(attack.get_max_damage()) * outgoing_mult)) * count
	
	var dmg_text: String
	if min_dmg == max_dmg:
		dmg_text = str(min_dmg)
	else:
		dmg_text = "%d-%d" % [min_dmg, max_dmg]

	var intent_string := "\n\n[color=red]ENEMY INTENT[/color]"
	intent_string += "\nWill attack using this limb next turn, dealing [color=#ff5555]%s[/color] damage." % dmg_text
	return intent_string

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
	var active_player_effects: Array[Dictionary] = []
	for raw_effect in _player_effects:
		var effect := raw_effect as Dictionary
		if effect.is_empty():
			continue
		var expires_round := int(effect.get("expires_round", current_round))
		if current_round <= expires_round:
			active_player_effects.append(effect)
		else:
			var expire_damage := int(effect.get("expire_damage", 0))
			if expire_damage > 0:
				_apply_raw_player_damage(expire_damage)
	_player_effects = active_player_effects

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
		or not is_zero_approx(spell.player_defense_delta)
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
		"icon_color": spell.icon_color,
		"border_color": spell.get_tier_color(),
		"outgoing_flat": spell.outgoing_damage_flat_bonus,
		"outgoing_mult_delta": spell.outgoing_damage_multiplier_delta,
		"damage_over_time": spell.damage_over_time,
		"stun_turns": bool(spell.stun_turns),
		"target_scope": int(spell.target_scope),
		"defense_delta": spell.player_defense_delta,
	})

	_refresh_player_buffs_ui()

func _append_enemy_effect(target_enemy: CombatEntity, spell: SpellData, target_limb: CombatLimb = null) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy) or spell == null:
		return

	var has_effect := not is_zero_approx(spell.outgoing_damage_multiplier_delta) \
		or not is_zero_approx(spell.incoming_damage_multiplier_delta) \
		or spell.damage_over_time != 0 \
		or spell.stun_turns \
		or not is_zero_approx(spell.target_defense_delta)
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
		"target_scope": int(spell.target_scope),
		"defense_delta": spell.target_defense_delta,
		"spell_name": spell.spell_name,
		"spell_type": int(spell.spell_type),
		"icon": spell.icon,
		"icon_color": spell.icon_color,
		"border_color": spell.get_tier_color(),
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

			var icon_color = effect.get("icon_color", Color.WHITE) as Color
			var border_width = 0
			var border_color = effect.get("border_color", Color.WHITE) as Color
			
			var sb := buff_icon.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
			if sb != null:
				sb.border_width_left = border_width
				sb.border_width_right = border_width
				sb.border_width_top = border_width
				sb.border_width_bottom = border_width
				sb.border_color = border_color
				sb.corner_radius_top_left = 2
				sb.corner_radius_top_right = 2
				sb.corner_radius_bottom_left = 2
				sb.corner_radius_bottom_right = 2
				buff_icon.add_theme_stylebox_override("panel", sb)

			if int(effect.get("spell_type", SpellData.SpellType.DEBUFF)) == int(SpellData.SpellType.DEBUFF):
				if icon_rect != null:
					icon_rect.modulate = icon_color * Color(1.0, 0.85, 0.85, 1.0)
			else:
				if icon_rect != null:
					icon_rect.modulate = icon_color

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
		
		var icon_color = effect.get("icon_color", Color.WHITE) as Color
		var border_width = 0
		var border_color = effect.get("border_color", Color.WHITE) as Color
		
		var sb := buff_icon.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if sb != null:
			sb.border_width_left = border_width
			sb.border_width_right = border_width
			sb.border_width_top = border_width
			sb.border_width_bottom = border_width
			sb.border_color = border_color
			sb.corner_radius_top_left = 2
			sb.corner_radius_top_right = 2
			sb.corner_radius_bottom_left = 2
			sb.corner_radius_bottom_right = 2
			buff_icon.add_theme_stylebox_override("panel", sb)
			
		icon_rect.modulate = icon_color

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

	total_multiplier *= source_enemy.combat_scaling_multiplier

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
		var target_limb: CombatLimb = instance_from_id(int(limb_id)) as CombatLimb
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
		var enemy_defense := _get_enemy_total_defense(target_enemy, affected_limb)
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

func _apply_player_damage(amount: int, source_enemy: CombatEntity = null, source_limb: CombatLimb = null) -> void:
	if current_state == CombatState.COMBAT_OVER:
		return
	if amount <= 0:
		return
	if _item_effects.player_has_invulnerable():
		var immune_hit_position = _get_vfx_anchor_position(null)
		if immune_hit_position is Vector2:
			_spawn_floating_damage_number(0, immune_hit_position as Vector2, true, false, "IMMUNE")
		return
	var mitigated_amount := _apply_player_defense(amount)
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
	else:
		_item_effects.apply_player_reflect_damage(mitigated_amount, source_enemy, source_limb)

func _restart_run_on_player_death() -> void:
	if _is_exiting_combat:
		return
	_is_exiting_combat = true
	_show_defeat_screen()

func _show_defeat_screen() -> void:
	if DEFEAT_SCREEN_SCENE == null:
		RunData.end_run()
		SaveLoad.save_data()
		TransitionManager.change_scene("res://scenes/UI/main_menu/main_menu.tscn", TransitionManager.TransitionType.FADE)
		return
	
	var defeat_screen = DEFEAT_SCREEN_SCENE.instantiate()
	add_child(defeat_screen)

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

func _apply_player_defense(amount: int) -> int:
	var defense := _get_player_defense()
	return _apply_defense_to_damage(amount, defense)

func _get_player_defense() -> float:
	_cleanup_expired_effects()

	var total_defense := float(RunData.get_stat("defense"))
	total_defense += _item_effects.get_item_defense_bonus()
	for effect in _player_effects:
		var expires_round := int(effect.get("expires_round", current_round))
		if current_round <= expires_round:
			total_defense += float(effect.get("defense_delta", 0.0))

	return max(0.0, total_defense)

func _get_enemy_total_defense(source_enemy: CombatEntity, source_limb: CombatLimb) -> float:
	if source_enemy == null or not is_instance_valid(source_enemy):
		return 0.0

	_cleanup_expired_effects()

	var total_defense := source_enemy.get_defense()
	if source_limb != null and is_instance_valid(source_limb):
		total_defense += source_limb.get_defense()

	var defense_key := "defense_delta"

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
	var vfx_lifetime_timer: SceneTreeTimer = null

	if attack.sfx != null:
		SoundManager.play_sfx(attack.sfx, attack.sfx_volume_db)

	await _play_attack_lunge(source_entity, target_entity)

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

	var start_position: Vector2
	if source_canvas.has_meta("base_position"):
		start_position = source_canvas.get_meta("base_position")
	else:
		start_position = source_canvas.global_position
		source_canvas.set_meta("base_position", start_position)

	var target_position := raw_target_position as Vector2
	var attack_direction := target_position - start_position
	if attack_direction.length_squared() <= 0.01:
		return

	var lunge_distance := minf(attack_lunge_distance, attack_direction.length() * 0.45)
	if lunge_distance <= 0.0:
		return

	var lunge_position := start_position + attack_direction.normalized() * lunge_distance
	var tween := create_tween()
	
	source_canvas.set_meta("active_lunge_tween", tween)
	
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(source_canvas, "global_position", lunge_position, 0.09)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(source_canvas, "global_position", start_position, 0.12)
	
	tween.finished.connect(func():
		if is_instance_valid(source_canvas):
			if source_canvas.has_meta("active_lunge_tween") and source_canvas.get_meta("active_lunge_tween") == tween:
				source_canvas.remove_meta("base_position")
				source_canvas.remove_meta("active_lunge_tween")
	)
	
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
	regen_amount += _item_effects.get_item_energy_regen_bonus()
	regen_amount += _item_effects.get_temp_energy_regen_bonus()
	_regenerate_player_energy(regen_amount)
	_attack_selected = false
	selected_spell = null
	_update_enemy_spell_targeting_preview()
	_set_enemy_targeting_enabled(false)
	_clear_spell_cursor_overlay()
	_update_button_states()
	_refresh_turns_order_ui()
	if debug_round_stats:
		_debug_print_round_stats()
	
	for enemy in enemy_entities:
		if enemy != null and is_instance_valid(enemy):
			enemy._refresh_highlight()
	_pre_roll_enemy_intents()
	call_deferred("_show_enemy_intent_visuals")

func _debug_print_round_stats() -> void:
	var stats_to_log := ["damage", "precision", "defense", "speed", "energy_regen", "luck"]
	var global_item_bonus := {
		"damage": 0.0,
		"precision": 0.0,
		"defense": 0.0,
		"speed": 0.0,
		"energy_regen": 0.0,
		"luck": 0.0,
	}
	var limb_effects: Dictionary = {}

	for item in RunData.items:
		if item == null:
			continue
		var target_key : String = _item_effects.normalize_target_key(item.target_limb)
		var is_global := target_key == "" or target_key == "none" or target_key == "all" or target_key == "alllimbs" or target_key == "self"
		if not is_global:
			var limb_label := target_key
			match target_key:
				"head":
					limb_label = "Head"
				"arm":
					limb_label = "Arm"
				"leg":
					limb_label = "Leg"
				"torso":
					limb_label = "Torso"
				"targetedlimb":
					limb_label = "Targeted Limb"
				_:
					limb_label = target_key
			if not limb_effects.has(limb_label):
				limb_effects[limb_label] = []
			var limb_entries: Array = limb_effects[limb_label]
			if item.status_to_apply.to_lower() != "none":
				limb_entries.append("Status %s (%s)" % [item.status_to_apply, item.item_name])
			elif item.buff_type.strip_edges() != "":
				limb_entries.append("%s %+0.1f (%s)" % [item.buff_type, item.buff_value, item.item_name])
			limb_effects[limb_label] = limb_entries
			continue

		var buff_type := item.buff_type.to_lower()
		if buff_type == "damage":
			global_item_bonus["damage"] += item.buff_value
		elif buff_type == "precision":
			global_item_bonus["precision"] += item.buff_value
		elif buff_type == "defense":
			if item.status_to_apply.to_lower() == "none" and item.item_name != "Thorned Bracer":
				global_item_bonus["defense"] += item.buff_value
		elif buff_type == "speed":
			global_item_bonus["speed"] += item.buff_value
		elif buff_type == "luck":
			global_item_bonus["luck"] += item.buff_value

	print("=== Round %d ===" % current_round)
	print("Global stats (base + global items):")
	for stat_key in stats_to_log:
		var base_value := float(PlayerStats.stats.get(stat_key, 0.0))
		var item_bonus := float(global_item_bonus.get(stat_key, 0.0))
		var total_value := base_value + item_bonus
		print("%s: %.2f (base %.2f, items %+0.2f)" % [stat_key, total_value, base_value, item_bonus])

	# temporary player effects 
	var temp_entries: Array[String] = []
	for raw_effect in _player_effects:
		var effect := raw_effect as Dictionary
		if effect.is_empty():
			continue
		var expires_round := int(effect.get("expires_round", current_round))
		var turns_remaining := int(max(1, expires_round - current_round + 1))
		var details: Array[String] = []
		var precision_delta := float(effect.get("precision_delta", 0.0))
		if not is_zero_approx(precision_delta):
			details.append("Precision %+0.1f" % precision_delta)
		var energy_regen_delta := float(effect.get("energy_regen_delta", 0.0))
		if not is_zero_approx(energy_regen_delta):
			details.append("EnergyRegen %+0.1f" % energy_regen_delta)
		var cooldown_delta := float(effect.get("cooldown_delta", 0.0))
		if not is_zero_approx(cooldown_delta):
			details.append("Cooldown %+0.1f" % cooldown_delta)
		var expire_damage := int(effect.get("expire_damage", 0))
		if expire_damage != 0:
			details.append("ExpireDmg %d" % expire_damage)
		if bool(effect.get("invulnerable", false)):
			details.append("Invulnerable")
		if details.is_empty():
			continue
		var effect_name := String(effect.get("spell_name", "Effect"))
		temp_entries.append("%s (%d turns): %s" % [effect_name, turns_remaining, ", ".join(details)])

	if temp_entries.size() > 0:
		print("Temporary effects:")
		for entry in temp_entries:
			print("- %s" % entry)

	if not limb_effects.is_empty():
		print("Limb-specific item effects:")
		for limb_label in limb_effects.keys():
			print("- %s" % limb_label)
			for entry in limb_effects[limb_label]:
				print("  * %s" % entry)

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
	var spell_icon_color: Color = Color.WHITE
	var spell_border_color: Color = Color.WHITE
	var spell_border_width: int = 0
	var use_whole_enemy_preview := false
	if _attack_selected and selected_spell != null:
		spell_icon = selected_spell.icon
		spell_icon_color = selected_spell.icon_color
		spell_border_color = selected_spell.get_tier_color()
		spell_border_width = 2
		var resolved_scope := _resolve_target_scope(selected_spell)
		use_whole_enemy_preview = resolved_scope == TargetScope.WHOLE_ENEMY or resolved_scope == TargetScope.ALL_ENEMIES

	for enemy in enemy_entities:
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.has_method("set_spell_targeting_preview"):
			enemy.set_spell_targeting_preview(_attack_selected, use_whole_enemy_preview, spell_icon, spell_icon_color, spell_border_color, spell_border_width)

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
	_spell_cursor_overlay.modulate = selected_spell.icon_color
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
				var texture_size := limb.texture.get_size() * limb.scale
				var limb_rect := Rect2(limb.global_position - texture_size * 0.5, texture_size)
				if limb_rect.has_point(mouse_pos):
					enemy._on_limb_mouse_entered(limb)
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

func _on_item_added(item: ItemData) -> void:
	if items_container == null or item == null:
		return
	var item_resource_path := item.resource_path
	for child in items_container.get_children():
		if child is Control and child.has_meta("item_resource_path") and child.get_meta("item_resource_path") == item_resource_path:
			_update_item_display_count(child, item)
			return

	_create_item_display(item, item_resource_path)

func _create_item_display(item: ItemData, resource_path: String) -> void:
	var container := Control.new()
	container.name = "ItemSlot"
	container.set_meta("item_resource_path", resource_path)
	container.custom_minimum_size = Vector2(48.0, 48.0)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var item_icon := TextureRect.new()
	item_icon.name = "Icon"
	item_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	item_icon.texture = item.texture
	item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	container.add_child(item_icon)
	
	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.text = "1x"
	count_label.add_theme_font_size_override("font_size", 7)
	count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	count_label.position = Vector2(1.0, -1.0)
	count_label.z_index = 2
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	container.add_child(count_label)
	container.mouse_entered.connect(_on_item_slot_mouse_entered.bind(item))
	container.mouse_exited.connect(_on_item_slot_mouse_exited)
	items_container.add_child(container)

func _update_item_display_count(display_container: Control, item: ItemData) -> void:
	var item_resource_path := item.resource_path
	var count := 0
	for existing_item in RunData.items:
		if existing_item != null and existing_item.resource_path == item_resource_path:
			count += 1
	
	var count_label := display_container.get_node_or_null("CountLabel") as Label
	if count_label != null:
		count_label.text = "%dx" % count

func _on_item_slot_mouse_entered(item: ItemData) -> void:
	_show_item_tooltip(item)

func _on_item_slot_mouse_exited() -> void:
	_hide_item_tooltip()

func _ensure_item_tooltip() -> void:
	if _item_tooltip != null:
		return

	_item_tooltip = PanelContainer.new()
	_item_tooltip.name = "ItemTooltip"
	_item_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_tooltip.top_level = true
	_item_tooltip.visible = false
	_item_tooltip.z_index = 200

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.96)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.35, 0.45, 0.6)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_item_tooltip.add_theme_stylebox_override("panel", style)

	_item_tooltip_label = RichTextLabel.new()
	_item_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_tooltip_label.fit_content = true
	_item_tooltip_label.scroll_active = false
	_item_tooltip_label.bbcode_enabled = true
	_item_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_item_tooltip_label.add_theme_font_size_override("normal_font_size", 13)
	_item_tooltip_label.add_theme_font_size_override("bold_font_size", 14)
	_item_tooltip_label.add_theme_color_override("default_color", Color(0.92, 0.92, 0.95, 1.0))
	_item_tooltip.add_child(_item_tooltip_label)

	add_child(_item_tooltip)

func _show_item_tooltip(item: ItemData) -> void:
	if item == null:
		return
	_ensure_item_tooltip()
	_item_tooltip_item = item
	_item_tooltip_was_shift_pressed = Input.is_key_pressed(KEY_SHIFT)
	var stack_count := _get_item_stack_count(item)
	_item_tooltip_label.text = ""
	_item_tooltip.reset_size()
	_item_tooltip_label.text = item.build_tooltip_bbcode(_item_tooltip_was_shift_pressed, stack_count)
	_item_tooltip.visible = true
	_update_item_tooltip_position()

func _hide_item_tooltip() -> void:
	_item_tooltip_item = null
	if _item_tooltip != null:
		_item_tooltip.visible = false

func _update_item_tooltip_position() -> void:
	if _item_tooltip == null or not _item_tooltip.visible:
		return
	var vp_size := get_viewport().get_visible_rect().size
	var mouse := get_viewport().get_mouse_position()
	var tip_size := _item_tooltip.size
	var pos := mouse + Vector2(-tip_size.x * 0.5, -tip_size.y - 124.0)
	pos.x = clamp(pos.x, 0.0, maxf(0.0, vp_size.x - tip_size.x))
	pos.y = clamp(pos.y, 48.0, maxf(0.0, vp_size.y - tip_size.y))
	_item_tooltip.global_position = pos

func _get_item_stack_count(item: ItemData) -> int:
	if item == null:
		return 1
	var item_key := item.resource_path if not item.resource_path.is_empty() else item.item_name
	var count := 0
	for existing_item in RunData.items:
		if existing_item == null:
			continue
		var existing_key := existing_item.resource_path if not existing_item.resource_path.is_empty() else existing_item.item_name
		if existing_key == item_key:
			count += 1
	return maxi(1, count)

func _populate_existing_items() -> void:
	if items_container == null:
		return
	for child in items_container.get_children():
		child.queue_free()

	var displayed_items: Dictionary = {}
	for item in RunData.items:
		if item == null:
			continue
		var item_key := item.resource_path if not item.resource_path.is_empty() else item.item_name
		if not displayed_items.has(item_key):
			displayed_items[item_key] = item

	for resource_path in displayed_items.keys():
		_create_item_display(displayed_items[resource_path], str(resource_path))
		var slot := items_container.get_child(items_container.get_child_count() - 1) as Control
		if slot != null:
			_update_item_display_count(slot, displayed_items[resource_path])
