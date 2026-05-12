class_name MapNode
extends Area2D

signal selected(room: Room)

const ICONS := {
	Room.Type.COMBAT: preload("res://assets/map/icons/map_icon_combat.png"),
	Room.Type.SHOP: preload("res://assets/map/icons/map_icon_shop.png"),
	Room.Type.PUZZLE: preload("res://assets/map/icons/map_icon_puzzle.png")
}

@onready var sprite : Sprite2D = $Visuals/Sprite2D
@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var cross: Sprite2D = $Visuals/Cross
@export_enum("COMBAT", "PUZZLE", "SHOP") var map_node_type: String = "COMBAT"

var available := false : set = set_available
var room : Room : set = set_room

func _ready() -> void:
	#var test_node := MapNodeData.new()
	#test_node.type = MapNodeData.Type.SHOP
	#data = test_node
	#
	#await get_tree().create_timer(3).timeout
	#available = true
	
	if !available:
		sprite.modulate = Color(0.826, 0.826, 0.826, 1.0)
	else:
		sprite.modulate = Color(0.0, 0.0, 0.0)

func set_available(new_value: bool):
	available = new_value
	
	if available:
		animation_player.play("highlight")
		sprite.modulate = Color(0.0, 0.0, 0.0)
	elif not room.selected:
		animation_player.play("RESET")
	else:
		cross.visible = true

func set_room(new_data: Room):
	room = new_data
	position = room.position
	cross.rotation_degrees = randi_range(-20, 20)
	sprite.texture = ICONS[room.type][0]
	

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not available or not event.is_action_pressed("mousebutton_left"):
		return
	
	room.selected = true
	animation_player.play("select")
	_on_map_node_selected()

func _on_map_node_selected():
	selected.emit(room)
