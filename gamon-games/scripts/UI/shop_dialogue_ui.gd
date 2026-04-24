extends CanvasLayer

signal bark_finished

@export_range(0.5, 10.0, 0.1) var default_bark_duration := 2.4
@export_range(0.05, 0.5, 0.01) var pop_tween_time := 0.16

@onready var name_label: Label = $Sprite2D/Label
@onready var text_label: RichTextLabel = $Sprite2D/RichTextLabel
@onready var bubble: CanvasItem = $Sprite2D

var _hide_timer: Timer
var _bubble_base_scale := Vector2.ONE
var _pop_tween: Tween

func _ready() -> void:
	hide()
	if bubble != null and bubble is Node2D:
		_bubble_base_scale = (bubble as Node2D).scale
		bubble.modulate.a = 0.0
	_hide_timer = Timer.new()
	_hide_timer.one_shot = true
	_hide_timer.timeout.connect(_on_hide_timer_timeout)
	add_child(_hide_timer)

func show_bark(line: Dictionary, duration_sec: float = -1.0) -> bool:
	if line.is_empty():
		return false

	if name_label == null:
		name_label = get_node_or_null("Sprite2D/Label") as Label
	if text_label == null:
		text_label = get_node_or_null("Sprite2D/RichTextLabel") as RichTextLabel
	if name_label == null or text_label == null:
		push_warning("ShopDialogueUI missing label nodes; bark skipped")
		return false

	name_label.text = str(line.get("speaker", "AVARUS"))
	text_label.text = str(line.get("text", ""))
	show()
	_play_pop_in()

	var final_duration := default_bark_duration if duration_sec <= 0.0 else duration_sec
	_hide_timer.start(final_duration)
	return true

func force_hide() -> void:
	if _hide_timer != null:
		_hide_timer.stop()
	await _play_pop_out()
	bark_finished.emit()

func _on_hide_timer_timeout() -> void:
	await _play_pop_out()
	bark_finished.emit()

func _play_pop_in() -> void:
	if bubble == null or not (bubble is Node2D):
		return

	if _pop_tween != null:
		_pop_tween.kill()

	var node := bubble as Node2D
	node.scale = _bubble_base_scale * 0.9
	bubble.modulate.a = 0.0

	_pop_tween = create_tween()
	_pop_tween.set_parallel(true)
	_pop_tween.tween_property(node, "scale", _bubble_base_scale, pop_tween_time)
	_pop_tween.tween_property(bubble, "modulate:a", 1.0, pop_tween_time)

func _play_pop_out() -> void:
	if bubble == null or not (bubble is Node2D):
		hide()
		return

	if _pop_tween != null:
		_pop_tween.kill()

	var node := bubble as Node2D
	_pop_tween = create_tween()
	_pop_tween.set_parallel(true)
	_pop_tween.tween_property(node, "scale", _bubble_base_scale * 0.92, pop_tween_time)
	_pop_tween.tween_property(bubble, "modulate:a", 0.0, pop_tween_time)
	await _pop_tween.finished
	node.scale = _bubble_base_scale
	hide()
