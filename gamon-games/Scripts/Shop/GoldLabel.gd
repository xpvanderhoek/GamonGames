extends Label

func _ready() -> void:
	text = str(CurrenciesManager.gold) + " COINS"
	CurrenciesManager.gold_changed.connect(_on_gold_changed)

func _on_gold_changed(new_amount):
	text = str(new_amount) + " COINS"
