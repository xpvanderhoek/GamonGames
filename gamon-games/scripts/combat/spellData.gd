class_name SpellData
extends Resource

enum SpellType {
	ATTACK,
	BUFF,
	DEBUFF,
	HEAL,
}

enum DamageType {
	PHYSICAL,
	MAGIC,
}

enum TargetScope {
	LIMB,
	WHOLE_ENEMY,
	ALL_ENEMIES,
}

enum VfxAnchor {
	SELF,
	TARGET,
	SCREEN_CENTER,
}

enum SpellTier {
	TIER_1,
	TIER_2,
	TIER_3,
	TIER_4,
	TIER_5,
}

@export var spell_id: String = ""
var level: int = 1
@export var spell_name: String = "Attack"
@export var spell_type: SpellType = SpellType.ATTACK
@export var target_scope: TargetScope = TargetScope.LIMB
@export var min_damage: int = -1
@export var max_damage: int = -1
@export_range(1, 20, 1) var attack_count: int = 1
@export var energy: int = 0
@export_range(0, 100, 1) var accuracy: float = 1

@export var damage_type: DamageType = DamageType.PHYSICAL
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export var icon: Texture2D
@export var tier: SpellTier = SpellTier.TIER_1
@export var icon_color: Color = Color.WHITE
@export_category("VFX-SFX")
@export var sfx: AudioStream
@export_range(-80.0, 24.0, 0.1) var sfx_volume_db: float = 0.0
@export var vfx_scene: PackedScene
@export var vfx_anchor: VfxAnchor = VfxAnchor.SELF
@export var vfx_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 30.0, 0.1) var vfx_lifetime: float = 1.5

@export_category("Buff-Debuff Modifiers")
@export_range(1, 10, 1) var duration_rounds: int = 1
@export var outgoing_damage_flat_bonus: int = 0
@export_range(-0.95, 3.0, 0.01) var outgoing_damage_multiplier_delta: float = 0.0

@export_range(-0.95, 3.0, 0.01) var incoming_damage_multiplier_delta: float = 0.0
@export var heal_amount: int = 0
@export_range(-100.0, 100.0, 0.1) var player_physical_defense_delta: float = 0.0
@export_range(-100.0, 100.0, 0.1) var player_magic_defense_delta: float = 0.0
@export_range(-100.0, 100.0, 0.1) var player_precision_delta: float = 0.0
@export_range(-100.0, 100.0, 0.1) var target_physical_defense_delta: float = 0.0
@export_range(-100.0, 100.0, 0.1) var target_magic_defense_delta: float = 0.0
@export var extra_turn_count: int = 0

@export var damage_over_time: int = 0
@export var stun_turns: bool = false

func calculate_outgoing_damage_multiplier() -> float:
	return 1.0 + outgoing_damage_multiplier_delta

func get_tier_color() -> Color:
	match tier:
		SpellTier.TIER_2:
			return Color(0.12, 0.85, 0.25, 1.0) # Green
		SpellTier.TIER_3:
			return Color(0.15, 0.55, 1.0, 1.0)  # Blue
		SpellTier.TIER_4:
			return Color(0.7, 0.2, 0.9, 1.0)    # Purple
		SpellTier.TIER_5:
			return Color(1.0, 0.6, 0.05, 1.0)   # Orange
		_:
			return Color(0.9, 0.9, 0.9, 1.0)    # White

func get_min_damage() -> int:
	if min_damage >= 0:
		return max(0, min_damage)
	return 0

func get_max_damage() -> int:
	var resolved_min := get_min_damage()
	if max_damage >= 0:
		return max(resolved_min, max_damage)
	return resolved_min

func has_damage() -> bool:
	return get_max_damage() > 0

func get_attack_count() -> int:
	return maxi(1, attack_count)

func roll_damage() -> int:
	var low := get_min_damage()
	var high := get_max_damage()
	if high <= low:
		return low
	return randi_range(low, high)
