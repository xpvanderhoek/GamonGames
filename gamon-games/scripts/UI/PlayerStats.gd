extends TextureRect

@onready var health_label = $Legends/Health
@onready var damage_label = $Legends/Damage
@onready var precision_label = $Legends/Precision
@onready var luck_label = $Legends/Luck
@onready var defense_label = $Legends/Defense
@onready var energy_regen_label = $Legends/EnergyRegen
@onready var gold_gain_label = $Legends/GoldGain
@onready var debuff_res_label = $Legends/DebuffResistance

var _item_tooltip: PanelContainer = null
var _item_tooltip_label: RichTextLabel = null

func _ready() -> void:
	PlayerStats.stats_changed.connect(_update_stats_from_signal)
	if not RunData.item_added.is_connected(_on_item_added):
		RunData.item_added.connect(_on_item_added)
	if not RunData.shop_item_hovered.is_connected(_on_shop_item_hovered):
		RunData.shop_item_hovered.connect(_on_shop_item_hovered)
	if not RunData.shop_item_unhovered.is_connected(_on_shop_item_unhovered):
		RunData.shop_item_unhovered.connect(_on_shop_item_unhovered)
	_update_stats()
	_setup_tooltips()

func _update_stats_from_signal(_stat_name: String, _val: float) -> void:
	_update_stats()

func _on_item_added(_item: ItemData) -> void:
	_update_stats()

func _on_shop_item_hovered(item: ItemData) -> void:
	_reset_highlights()
	if item == null or item.buff_type == "None" or is_zero_approx(item.buff_value):
		return
		
	var buff_type = item.buff_type.to_lower()
	if buff_type == "hp_max":
		buff_type = "health"
	
	var highlight_color = Color(0.15, 0.65, 0.15, 1.0) # Nice distinct green
	match buff_type:
		"health": health_label.add_theme_color_override("font_color", highlight_color)
		"damage": damage_label.add_theme_color_override("font_color", highlight_color)
		"precision": precision_label.add_theme_color_override("font_color", highlight_color)
		"luck": luck_label.add_theme_color_override("font_color", highlight_color)
		"defense": defense_label.add_theme_color_override("font_color", highlight_color)
		"energy_regen": energy_regen_label.add_theme_color_override("font_color", highlight_color)
		"gold_gain": gold_gain_label.add_theme_color_override("font_color", highlight_color)
		"debuff_resistance": debuff_res_label.add_theme_color_override("font_color", highlight_color)

func _on_shop_item_unhovered() -> void:
	_reset_highlights()

func _reset_highlights() -> void:
	var default_color = Color(0, 0, 0, 1)
	health_label.add_theme_color_override("font_color", default_color)
	damage_label.add_theme_color_override("font_color", default_color)
	precision_label.add_theme_color_override("font_color", default_color)
	luck_label.add_theme_color_override("font_color", default_color)
	defense_label.add_theme_color_override("font_color", default_color)
	energy_regen_label.add_theme_color_override("font_color", default_color)
	gold_gain_label.add_theme_color_override("font_color", default_color)
	debuff_res_label.add_theme_color_override("font_color", default_color)

func _process(_delta: float) -> void:
	_update_item_tooltip_position()

func _ensure_item_tooltip() -> void:
	if _item_tooltip != null:
		return
	_item_tooltip = PanelContainer.new()
	_item_tooltip.name = "ItemTooltip"
	_item_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_tooltip.z_as_relative = false
	_item_tooltip.z_index = 4096
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

	add_child(_item_tooltip)

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

func _show_tooltip(text: String) -> void:
	_ensure_item_tooltip()
	_item_tooltip_label.text = text
	_item_tooltip.visible = text != ""
	_item_tooltip.reset_size()
	_update_item_tooltip_position()

func _hide_tooltip() -> void:
	if _item_tooltip != null:
		_item_tooltip.visible = false

func _setup_tooltips() -> void:
	health_label.mouse_filter = Control.MOUSE_FILTER_STOP
	health_label.mouse_entered.connect(func(): _show_tooltip("Your maximum life points. If health reaches 0, your run is over."))
	health_label.mouse_exited.connect(_hide_tooltip)
	
	damage_label.mouse_filter = Control.MOUSE_FILTER_STOP
	damage_label.mouse_entered.connect(func(): _show_tooltip("Increases the base damage of your attacks against enemies."))
	damage_label.mouse_exited.connect(_hide_tooltip)
	
	precision_label.mouse_filter = Control.MOUSE_FILTER_STOP
	precision_label.mouse_entered.connect(func(): _show_tooltip("Increases your chance to successfully hit enemy limbs."))
	precision_label.mouse_exited.connect(_hide_tooltip)
	
	luck_label.mouse_filter = Control.MOUSE_FILTER_STOP
	luck_label.mouse_entered.connect(func(): _show_tooltip("Improves your chances of finding better loot and critical hits."))
	luck_label.mouse_exited.connect(_hide_tooltip)
	
	defense_label.mouse_filter = Control.MOUSE_FILTER_STOP
	defense_label.mouse_entered.connect(func(): _show_tooltip("Reduces the amount of damage you take from enemy attacks."))
	defense_label.mouse_exited.connect(_hide_tooltip)
	
	energy_regen_label.mouse_filter = Control.MOUSE_FILTER_STOP
	energy_regen_label.mouse_entered.connect(func(): _show_tooltip("The amount of energy you recover at the start of each turn."))
	energy_regen_label.mouse_exited.connect(_hide_tooltip)
	
	gold_gain_label.mouse_filter = Control.MOUSE_FILTER_STOP
	gold_gain_label.mouse_entered.connect(func(): _show_tooltip("Multiplier for the amount of coins you earn from battles."))
	gold_gain_label.mouse_exited.connect(_hide_tooltip)
	
	debuff_res_label.mouse_filter = Control.MOUSE_FILTER_STOP
	debuff_res_label.mouse_entered.connect(func(): _show_tooltip("Chance to resist negative status effects."))
	debuff_res_label.mouse_exited.connect(_hide_tooltip)

func _update_stats() -> void:
	health_label.text = "Health: %.0f" % RunData.get_stat("health")
	damage_label.text = "Damage: %.0f" % RunData.get_stat("damage")
	precision_label.text = "Precision: %.0f" % RunData.get_stat("precision")
	luck_label.text = "Luck: %.0f" % RunData.get_stat("luck")
	defense_label.text = "Defense: %.0f" % RunData.get_stat("defense")
	energy_regen_label.text = "Energy Reg: %.0f" % RunData.get_stat("energy_regen")
	gold_gain_label.text = "Gold Gain: %.1fx" % RunData.get_stat("gold_gain")
	debuff_res_label.text = "Debuff Res: %.0f%%" % RunData.get_stat("debuff_resistance")
