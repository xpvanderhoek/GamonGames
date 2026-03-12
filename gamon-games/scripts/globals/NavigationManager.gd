extends Node

const scene_room1 = "res://scenes/rooms/room_1.tscn"
const scene_room2 = "res://scenes/rooms/room_2.tscn"
const scene_room3 = "res://scenes/rooms/room_3.tscn"
var current_room_path: String = scene_room1

@onready var rooms : Array[String] = [scene_room1, scene_room2, scene_room3]

	var destination: String = current_room

	while destination == current_room: # Prevent current room appearing repeatedly
		destination = rooms[randi() % rooms.size()]

	current_room_path = destination
	TransitionManager.call_deferred("transition_room", destination, 0) # call_deferred() used to prevent physics bugs.

func go_back_to_current_room():
	TransitionManager.exit_combat_deferred()