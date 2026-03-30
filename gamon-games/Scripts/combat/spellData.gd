class_name SpellData
extends Resource

enum SpellType {
	ATTACK,
	BUFF,
	DEBUFF,
	HEAL,
}

enum TargetScope {
	LIMB,
	WHOLE_ENEMY,
}

enum VfxAnchor {
	PLAYER,
	ENEMY,
	SCREEN_CENTER,
}

@export var spell_id: String = ""
@export var spell_name: String = "Attack"
@export var spell_type: SpellType = SpellType.ATTACK
@export var target_scope: TargetScope = TargetScope.LIMB
@export var damage: int = 0
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export var icon: Texture2D

@export_category("VFX-SFX")
@export var sfx: AudioStream
@export var vfx_scene: PackedScene
@export var vfx_anchor: VfxAnchor = VfxAnchor.PLAYER
@export var vfx_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 30.0, 0.1) var vfx_lifetime: float = 1.5

@export_category("Buff-Debuff Modifiers")
@export_range(1, 10, 1) var duration_rounds: int = 1
@export var outgoing_damage_flat_bonus: int = 0
@export_range(-0.95, 3.0, 0.01) var outgoing_damage_multiplier_delta: float = 0.0
@export_range(-0.95, 3.0, 0.01) var incoming_damage_multiplier_delta: float = 0.0
@export var heal_amount: int = 0

