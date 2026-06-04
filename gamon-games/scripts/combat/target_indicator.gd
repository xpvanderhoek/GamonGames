@tool
class_name TargetIndicator
extends Node2D

@export var hover_size: Vector2 = Vector2(40.0, 40.0):
	set(value):
		_hover_size = Vector2(max(1.0, value.x), max(1.0, value.y))
		_update_area_shape()
	get:
		return _hover_size

var _hover_size: Vector2 = Vector2(40.0, 40.0)
var _hover_area: Area2D = null
var _parent_limb: CombatLimb = null
var _pulse_tween: Tween = null
var _original_icon_scale: Vector2
var _original_frame_scale: Vector2
var _is_hovered: bool = false

func _ready() -> void:
	var icon = get_node_or_null("SpellTargetIcon")
	var frame = get_node_or_null("SpellTargetFrame")
	if icon: _original_icon_scale = icon.scale
	if frame: 
		_original_frame_scale = frame.scale
		if frame.texture != null:
			hover_size = frame.texture.get_size() * frame.scale
	
	_parent_limb = _find_parent_limb()
	_ensure_hover_area()
	_update_visuals()

func _process(_delta: float) -> void:
	if _hover_area != null and is_instance_valid(_hover_area):
		_hover_area.global_position = global_position
		
	if Engine.is_editor_hint():
		var frame = get_node_or_null("SpellTargetFrame")
		if frame != null:
			frame.global_position = global_position
		var icon = get_node_or_null("SpellTargetIcon")
		if icon != null:
			icon.global_position = global_position

func _update_visuals() -> void:
	var icon = get_node_or_null("SpellTargetIcon")
	var frame = get_node_or_null("SpellTargetFrame")
	
	if icon == null or frame == null:
		return
		
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
		
	if _is_hovered:
		frame.modulate.a = 1.0
		frame.scale = _original_frame_scale * 1.15
	else:
		frame.modulate.a = 0.6
		frame.scale = _original_frame_scale
		
		_pulse_tween = create_tween().set_loops()
		_pulse_tween.tween_property(frame, "scale", _original_frame_scale * 1.15, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse_tween.tween_property(frame, "scale", _original_frame_scale, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _find_parent_limb() -> CombatLimb:
	var node := get_parent()
	while node != null:
		if node is CombatLimb:
			return node as CombatLimb
		node = node.get_parent()
	return null

func _ensure_hover_area() -> void:
	if _hover_area == null or not is_instance_valid(_hover_area):
		_hover_area = get_node_or_null("IndicatorArea") as Area2D

	if _hover_area == null or not is_instance_valid(_hover_area):
		return

	_update_area_shape()
	if not _hover_area.mouse_entered.is_connected(_on_indicator_mouse_entered):
		_hover_area.mouse_entered.connect(_on_indicator_mouse_entered)
	if not _hover_area.mouse_exited.is_connected(_on_indicator_mouse_exited):
		_hover_area.mouse_exited.connect(_on_indicator_mouse_exited)
	if _parent_limb != null and _parent_limb.can_be_targeted:
		if not _hover_area.input_event.is_connected(_on_indicator_input_event):
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

func set_hovered(hovered: bool) -> void:
	if _is_hovered != hovered:
		_is_hovered = hovered
		_update_visuals()

func _on_indicator_mouse_entered() -> void:
	set_hovered(true)
	
	if _parent_limb == null or not is_instance_valid(_parent_limb) or _parent_limb.is_destroyed:
		return
	_parent_limb.mouse_entered_limb.emit()

func _on_indicator_mouse_exited() -> void:
	set_hovered(false)
	
	if _parent_limb == null or not is_instance_valid(_parent_limb) or _parent_limb.is_destroyed:
		return
	_parent_limb.mouse_exited_limb.emit()

func _on_indicator_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _parent_limb == null or not is_instance_valid(_parent_limb) or _parent_limb.is_destroyed:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_parent_limb.limb_clicked.emit(_parent_limb)