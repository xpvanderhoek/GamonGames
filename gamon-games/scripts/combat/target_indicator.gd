@tool
class_name TargetIndicator
extends Node2D

@export var hover_size: Vector2 = Vector2(48.0, 48.0):
	set(value):
		_hover_size = Vector2(max(1.0, value.x), max(1.0, value.y))
		_update_area_shape()
	get:
		return _hover_size

var _hover_size: Vector2 = Vector2(48.0, 48.0)
var _hover_area: Area2D = null
var _parent_limb: CombatLimb = null

func _ready() -> void:
	_parent_limb = _find_parent_limb()
	_ensure_hover_area()

func _find_parent_limb() -> CombatLimb:
	var node := get_parent()
	while node != null:
		if node is CombatLimb:
			return node as CombatLimb
		node = node.get_parent()
	return null

func _ensure_hover_area() -> void:
	if _hover_area != null and is_instance_valid(_hover_area):
		_update_area_shape()
		return

	_hover_area = Area2D.new()
	_hover_area.name = "IndicatorArea"
	_hover_area.input_pickable = true
	add_child(_hover_area)

	var shape := CollisionShape2D.new()
	shape.name = "IndicatorShape"
	shape.shape = RectangleShape2D.new()
	_hover_area.add_child(shape)
	_update_area_shape()

	_hover_area.mouse_entered.connect(_on_indicator_mouse_entered)
	_hover_area.mouse_exited.connect(_on_indicator_mouse_exited)
	if _parent_limb != null and _parent_limb.can_be_targeted:
		_hover_area.input_event.connect(_on_indicator_input_event)

func _update_area_shape() -> void:
	if _hover_area == null or not is_instance_valid(_hover_area):
		return
	var shape := _hover_area.get_node_or_null("IndicatorShape") as CollisionShape2D
	if shape == null:
		return
	var rect := shape.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		shape.shape = rect
	rect.size = _hover_size

func _on_indicator_mouse_entered() -> void:
	if _parent_limb == null or not is_instance_valid(_parent_limb) or _parent_limb.is_destroyed:
		return
	_parent_limb.mouse_entered_limb.emit()

func _on_indicator_mouse_exited() -> void:
	if _parent_limb == null or not is_instance_valid(_parent_limb) or _parent_limb.is_destroyed:
		return
	_parent_limb.mouse_exited_limb.emit()

func _on_indicator_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _parent_limb == null or not is_instance_valid(_parent_limb) or _parent_limb.is_destroyed:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_parent_limb.limb_clicked.emit(_parent_limb)