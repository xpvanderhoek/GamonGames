extends Node

signal gold_changed(new_amount)

var gold: int = 100:
    set(value):
        gold = value
        gold_changed.emit(gold)