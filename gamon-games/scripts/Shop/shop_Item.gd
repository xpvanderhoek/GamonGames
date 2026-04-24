extends Node2D

signal item_hover_started(item_data: ItemData)
signal item_hover_ended
signal no_coins_attempted

@export var item_data: ItemData
@onready var sprite = $Item
@onready var price_tag = $PriceTag
@onready var price_label = $PriceTag/PriceLabel
@onready var shadow = $Shadow
@onready var buy_button = $BuyItemButton
@onready var buy_smoke: GPUParticles2D = $BuySmoke
@onready var item_hover_area: Area2D = $Item/ItemHoverArea

var _is_being_purchased := false
var _last_no_coins_dialogue_ms := -100000

const NO_COINS_DIALOGUE_COOLDOWN_MS := 2000

func _ready():
	_on_item_data_assigned()
	_sync_shadow_sprite()
	buy_button.shop_item = self
	
	if item_hover_area:
		item_hover_area.mouse_entered.connect(_on_item_hover)
		item_hover_area.mouse_exited.connect(_on_item_unhover)

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
	if _is_being_purchased:
		return
	if DialogueManager.is_in_dialogue:
		return

	if RunData.coins >= item_data.cost:
		if RunData.add_item(item_data):
			RunData.coins -= item_data.cost
			item_hover_ended.emit()
			_is_being_purchased = true
			await _play_buy_smoke_effect()
			queue_free()
		else:
			print("Cannot pick up item right now.")
	else:
		var now_ms := Time.get_ticks_msec()
		if now_ms - _last_no_coins_dialogue_ms < NO_COINS_DIALOGUE_COOLDOWN_MS:
			return

		_last_no_coins_dialogue_ms = now_ms
		no_coins_attempted.emit()

func on_hover_started() -> void:
	if _is_being_purchased:
		return
	item_hover_started.emit(item_data)

func on_hover_ended() -> void:
	item_hover_ended.emit()

func _on_item_hover() -> void:
	if _is_being_purchased:
		return
	on_hover_started()

func _on_item_unhover() -> void:
	on_hover_ended()

func _play_buy_smoke_effect() -> void:
	if buy_button:
		buy_button.visible = false

	if buy_smoke:
		buy_smoke.position = sprite.position
		buy_smoke.emitting = false
		buy_smoke.restart()
		buy_smoke.emitting = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position:y", sprite.position.y - 18.0, 0.3)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_property(price_tag, "position:y", price_tag.position.y - 14.0, 0.25)
	tween.tween_property(price_tag, "modulate:a", 0.0, 0.25)
	tween.tween_property(shadow, "modulate:a", 0.0, 0.25)
	tween.tween_property(sprite, "scale", sprite.scale * 1.18, 0.3)
	await tween.finished

	var smoke_wait := 0.2
	if buy_smoke:
		smoke_wait = max(smoke_wait, buy_smoke.lifetime)

	await get_tree().create_timer(smoke_wait).timeout
