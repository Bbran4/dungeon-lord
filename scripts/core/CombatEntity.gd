extends Node2D
class_name CombatEntity

signal health_changed(current_health)
signal died(entity)

@export var max_health: int = 10
@export var damage: int = 2
@export var armor: int = 0
@export var attack_speed: float = 1.0

var current_health: int


func _ready() -> void:
	current_health = max_health


func attack(target: CombatEntity) -> void:
	if target:
		target.take_damage(damage)


func take_damage(amount: int) -> void:
	amount = max(1, amount - armor)

	current_health -= amount

	health_changed.emit(current_health)

	if current_health <= 0:
		die()


func die() -> void:
	died.emit(self)
	queue_free()
