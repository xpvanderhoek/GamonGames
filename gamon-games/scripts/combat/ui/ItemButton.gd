class_name ItemButton
extends Panel

signal item_pressed(slot_index: int)

var item_data: ItemData = null
var slot_index: int = -1
@onready var _icon: TextureRect = get_node_or_null("Icon") as TextureRect

func _ready() -> void:
	if _icon == null:
		_icon = TextureRect.new()
		_icon.name = "Icon"
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.anchor_left = 0.5
		_icon.anchor_top = 0.5
		_icon.anchor_right = 0.5
		_icon.anchor_bottom = 0.5
		_icon.offset_left = -16
		_icon.offset_top = -16
		_icon.offset_right = 16
		_icon.offset_bottom = 16
		_icon.custom_minimum_size = Vector2(24, 24)
		add_child(_icon)
	_refresh()

func set_item(item: ItemData, slot: int) -> void:
	item_data = item
	slot_index = slot
	_refresh()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if item_data != null:
			item_pressed.emit(slot_index)
			accept_event()

func _refresh() -> void:
	if _icon == null:
		return
	if item_data == null:
		_icon.texture = null
		_icon.visible = false
		tooltip_text = ""
		modulate = Color(1.0, 1.0, 1.0, 0.35)
		return
	_icon.texture = item_data.texture
	_icon.visible = true
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tooltip_lines: Array[String] = []
	if item_data.item_name.strip_edges() != "":
		tooltip_lines.append(item_data.item_name)
	if item_data.effect.strip_edges() != "":
		tooltip_lines.append(item_data.effect)
	tooltip_text = "\n".join(tooltip_lines)
