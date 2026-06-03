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

# Tooltip system similar to spells
func build_item_tooltip_bbcode(item: ItemData, shift_pressed: bool = false) -> String:
	if item == null:
		return ""

	var t := "[b][font_size=15]%s[/font_size][/b]" % item.item_name
	
	if item is ConsumableItemData:
		t += " [color=#a0d8ff][font_size=12][CONSUMABLE][/font_size][/color]"
	
	# Category and cost
	t += "\n[color=#cccccc]Category: %s[/color]" % item.category
	t += "\n[color=#f0d060]Cost: %d[/color]" % item.cost
	
	# Main effect
	if item.effect.strip_edges() != "":
		t += "\n[color=#90d080]%s[/color]" % item.effect

	# Buff information
	if item.buff_type != "None" and item.buff_value != 0:
		t += "\n"
		var buff_display := _format_buff_type(item.buff_type)
		var buff_color := _get_buff_type_color(item.buff_type)
		
		# Show current value and new value
		var current_value := _get_current_stat_value(item.buff_type)
		var new_value := _calculate_new_stat_value(item)
		
		t += "\n%s: [color=#%s]%s[/color] → [color=#90d080]%s[/color]" % [
			buff_display,
			buff_color,
			_format_stat_value(current_value, item.buff_type),
			_format_stat_value(new_value, item.buff_type)
		]
		
		if shift_pressed:
			var value_type := _get_value_type_hint(item.buff_value)
			t += "\n[color=#8a8a9e][font_size=11]  - Increases by %s (%s)[/font_size][/color]" % [
				_format_signed_value(item.buff_value),
				value_type
			]

	# Target limb info if applicable
	if item.target_limb != "None":
		t += "\n[color=#8a8a9e][font_size=11]Affects: %s[/font_size][/color]" % item.target_limb
		if shift_pressed:
			t += "\n[color=#8a8a9e][font_size=11]  - Only applies when targeting this limb.[/font_size][/color]"

	# Status effect info if applicable
	if item.status_to_apply != "None":
		t += "\n[color=#e09060]Status Effect: %s[/color]" % item.status_to_apply

	# Lore
	if item.lore.strip_edges() != "" and shift_pressed:
		t += "\n[color=#6a7a8e][font_size=11][i]%s[/i][/font_size][/color]" % item.lore

	if not shift_pressed:
		t += "\n[color=#5a5a6a][font_size=10][i]Hold Shift for more info[/i][/font_size][/color]"

	return t

func _format_buff_type(buff_type: String) -> String:
	match buff_type.to_lower():
		"damage":
			return "Damage"
		"precision":
			return "Precision"
		"defense":
			return "Defense"
		"speed":
			return "Speed"
		"hp_max":
			return "HP"
		"cooldown":
			return "Cooldown"
		"limb_repair":
			return "Limb Repair"
		"luck":
			return "Luck"
		_:
			return buff_type

func _get_buff_type_color(buff_type: String) -> String:
	match buff_type.to_lower():
		"damage":
			return "ffb366"
		"precision":
			return "a0d8ff"
		"defense":
			return "80c8e0"
		"speed":
			return "ffd966"
		"hp_max":
			return "64e09e"
		"cooldown":
			return "b0a0e0"
		"limb_repair":
			return "90d080"
		"luck":
			return "e0c080"
		_:
			return "cccccc"

func _get_current_stat_value(buff_type: String) -> float:
	return RunData.get_stat(buff_type)

func _calculate_new_stat_value(item: ItemData) -> float:
	var current: float = RunData.get_stat(item.buff_type)
	return current + item.buff_value

func _format_stat_value(value: float, buff_type: String) -> String:
	# Different formats for different stat types
	match buff_type.to_lower():
		"cooldown":
			return "%.1f" % value
		_:
			return str(int(value))

func _format_signed_value(value: float) -> String:
	if value > 0:
		return "+%s" % _format_stat_value(value, "")
	return _format_stat_value(value, "")

func _get_value_type_hint(buff_value: float) -> String:
	if buff_value > 0:
		return "flat bonus"
	return "flat penalty"

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
