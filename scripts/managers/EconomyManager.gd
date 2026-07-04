extends Node

signal gold_changed(new_gold)

@export var starting_gold := 100

var gold := 0


func _ready() -> void:
	reset()


func reset() -> void:
	gold = starting_gold
	gold_changed.emit(gold)


func add_gold(amount: int) -> void:

	gold += amount

	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:

	if gold < amount:
		return false

	gold -= amount

	gold_changed.emit(gold)

	return true


func can_afford(amount: int) -> bool:
	return gold >= amount
