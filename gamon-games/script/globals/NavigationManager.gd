extends Node

const scene_room1 = "res://scene/rooms/room_1.tscn"
const scene_room2 = "res://scene/rooms/room_2.tscn"
const scene_room_end= "res://scene/rooms/room_end.tscn"

@onready var rooms : Array[String] = [scene_room1, scene_room2]

func go_to_random_room(current_room: String):
	var destination: String = current_room

	while destination == current_room: # Prevent current room appearing repeatedly
		destination = rooms[randi() % rooms.size()]

	TransitionManager.call_deferred("transition_room", destination, 0) # call_deferred() used to prevent physics bugs.

func go_back_to_current_room():
	TransitionManager.exit_combat_deferred()

func get_new_random_room() -> String:
	var possible_rooms = rooms.filter(func(x): return x not in RunData.entered_rooms) # Removes all entered rooms in current run from the rooms array.

	if possible_rooms.is_empty():
		return scene_room_end

	var random_index = RunData.rng.randi_range(0, possible_rooms.size() - 1) # Choose random room that has not been entered during the current run yet.
	var random_room = possible_rooms[random_index]

	return random_room

func go_to_room(room : String):
	TransitionManager.call_deferred("transition_room", room, 0)
