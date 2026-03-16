class_name CombatAttack
extends Resource

@export var attack_name: String = "Attack"
@export var damage: int = 0
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export var sfx: AudioStream
@export var vfx_scene: PackedScene
@export var vfx_offset: Vector2 = Vector2.ZERO
@export_range(0.0, 30.0, 0.1) var vfx_lifetime: float = 1.5
