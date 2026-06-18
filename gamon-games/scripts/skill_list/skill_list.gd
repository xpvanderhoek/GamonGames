extends Control

@onready var marrow_shards_label: Label = $Control/TextureRect/MarrowShardsLabel
@onready var skill_vbox_container: VBoxContainer = $Panel/VBoxContainer/HBoxContainer/ScrollContainer/SkillVboxContainer
@export var skills: Array[SkillData]
var _item_tooltip: PanelContainer = null
var _item_tooltip_label: RichTextLabel = null

var skill_list_line: SkillListLine

var new_skill_line:= preload("res://scenes/skill_list/skill_list_line.tscn")

var _marrow_shards_base_modulate: Color
var _marrow_shards_base_position: Vector2
var _marrow_shards_flash_tween: Tween
var _marrow_shards_shake_tween: Tween

func _ready() -> void:
	_update_marrow_shards_label()
	RunData.marrow_shards_changed.connect(_update_marrow_shards_label)
	_marrow_shards_base_modulate = _get_marrow_shards_base_modulate()
	_marrow_shards_base_position = _get_marrow_shards_base_position()
	_ensure_item_tooltip()
	_load_skill_lines(skills)

func _update_marrow_shards_label() -> void:
	marrow_shards_label.text = str(RunData.marrow_shards)

func _load_skill_lines(skills) -> void:
	if skills:
		for skill in skills:
			var line = new_skill_line.instantiate()
			skill_vbox_container.add_child(line)
			line.setup_skill(skill)
			if line.tooltip_requested.is_connected(_on_skill_tooltip_requested) == false:
				line.tooltip_requested.connect(_on_skill_tooltip_requested)
			if line.tooltip_cleared.is_connected(_on_skill_tooltip_cleared) == false:
				line.tooltip_cleared.connect(_on_skill_tooltip_cleared)
			if line.upgrade_failed.is_connected(_on_skill_upgrade_failed) == false:
				line.upgrade_failed.connect(_on_skill_upgrade_failed)
	else:
		print("Skills array is empty")

func _get_marrow_shards_base_modulate() -> Color:
	if marrow_shards_label != null:
		return marrow_shards_label.modulate
	return Color(1, 1, 1, 1)

func _get_marrow_shards_base_position() -> Vector2:
	if marrow_shards_label != null:
		return marrow_shards_label.position
	return Vector2.ZERO

func _flash_marrow_shards_label() -> void:
	if marrow_shards_label == null:
		return
	if _marrow_shards_flash_tween != null and _marrow_shards_flash_tween.is_running():
		_marrow_shards_flash_tween.kill()
	if _marrow_shards_shake_tween != null and _marrow_shards_shake_tween.is_running():
		_marrow_shards_shake_tween.kill()
	marrow_shards_label.modulate = _marrow_shards_base_modulate
	marrow_shards_label.position = _marrow_shards_base_position
	_marrow_shards_flash_tween = create_tween()
	_marrow_shards_flash_tween.tween_property(
		marrow_shards_label,
		"modulate",
		Color(1, 0.3, 0.3, 1),
		0.08
	)
	_marrow_shards_flash_tween.tween_property(
		marrow_shards_label,
		"modulate",
		_marrow_shards_base_modulate,
		0.2
	)
	_marrow_shards_shake_tween = create_tween()
	_marrow_shards_shake_tween.tween_property(
		marrow_shards_label,
		"position",
		_marrow_shards_base_position + Vector2(-4, 0),
		0.05
	)
	_marrow_shards_shake_tween.tween_property(
		marrow_shards_label,
		"position",
		_marrow_shards_base_position + Vector2(4, 0),
		0.05
	)
	_marrow_shards_shake_tween.tween_property(
		marrow_shards_label,
		"position",
		_marrow_shards_base_position + Vector2(-3, 0),
		0.05
	)
	_marrow_shards_shake_tween.tween_property(
		marrow_shards_label,
		"position",
		_marrow_shards_base_position,
		0.06
	)

func _process(_delta: float) -> void:
	if _item_tooltip != null and _item_tooltip.visible:
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

func _on_skill_tooltip_requested(text: String, max_level: int) -> void:
	_ensure_item_tooltip()
	_item_tooltip_label.text = text + "\nMax lvl: " + str(max_level)
	_item_tooltip.visible = text.strip_edges() != ""
	_item_tooltip.reset_size()
	_update_item_tooltip_position()

func _on_skill_tooltip_cleared() -> void:
	if _item_tooltip:
		_item_tooltip.visible = false

func _on_skill_upgrade_failed() -> void:
	_flash_marrow_shards_label()


func _on_quit_button_pressed() -> void:
	SaveLoad.save_data()
	SoundManager.play_click()
	queue_free()


func _on_quit_button_mouse_entered() -> void:
	SoundManager.play_hover()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		_on_quit_button_pressed()
		get_viewport().set_input_as_handled()
