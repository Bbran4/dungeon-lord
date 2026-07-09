extends Resource
class_name BossPhaseData

## One phase of a BossData's fight. Phase 0 is always active from the
## start of the fight (its health_threshold is ignored - use 1.0 by
## convention). Every later phase triggers the FIRST time the boss's
## health ratio drops to or below health_threshold, in the order
## phases are listed - so list them highest threshold first
## (e.g. 1.0, 0.66, 0.33).

@export var phase_name : String = ""

## Boss current_health / max_health at or below which this phase
## triggers. Ignored for phase 0.
@export_range(0.0, 1.0, 0.01) var health_threshold : float = 1.0

## Replaces the boss's special-ability set for the rest of the fight.
## The boss's basic attack is untouched - see CombatEntity's
## auto-generated basic attack ability.
@export var abilities : Array[AbilityData]

## Spawned once, the instant this phase triggers, and fought alongside
## the boss for the rest of the encounter.
@export var summons : Array[MonsterData]

## Logged when this phase triggers (CombatManager.boss_phase_changed).
## This is the seed of the README's "Bosses as Characters" vision -
## authored flavor text for now, not a reactive system yet.
@export_multiline var announcement : String = ""
