extends Node2D

@export var item_scene: PackedScene 
@export var resources_folder: String = "res://assets/ShopItems/Resources"
@export var shop_items: Array[ItemData] = []
@export var mouse_parallax_strength := Vector2(18.0, 10.0)
@export_range(1.0, 30.0, 0.1) var mouse_parallax_smoothing := 8.0

const PAUSE_MENU := preload("res://scenes/UI/main_menu/settings/settings_menu.tscn")

const TIER_1_BASE_WEIGHT := 70.0
const TIER_2_BASE_WEIGHT := 20.0
const TIER_3_BASE_WEIGHT := 10.0
const SHOP_DIALOGUE_FIRST_KEY := "Avarus_intro"
const SHOP_DIALOGUE_ENTER_KEY := "Avarus_shop_enter"
const SHOP_DIALOGUE_IDLE_KEY := "Avarus_idle"
const SHOP_DIALOGUE_EXIT_KEY := "Avarus_shop_exit"
const SHOP_DIALOGUE_NO_COINS_KEY := "Avarus_no_coins"

@onready var spawn_positions = [$Parallax2D2/Item1, $Parallax2D2/Item2, $Parallax2D2/Item3, $Parallax2D2/Item4, $Parallax2D2/Item5, $Parallax2D2/Item6]
@onready var parallax_layers = [$Parallax2D, $Parallax2D2]
@onready var exit_button = [$CanvasLayer/ShopUI/ExitButton]
@onready var coins: Label = $CanvasLayer/ShopUI/CoinSprite/CoinLabel
@onready var canvas_layer: CanvasLayer = $CanvasLayer

var _parallax_offset := Vector2.ZERO
var _shop_chatter_timer: Timer
@onready var _shop_dialogue_ui: CanvasLayer = $Parallax2D2/SpeechBubble
var _is_exiting := false

var _item_tooltip: PanelContainer = null
var _item_tooltip_label: RichTextLabel = null
var _item_tooltip_item: ItemData = null
var _item_tooltip_shop_item: Node2D = null
var _item_tooltip_was_shift_pressed: bool = false

const SHOP_CHATTER_MIN_SEC := 10.0
const SHOP_CHATTER_MAX_SEC := 25.0

func _ready():
	RunData.shops_visited += 1
	SoundManager.play_shop_music()
	if exit_button != null:
		var on_exit_pressed := Callable(self, "_exit_shop")
		if not exit_button[0].pressed.is_connected(on_exit_pressed):
			exit_button[0].pressed.connect(on_exit_pressed)

	coins.text = str(RunData.coins)
	spawn_shop_inventory()
	_setup_shop_dialogue_system()
	_ensure_item_tooltip()

func _setup_shop_dialogue_system() -> void:
	if _shop_dialogue_ui != null and not _shop_dialogue_ui.is_node_ready():
		await _shop_dialogue_ui.ready

	if not PlayerStats.knows_avarus:
		await _show_bark_sequence(SHOP_DIALOGUE_FIRST_KEY, 4)
		PlayerStats.knows_avarus = true
	else:
		_show_random_bark(SHOP_DIALOGUE_ENTER_KEY, 4.0)

	_setup_shop_chatter_timer()
func _setup_shop_chatter_timer() -> void:
	_shop_chatter_timer = Timer.new()
	_shop_chatter_timer.one_shot = true
	_shop_chatter_timer.wait_time = randf_range(SHOP_CHATTER_MIN_SEC, SHOP_CHATTER_MAX_SEC)
	_shop_chatter_timer.timeout.connect(_on_shop_chatter_timeout)
	add_child(_shop_chatter_timer)
	_shop_chatter_timer.start()

func _on_shop_chatter_timeout() -> void:
	if _is_exiting:
		return

	_show_random_bark(SHOP_DIALOGUE_IDLE_KEY, 4.0)

	if _shop_chatter_timer != null:
		_shop_chatter_timer.wait_time = randf_range(SHOP_CHATTER_MIN_SEC, SHOP_CHATTER_MAX_SEC)
		_shop_chatter_timer.start()

func _process(delta: float):
	coins.text = str(RunData.coins)
	var vp_size := get_viewport_rect().size
	var half := vp_size * 0.5
	if half.x == 0.0 or half.y == 0.0:
		return

	var scale_factor = maxf(vp_size.x / 1152.0, vp_size.y / 648.0)
	scale = Vector2(scale_factor, scale_factor)
	position = (vp_size - Vector2(1152.0, 648.0) * scale_factor) / 2.0

	if _shop_dialogue_ui != null:
		_shop_dialogue_ui.scale = Vector2(0.455, 0.455) * scale_factor
		_shop_dialogue_ui.offset = position + Vector2(93.075, 50.555) * scale_factor

	var mouse := get_viewport().get_mouse_position()
	var offset := Vector2(
		(mouse.x - half.x) / half.x,
		(mouse.y - half.y) / half.y
	) * mouse_parallax_strength

	_parallax_offset = _parallax_offset.lerp(offset, mouse_parallax_smoothing * delta)
	for layer in parallax_layers:
		layer.scroll_offset = _parallax_offset * layer.scroll_scale

	# Check for shift key changes when tooltip is visible
	if _item_tooltip_item != null and _item_tooltip != null and _item_tooltip.visible and _item_tooltip_shop_item != null:
		var shift_now := Input.is_key_pressed(KEY_SHIFT)
		if shift_now != _item_tooltip_was_shift_pressed:
			_item_tooltip_was_shift_pressed = shift_now
			_show_item_tooltip(_item_tooltip_item, _item_tooltip_shop_item)
	
	# Update tooltip position if visible
	if _item_tooltip != null and _item_tooltip.visible:
		_update_item_tooltip_position()

func _input(event):
	if event.is_action_pressed("escape"):
		canvas_layer.add_child(PAUSE_MENU.instantiate())

func _exit_shop() -> void:
	if _is_exiting:
		return

	_is_exiting = true
	if _shop_chatter_timer != null:
		_shop_chatter_timer.stop()

	SoundManager.play_click()
	if exit_button and exit_button[0]:
		exit_button[0].disabled = true

	var fade_tween = create_tween()
	var black_overlay = CanvasLayer.new()
	var color_rect = ColorRect.new()
	color_rect.color = Color.BLACK
	color_rect.anchor_right = 1.0
	color_rect.anchor_bottom = 1.0
	black_overlay.add_child(color_rect)
	add_child(black_overlay)
	color_rect.modulate.a = 0.0
	fade_tween.tween_property(color_rect, "modulate:a", 0.5, 3)

	var played_exit_bark := _show_random_bark(SHOP_DIALOGUE_EXIT_KEY, 2.3)
	if played_exit_bark and _shop_dialogue_ui != null:
		await _shop_dialogue_ui.bark_finished

	DialogueManager.cancel_dialogue()
	SoundManager.stop_shop_music()
	TransitionManager.change_scene("res://scenes/map/map.tscn", TransitionManager.TransitionType.FADE)

func _show_random_bark(key: String, duration_sec: float = 4.0) -> bool:
	if _shop_dialogue_ui == null or not _shop_dialogue_ui.has_method("show_bark"):
		return false

	if not DialogueManager.has_dialogue(key):
		return false

	var pool: Variant = DialogueManager.dialogue_data[key]
	if not (pool is Array) or pool.is_empty():
		return false

	var line: Variant = pool[RunData.rng.randi_range(0, pool.size() - 1)]
	if not (line is Dictionary):
		return false

	if line.is_empty():
		return false

	return _shop_dialogue_ui.show_bark(line, duration_sec)

func spawn_shop_inventory():
	var item_pool := _load_shop_items()
	if item_pool.is_empty():
		push_warning("You donkey, You didn't put any resources in %s" % resources_folder)
		return

	var luck_value := _get_total_luck()

	for i in range(spawn_positions.size()):
		if item_pool.is_empty():
			break

		var selected_item := _roll_item_from_pool(item_pool, luck_value)
		if selected_item == null:
			break

		item_pool.erase(selected_item)

		var new_item = item_scene.instantiate()
		spawn_positions[i].add_child(new_item)
		new_item.position = Vector2.ZERO
		if new_item.has_signal("item_hover_started"):
			new_item.item_hover_started.connect(_on_item_hover_started)
		if new_item.has_signal("item_hover_ended"):
			new_item.item_hover_ended.connect(_on_item_hover_ended)
		if new_item.has_signal("no_coins_attempted"):
			new_item.no_coins_attempted.connect(_on_item_no_coins_attempted)

		# Pass the specific resource data to the item
		new_item.item_data = selected_item
		new_item._on_item_data_assigned()

func _on_item_hover_started(item_data: ItemData) -> void:
	if item_data == null:
		return
	var shop_item_node: Node2D = null
	for spawn_pos in spawn_positions:
		for child in spawn_pos.get_children():
			if child is Node2D and child.has_method("_on_item_data_assigned"):
				if child.item_data == item_data:
					shop_item_node = child
					break
	_show_item_tooltip(item_data, shop_item_node)
	RunData.shop_item_hovered.emit(item_data)

func _on_item_hover_ended() -> void:
	_item_tooltip_item = null
	_hide_item_tooltip()
	RunData.shop_item_unhovered.emit()

func _on_item_no_coins_attempted() -> void:
	_show_random_bark(SHOP_DIALOGUE_NO_COINS_KEY, 4.0)

func _show_bark_sequence(key: String, duration_sec: float = 3.4) -> bool:
	if _shop_dialogue_ui == null or not _shop_dialogue_ui.has_method("show_bark"):
		return false

	if not DialogueManager.has_dialogue(key):
		return false

	var pool: Variant = DialogueManager.dialogue_data[key]
	if not (pool is Array) or pool.is_empty():
		return false

	var played_any := false
	for line in pool:
		if _is_exiting:
			break
		if not (line is Dictionary):
			continue

		if _shop_dialogue_ui.show_bark(line, duration_sec):
			played_any = true
			await _shop_dialogue_ui.bark_finished

	return played_any

func _load_shop_items() -> Array[ItemData]:
	return shop_items.duplicate()

func _roll_item_from_pool(pool: Array[ItemData], luck_value: float) -> ItemData:
	if pool.is_empty():
		return null

	var total_weight := 0.0
	for item in pool:
		total_weight += _get_weight_for_item(item, luck_value)

	if total_weight <= 0.0:
		return pool[RunData.rng.randi_range(0, pool.size() - 1)]

	var roll := RunData.rng.randf_range(0.0, total_weight)
	var running_weight := 0.0
	for item in pool:
		running_weight += _get_weight_for_item(item, luck_value)
		if roll <= running_weight:
			return item

	return pool[pool.size() - 1]

func _get_weight_for_item(item: ItemData, luck_value: float) -> float:
	var luck : Variant= clamp(luck_value, 0.0, 100.0)

	match item.category:
		"Tier I":
			return max(1.0, TIER_1_BASE_WEIGHT - (luck * 0.6))
		"Tier II":
			return TIER_2_BASE_WEIGHT + (luck * 0.4)
		"Tier III":
			return TIER_3_BASE_WEIGHT + (luck * 0.2)
		_:
			return 1.0

func _get_total_luck() -> float:
	return float(RunData.get_stat("luck"))

func _ensure_item_tooltip() -> void:
	if _item_tooltip != null:
		return

	_item_tooltip = PanelContainer.new()
	_item_tooltip.name = "ItemTooltip"
	_item_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_tooltip.z_index = 200
	_item_tooltip.top_level = true
	_item_tooltip.visible = false

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

	_item_tooltip.add_theme_stylebox_override("panel", style)

	_item_tooltip_label = RichTextLabel.new()
	_item_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_tooltip_label.fit_content = true
	_item_tooltip_label.scroll_active = false
	_item_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_item_tooltip_label.custom_minimum_size = Vector2(0, 0)
	_item_tooltip_label.bbcode_enabled = true
	_item_tooltip_label.add_theme_font_size_override("normal_font_size", 13)
	_item_tooltip_label.add_theme_font_size_override("bold_font_size", 14)
	_item_tooltip_label.add_theme_color_override("default_color", Color(0.92, 0.92, 0.95, 1.0))
	_item_tooltip.add_child(_item_tooltip_label)

	canvas_layer.add_child(_item_tooltip)

func _show_item_tooltip(item: ItemData, shop_item: Node2D) -> void:
	_ensure_item_tooltip()
	_item_tooltip_item = item
	_item_tooltip_shop_item = shop_item
	_item_tooltip_was_shift_pressed = Input.is_key_pressed(KEY_SHIFT)

	# FORCE the tooltip to use the resource method directly with the shop flag enabled
	var bbcode := item.build_tooltip_bbcode(_item_tooltip_was_shift_pressed, 1, true)
	
	_item_tooltip_label.text = ""
	_item_tooltip.reset_size()
	_item_tooltip_label.text = bbcode
	_item_tooltip.visible = true
	_update_item_tooltip_position()

func _build_fallback_tooltip(item: ItemData, _shift_pressed: bool) -> String:
	var t := "[b][font_size=15]%s[/font_size][/b]" % item.item_name
	if item.effect.strip_edges() != "":
		t += "\n%s" % item.effect
	elif item.lore.strip_edges() != "":
		t += "\n%s" % item.lore
	return t

func _hide_item_tooltip() -> void:
	if _item_tooltip != null:
		_item_tooltip.visible = false

func _update_item_tooltip_position() -> void:
	if _item_tooltip == null or not _item_tooltip.visible:
		return
	var vp_size  := get_viewport().get_visible_rect().size
	var mouse    := get_viewport().get_mouse_position()
	var tip_size := _item_tooltip.size

	var pos := mouse + Vector2(-tip_size.x * 0.5, -tip_size.y - 14.0)
	pos.x = clamp(pos.x, 0.0, vp_size.x - tip_size.x)
	pos.y = clamp(pos.y, 0.0, vp_size.y - tip_size.y)
	_item_tooltip.global_position = pos
