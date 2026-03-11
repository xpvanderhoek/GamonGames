extends Node2D

# Drag and drop your .tres files (ItemData resources) into this array in the Inspector
@export var possible_items: Array[ItemData] = []
@export var item_scene: PackedScene 

@onready var spawn_positions = [$Item1, $Item2, $Item3]

func _ready():
	spawn_shop_inventory()

func spawn_shop_inventory():
	# Random items each time
	possible_items.shuffle()
	
	for i in range(spawn_positions.size()):
		if i < possible_items.size():
			var new_item = item_scene.instantiate()
			# Parent the item under the spawn marker
			spawn_positions[i].add_child(new_item)
			new_item.position = Vector2.ZERO
			
			# Pass the specific resource data to the item
			new_item.item_data = possible_items[i]
			new_item._on_item_data_assigned()