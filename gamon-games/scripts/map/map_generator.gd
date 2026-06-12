class_name MapGenerator
extends Node

const X_DIST := 150
const Y_DIST := 100
const PLACEMENT_RANDOMNESS := 40
const FLOORS := 15
const MAP_WIDTH := 4
const PATHS := 6
const MIN_PATH_STARTS := 2
const COMBAT_ROOM_WEIGHT := 53.0
const PUZZLE_ROOM_WEIGHT := 22.0
const SHOP_ROOM_WEIGHT := 5.0
const CAMPFIRE_ROOM_WEIGHT := 12.0

var random_room_type_weights = {
	Room.Type.COMBAT: 0.0,
	Room.Type.PUZZLE: 0.0,
	Room.Type.SHOP: 0.0,
	Room.Type.CAMPFIRE: 0.0,
}
var random_room_total_weight := 0
var map_data : Array[Array]

func generate_map() -> Array[Array]:
	map_data = _generate_initial_grid()
	var starting_points := _get_random_starting_points()	
	
	for j in starting_points:
		var current_j := j
		for i in FLOORS - 1:
			current_j = _setup_connection(i, current_j)
	
	_setup_boss_room()
	_setup_random_room_weights()
	_setup_room_types()
	
	# These prints are for debugging the generation. If needed, uncomment.
	#var i := 0
	#for floor in map_data:
		#print("floor is %s" % i)
		#var used_rooms = floor.filter(
			#func(room : Room): return room.next_rooms.size() > 0
		#)
		#print(used_rooms)
		#i += 1
	
	return map_data

func _generate_initial_grid() -> Array[Array]:
	var result: Array[Array] = []
	
	for i in FLOORS:
		var adjacent_rooms: Array[Room] = []
		
		for j in MAP_WIDTH:
			var current_room := Room.new()
			var offset := Vector2(randf(), randf())  * PLACEMENT_RANDOMNESS
			current_room.position = Vector2(j * X_DIST, i * -Y_DIST) + offset
			current_room.row = i
			current_room.column = j
			current_room.next_rooms = []
			
			# Boss room has a non-random Y
			if i == FLOORS - 1:
				current_room.position.y = i * -Y_DIST
			
			adjacent_rooms.append(current_room)
		
		result.append(adjacent_rooms)
	
	return result

func _get_random_starting_points() -> Array[int]:
	var y_coordinates: Array[int] = []
	var options := range(MAP_WIDTH) 
	var min_path_starts := clampi(MIN_PATH_STARTS, 0, MAP_WIDTH)

	for i in min_path_starts:
		var random_index := RunData.rng.randi_range(0, options.size()-1)
		var starting_point: int = options.pop_at(random_index)
		y_coordinates.append(starting_point)
	
	for i in range(min_path_starts, PATHS):
		var starting_point: int = RunData.rng.randi_range(0, MAP_WIDTH - 1)
		y_coordinates.append(starting_point)
	
	return y_coordinates

func _setup_connection(i : int, j : int) -> int:
	var next_room : Room
	var current_room := map_data[i][j] as Room
	
	while not next_room or _would_cross_existing_path(i, j, next_room):
		var random_j := clampi(RunData.rng.randi_range(j - 1, j + 1), 0, MAP_WIDTH - 1)
		next_room = map_data[i + 1][random_j]
	
	current_room.next_rooms.append(next_room)
	
	return next_room.column

func _would_cross_existing_path(i : int, j : int, room : Room):
	var left_neighbour : Room
	var right_neighbour : Room
	
	# if j == 0, there is no left neighbour
	if j > 0:
		left_neighbour = map_data[i][j - 1]
	# if j == MAP_WIDTH - 1, there is no right neighbour
	if j < MAP_WIDTH - 1:
		right_neighbour = map_data[i][j + 1]
		
	# cannot cross in right dir if right neighbour goes left
	if right_neighbour and room.column > j:
		for next_room: Room in right_neighbour.next_rooms:
			if next_room.column < room.column:
				return true
	
	# cannot cross in left dir if left neighbour goes right
	if left_neighbour and room.column < j:
		for next_room: Room in left_neighbour.next_rooms:
			if next_room.column > room.column:
				return true
	
	return false

func _setup_boss_room():
	var middle := floori(MAP_WIDTH * 0.5)
	var boss_room := map_data[FLOORS - 1][middle] as Room
	
	for j in MAP_WIDTH:
		var current_room = map_data[FLOORS - 2][j] as Room
		if current_room.next_rooms:
			current_room.next_rooms = [] as Array[Room]
			current_room.next_rooms.append(boss_room)
		
	boss_room.type = Room.Type.BOSS

func _setup_random_room_weights():
	random_room_type_weights[Room.Type.COMBAT] = COMBAT_ROOM_WEIGHT
	random_room_type_weights[Room.Type.PUZZLE] = PUZZLE_ROOM_WEIGHT + COMBAT_ROOM_WEIGHT
	random_room_type_weights[Room.Type.SHOP] = SHOP_ROOM_WEIGHT + COMBAT_ROOM_WEIGHT + PUZZLE_ROOM_WEIGHT
	random_room_type_weights[Room.Type.CAMPFIRE] = CAMPFIRE_ROOM_WEIGHT + SHOP_ROOM_WEIGHT + COMBAT_ROOM_WEIGHT + PUZZLE_ROOM_WEIGHT
	
	random_room_total_weight = random_room_type_weights[Room.Type.CAMPFIRE]

func _setup_room_types():
	# first floor is always combat
	for room : Room in map_data[0]:
		if room.next_rooms.size() > 0:
			room.type = Room.Type.PUZZLE
	
	# Optional: last floor before the boss fight is always a shop
	for room : Room in map_data[FLOORS - 2]:
		if room.next_rooms.size() > 0:
			room.type = Room.Type.CAMPFIRE
	
	# remainder of rooms
	for current_floor in map_data:
		for room : Room in current_floor:
			for next_room : Room in room.next_rooms:
				if next_room.type == Room.Type.NOT_ASSIGNED:
					_set_room_randomly(next_room)

func _set_room_randomly(room_to_set : Room):
	var consecutive_shop := true
	var consecutive_campfire := true
	var shop_below_boss := true
	
	var type_candidate : Room.Type
	
	while shop_below_boss or consecutive_shop or consecutive_campfire:
		type_candidate = _get_random_room_type_by_weight()
		
		var is_shop := type_candidate == Room.Type.SHOP
		var is_campfire := type_candidate == Room.Type.CAMPFIRE
		var has_shop_parent := _room_has_parent_of_type(room_to_set, Room.Type.SHOP)
		var has_campfire_parent := _room_has_parent_of_type(room_to_set, Room.Type.CAMPFIRE)
		
		consecutive_shop = is_shop and has_shop_parent
		consecutive_campfire = is_campfire and has_campfire_parent
		shop_below_boss = is_shop and room_to_set.row == FLOORS - 3
	
	room_to_set.type = type_candidate

func _room_has_parent_of_type(room : Room, type : Room.Type) -> bool:
	var parents: Array[Room] = []
	# left parent
	if room.column > 0 and room.row > 0:
		var parent_candidate := map_data[room.row - 1][room.column - 1] as Room
		if parent_candidate.next_rooms.has(room):
			parents.append(parent_candidate)
	
	# parent below
	if room.row > 0:
		var parent_candidate := map_data[room.row - 1][room.column] as Room
		if parent_candidate.next_rooms.has(room):
			parents.append(parent_candidate)
	
	# right parent
	if room.column < MAP_WIDTH - 1 and room.row > 0:
		var parent_candidate := map_data[room.row - 1][room.column + 1] as Room
		if parent_candidate.next_rooms.has(room):
			parents.append(parent_candidate)
	
	for parent : Room in parents:
		if parent.type == type:
			return true
	
	return false

func _get_random_room_type_by_weight() -> Room.Type:
	var roll := randf_range(0.0, random_room_total_weight)
	
	for type : Room.Type in random_room_type_weights:
		if random_room_type_weights[type] > roll:
			return type
	
	return Room.Type.COMBAT
