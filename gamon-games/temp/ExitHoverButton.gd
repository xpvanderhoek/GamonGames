extends Button

@export var hover_tint: Color = Color(0.9, 0.9, 0.9, 1.0)

var _base_tint: Color = Color.WHITE

func _ready() -> void:
	_base_tint = modulate
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	modulate = hover_tint

func _on_mouse_exited() -> void:
	modulate = _base_tint
