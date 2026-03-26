class_name SpellData
extends Resource

enum VfxAnchor {
	PLAYER,
	ENEMY,
	SCREEN_CENTER,
}

@export var attack_name: String = "Attack"
@export var damage: int = 0
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0

@export var spell_id: String = ""
@export var spell_name: String = "Attack"
@export var icon: Texture2D
@export var attack_power: int = 0

@export var sfx: AudioStream
@export var vfx_scene: PackedScene
@export var vfx_anchor: VfxAnchor = VfxAnchor.PLAYER
@export var vfx_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 30.0, 0.1) var vfx_lifetime: float = 1.5