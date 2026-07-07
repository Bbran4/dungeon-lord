extends Node

## Tracks permanently-owned passive upgrades for the current run (reset
## only by a full TestHarness reset, NOT between waves). Passives are
## purely additive/multiplicative modifiers queried by other systems -
## this autoload never touches gameplay state directly, it just answers
## "what's my current multiplier" questions.
##
## Stacking is ADDITIVE, not compounding: owning two +15% passives of
## the same effect_type gives 1.0 + 0.15 + 0.15 = 1.30, never
## 1.15 * 1.15. See _sum_magnitude.
##
## Some passives cap how many times they can ever be owned
## (PassiveData.max_stacks, 0 = unlimited) - see can_apply/
## get_stack_count. Enforcement of the cap at PURCHASE time is
## ShopManager's job (it calls can_apply before spending gold);
## PassiveManager itself just tracks ownership and answers queries.

signal passive_applied(passive_data: PassiveData)

var owned_passives: Array[PassiveData] = []


func reset() -> void:
	owned_passives.clear()


func apply_passive(passive_data: PassiveData) -> void:
	owned_passives.append(passive_data)
	passive_applied.emit(passive_data)


## How many copies of this exact PassiveData resource are currently
## owned.
func get_stack_count(passive_data: PassiveData) -> int:

	var count: int = 0

	for owned: PassiveData in owned_passives:
		if owned == passive_data:
			count += 1

	return count


## False if this passive has a max_stacks cap and it's already been
## reached. True for unlimited (max_stacks <= 0) passives, or capped
## ones still under their limit.
func can_apply(passive_data: PassiveData) -> bool:

	if passive_data.max_stacks <= 0:
		return true

	return get_stack_count(passive_data) < passive_data.max_stacks


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


## Sums every owned passive's magnitude for a given effect_type and
## returns the RAW SUM - callers add this to 1.0 themselves for
## multiplier-type effects (or use it directly, as get_reroll_discount
## does for the flat-gold effect). Summing rather than multiplying is
## what keeps stacking additive instead of compounding.
func _sum_magnitude(effect_type: GameEnums.PassiveEffectType) -> float:

	var total: float = 0.0

	for passive: PassiveData in owned_passives:
		if passive.effect_type == effect_type:
			total += passive.magnitude

	return total
