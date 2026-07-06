extends Node

## Tick-based group combat: heroes and monsters each act independently
## once their own attack_speed cooldown elapses.
##
## Heroes currently pick a random living monster to attack - player-
## facing hero targeting (Rogue backstab targeting, Mage picking a
## priority target, etc.) is future work once ability kits exist.
##
## Monsters pick their target using a per-monster THREAT TABLE: whoever
## has dealt that specific monster the most cumulative damage is who it
## attacks, WoW-style. A monster with an empty table (nobody's hit it
## yet) falls back to a random living hero - "first pull."
##
## NOTE: this is aggro-by-damage-dealt only. It does NOT yet include a
## Tank's taunt/self-buff (an explicit threat-table-topping effect) -
## that needs the ability/cooldown system (a later step). Right now a
## Tank only draws aggro if they happen to be the one landing hits on a
## given monster, same as anyone else.

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

	# threat_table[monster] = { hero: accumulated_damage_dealt_to_monster }
	var threat_table: Dictionary = {}

	for monster: CombatEntity in monsters:
		cooldowns[monster] = 0.0
		threat_table[monster] = {}

	while _has_living(heroes) and _has_living(monsters):

		await get_tree().create_timer(TICK_INTERVAL).timeout

		for hero: CombatEntity in heroes:
			if is_instance_valid(hero):
				_tick_hero(hero, monsters, cooldowns, threat_table)

		for monster: CombatEntity in monsters:
			if is_instance_valid(monster):
				_tick_monster(monster, heroes, cooldowns, threat_table)

	group_combat_finished.emit(_has_living(heroes))


func _has_living(group: Array[CombatEntity]) -> bool:

	for entity: CombatEntity in group:
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() and entity.current_health > 0:
			return true

	return false


func _tick_hero(hero: CombatEntity, monsters: Array[CombatEntity], cooldowns: Dictionary, threat_table: Dictionary) -> void:

	if hero.is_queued_for_deletion() or hero.current_health <= 0:
		return

	cooldowns[hero] = cooldowns.get(hero, 0.0) - TICK_INTERVAL

	if cooldowns[hero] > 0.0:
		return

	var target: CombatEntity = _pick_random_target(monsters)

	if target == null:
		return

	var dealt: int = hero.attack(target)

	if is_instance_valid(target) and threat_table.has(target):
		var monster_threat: Dictionary = threat_table[target]
		monster_threat[hero] = monster_threat.get(hero, 0.0) + float(dealt)

	var attack_speed: float = hero.attack_speed if hero.attack_speed > 0.0 else 1.0
	cooldowns[hero] = 1.0 / attack_speed


func _tick_monster(monster: CombatEntity, heroes: Array[CombatEntity], cooldowns: Dictionary, threat_table: Dictionary) -> void:

	if monster.is_queued_for_deletion() or monster.current_health <= 0:
		return

	cooldowns[monster] = cooldowns.get(monster, 0.0) - TICK_INTERVAL

	if cooldowns[monster] > 0.0:
		return

	var target: CombatEntity = _pick_highest_threat_target(monster, heroes, threat_table)

	if target == null:
		return

	monster.attack(target)

	var attack_speed: float = monster.attack_speed if monster.attack_speed > 0.0 else 1.0
	cooldowns[monster] = 1.0 / attack_speed


func _pick_random_target(group: Array[CombatEntity]) -> CombatEntity:

	var living: Array[CombatEntity] = _living_only(group)

	if living.is_empty():
		return null

	return living[randi() % living.size()]


## Highest-threat living hero on this monster's table. Falls back to a
## random living hero if the table is empty or every living hero on it
## still has zero threat (nobody's landed a hit on this monster yet).
func _pick_highest_threat_target(monster: CombatEntity, heroes: Array[CombatEntity], threat_table: Dictionary) -> CombatEntity:

	var living: Array[CombatEntity] = _living_only(heroes)

	if living.is_empty():
		return null

	var monster_threat: Dictionary = threat_table.get(monster, {})

	var best_target: CombatEntity = null
	var best_threat: float = -1.0

	for hero: CombatEntity in living:

		var threat: float = monster_threat.get(hero, 0.0)

		if threat > best_threat:
			best_threat = threat
			best_target = hero

	if best_target == null or best_threat <= 0.0:
		return living[randi() % living.size()]

	return best_target


func _living_only(group: Array[CombatEntity]) -> Array[CombatEntity]:

	var living: Array[CombatEntity] = []

	for entity: CombatEntity in group:
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() and entity.current_health > 0:
			living.append(entity)

	return living
