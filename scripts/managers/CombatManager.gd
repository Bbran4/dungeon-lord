extends Node

## Tick-based group combat with an ability/cooldown system. Each living
## combatant, every tick, checks its own abilities (implicit basic
## attack + any authored specials) for which are off cooldown, and picks
## RANDOMLY among whichever are ready - not priority order, not role
## logic.
##
## AGGRO: monsters target using a per-monster threat table (whoever has
## dealt that monster the most cumulative damage). TAUNT is a HARD
## OVERRIDE on top of that - while a hero's taunt is active, every
## monster's target selection is forced onto the currently-taunting
## hero(s), completely ignoring the threat table, for the ability's
## duration. Heroes still pick a random living monster target for their
## own Attack-type abilities (no hero-side targeting AI yet).
##
## BUFFS (armor bonuses) are applied immediately and tracked for the
## rest of the encounter; anything still active when the encounter ends
## is force-reverted so nothing leaks into the next room.
##
## TAUNTS are tracked the same way, with one extra wrinkle: a taunt must
## be cleared the instant its owner dies, not just when its duration
## expires - otherwise a monster can be left hard-locked onto a dead
## hero. _expire_taunts checks liveness every tick for exactly this
## reason. Dictionary.keys() returns an untyped Array, so iterating it
## with a strictly-typed `for hero: CombatEntity in ...` performs a
## checked cast per element that CRASHES if that element is a genuinely
## freed object - so both taunt-cleanup functions iterate untyped and
## check is_instance_valid() before treating anything as a CombatEntity.
##
## ability_used emits a plain human-readable String (not CombatEntity
## references) every time any actor executes any ability, plus when a
## taunt expires - this is what lets TestHarness (or anything else)
## narrate combat into a log without ever touching a possibly-freed
## entity itself.

signal group_combat_started(heroes: Array[CombatEntity], monsters: Array[CombatEntity])
signal group_combat_finished(heroes_won: bool)
signal ability_used(message: String)

## Simulation clock granularity, not a stat - each combatant's own
## ability cooldowns still determine how often THEY personally act.
const TICK_INTERVAL: float = 0.1

## Chain Heal's secondary targets heal for this fraction of magnitude.
const CHAIN_HEAL_FALLOFF: float = 0.6


func begin_group_combat(heroes: Array[CombatEntity], monsters: Array[CombatEntity]) -> void:

	group_combat_started.emit(heroes, monsters)

	# cooldowns[actor][ability] = remaining seconds. Ability objects are
	# used as dictionary keys directly (by identity), which works fine
	# since each entity's abilities - including its own implicit basic
	# attack instance - are stable resource references for its lifetime.
	var cooldowns: Dictionary = {}

	# threat_table[monster][hero] = cumulative damage dealt. Only
	# monsters get entries - heroes are never aggro targets.
	var threat_table: Dictionary = {}

	# active_taunts[hero] = elapsed_time at which the taunt expires.
	var active_taunts: Dictionary = {}

	# Array of {"entity": CombatEntity, "amount": int, "expires_at": float}
	var active_buffs: Array = []

	var elapsed_time: float = 0.0

	for hero: CombatEntity in heroes:
		cooldowns[hero] = {}

	for monster: CombatEntity in monsters:
		cooldowns[monster] = {}
		threat_table[monster] = {}

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

	var actor_name: String = _describe(actor)

	match ability.ability_type:

		GameEnums.AbilityType.ATTACK:

			var target: CombatEntity = _pick_enemy_target(actor, enemies, threat_table, active_taunts, elapsed_time, is_monster_side)

			if target == null:
				return

			var target_name: String = _describe(target)
			var dealt: int = actor.attack_with_amount(target, ability.magnitude)

			if is_instance_valid(target) and threat_table.has(target):
				var monster_threat: Dictionary = threat_table[target]
				monster_threat[actor] = monster_threat.get(actor, 0.0) + float(dealt)
				threat_table[target] = monster_threat

			var via: String = " (%s)" % ability.ability_name if ability.ability_name != "Attack" else ""
			ability_used.emit("%s attacks %s%s for %d" % [actor_name, target_name, via, dealt])

		GameEnums.AbilityType.HEAL:

			var target: CombatEntity = _pick_ally_target(ability.target_rule, actor, allies)

			if target != null and is_instance_valid(target):
				var target_name: String = _describe(target)
				target.heal(ability.magnitude)
				ability_used.emit("%s casts %s on %s for %d" % [actor_name, ability.ability_name, target_name, ability.magnitude])

		GameEnums.AbilityType.CHAIN_HEAL:

			var living: Array[CombatEntity] = _living_only(allies)

			if living.is_empty():
				return

			living.sort_custom(func(a: CombatEntity, b: CombatEntity) -> bool: return a.current_health < b.current_health)

			var primary_name: String = _describe(living[0])
			living[0].heal(ability.magnitude)

			var extra: int = mini(ability.chain_count, living.size() - 1)
			var extra_names: Array[String] = []

			for i: int in range(1, extra + 1):
				living[i].heal(int(round(ability.magnitude * CHAIN_HEAL_FALLOFF)))
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


## Removes a taunt the instant EITHER its duration has run out OR its
## owner is no longer alive - dying clears the taunt immediately rather
## than waiting for it to time out on its own, which is what left
## monsters hard-locked onto a dead hero before this fix. Iterates
## active_taunts.keys() untyped (see file-level note) since a dead
## hero's key may already be a genuinely freed object. Emits a log line
## either way, distinguishing "faded" (timed out) from "ended" (owner
## died), so it's visible in the log why a taunt stopped.
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
