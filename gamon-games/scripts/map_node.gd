class_name MapNode
extends Area2D

signal selected(map_node: MapNode)

const ICONS := {
	MapNodeData.Type.COMBAT: preload("res://assets/map/icons/map_icon_combat.png"),
	MapNodeData.Type.SHOP: preload("res://assets/map/icons/map_icon_shop.png")
}

@onready var sprite : Sprite2D = $Visuals/Sprite2D
@onready var animation_player : AnimationPlayer = $AnimationPlayer

var available := false : set = set_available
var data : MapNodeData : set = set_data

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
		
	elif not data.selected:
		animation_player.play("RESET")
	else:
		$Visuals/Cross.visible = true

func set_data(new_data: MapNodeData):
	data = new_data
	sprite.texture = ICONS[data.type]

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not available or not event.is_action_pressed("mousebutton_left"):
		return
	
	data.selected = true
	animation_player.play("RESET")
	_on_map_node_selected()

func _unlock_next_nodes():
	pass

func _on_map_node_selected():
	selected.emit(data)
