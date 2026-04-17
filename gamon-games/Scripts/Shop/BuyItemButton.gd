extends Node2D

@export var shop_item: Node2D
@onready var button = $Button

var original_scale: Vector2

func _ready():
	original_scale = button.scale
	# Set pivot to center so scaling happens from center
	button.pivot_offset = button.size / 2
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_button_hover)
	button.mouse_exited.connect(_on_button_unhover)

func _on_button_hover():
	button.scale = original_scale * 1.2
	button.modulate = Color(0.7, 0.7, 0.7)

func _on_button_unhover():
	button.scale = original_scale
	button.modulate = Color.WHITE

func _on_button_pressed():
	if shop_item and shop_item.has_method("buy_item"):
		shop_item.buy_item()
