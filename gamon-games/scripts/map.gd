extends Node2D

@onready var dotted_line: Line2D = $DottedLine
@onready var map_nodes: Node2D = $MapNodes

func _ready() -> void:
	_setup_map_nodes()
	_update_node_availability()

func _setup_map_nodes():
	var nodes_list := map_nodes.get_children()
	
	# If we don't have saved map data, generate it
	if RunData.map_nodes_data.is_empty():
		var previous_node : MapNodeData = null
		
		for node in nodes_list:
			var data : MapNodeData = MapNodeData.new()
			var rand_idx = randi_range(0, MapNodeData.Type.size() - 1)
			data.type = rand_idx
			
			RunData.map_nodes_data.append(data)
			
			node.data = data
			node.selected.connect(_on_map_node_selected)
			
			if previous_node == null:
				node.available = true
			else:
				previous_node.next_rooms.append(node.data)
				
			previous_node = data
	else:
		# Use the saved map data
		for i in range(nodes_list.size()):
			var node = nodes_list[i]
			var data = RunData.map_nodes_data[i]
			
			node.data = data
			node.selected.connect(_on_map_node_selected)

func _on_map_node_selected(data: MapNodeData) -> void:
	# Store the selected node for when we return
	RunData.current_map_node = data
	
	match data.type:
		MapNodeData.Type.COMBAT:
			# To transition to combat, call TransitionManager.transition_combat()
			# You'll need to specify a combat scene path
			#TransitionManager.transition_combat(true, "res://scenes/combat/CombatScene.tscn", TransitionManager.TransitionType.FADE)
			TransitionManager.change_scene("res://scenes/combat/combat.tscn")
		
		MapNodeData.Type.SHOP:
			# For shop, use change_scene() since it's a regular scene transition
			TransitionManager.change_scene("res://scenes/Shop/ShopRoom.tscn", TransitionManager.TransitionType.FADE)

func _update_node_availability() -> void:
	# First, set all nodes to unavailable by default
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
		# No current node selected yet, enable the first node
		var nodes_list = map_nodes.get_children()
		if nodes_list.size() > 0:
			nodes_list[0].available = true

func _process(delta: float) -> void:
	draw_dotted_line()

func draw_dotted_line():
	dotted_line.clear_points()
	
	var nodes_list := map_nodes.get_children()
	for node in nodes_list:
		dotted_line.add_point(node.global_position)
