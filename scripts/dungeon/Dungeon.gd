extends Node2D
class_name Dungeon

## Moves a whole hero party together through the dungeon's room sequence
## and resolves each room as a GROUP encounter (all living party members
## vs. all of a room's monsters at once via CombatManager.
## begin_group_combat), rather than each hero running the dungeon solo.
## This is what makes party mechanics meaningful - a Tank, Healer, etc.
## can only matter to "the party" if the party is actually fighting
## together in the same room at the same time.
##
## Expects a child node named "DungeonGrid" positioned at local origin,
## since waypoint coordinates from DungeonGrid are used directly as
## this node's children's local positions.
##
## Active hero tracking is delegated to HeroManager (spawn_hero/
## remove_hero/active_heroes) as before. Internally, Dungeon also keeps
## its own small per-wave roster (_party) pairing each hero's
## CombatEntity with its HeroData and a "resolved" flag, so gold can be
## awarded exactly once per hero whether they die mid-run or escape at
## the end.
##
## A room may carry a trap, a monster group, or both. Traps resolve
## first, individually per living hero - a single probabilistic damage
## instance with no counter-attack, no CombatManager involvement. Room
## monsters resolve as a single group encounter for whoever in the party
## is still alive; a room can field more than one monster via
## RoomData.monster_count (e.g. a Skeleton Den fielding 3 Skeletons).
##
## Gold is awarded per-hero, once, at the moment they're resolved
## (killed or escaped), via EconomyManager.award_hero_damage_gold(). If
## every hero in the wave dies with none escaping,
## EconomyManager.award_wipe_bonus() also fires once the wave finishes.

signal hero_escaped(hero: CombatEntity)
signal trap_triggered(hero: CombatEntity, trap_data: TrapData)
signal wave_cleared

@onready var dungeon_grid: DungeonGrid = $DungeonGrid

@export var hero_scene: PackedScene
@export var move_speed: float = 200.0

## Vertical spacing (px) between party members so they don't fully
## overlap visually while moving and fighting as a group.
@export var party_spread: float = 30.0

var _heroes_escaped_count: int = 0
var _heroes_died_count: int = 0
var _current_wave_hero_data: Array[HeroData] = []

## Each entry: {"entity": CombatEntity, "data": HeroData,
## "offset_y": float, "resolved": bool}
var _party: Array[Dictionary] = []


func send_wave(hero_data_list: Array[HeroData]) -> void:

	# Safety net: clears out any stale entries if a previous wave was
	# interrupted (e.g. a mid-combat reset) before it fully resolved.
	HeroManager.clear_heroes()

	_heroes_escaped_count = 0
	_heroes_died_count = 0
	_current_wave_hero_data = hero_data_list.duplicate()
	_party.clear()

	var count: int = hero_data_list.size()

	for i: int in count:

		var hero_data: HeroData = hero_data_list[i]
		var hero: CombatEntity = HeroManager.spawn_hero(hero_scene, self) as CombatEntity
		hero.configure(hero_data.max_health, hero_data.damage, hero_data.armor)
		hero.name = "Hero_%s" % hero_data.hero_name

		var offset_y: float = (i - (count - 1) / 2.0) * party_spread
		hero.position = Vector2(0, offset_y)

		_party.append({
			"entity": hero,
			"data": hero_data,
			"offset_y": offset_y,
			"resolved": false,
		})

	_run_party()


func _run_party() -> void:

	var waypoints: Array[Vector2] = dungeon_grid.get_path_waypoints()

	for i: int in waypoints.size():

		if _living_party_entities().is_empty():
			return

		await _move_party_to(waypoints[i])

		var room_data: RoomData = dungeon_grid.get_room_data_at_path_index(i)

		if room_data != null and room_data.trap != null:
			for member: Dictionary in _party:
				_resolve_trap_for_member(member, room_data.trap)

		if _living_party_entities().is_empty():
			_finish_wave()
			return

		if room_data != null and room_data.monster != null:

			var living_heroes: Array[CombatEntity] = _living_party_entities()
			var monsters: Array[CombatEntity] = _spawn_monster_group(room_data, waypoints[i])

			await CombatManager.begin_group_combat(living_heroes, monsters)

			for monster: CombatEntity in monsters:
				if is_instance_valid(monster):
					monster.queue_free()

			_resolve_dead_party_members()

			if _living_party_entities().is_empty():
				_finish_wave()
				return

	_resolve_escaped_party()


func _living_party_entities() -> Array[CombatEntity]:

	var living: Array[CombatEntity] = []

	for member: Dictionary in _party:
		if _is_alive(member["entity"]):
			living.append(member["entity"])

	return living


## True only if the entity is both a valid instance and not already
## scheduled for deletion (queue_free() defers the actual free, so
## is_instance_valid() alone can report true for a frame after death).
func _is_alive(entity: CombatEntity) -> bool:
	return is_instance_valid(entity) and not entity.is_queued_for_deletion()


func _move_party_to(waypoint: Vector2) -> void:

	var tweens: Array[Tween] = []

	for member: Dictionary in _party:

		var hero: CombatEntity = member["entity"]

		if not _is_alive(hero):
			continue

		var target: Vector2 = waypoint + Vector2(0, member["offset_y"])
		var distance: float = hero.position.distance_to(target)
		var duration: float = distance / move_speed if move_speed > 0.0 else 0.0

		if duration <= 0.0:
			hero.position = target
			continue

		var tween: Tween = create_tween()
		tween.tween_property(hero, "position", target, duration)
		tweens.append(tween)

	for tween: Tween in tweens:
		await tween.finished


func _spawn_monster_group(room_data: RoomData, at_position: Vector2) -> Array[CombatEntity]:

	var monsters: Array[CombatEntity] = []
	var count: int = maxi(1, room_data.monster_count)

	for i: int in count:

		var monster: CombatEntity = CombatEntity.new()
		monster.name = "Monster_%s_%d" % [room_data.monster.monster_name, i + 1]

		add_child(monster)
		monster.configure(room_data.monster.max_health, room_data.monster.damage, room_data.monster.armor)
		monster.position = at_position + Vector2(0, (i - (count - 1) / 2.0) * 40.0)

		monsters.append(monster)

	return monsters


## Single probabilistic damage instance - no counter-attack, no spawned
## entity, no CombatManager. A miss (roll above trigger_chance) does
## nothing at all. Damage still flows through CombatEntity.take_damage
## so it counts toward damage_taken (and therefore gold) exactly like
## damage from monster combat.
func _resolve_trap_for_member(member: Dictionary, trap_data: TrapData) -> void:

	var hero: CombatEntity = member["entity"]

	if not _is_alive(hero):
		return

	if randf() > trap_data.trigger_chance:
		return

	hero.take_damage(trap_data.damage, trap_data.ignores_armor)
	trap_triggered.emit(hero, trap_data)

	if not _is_alive(hero):
		_handle_hero_death(member)


func _resolve_dead_party_members() -> void:

	for member: Dictionary in _party:
		if not member["resolved"] and not _is_alive(member["entity"]):
			_handle_hero_death(member)


## Hero already freed itself via CombatEntity.die() -> queue_free() by
## the time this runs. HeroManager.remove_hero() only updates tracking
## (it does NOT call queue_free()), so this is safe to call on an
## already-dying hero - see the double-free note in HeroManager.gd.
func _handle_hero_death(member: Dictionary) -> void:

	if member["resolved"]:
		return

	member["resolved"] = true

	var hero: CombatEntity = member["entity"]
	var hero_data: HeroData = member["data"]

	EconomyManager.award_hero_damage_gold(hero, hero_data)
	HeroManager.remove_hero(hero)
	_heroes_died_count += 1


func _resolve_escaped_party() -> void:

	for member: Dictionary in _party:

		if member["resolved"]:
			continue

		member["resolved"] = true

		var hero: CombatEntity = member["entity"]
		var hero_data: HeroData = member["data"]

		EconomyManager.award_hero_damage_gold(hero, hero_data)
		HeroManager.remove_hero(hero)
		_heroes_escaped_count += 1
		hero_escaped.emit(hero)
		hero.queue_free()

	_finish_wave()


func _finish_wave() -> void:

	# Defensive: catches any member neither explicitly resolved as dead
	# nor as escaped (shouldn't happen given the call sites above).
	for member: Dictionary in _party:
		if not member["resolved"]:
			_handle_hero_death(member)

	if _heroes_escaped_count == 0 and _heroes_died_count > 0:
		EconomyManager.award_wipe_bonus(_current_wave_hero_data)

	wave_cleared.emit()
