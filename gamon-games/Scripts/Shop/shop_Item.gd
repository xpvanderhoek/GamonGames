extends Node2D

@export var item_data: ItemData
@onready var sprite = $Sprite2D
@onready var price_label = $PriceLabel
@onready var prompt = $Prompt

var player_in_range: bool = false

func _ready():
	if item_data:
		sprite.texture = item_data.texture
		price_label.text = str(item_data.cost)
	prompt.hide()

func _unhandled_input(event):
	if event.is_action_pressed("interact") and player_in_range:
		buy_item()

# Assigns the item data to the item and updates the visuals 
func _on_item_data_assigned():
	if item_data:
		sprite.texture = item_data.texture
		price_label.text = str(item_data.cost)
		
		var max_size = 64.0
		if sprite.texture:
			var tex_size = sprite.texture.get_size()
			var scale_factor = min(max_size / tex_size.x, max_size / tex_size.y, 1.0)
			sprite.scale = Vector2(scale_factor, scale_factor)

func buy_item():
	if CurrenciesManager.gold >= item_data.cost:
		CurrenciesManager.gold -= item_data.cost
		apply_buff()
		queue_free() 
	else:
		print("You're broke, adventurer.")


## For now its just an example, but we'll need to connect it correctly to jakubs character stats 
func apply_buff():
	var player = get_tree().get_first_node_in_group("Player")
	##if player:
		##match item_data.buff_type:
			##"Health": player.max_health += item_data.buff_value
			##"Damage": player.attack_power += item_data.buff_value
			##"Speed": player.move_speed += item_data.buff_value

func _on_buy_zone_body_entered(body: Node2D) -> void:
	print("Player entered buy zone")
	if body.is_in_group("Player"):
		player_in_range = true
		prompt.show()


func _on_buy_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = false
		prompt.hide()
