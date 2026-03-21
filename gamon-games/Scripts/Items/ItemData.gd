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
@export_enum("None", "Head", "Arm", "Leg", "Torso", "Self", "All Limbs")
var target_limb: String = "None"
@export_enum("Damage", "Precision", "Defense", "Speed", "HP_Max", "Cooldown", "Limb_Repair")
var buff_type: String = "Damage"
@export var buff_value: float = 10.0

@export_group("Status Effects")
@export_enum("None", "Bleed", "Poison", "Decay", "Vulnerable", "Burn", "Invulnerable")
var status_to_apply: String = "None"
