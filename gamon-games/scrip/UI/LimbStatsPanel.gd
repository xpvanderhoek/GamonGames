extends Panel

@onready var lbl_name = $VBoxContainer/LabelName
@onready var lbl_hp = $VBoxContainer/LabelHP
@onready var lbl_hit = $VBoxContainer/LabelHitChance

func show_limb_stats(limb: CombatLimb) -> void:
	lbl_name.text = limb.limb_name
	lbl_hp.text = "%d / %d" % [limb.current_health, limb.max_health]
	lbl_hit.text = "%.1f%%" % limb.hit_chance_percent
	visible = true

func hide_panel() -> void:
	visible = false
