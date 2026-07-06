extends Node

## Tick-based group combat: heroes and monsters each act independently
## once their own attack_speed cooldown elapses, picking a random living
## target on the opposing side. Replaces the old strict 1v1
## attacker/defender alternation - multiple combatants on both sides can
## now be mid-cooldown or acting at roughly the same time, which is the
## foundation later steps (aggro, Tank taunt, spells) build on.

signal group_combat_started(heroes: Array[CombatEntity], monsters: Array[CombatEntity])
signal group_combat_finished(heroes_won: bool)

## Simulation clock granularity, not a stat - each combatant's own
## attack_speed still determines how often THEY personally act.
const TICK_INTERVAL: float = 0.1


func begin_group_combat(heroes: Array[CombatEntity], monsters: Array[CombatEntity]) -> void:

	group_combat_started.emit(heroes, monsters)

	var cooldowns: Dictionary = {}

	for hero: CombatEntity in heroes:
		cooldowns[hero] = 0.0

	for monster: CombatEntity in monsters:
		cooldowns[monster] = 0.0

	while _has_living(heroes) and _has_living(monsters):

		await get_tree().create_timer(TICK_INTERVAL).timeout

		for hero: CombatEntity in heroes:
			# Guard BEFORE the call, not inside it - passing an already
			# freed object into a function whose parameter is typed
			# CombatEntity crashes at the call boundary itself (a live
			# class check on the freed object), rather than failing
			# gracefully the way is_instance_valid() does on its own.
			if is_instance_valid(hero):
				_tick_combatant(hero, monsters, cooldowns)

		for monster: CombatEntity in monsters:
			if is_instance_valid(monster):
				_tick_combatant(monster, heroes, cooldowns)

	group_combat_finished.emit(_has_living(heroes))


func _has_living(group: Array[CombatEntity]) -> bool:

	for entity: CombatEntity in group:
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() and entity.current_health > 0:
			return true

	return false


func _tick_combatant(actor: CombatEntity, enemies: Array[CombatEntity], cooldowns: Dictionary) -> void:

	if actor.is_queued_for_deletion() or actor.current_health <= 0:
		return

	cooldowns[actor] = cooldowns.get(actor, 0.0) - TICK_INTERVAL

	if cooldowns[actor] > 0.0:
		return

	var target: CombatEntity = _pick_random_target(enemies)

	if target == null:
		return

	actor.attack(target)

	var attack_speed: float = actor.attack_speed if actor.attack_speed > 0.0 else 1.0
	cooldowns[actor] = 1.0 / attack_speed


func _pick_random_target(group: Array[CombatEntity]) -> CombatEntity:

	var living: Array[CombatEntity] = []

	for entity: CombatEntity in group:
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() and entity.current_health > 0:
			living.append(entity)

	if living.is_empty():
		return null

	return living[randi() % living.size()]
