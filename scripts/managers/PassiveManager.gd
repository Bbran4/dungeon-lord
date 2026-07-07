extends Node

## Tracks permanently-owned passive upgrades for the current run (reset
## only by a full TestHarness reset, NOT between waves). Passives are
## purely additive/multiplicative modifiers queried by other systems -
## this autoload never touches gameplay state directly, it just answers
## "what's my current multiplier" questions.

signal passive_applied(passive_data: PassiveData)

var owned_passives: Array[PassiveData] = []


func reset() -> void:
	owned_passives.clear()


func apply_passive(passive_data: PassiveData) -> void:
	owned_passives.append(passive_data)
	passive_applied.emit(passive_data)


func get_gold_multiplier() -> float:
	return 1.0 + _sum_magnitude(GameEnums.PassiveEffectType.GOLD_MULTIPLIER)


func get_trap_damage_multiplier() -> float:
	return 1.0 + _sum_magnitude(GameEnums.PassiveEffectType.TRAP_DAMAGE_MULTIPLIER)


func get_monster_damage_multiplier() -> float:
	return 1.0 + _sum_magnitude(GameEnums.PassiveEffectType.MONSTER_DAMAGE_MULTIPLIER)


func get_monster_health_multiplier() -> float:
	return 1.0 + _sum_magnitude(GameEnums.PassiveEffectType.MONSTER_HEALTH_MULTIPLIER)


## Flat gold amount, not a percentage - see PassiveData.magnitude docs.
func get_reroll_discount() -> float:
	return _sum_magnitude(GameEnums.PassiveEffectType.REROLL_DISCOUNT)


func _sum_magnitude(effect_type: GameEnums.PassiveEffectType) -> float:

	var total: float = 0.0

	for passive: PassiveData in owned_passives:
		if passive.effect_type == effect_type:
			total += passive.magnitude

	return total
