extends Resource
class_name ItemData

@export_group("Identity")
@export var item_name: String = "Mysterious Relic"
@export_multiline var effect: String = ""
@export_multiline var lore: String = ""
@export_enum("Tier I", "Tier II", "Tier III") var category: String = "Tier I"
@export var texture: Texture2D

@export_group("Economy")
@export var cost: int = 50

@export_group("Combat Stats")
@export_enum("None", "Head", "Arm", "Leg", "Torso", "Self", "All Limbs", "Targeted Limb") var target_limb: String = "None"
@export_enum("Damage", "Precision", "Defense", "Speed", "HP_Max", "Cooldown", "Limb_Repair", "Luck") var buff_type: String = "Damage"
@export var buff_value: float = 10.0 

@export_group("Status Effects")
@export_enum("None", "Bleed", "Poison", "Decay", "Vulnerable", "Burn", "Invulnerable") var status_to_apply: String = "None"

func build_tooltip_bbcode(shift_pressed: bool = false, stack_count: int = 1, is_shop_preview: bool = false) -> String:
	var count := maxi(1, stack_count)
	var text := "[b][font_size=15]%s[/font_size][/b]" % item_name

	if self is ConsumableItemData:
		text += " [color=#a0d8ff][font_size=12][CONSUMABLE][/font_size][/color]"
	if count > 1:
		text += " [color=#cfd6ff][font_size=12]x%d[/font_size][/color]" % count

	text += "\n[color=#cccccc]Category: %s[/color]" % category
	text += "\n[color=#f0d060]Cost: %d[/color]" % cost

	if effect.strip_edges() != "":
		text += "\n[color=#90d080]%s[/color]" % effect

	if buff_type != "None" and not is_zero_approx(buff_value):
		var current_value := _get_current_stat_value(buff_type)
		var new_value := 0.0
		
		if is_shop_preview:
			var owned_count := 0
			var current_key := resource_path if not resource_path.is_empty() else item_name
			
			if RunData.get("items") is Array:
				for existing_item in RunData.items:
					if existing_item == null:
						continue
					var existing_key := existing_item.resource_path if not existing_item.resource_path.is_empty() else existing_item.item_name
					if existing_key == current_key:
						owned_count += 1
			
			var items_already_factored := int(current_value / buff_value) if buff_value != 0.0 else 0
			if items_already_factored < owned_count:
				var missing_stacks := owned_count - items_already_factored
				current_value += missing_stacks * buff_value
			
			# preview always increments by exactly 1 more shop item copy just to get that buffed tier value, regardless of how many are already owned
			new_value = current_value + buff_value
		else:
			var total_bonus := buff_value * float(count)
			new_value = current_value + total_bonus
			
		text += "\n%s: [color=#%s]%s[/color] → [color=#90d080]%s[/color]" % [
			_format_buff_type(buff_type),
			_get_buff_type_color(buff_type),
			_format_stat_value(current_value, buff_type),
			_format_stat_value(new_value, buff_type)
		]
		if shift_pressed:
			text += "\n[color=#8a8a9e][font_size=11]  - Increases by %s (%s)[/font_size][/color]" % [
				_format_signed_value(buff_value),
				_get_value_type_hint(buff_value)
			]

	if target_limb != "None":
		text += "\n[color=#8a8a9e][font_size=11]Affects: %s[/font_size][/color]" % target_limb
		if shift_pressed:
			text += "\n[color=#8a8a9e][font_size=11]  - Only applies when targeting this limb.[/font_size][/color]"

	if status_to_apply != "None":
		text += "\n[color=#e09060]Status Effect: %s[/color]" % status_to_apply

	if shift_pressed and lore.strip_edges() != "":
		text += "\n[color=#6a7a8e][font_size=11][i]%s[/i][/font_size][/color]" % lore

	if not shift_pressed:
		text += "\n[color=#5a5a6a][font_size=10][i]Hold Shift for more info[/i][/font_size][/color]"

	return text

func _format_buff_type(type_name: String) -> String:
	match type_name.to_lower():
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
			return type_name

func _get_buff_type_color(type_name: String) -> String:
	match type_name.to_lower():
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

func _get_current_stat_value(type_name: String) -> float:
	return float(RunData.get_stat(type_name))

func _format_stat_value(value: float, type_name: String) -> String:
	if type_name.to_lower() == "cooldown":
		return "%.1f" % value
	return str(int(value))

func _format_signed_value(value: float) -> String:
	if value > 0.0:
		return "+%s" % _format_stat_value(value, "")
	return _format_stat_value(value, "")

func _get_value_type_hint(value: float) -> String:
	if value > 0.0:
		return "flat bonus"
	return "flat penalty"
