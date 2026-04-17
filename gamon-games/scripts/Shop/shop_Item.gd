extends Node2D

@export var item_data: ItemData
@onready var sprite = $Item
@onready var price_label = $PriceTag/PriceLabel
@onready var shadow = $Shadow
@onready var buy_button = $BuyItemButton

func _ready():
	_on_item_data_assigned()
	_sync_shadow_sprite()
	buy_button.shop_item = self

func _sync_shadow_sprite():
	shadow.texture = sprite.texture
	shadow.scale = Vector2(sprite.scale.x, sprite.scale.x * 0.3)

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

		_sync_shadow_sprite()


func buy_item():
	if RunData.coins >= item_data.cost:
		if RunData.add_item(item_data):
			RunData.coins -= item_data.cost
			queue_free()
		else:
			print("Cannot pick up item right now.")
