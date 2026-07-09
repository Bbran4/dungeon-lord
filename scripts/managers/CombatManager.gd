extends Node

## Tick-based group combat with an ability/cooldown system.
##
## ABILITY TYPES: ATTACK (single-target instant hit), DOT_ATTACK (single
## initial hit + a fire-and-forget ticking DoT afterward, e.g. poison),
## CHAIN_ATTACK (a primary target plus chain_count additional random
## living enemies at reduced damage, e.g. Chain Lightning), HEAL,
## CHAIN_HEAL, BUFF, and TAUNT (all ally/self-targeted "support" types,
## handled by _execute_support_ability).
##
## OPENING ACTIONS: the instant combat begins (elapsed_time = 0), every
## living actor gets ONE chance to fire a ready SUPPORT ability (Heal/
## ChainHeal/Buff/Taunt) via _perform_opening_actions - the "party stops
## in formation and applies buffs, then the fight begins" beat. Attack-
## type abilities (Attack/DotAttack/ChainAttack) never fire here; only
## the normal per-tick loop uses those.
##
## AGGRO: monsters target using a per-monster threat table (whoever has
## dealt that monster the most cumulative damage, including DoT ticks
## and chain-attack splash). TAUNT is a HARD OVERRIDE on top of that -
## while a hero's taunt is active, every monster's target selection is
## forced onto the currently-taunting hero(s), completely ignoring the
## threat table, for the ability's duration.
##
## BUFFS (armor bonuses) are applied immediately and tracked for the
## rest of the encounter; anything still active when the encounter ends
## is force-reverted so nothing leaks into the next room.
##
## TAUNTS are cleared the instant their owner dies, not just when their
## duration expires. Dictionary.keys() returns an untyped Array, so
## iterating it with a strictly-typed `for hero: CombatEntity in ...`
## crashes if an element is a genuinely freed object - both taunt
## functions iterate untyped and check is_instance_valid() first.
##
## ability_used emits a plain human-readable String (not CombatEntity
## references) every time any actor executes any ability, plus when a
## taunt expires - lets TestHarness narrate combat into a log without
## ever touching a possibly-freed entity itself.

signal group_combat_started(heroes: Array[CombatEntity], monsters: Array[CombatEntity])
signal group_combat_finished(heroes_won: bool)
signal ability_used(message: String)
signal boss_phase_changed(boss: CombatEntity, boss_data: BossData, phase_index: int)
signal boss_phase_summon_requested(phase: BossPhaseData, boss: CombatEntity, monster_group: Array[CombatEntity])

## Simulation clock granularity, not a stat - each combatant's own
## ability cooldowns still determine how often THEY personally act.
const TICK_INTERVAL: float = 0.1

## Chain Heal's / Chain Attack's secondary targets are affected at this
## fraction of magnitude.
const CHAIN_HEAL_FALLOFF: float = 0.6
const CHAIN_ATTACK_FALLOFF: float = 0.6


func begin_group_combat(heroes: Array[CombatEntity], monsters: Array[CombatEntity]) -> void:

	group_combat_started.emit(heroes, monsters)

	var cooldowns: Dictionary = {}
	var threat_table: Dictionary = {}
	var active_taunts: Dictionary = {}
	var active_buffs: Array = []
	var elapsed_time: float = 0.0

	for hero: CombatEntity in heroes:
		cooldowns[hero] = {}

	for monster: CombatEntity in monsters:
		cooldowns[monster] = {}
		threat_table[monster] = {}

	# Opening beat: "stop in formation and apply buffs" before the fight
	# begins. Only ever touches support (non-attack) abilities.
	_perform_opening_actions(heroes, cooldowns, active_taunts, active_buffs, elapsed_time)
	_perform_opening_actions(monsters, cooldowns, active_taunts, active_buffs, elapsed_time)

	while _has_living(heroes) and _has_living(monsters):

		await get_tree().create_timer(TICK_INTERVAL).timeout
		elapsed_time += TICK_INTERVAL

		_expire_buffs(active_buffs, elapsed_time)
		_expire_taunts(active_taunts, elapsed_time)

		for hero: CombatEntity in heroes:
			if is_instance_valid(hero):
				_tick_actor(hero, heroes, monsters, cooldowns, threat_table, active_taunts, active_buffs, elapsed_time, false)

		for monster: CombatEntity in monsters:
			if is_instance_valid(monster):
				_tick_actor(monster, monsters, heroes, cooldowns, threat_table, active_taunts, active_buffs, elapsed_time, true)

	_revert_all_buffs(active_buffs)
	_revert_all_taunts(active_taunts)

	group_combat_finished.emit(_has_living(heroes))


func _has_living(group: Array[CombatEntity]) -> bool:

	for entity: CombatEntity in group:
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() and entity.current_health > 0:
			return true

	return false


func _living_only(group: Array[CombatEntity]) -> Array[CombatEntity]:

	var living: Array[CombatEntity] = []

	for entity: CombatEntity in group:
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() and entity.current_health > 0:
			living.append(entity)

	return living


## Safe to call on anything, including a possibly-freed reference -
## never touches .name unless is_instance_valid() confirms it's safe.
func _describe(entity: Variant) -> String:
	if entity != null and is_instance_valid(entity):
		return entity.name
	return "???"


func _is_support_type(ability_type: GameEnums.AbilityType) -> bool:
	return ability_type != GameEnums.AbilityType.ATTACK \
		and ability_type != GameEnums.AbilityType.DOT_ATTACK \
		and ability_type != GameEnums.AbilityType.CHAIN_ATTACK


## Runs once, immediately, right when combat begins (elapsed_time = 0)
## - before the main random-tick loop. Each living actor in `group` gets
## ONE chance to fire a ready SUPPORT ability (Heal/ChainHeal/Buff/
## Taunt) as an opening beat. Never touches Attack/DotAttack/
## ChainAttack - those only ever fire from the normal tick loop.
func _perform_opening_actions(group: Array[CombatEntity], cooldowns: Dictionary, active_taunts: Dictionary, active_buffs: Array, elapsed_time: float) -> void:

	for actor: CombatEntity in group:

		if not is_instance_valid(actor) or actor.is_queued_for_deletion() or actor.current_health <= 0:
			continue

		var actor_cooldowns: Dictionary = cooldowns.get(actor, {})

		for ability: AbilityData in actor.get_combat_abilities():

			if not _is_support_type(ability.ability_type):
				continue

			var remaining: float = actor_cooldowns.get(ability, 0.0)

			if remaining > 0.0:
				continue

			_execute_support_ability(actor, ability, group, active_taunts, active_buffs, elapsed_time)
			actor_cooldowns[ability] = ability.cooldown
			cooldowns[actor] = actor_cooldowns
			break


func _tick_actor(
	actor: CombatEntity,
	allies: Array[CombatEntity],
	enemies: Array[CombatEntity],
	cooldowns: Dictionary,
	threat_table: Dictionary,
	active_taunts: Dictionary,
	active_buffs: Array,
	elapsed_time: float,
	is_monster_side: bool
) -> void:

	if actor.is_queued_for_deletion() or actor.current_health <= 0:
		return

	var actor_cooldowns: Dictionary = cooldowns.get(actor, {})

	for ability: AbilityData in actor_cooldowns.keys():
		actor_cooldowns[ability] = actor_cooldowns[ability] - TICK_INTERVAL

	var ready: Array[AbilityData] = []

	for ability: AbilityData in actor.get_combat_abilities():
		var remaining: float = actor_cooldowns.get(ability, 0.0)
		if remaining <= 0.0:
			ready.append(ability)

	if ready.is_empty():
		cooldowns[actor] = actor_cooldowns
		return

	var chosen: AbilityData = ready[randi() % ready.size()]

	_execute_ability(actor, chosen, allies, enemies, threat_table, active_taunts, active_buffs, elapsed_time, is_monster_side)

	actor_cooldowns[chosen] = chosen.cooldown
	cooldowns[actor] = actor_cooldowns


func _execute_ability(
	actor: CombatEntity,
	ability: AbilityData,
	allies: Array[CombatEntity],
	enemies: Array[CombatEntity],
	threat_table: Dictionary,
	active_taunts: Dictionary,
	active_buffs: Array,
	elapsed_time: float,
	is_monster_side: bool
) -> void:

	match ability.ability_type:

		GameEnums.AbilityType.ATTACK:
			_execute_attack(actor, ability, enemies, threat_table, active_taunts, elapsed_time, is_monster_side)

		GameEnums.AbilityType.DOT_ATTACK:
			_execute_dot_attack(actor, ability, enemies, threat_table, active_taunts, elapsed_time, is_monster_side)

		GameEnums.AbilityType.CHAIN_ATTACK:
			_execute_chain_attack(actor, ability, enemies, threat_table, active_taunts, elapsed_time, is_monster_side)

		_:
			_execute_support_ability(actor, ability, allies, active_taunts, active_buffs, elapsed_time)


func _execute_attack(
	actor: CombatEntity,
	ability: AbilityData,
	enemies: Array[CombatEntity],
	threat_table: Dictionary,
	active_taunts: Dictionary,
	elapsed_time: float,
	is_monster_side: bool
) -> void:

	var target: CombatEntity = _pick_enemy_target(actor, enemies, threat_table, active_taunts, elapsed_time, is_monster_side)

	if target == null:
		return

	var actor_name: String = _describe(actor)
	var target_name: String = _describe(target)
	var dealt: int = actor.attack_with_amount(target, ability.magnitude, ability.ignore_armor)

	_add_threat(threat_table, target, actor, dealt)

	var via: String = " (%s)" % ability.ability_name if ability.ability_name != "Attack" else ""
	ability_used.emit("%s attacks %s%s for %d" % [actor_name, target_name, via, dealt])


## Initial hit, then kicks off a fire-and-forget DoT tick loop
## (_apply_ability_dot) that keeps running even after this encounter
## ends - matching how PoisonArrowTrapController's DoT already behaves,
## since poison lingers regardless of what room the party is in next.
func _execute_dot_attack(
	actor: CombatEntity,
	ability: AbilityData,
	enemies: Array[CombatEntity],
	threat_table: Dictionary,
	active_taunts: Dictionary,
	elapsed_time: float,
	is_monster_side: bool
) -> void:

	var target: CombatEntity = _pick_enemy_target(actor, enemies, threat_table, active_taunts, elapsed_time, is_monster_side)

	if target == null:
		return

	var actor_name: String = _describe(actor)
	var target_name: String = _describe(target)
	var dealt: int = actor.attack_with_amount(target, ability.magnitude, ability.ignore_armor)

	_add_threat(threat_table, target, actor, dealt)

	ability_used.emit("%s hits %s with %s for %d (poisoned)" % [actor_name, target_name, ability.ability_name, dealt])

	_apply_ability_dot(actor, target, ability, threat_table)


## Fire-and-forget - called without `await` from _execute_dot_attack,
## same pattern PoisonArrowTrapController already uses for its own DoT.
func _apply_ability_dot(actor: CombatEntity, target: CombatEntity, ability: AbilityData, threat_table: Dictionary) -> void:

	for i: int in ability.tick_count:

		await get_tree().create_timer(ability.tick_interval).timeout

		if not is_instance_valid(target) or target.is_queued_for_deletion() or target.current_health <= 0:
			return

		var tick_dealt: int = target.take_damage(ability.tick_damage, ability.ignore_armor)

		if is_instance_valid(actor):
			_add_threat(threat_table, target, actor, tick_dealt)


## Primary target plus chain_count additional random LIVING enemies
## (distinct from the primary), each at CHAIN_ATTACK_FALLOFF damage.
func _execute_chain_attack(
	actor: CombatEntity,
	ability: AbilityData,
	enemies: Array[CombatEntity],
	threat_table: Dictionary,
	active_taunts: Dictionary,
	elapsed_time: float,
	is_monster_side: bool
) -> void:

	var primary: CombatEntity = _pick_enemy_target(actor, enemies, threat_table, active_taunts, elapsed_time, is_monster_side)

	if primary == null:
		return

	var chain_pool: Array[CombatEntity] = _living_only(enemies)
	chain_pool.erase(primary)
	chain_pool.shuffle()

	var extra_count: int = mini(ability.chain_count, chain_pool.size())

	var targets: Array[CombatEntity] = [primary]
	for i: int in extra_count:
		targets.append(chain_pool[i])

	var actor_name: String = _describe(actor)
	var hit_names: Array[String] = []

	for i: int in targets.size():

		var target: CombatEntity = targets[i]
		var amount: int = ability.magnitude if i == 0 else int(round(ability.magnitude * CHAIN_ATTACK_FALLOFF))
		var dealt: int = actor.attack_with_amount(target, amount, ability.ignore_armor)

		_add_threat(threat_table, target, actor, dealt)
		hit_names.append(_describe(target))

	ability_used.emit("%s casts %s hitting %s" % [actor_name, ability.ability_name, ", ".join(hit_names)])


func _add_threat(threat_table: Dictionary, target: CombatEntity, actor: CombatEntity, amount: int) -> void:

	if is_instance_valid(target) and threat_table.has(target):
		var monster_threat: Dictionary = threat_table[target]
		monster_threat[actor] = monster_threat.get(actor, 0.0) + float(amount)
		threat_table[target] = monster_threat


## Handles Heal/ChainHeal/Buff/Taunt - the "support" ability types that
## only ever target within `allies`, never an enemy. Shared between the
## main per-tick execution and the opening-actions pass, so a Tank's
## Taunt or a Healer's Heal can fire the instant combat starts, not
## just from a later random roll.
func _execute_support_ability(
	actor: CombatEntity,
	ability: AbilityData,
	allies: Array[CombatEntity],
	active_taunts: Dictionary,
	active_buffs: Array,
	elapsed_time: float
) -> void:

	var actor_name: String = _describe(actor)

	match ability.ability_type:

		GameEnums.AbilityType.HEAL:

			var target: CombatEntity = _pick_ally_target(ability.target_rule, actor, allies)

			if target != null and is_instance_valid(target):
				var target_name: String = _describe(target)
				target.heal(ability.magnitude)
				actor.fire_projectile_to(target)
				ability_used.emit("%s casts %s on %s for %d" % [actor_name, ability.ability_name, target_name, ability.magnitude])

		GameEnums.AbilityType.CHAIN_HEAL:

			var living: Array[CombatEntity] = _living_only(allies)

			if living.is_empty():
				return

			living.sort_custom(func(a: CombatEntity, b: CombatEntity) -> bool: return a.current_health < b.current_health)

			var primary_name: String = _describe(living[0])
			living[0].heal(ability.magnitude)
			actor.fire_projectile_to(living[0])

			var extra: int = mini(ability.chain_count, living.size() - 1)
			var extra_names: Array[String] = []

			for i: int in range(1, extra + 1):
				living[i].heal(int(round(ability.magnitude * CHAIN_HEAL_FALLOFF)))
				actor.fire_projectile_to(living[i])
				extra_names.append(_describe(living[i]))

			var summary: String = primary_name
			if not extra_names.is_empty():
				summary += " + " + ", ".join(extra_names)

			ability_used.emit("%s casts %s on %s" % [actor_name, ability.ability_name, summary])

		GameEnums.AbilityType.BUFF:

			var target: CombatEntity = _pick_ally_target(ability.target_rule, actor, allies)

			if target != null and is_instance_valid(target):
				var target_name: String = _describe(target)
				target.armor += ability.magnitude
				active_buffs.append({
					"entity": target,
					"amount": ability.magnitude,
					"expires_at": elapsed_time + ability.duration,
				})
				ability_used.emit("%s casts %s on %s (+%d armor for %.1fs)" % [actor_name, ability.ability_name, target_name, ability.magnitude, ability.duration])

		GameEnums.AbilityType.TAUNT:

			active_taunts[actor] = elapsed_time + ability.duration
			actor.set_taunting(true)
			ability_used.emit("%s casts %s! (%.1fs)" % [actor_name, ability.ability_name, ability.duration])


## Attack-type target selection: random living monster for heroes;
## for monsters, a taunting hero (hard override) if any is active,
## otherwise whoever tops the monster's own threat table.
func _pick_enemy_target(
	actor: CombatEntity,
	enemies: Array[CombatEntity],
	threat_table: Dictionary,
	active_taunts: Dictionary,
	elapsed_time: float,
	is_monster_side: bool
) -> CombatEntity:

	if not is_monster_side:
		return _pick_random_target(enemies)

	var taunting: Array[CombatEntity] = []

	for hero: CombatEntity in enemies:
		if is_instance_valid(hero) and not hero.is_queued_for_deletion() and hero.current_health > 0:
			if active_taunts.get(hero, -1.0) > elapsed_time:
				taunting.append(hero)

	if not taunting.is_empty():
		return taunting[randi() % taunting.size()]

	return _pick_highest_threat_target(actor, enemies, threat_table)


## Ally-targeted rule for Heal/ChainHeal/Buff/Taunt abilities.
func _pick_ally_target(rule: GameEnums.AbilityTargetRule, actor: CombatEntity, allies: Array[CombatEntity]) -> CombatEntity:

	match rule:

		GameEnums.AbilityTargetRule.LOWEST_HP_ALLY:

			var living: Array[CombatEntity] = _living_only(allies)

			if living.is_empty():
				return null

			living.sort_custom(func(a: CombatEntity, b: CombatEntity) -> bool: return a.current_health < b.current_health)

			return living[0]

		_:
			return actor


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


func _expire_buffs(active_buffs: Array, elapsed_time: float) -> void:

	var remaining: Array = []

	for buff: Dictionary in active_buffs:
		if elapsed_time >= buff["expires_at"]:
			if is_instance_valid(buff["entity"]):
				buff["entity"].armor -= buff["amount"]
		else:
			remaining.append(buff)

	active_buffs.clear()
	active_buffs.append_array(remaining)


func _expire_taunts(active_taunts: Dictionary, elapsed_time: float) -> void:

	var expired: Array = []

	for hero in active_taunts.keys():

		var still_alive: bool = is_instance_valid(hero) and not hero.is_queued_for_deletion() and hero.current_health > 0

		if not still_alive:
			expired.append({"hero": hero, "reason": "died"})
		elif elapsed_time >= active_taunts[hero]:
			expired.append({"hero": hero, "reason": "faded"})

	for entry: Dictionary in expired:

		var hero = entry["hero"]

		active_taunts.erase(hero)

		if is_instance_valid(hero):
			hero.set_taunting(false)
			ability_used.emit("%s's Taunt %s" % [_describe(hero), entry["reason"]])
		else:
			ability_used.emit("A Taunt ended (source died)")


func _revert_all_buffs(active_buffs: Array) -> void:

	for buff: Dictionary in active_buffs:
		if is_instance_valid(buff["entity"]):
			buff["entity"].armor -= buff["amount"]

	active_buffs.clear()


func _revert_all_taunts(active_taunts: Dictionary) -> void:

	for hero in active_taunts.keys():
		if is_instance_valid(hero):
			hero.set_taunting(false)

	active_taunts.clear()

## Boss variant of begin_group_combat(). Same tick loop and the same
## private helpers (_tick_actor, _perform_opening_actions, threat/
## taunt/buff bookkeeping), plus a phase check each tick.
##
## monster_group must be passed in pre-populated with just the boss
## (e.g. [boss]) - it's a live reference, so summons appended to it
## mid-fight (via boss_phase_summon_requested) are picked up by the
## very next tick automatically. The caller (Dungeon._run_boss_encounter)
## owns spawning/freeing every entity that ends up in it.
func begin_boss_combat(heroes: Array[CombatEntity], boss: CombatEntity, boss_data: BossData, monster_group: Array[CombatEntity]) -> void:

	group_combat_started.emit(heroes, monster_group)

	var cooldowns: Dictionary = {}
	var threat_table: Dictionary = {}
	var active_taunts: Dictionary = {}
	var active_buffs: Array = []
	var elapsed_time: float = 0.0

	for hero: CombatEntity in heroes:
		cooldowns[hero] = {}

	for monster: CombatEntity in monster_group:
		cooldowns[monster] = {}
		threat_table[monster] = {}

	# Phase 0 is already active (configured by the caller before this
	# is called) - start scanning from phase 1.
	var next_phase_index: int = 1

	_perform_opening_actions(heroes, cooldowns, active_taunts, active_buffs, elapsed_time)
	_perform_opening_actions(monster_group, cooldowns, active_taunts, active_buffs, elapsed_time)

	while _has_living(heroes) and _has_living(monster_group):

		await get_tree().create_timer(TICK_INTERVAL).timeout
		elapsed_time += TICK_INTERVAL

		_expire_buffs(active_buffs, elapsed_time)
		_expire_taunts(active_taunts, elapsed_time)

		next_phase_index = _check_boss_phase_transition(boss, boss_data, next_phase_index, monster_group, cooldowns, threat_table)

		for hero: CombatEntity in heroes:
			if is_instance_valid(hero):
				_tick_actor(hero, heroes, monster_group, cooldowns, threat_table, active_taunts, active_buffs, elapsed_time, false)

		for monster: CombatEntity in monster_group:
			if is_instance_valid(monster):
				_tick_actor(monster, monster_group, heroes, cooldowns, threat_table, active_taunts, active_buffs, elapsed_time, true)

	_revert_all_buffs(active_buffs)
	_revert_all_taunts(active_taunts)

	group_combat_finished.emit(_has_living(heroes))


## Fires each phase at most once, in array order. Returns the index of
## the next phase still to check, so already-triggered phases aren't
## re-scanned every tick.
func _check_boss_phase_transition(boss: CombatEntity, boss_data: BossData, next_phase_index: int, monster_group: Array[CombatEntity], cooldowns: Dictionary, threat_table: Dictionary) -> int:

	if not is_instance_valid(boss) or boss.current_health <= 0:
		return next_phase_index

	if next_phase_index >= boss_data.phases.size():
		return next_phase_index

	var phase: BossPhaseData = boss_data.phases[next_phase_index]
	var health_ratio: float = float(boss.current_health) / float(boss.max_health)

	if health_ratio > phase.health_threshold:
		return next_phase_index

	boss.abilities = phase.abilities

	boss_phase_changed.emit(boss, boss_data, next_phase_index)
	ability_used.emit("%s: %s" % [_describe(boss), phase.announcement if phase.announcement != "" else "enters a new phase!"])

	if not phase.summons.is_empty():
		boss_phase_summon_requested.emit(phase, boss, monster_group)
		for monster: CombatEntity in monster_group:
			if is_instance_valid(monster) and not cooldowns.has(monster):
				cooldowns[monster] = {}
				threat_table[monster] = {}

	return next_phase_index + 1
