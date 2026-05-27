class_name MapRoom
extends Area2D

signal selected(room: Room)

const ICONS := {
	Room.Type.NOT_ASSIGNED: [null, Vector2.ONE],
	Room.Type.COMBAT: [preload("res://assets/map/icons/map_icon_combat.png"), Vector2.ONE],
	Room.Type.SHOP: [preload("res://assets/map/icons/map_icon_shop.png"), Vector2.ONE],
	Room.Type.PUZZLE: [preload("res://assets/map/icons/map_icon_puzzle.png"), Vector2.ONE],
	Room.Type.BOSS: [preload("res://assets/map/icons/map_icon_boss.png"), Vector2(2, 2)]
}

@onready var sprite : Sprite2D = $Visuals/Sprite2D
@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var cross: Sprite2D = $Visuals/Cross

var available := false : set = set_available
var room : Room : set = set_room

func _ready() -> void:
	#var test_node := MapNodeData.new()
	#test_node.type = MapNodeData.Type.SHOP
	#data = test_node
	#
	#await get_tree().create_timer(3).timeout
	#available = true
	sprite.material = sprite.material.duplicate()
	cross.material = cross.material.duplicate()
	
	if !available:
		sprite.modulate = Color("62615d")

func set_available(new_value: bool):
	available = new_value

	if room != null and room.selected:
		show_selected()
		return

	if available:
		cross.visible = false
		cross.material.set_shader_parameter("progress", 1.0)
		var random_offset = randf_range(0.1, 0.5)
		animation_player.play("highlight")
		animation_player.seek(random_offset)
		sprite.modulate = Color("1a252f")
	elif room != null and room.selected:
		show_selected()
	else:
		cross.visible = false
		sprite.modulate = Color("1a252f")

func set_room(new_data: Room):
	room = new_data
	position = room.position
	cross.rotation_degrees = RunData.rng.randi_range(0, 180)
	sprite.texture = ICONS[room.type][0]
	$Visuals.scale = ICONS[room.type][1]


	if room.selected:
		show_selected()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not available or not event.is_action_pressed("mousebutton_left"):
		return

	room.selected = true
	cross.visible = true
	animation_player.play("select")
	

func show_selected() -> void:
	cross.visible = true
	cross.material.set_shader_parameter("progress", 1.0)
	sprite.modulate = Color("1a252f")
	if animation_player.current_animation != "select":
		animation_player.stop()

func _on_map_node_selected():
	selected.emit(room)

func _on_mouse_entered() -> void:
	if available:
		sprite.material.set_shader_parameter("outline_color", Color(1, 1, 1, 1))

func _on_mouse_exited() -> void:
	if !available:
		return
	
	sprite.material.set_shader_parameter("outline_color", Color(0.863, 0.788, 0.655))

func _play_select_sound() -> void:
	SoundManager.play_pencil()
