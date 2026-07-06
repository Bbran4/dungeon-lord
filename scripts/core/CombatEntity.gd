extends Node2D
class_name CombatEntity

signal health_changed(current_health: int)
signal died(entity: CombatEntity)

@export var max_health: int = 10
@export var damage: int = 2
@export var armor: int = 0
@export var attack_speed: float = 1.0

var current_health: int = 0

## Cumulative raw damage this entity has taken (post-armor), across its
## whole lifetime. Used by EconomyManager to reward damage dealt to
## heroes rather than requiring a kill.
var damage_taken: int = 0

## Cumulative healing this entity has received. Added to max_health when
## computing effective max health, so a hero that gets healed mid-run
## doesn't let attackers earn more than 100% gold credit against them.
var healing_received: int = 0


func _ready() -> void:
	current_health = max_health


## Sets stats and resets current_health accordingly. Safe to call before
## or after the node enters the tree.
func configure(new_max_health: int, new_damage: int, new_armor: int) -> void:
	max_health = new_max_health
	damage = new_damage
	armor = new_armor
	current_health = max_health
	damage_taken = 0
	healing_received = 0


func attack(target: CombatEntity) -> void:
	if target:
		target.take_damage(damage)


func take_damage(amount: int) -> void:
	amount = max(1, amount - armor)

	current_health -= amount
	damage_taken += amount

	health_changed.emit(current_health)

	if current_health <= 0:
		die()


## Restores health (capped at max_health) and records the amount healed.
## No ability calls this yet - it exists so future Healer behavior can
## hook in without touching the gold-reward math later.
func heal(amount: int) -> void:
	if amount <= 0:
		return

	healing_received += amount
	current_health = mini(current_health + amount, max_health)

	health_changed.emit(current_health)


## Base max health plus all healing received - the total health pool an
## attacker actually had to overcome to defeat this entity.
func effective_max_health() -> int:
	return max_health + healing_received


func die() -> void:
	died.emit(self)
	queue_free()
