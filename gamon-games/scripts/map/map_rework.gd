class_name Map
extends Node2D

signal room_selected(room: Room)

var enemy_scenes := [
	"res://scenes/combat/enemies/ttt.tscn"
]

const SCROLL_SPEED := 15
const MAP_NODE = preload("res://scenes/map_node.tscn")
const MAP_LINE = preload("res://scenes/map/map_line.tscn")

const COMBAT_SCENE := "res://scenes/combat/combat.tscn"
const SHOP_SCENE := "res://scenes/Shop/ShopRoom.tscn"

const PUZZLE_SCENES := [
	"res://scenes/puzzles/sliding_puzzle/sliding_puzzle.tscn",
	"res://scenes/puzzles/simon_says/start_simon.tscn"
]

@onready var visuals: Node2D = $Visuals
@onready var lines: Node2D = %Lines
@onready var rooms: Node2D = %Rooms
@onready var camera_2d: Camera2D = $Camera2D
@onready var map_generator: MapGenerator = $MapGenerator

var map_data : Array[Array]
var floors_climbed : int
var last_room : Room
var camera_edge_y : float

func _ready() -> void:
	camera_edge_y = MapGenerator.Y_DIST * (MapGenerator.FLOORS - 1)

	if not RunData.run_active or RunData.map_data.is_empty():
		RunData.new_run()
		generate_new_map()
		_save_map_state()
		unlock_floor(0)
	else:
		map_data = RunData.map_data
		floors_climbed = RunData.floors_climbed
		last_room = RunData.last_map_room
		create_map()
		if last_room:
			unlock_next_rooms()
		else:
			unlock_floor(0)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("scroll_up"):
		camera_2d.position.y -= SCROLL_SPEED
	elif event.is_action_pressed("scroll_down"):
		camera_2d.position.y += SCROLL_SPEED
	
	# macOS trackpad pan gesture
	elif event is InputEventPanGesture:
		camera_2d.position.y += event.delta.y * SCROLL_SPEED
	
	camera_2d.position.y = clamp(camera_2d.position.y, -camera_edge_y, 0)

func generate_new_map():
	floors_climbed = 0
	map_data = map_generator.generate_map()
	create_map()
	_save_map_state()

func create_map():
	for current_floor: Array in map_data:
		for room: Room in current_floor:
			if room.next_rooms.size() > 0:
				_spawn_room(room)
				
	# boss room has no next room but we need to spawn it
	var middle := floori(MapGenerator.MAP_WIDTH * 0.5)
	_spawn_room(map_data[MapGenerator.FLOORS-1][middle])
	
	var map_width_pixels := MapGenerator.X_DIST * (MapGenerator.MAP_WIDTH - 1)
	visuals.position.x = (get_viewport_rect().size.x - map_width_pixels) / 2
	visuals.position.y = get_viewport_rect().size.y / 2

func unlock_floor(which_floor : int = floors_climbed):
	for map_node : MapNode in rooms.get_children():
		if map_node.room.row == which_floor:
			map_node.available = true

func unlock_next_rooms():
	for map_node : MapNode in rooms.get_children():
		if last_room.next_rooms.has(map_node.room):
			map_node.available = true

func show_map():
	show()
	camera_2d.enabled = true

func hide_map():
	hide()
	camera_2d.enabled = false

func _spawn_room(room : Room):
	var new_map_room := MAP_NODE.instantiate() as MapNode
	rooms.add_child(new_map_room)
	new_map_room.room = room
	new_map_room.selected.connect(_on_map_room_selected)
	_connect_lines(room)

	if room.selected and room.row < floors_climbed:
		if new_map_room.has_method("show_selected"):
			new_map_room.show_selected()

func _connect_lines(room : Room):
	if room.next_rooms.is_empty():
		return

	for next : Room in room.next_rooms:
		var new_map_line := MAP_LINE.instantiate() as Line2D
		new_map_line.points = []
		new_map_line.add_point(room.position)
		new_map_line.add_point(next.position)
		lines.add_child(new_map_line)

func _save_map_state() -> void:
	RunData.map_data = map_data
	RunData.floors_climbed = floors_climbed
	RunData.last_map_room = last_room

func _on_map_room_selected(room : Room):
	for map_room : MapNode in rooms.get_children():
		if map_room.room.row == room.row:
			map_room.available = false

	last_room = room
	floors_climbed += 1
	_save_map_state()
	emit_signal("room_selected", room)
	_go_to_room(room)
	

func _go_to_room(room : Room) -> void:
	match room.type:
		Room.Type.COMBAT:
			TransitionManager.change_scene(COMBAT_SCENE)
		Room.Type.SHOP:
			TransitionManager.change_scene(SHOP_SCENE, TransitionManager.TransitionType.FADE)
		Room.Type.PUZZLE:
			TransitionManager.change_scene(PUZZLE_SCENES[randi() % PUZZLE_SCENES.size()])
		Room.Type.BOSS:
			TransitionManager.change_scene(COMBAT_SCENE)
