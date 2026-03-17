extends Node2D

@export var item_data: ItemData
@onready var sprite = $Sprite2D
@onready var price_label = $PriceLabel
@onready var prompt = $Prompt

var player_in_range: bool = false

func _ready():
	_on_item_data_assigned()
	prompt.hide()

func _on_item_data_assigned():
	if item_data:
		sprite.texture = item_data.texture
		price_label.text = str(item_data.cost)
		
		# Auto-scale sprite to fit shop slot
		var max_size = 64.0
		if sprite.texture:
			var tex_size = sprite.texture.get_size()
			var image: Image = sprite.texture.get_image()
			if image:
				var used_rect := image.get_used_rect()
				if used_rect.size.x > 0 and used_rect.size.y > 0 and Vector2(used_rect.size) != tex_size:
					var atlas := AtlasTexture.new()
					atlas.atlas = sprite.texture
					atlas.region = used_rect
					sprite.texture = atlas
					tex_size = used_rect.size

			if tex_size.x > 0.0 and tex_size.y > 0.0:
				var scale_factor = min(max_size / tex_size.x, max_size / tex_size.y)
				sprite.scale = Vector2(scale_factor, scale_factor)

func _unhandled_input(event):
	if event.is_action_pressed("interact") and player_in_range:
		buy_item()

func buy_item():
	if RunData.coins >= item_data.cost:
		if RunData.add_item(item_data):
			RunData.coins -= item_data.cost
			queue_free()
		else:
			print("Cannot pick up item right now.")
	else:
		print("Insufficient Coins. You're broke!")

func _on_buy_zone_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = true
		if item_data:
			prompt.text = "[E] Buy " + item_data.item_name + " (" + str(item_data.cost) + ")"
			prompt.show()

func _on_buy_zone_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = false
		prompt.hide()
