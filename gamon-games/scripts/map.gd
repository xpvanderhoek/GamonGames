extends Node2D

@onready var dotted_line: Line2D = $DottedLine
@onready var map_nodes: Node2D = $MapNodes
@onready var coins: Label = $CoinLabel

var enemy_scenes := [
	"res://scenes/combat/enemies/ttt.tscn"
]

var puzzles := [
	"res://scenes/puzzles/sliding_puzzle/sliding_puzzle.tscn",
	"res://scenes/puzzles/simon_says/start_simon.tscn"
]

func _ready() -> void:
	if not RunData.run_active:
		RunData.new_run()
	coins.text = str(RunData.coins)
	_setup_map_nodes()
	_update_node_availability()

func _setup_map_nodes():
	var nodes_list := map_nodes.get_children()
	
	if RunData.map_nodes_data.is_empty():
		var previous_node : MapNodeData = null
		
		for node in nodes_list:
			var data : MapNodeData = MapNodeData.new()
			
			if previous_node == null:
				data.type = MapNodeData.Type.COMBAT
			else:
				var rand_idx = randi_range(0, MapNodeData.Type.size() - 1)
				data.type = rand_idx as MapNodeData.Type
			
			if data.type == MapNodeData.Type.COMBAT:
				var enemy_count = randi_range(1, 3)
				for i in range(enemy_count):
					var random_enemy = enemy_scenes[randi() % enemy_scenes.size()]
					data.enemies.append(random_enemy)
			
			RunData.map_nodes_data.append(data)
			
			node.data = data
			node.selected.connect(_on_map_node_selected)
			
			if previous_node == null:
				node.available = true
			else:
				previous_node.next_rooms.append(node.data)
				
			previous_node = data
	else:
		for i in range(nodes_list.size()):
			var node = nodes_list[i]
			var data = RunData.map_nodes_data[i]
			
			node.data = data
			node.selected.connect(_on_map_node_selected)

func _on_map_node_selected(data: MapNodeData) -> void:
	RunData.current_map_node = data
	
	match data.type:
		MapNodeData.Type.COMBAT:
			var encounter_scenes: Array[PackedScene] = []
			for enemy_path in data.enemies:
				var scene = load(enemy_path) as PackedScene
				if scene:
					encounter_scenes.append(scene)
			RunData.current_encounter = encounter_scenes
			TransitionManager.change_scene("res://scenes/combat/combat.tscn")
		
		MapNodeData.Type.SHOP:
			TransitionManager.change_scene("res://scenes/Shop/ShopRoom.tscn", TransitionManager.TransitionType.FADE)
		
		MapNodeData.Type.PUZZLE:
			TransitionManager.change_scene(pick_type_map(puzzles))
			

func pick_type_map(array: Array):
	var array_number = randi_range(0, array.size() - 1)
	return array[array_number]

func _update_node_availability() -> void:
	coins.text = str(RunData.coins)
	for node in map_nodes.get_children():
		node.available = false
	
	# If we have a current map node, disable it and enable its next rooms
	if RunData.current_map_node:
		# Enable all next rooms
		for next_data in RunData.current_map_node.next_rooms:
			for node in map_nodes.get_children():
				if node.data == next_data:
					node.available = true
					break
	else:
		var nodes_list = map_nodes.get_children()
		if nodes_list.size() > 0:
			nodes_list[0].available = true

func _process(_delta: float) -> void:
	draw_dotted_line()

func draw_dotted_line():
	dotted_line.clear_points()
	
	var nodes_list := map_nodes.get_children()
	for node in nodes_list:
		dotted_line.add_point(node.global_position)
