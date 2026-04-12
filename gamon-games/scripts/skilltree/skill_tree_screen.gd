extends Control

@onready var marrow_shards_label: Label = $Marrow_Shards_label

func _ready() -> void:
	_update_marrow_shards_label()
	RunData.marrow_shards_changed.connect(_update_marrow_shards_label)

func _process(_delta: float) -> void:
	pass

func _update_marrow_shards_label() -> void:
	marrow_shards_label.text = "Marrow shards:\n%d"%RunData.marrow_shards
