extends Label


func _ready() -> void:
	text = str(RunData.coins) + " Lirah"
	RunData.coins_changed.connect(_on_coins_changed)


func _on_coins_changed(new_amount):
	text = str(new_amount) + " Lirah"
