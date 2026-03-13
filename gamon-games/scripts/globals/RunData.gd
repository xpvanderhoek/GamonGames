extends Node

var random_seed : int = 0
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

var coins : int = 0:
    set(value):
        coins = value
        coins_changed.emit()

var current_hp : int = 0:
    set(value):
        current_hp = value
        hp_changed.emit()

var current_corruption : int = 0:
    set(value):
        current_corruption = value
        corruption_changed.emit()

var entered_rooms : Array = []
var buffs : Array = []

signal coins_changed(new_amount)
signal hp_changed(new_amount)
signal corruption_changed(new_amount)

func new_run():
    
    random_seed = randi()
    rng.seed = random_seed
    coins = 100
    entered_rooms.clear()
    buffs.clear()
    current_hp = 100
    current_corruption = 10

func add_buff(buff : Resource):
    buffs.append(buff)



