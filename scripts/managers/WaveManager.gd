extends Node

## Tracks wave "tiers" rather than a raw attempt count. A tier only
## advances when the Dungeon Lord fully wipes an incoming hero party -
## no heroes escaping. If any hero escapes, the tier stays the same and
## the next attempt sends a party of the SAME strength again; the
## Dungeon Lord must hold the line before heroes get any stronger.
##
## Hero stats (and gold value) for a given attempt are scaled by
## current_stat_multiplier(), which increases LINEARLY per tier
## survived - 1.0x at tier 0 (no wipes yet), 1.1x after the first full
## wipe, 1.2x after the second, 1.3x after the third, and so on (NOT
## compounding). See Dungeon.send_wave() for where this actually gets
## applied to spawned heroes.

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int, full_wipe: bool)

@export var starting_wave: int = 1

## Stat multiplier increase per tier advanced (0.10 = +10% per tier,
## added linearly - tier 3 is +30%, not +33.1%).
@export var stat_buff_per_wave: float = 0.10

var current_wave: int = 0


func reset() -> void:
	current_wave = starting_wave - 1


## Currently unused by TestHarness (wave advancement is driven entirely
## by combat outcome via complete_wave()) - kept as a manual override
## hook for future use (e.g. a card effect that skips a tier).
func start_next_wave() -> void:
	current_wave += 1
	wave_started.emit(current_wave)


## full_wipe: whether the Dungeon Lord fully wiped the incoming party
## (no heroes escaped). The tier ONLY advances when full_wipe is true -
## this is what "waves restart until defeated, then spawn stronger"
## actually means mechanically.
func complete_wave(full_wipe: bool) -> void:

	if full_wipe:
		current_wave += 1

	wave_completed.emit(current_wave, full_wipe)


## Current stat multiplier heroes (and their gold_value) should be
## scaled by for the NEXT wave sent. 1.0 until the first full wipe, then
## +stat_buff_per_wave per tier survived after that, added linearly:
## 1.0, 1.1, 1.2, 1.3, ...
func current_stat_multiplier() -> float:
	return 1.0 + stat_buff_per_wave * float(current_wave)
