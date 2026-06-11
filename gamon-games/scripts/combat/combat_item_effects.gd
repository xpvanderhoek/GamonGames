class_name CombatItemEffects
extends RefCounted

var manager: CombatManager

func _init(owner: CombatManager) -> void:
	manager = owner

func apply_consumable_item(item: ItemData) -> void:
	if item == null or manager == null:
		return
	match item.item_name:
		"Dark Balsam":
			_apply_healing_consumable(item)
		"Iron-Suture Kit":
			_apply_healing_consumable(item)
		"Smelling Salts":
			add_player_item_effect("item:smelling_salts", item.item_name, item.texture, 3, {
				"precision_delta": 10.0,
			})
		"Adrenaline Spike":
			add_player_item_effect("item:adrenaline_spike", item.item_name, item.texture, 2, {
				"energy_regen_delta": 2.0,
				"expire_damage": 10,
			})
		"Essence of the Void":
			add_player_item_effect("item:essence_void", item.item_name, item.texture, 1, {
				"invulnerable": true,
			})
		"Viper's Tongue":
			manager._pending_consumable_status = {
				"status": "Poison",
				"stacks": maxi(1, int(round(item.buff_value))),
				"duration": 3,
				"icon": item.texture,
				"name": item.item_name,
			}
		_:
			var buff_type := item.buff_type.to_lower()
			if buff_type == "hp_max":
				_apply_healing_consumable(item)
			elif buff_type == "precision":
				add_player_item_effect("item:%s" % item.item_name, item.item_name, item.texture, 3, {
					"precision_delta": item.buff_value,
				})
			elif buff_type == "speed":
				add_player_item_effect("item:%s" % item.item_name, item.item_name, item.texture, 2, {
					"energy_regen_delta": 1.0,
				})

func _apply_healing_consumable(item: ItemData) -> void:
	if item == null or manager == null:
		return
	manager._apply_player_heal(int(round(item.buff_value)))

func add_player_item_effect(effect_id: String, label: String, icon: Texture2D, duration_rounds: int, fields: Dictionary) -> void:
	if manager == null:
		return
	var expires_round = manager.current_round + max(1, duration_rounds) - 1
	for index in range(manager._player_effects.size()):
		var existing := manager._player_effects[index] as Dictionary
		if String(existing.get("effect_id", "")) != effect_id:
			continue
		existing["expires_round"] = max(expires_round, int(existing.get("expires_round", manager.current_round)))
		for key in fields.keys():
			existing[key] = fields[key]
		manager._player_effects[index] = existing
		manager._refresh_player_buffs_ui()
		return

	var new_effect := {
		"expires_round": expires_round,
		"effect_id": effect_id,
		"spell_id": effect_id,
		"spell_name": label,
		"spell_type": int(SpellData.SpellType.BUFF),
		"icon": icon,
	}
	for key in fields.keys():
		new_effect[key] = fields[key]
	manager._player_effects.append(new_effect)
	manager._refresh_player_buffs_ui()

func has_item_named(name: String) -> bool:
	for item in RunData.items:
		if item != null and item.item_name == name:
			return true
	return false

func get_item_count_by_name(name: String) -> int:
	var count := 0
	for item in RunData.items:
		if item != null and item.item_name == name:
			count += 1
	return count

func get_item_value_by_name(name: String, fallback: float) -> float:
	var total := 0.0
	var found := false
	for item in RunData.items:
		if item != null and item.item_name == name:
			found = true
			total += item.buff_value
	if found:
		return total
	return fallback

func get_item_damage_bonus(target_limb: CombatLimb) -> int:
	var total := 0
	for item in RunData.items:
		if item == null:
			continue
		if item.buff_type.to_lower() != "damage":
			continue
		if not item_applies_to_enemy_limb(item, target_limb):
			continue
		total += int(round(item.buff_value))
	return total

func get_item_precision_bonus(target_limb: CombatLimb) -> float:
	var total := 0.0
	for item in RunData.items:
		if item == null:
			continue
		if item.buff_type.to_lower() != "precision":
			continue
		if not item_applies_to_enemy_limb(item, target_limb):
			continue
		total += item.buff_value
	return total

func get_item_statuses_for_limb(target_limb: CombatLimb) -> Array[String]:
	var statuses: Array[String] = []
	for item in RunData.items:
		if item == null:
			continue
		if item.status_to_apply.to_lower() == "none":
			continue
		if not item_applies_to_enemy_limb(item, target_limb):
			continue
		var status_label := "%s (%s)" % [item.status_to_apply, item.item_name]
		statuses.append(status_label)
	return statuses

func get_item_defense_bonus() -> float:
	var total := 0.0
	for item in RunData.items:
		if item == null:
			continue
		if item.buff_type.to_lower() != "defense":
			continue
		if item.status_to_apply.to_lower() != "none":
			continue
		if item.item_name == "Thorned Bracer":
			continue
		total += item.buff_value
	return total

func get_item_energy_regen_bonus() -> int:
	var total := 0
	for item in RunData.items:
		if item == null:
			continue
		if item.buff_type.to_lower() != "speed":
			continue
		total += int(round(item.buff_value))
	return total

func get_item_cooldown_reduction() -> int:
	var total := 0
	for item in RunData.items:
		if item == null:
			continue
		if item.buff_type.to_lower() != "cooldown":
			continue
		total += int(round(-item.buff_value))
	return total

func get_temp_precision_bonus() -> float:
	if manager == null:
		return 0.0
	manager._cleanup_expired_effects()
	var total := 0.0
	for effect in manager._player_effects:
		total += float(effect.get("precision_delta", 0.0))
	return total

func get_temp_energy_regen_bonus() -> int:
	if manager == null:
		return 0
	manager._cleanup_expired_effects()
	var total := 0
	for effect in manager._player_effects:
		total += int(round(float(effect.get("energy_regen_delta", 0.0))))
	return total

func get_temp_cooldown_reduction() -> int:
	if manager == null:
		return 0
	manager._cleanup_expired_effects()
	var total := 0
	for effect in manager._player_effects:
		total += int(round(float(effect.get("cooldown_delta", 0.0))))
	return total

func item_applies_to_enemy_limb(item: ItemData, target_limb: CombatLimb) -> bool:
	if item == null:
		return false
	if target_limb == null or not is_instance_valid(target_limb):
		return false
	var target_key := normalize_target_key(item.target_limb)
	if target_key == "self":
		return false
	if target_key == "none" or target_key == "all" or target_key == "alllimbs" or target_key == "targetedlimb":
		return true
	var limb_label := get_limb_label(target_limb)
	return limb_label != "" and limb_label == target_key

func normalize_target_key(raw: String) -> String:
	return raw.to_lower().replace(" ", "").replace("_", "")

func get_limb_label(limb: CombatLimb) -> String:
	var label := limb.limb_name.strip_edges()
	if label == "":
		label = limb.name
	label = label.to_lower()
	if label.find("head") >= 0:
		return "head"
	if label.find("arm") >= 0 or label.find("hand") >= 0:
		return "arm"
	if label.find("leg") >= 0 or label.find("foot") >= 0:
		return "leg"
	if label.find("torso") >= 0 or label.find("body") >= 0:
		return "torso"
	return ""

func apply_item_status_on_hit(target_enemy: CombatEntity, target_limb: CombatLimb) -> void:
	for item in RunData.items:
		if item == null:
			continue
		if item.status_to_apply.to_lower() == "none":
			continue
		if item.item_name == "Withered Achilles Heel":
			continue
		if not item_applies_to_enemy_limb(item, target_limb):
			continue
		var stacks := maxi(1, int(round(item.buff_value)))
		if item.item_name == "Executioner's Hood" and item.status_to_apply.to_lower() == "bleed":
			stacks = 2
		apply_status_effect(target_enemy, target_limb, item.status_to_apply, stacks, 3, item.texture, item.item_name)

func apply_item_status_on_break(target_enemy: CombatEntity, target_limb: CombatLimb) -> void:
	for item in RunData.items:
		if item == null:
			continue
		if item.item_name != "Withered Achilles Heel":
			continue
		if not item_applies_to_enemy_limb(item, target_limb):
			continue
		apply_status_effect(target_enemy, target_limb, "Vulnerable", 3, 3, item.texture, item.item_name)

func apply_pending_consumable_status(target_enemy: CombatEntity, target_limb: CombatLimb) -> void:
	if manager == null or manager._pending_consumable_status.is_empty():
		return
	apply_status_effect(
		target_enemy,
		target_limb,
		String(manager._pending_consumable_status.get("status", "")),
		int(manager._pending_consumable_status.get("stacks", 1)),
		int(manager._pending_consumable_status.get("duration", 3)),
		manager._pending_consumable_status.get("icon", null),
		String(manager._pending_consumable_status.get("name", "Consumable"))
	)
	manager._pending_consumable_status.clear()

func apply_status_effect(target_enemy: CombatEntity, target_limb: CombatLimb, status: String, stacks: int, duration_rounds: int, icon: Texture2D, source_name: String) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy):
		return
	if status.strip_edges() == "":
		return
	if manager == null:
		return
	var status_key := status.to_lower()
	var effect_id := "item:%s:%s" % [source_name, status_key]
	var effect_data := {
		"expires_round": manager.current_round + max(1, duration_rounds) - 1,
		"spell_id": effect_id,
		"spell_name": "%s (%s)" % [source_name, status],
		"spell_type": int(SpellData.SpellType.DEBUFF),
		"icon": icon,
		"target_scope": int(CombatManager.TargetScope.LIMB),
		"outgoing_mult_delta": 0.0,
		"incoming_mult_delta": 0.0,
		"damage_over_time": 0,
		"stun_turns": false,
		"defense_delta": 0.0,
	}

	match status_key:
		"bleed", "poison", "decay", "burn":
			effect_data["damage_over_time"] = maxi(1, stacks)
		"vulnerable":
			effect_data["incoming_mult_delta"] = 0.1 * float(maxi(1, stacks))
		"invulnerable":
			return

	append_enemy_item_effect(target_enemy, target_limb, effect_data)

func append_enemy_item_effect(target_enemy: CombatEntity, target_limb: CombatLimb, effect_data: Dictionary) -> void:
	if target_enemy == null or not is_instance_valid(target_enemy) or manager == null:
		return
	var enemy_id := target_enemy.get_instance_id()
	var target_scope := int(effect_data.get("target_scope", int(CombatManager.TargetScope.LIMB)))
	if target_scope != int(CombatManager.TargetScope.LIMB) or target_limb == null or not is_instance_valid(target_limb):
		var enemy_effects: Array = manager._enemy_effects.get(enemy_id, [])
		for index in range(enemy_effects.size()):
			var existing := enemy_effects[index] as Dictionary
			if String(existing.get("spell_id", "")) != String(effect_data.get("spell_id", "")):
				continue
			existing["expires_round"] = max(int(existing.get("expires_round", manager.current_round)), int(effect_data.get("expires_round", manager.current_round)))
			enemy_effects[index] = existing
			manager._enemy_effects[enemy_id] = enemy_effects
			manager._refresh_enemy_buffs_ui()
			return
		enemy_effects.append(effect_data)
		manager._enemy_effects[enemy_id] = enemy_effects
		manager._refresh_enemy_buffs_ui()
		return

	var limb_id := target_limb.get_instance_id()
	var limb_effects_by_enemy := manager._enemy_limb_effects.get(enemy_id, {}) as Dictionary
	var limb_effects: Array = limb_effects_by_enemy.get(limb_id, [])
	for index in range(limb_effects.size()):
		var existing := limb_effects[index] as Dictionary
		if String(existing.get("spell_id", "")) != String(effect_data.get("spell_id", "")):
			continue
		existing["expires_round"] = max(int(existing.get("expires_round", manager.current_round)), int(effect_data.get("expires_round", manager.current_round)))
		limb_effects[index] = existing
		limb_effects_by_enemy[limb_id] = limb_effects
		manager._enemy_limb_effects[enemy_id] = limb_effects_by_enemy
		manager._refresh_enemy_buffs_ui()
		return
	limb_effects.append(effect_data)
	limb_effects_by_enemy[limb_id] = limb_effects
	manager._enemy_limb_effects[enemy_id] = limb_effects_by_enemy
	manager._refresh_enemy_buffs_ui()

func player_has_invulnerable() -> bool:
	if manager == null:
		return false
	manager._cleanup_expired_effects()
	for effect in manager._player_effects:
		if bool(effect.get("invulnerable", false)):
			return true
	return false

func apply_player_reflect_damage(amount: int, source_enemy: CombatEntity, source_limb: CombatLimb) -> void:
	if amount <= 0:
		return
	if manager == null:
		return
	if source_enemy == null or not is_instance_valid(source_enemy) or not source_enemy.is_alive:
		return
	var reflect_damage := 0
	var shroud_count := get_item_count_by_name("The Shroud of Malice")
	var bracer_count := get_item_count_by_name("Thorned Bracer")
	if shroud_count > 0:
		reflect_damage += int(round(float(amount) * 0.5 * float(shroud_count)))
	if bracer_count > 0:
		reflect_damage += 8 * bracer_count
	if reflect_damage <= 0:
		return
	var target_limb: CombatLimb = manager._get_first_alive_enemy_limb(source_enemy)
	if target_limb == null:
		return
	source_enemy.take_damage(target_limb, reflect_damage)
