extends Node

const scene_room1 = "res://scenes/rooms/room_1.tscn"
const scene_room2 = "res://scenes/rooms/room_2.tscn"
const scene_room3 = "res://scenes/rooms/room_3.tscn"

@onready var rooms : Array[String] = [scene_room1, scene_room2, scene_room3]

func go_to_random_room(current_scene_path : String):

	var destination_scene : String  = current_scene_path

	while destination_scene == current_scene_path: # Prevent current room appearing repeatedly 
		destination_scene = rooms[randi() % rooms.size()]

	if destination_scene != null:
		TransitionManager.call_deferred("change_scene", destination_scene, 0) # call_deferred() used to prevent physics bugs.
