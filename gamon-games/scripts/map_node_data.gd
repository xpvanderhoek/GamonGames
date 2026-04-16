class_name MapNodeData
extends Resource

enum Type {COMBAT, SHOP}

@export var type: Type
@export var next_rooms: Array[MapNodeData]
@export var selected := false
