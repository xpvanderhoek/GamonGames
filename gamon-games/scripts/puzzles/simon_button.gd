extends Control

#@export var idle_color: Color 
#@export var lit_color: Color 

const FLASH_TIME = 0.2

#@onready var color_rect = $ColorRect

signal button_pressed

func _ready():
	#color_rect.color = idle_color
	$TextureButton.pressed.connect(_on_click)

func flash():
	#color_rect.color = lit_color
	await get_tree().create_timer(FLASH_TIME).timeout
	#color_rect.color = idle_color

func _on_click():
	button_pressed.emit()
