extends Node

signal gold_changed(new_gold: int)

@export var starting_gold: int = 100

## Multiplier applied to a party's combined gold_value when the entire
## party is wiped out (no heroes escape). Rewards fully repelling a wave.
@export var full_wipe_bonus_ratio: float = 0.5

var gold: int = 0


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


## Awards gold for the damage a single hero took over a run, scaled
## against their effective max health (base max health plus any healing
## received). Killing a hero outright earns their full gold_value; a
## hero that escapes with some damage taken still earns partial credit.
## Damage dealt BY heroes (killing monsters, clearing rooms) never earns
## gold - only damage TAKEN by heroes does.
func award_hero_damage_gold(hero: CombatEntity, hero_data: HeroData) -> void:

	if hero_data == null:
		return

	var effective_max: int = hero.effective_max_health()

	if effective_max <= 0:
		return

	var ratio: float = clampf(float(hero.damage_taken) / float(effective_max), 0.0, 1.0)
	var earned: int = int(round(hero_data.gold_value * ratio))

	if earned > 0:
		add_gold(earned)


## Awards a bonus when an entire hero party is wiped out with no
## survivors, scaled off the party's combined gold_value.
func award_wipe_bonus(hero_data_list: Array[HeroData]) -> void:

	var total_value: int = 0

	for hero_data: HeroData in hero_data_list:
		if hero_data != null:
			total_value += hero_data.gold_value

	var bonus: int = int(round(total_value * full_wipe_bonus_ratio))

	if bonus > 0:
		add_gold(bonus)
