extends Node

const scene_room1 = preload("res://scenes/rooms/room_1.tscn")
const scene_room2 = preload("res://scenes/rooms/room_2.tscn")
const scene_room3 = preload("res://scenes/rooms/room_3.tscn")

@onready var rooms : Array[PackedScene] = [scene_room1, scene_room2, scene_room3]

func go_to_random_room():
	var destination_scene : PackedScene = rooms[randi() % rooms.size()]

	if destination_scene != null:
		get_tree().change_scene_to_packed(destination_scene)