extends Resource
class_name ItemData

@export var item_name: String = "Shiny Trinket"
@export var cost: int = 50
@export var texture: Texture2D
@export_enum("Health", "Damage", "Speed") var buff_type: String = "Health"
@export var buff_value: float = 10.0