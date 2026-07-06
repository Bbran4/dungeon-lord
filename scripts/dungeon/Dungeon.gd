extends Node2D
class_name Dungeon

## Moves a whole hero party together through the dungeon's room sequence
## and resolves each room as a GROUP encounter via
## CombatManager.begin_group_combat.
##
## Room monsters are spawned up front, all at once, when the wave
## starts - not lazily when the party happens to arrive. Each room's
## monster group sits visibly at that room's position for the whole
## wave (tracked in _room_monsters, keyed by room index) until the
## party reaches it and fights, or the wave ends and any never-reached
## room's monsters are cleaned up. Monsters never move from their room.
##
## Heroes are positioned using a class-based FORMATION rather than
## simple spawn order: Tank at the front (closest to the monster line),
## Ranger/Mage in the middle, Healer at the back, Rogue positioned past
## the monster line entirely (flanking). See _compute_formation_offsets.
## This is purely positional for now - it does not yet affect who
## monsters or heroes target (see CombatManager for threat/aggro).
##
## WAVE SCALING: hero stats (max health, damage, armor, attack speed)
## are scaled by WaveManager.current_stat_multiplier() at spawn time -
## HeroData resources themselves are never mutated, since they're
## shared assets. The multiplier only increases when the Dungeon Lord
## fully wipes a party (see wave_cleared below and WaveManager.gd) -
## escaping heroes send the same-strength party again next time.
##
## Expects a child node named "DungeonGrid" positioned at local origin,
## since waypoint coordinates from DungeonGrid are used directly as
## this node's children's local positions.
##
## Active hero tracking is delegated to HeroManager (spawn_hero/
## remove_hero/active_heroes) as before. Internally, Dungeon also keeps
## its own small per-wave roster (_party) pairing each hero's
## CombatEntity with its HeroData, formation offset, and a "resolved"
## flag, so gold can be awarded exactly once per hero whether they die
## mid-run or escape at the end.
##
## IMPORTANT: member["entity"] can become a genuinely FREED object by
## the time later code reads it back out of _party (combat runs across
## many awaited ticks after a hero dies). Passing a freed reference
## straight into a function/variable typed as CombatEntity crashes at
## the call boundary itself, so every read of member["entity"] here
## goes through _is_alive(), which takes an untyped Variant and checks
## is_instance_valid() BEFORE anything ever touches a CombatEntity-typed
## slot.
##
## A room may carry a trap, a monster group, or both. Traps resolve
## first, individually per living hero - a single probabilistic damage
## instance with no counter-attack, no CombatManager involvement. Room
## monsters resolve as a group encounter for whoever in the party is
## still alive; a room can field more than one monster via
## RoomData.monster_count (e.g. a Skeleton Den fielding 3 Skeletons).
##
## Gold is awarded per-hero, once, at the moment they're resolved
## (killed or escaped), via EconomyManager.award_hero_damage_gold(). If
## every hero in the wave dies with none escaping,
## EconomyManager.award_wipe_bonus() also fires once the wave finishes,
## and wave_cleared reports full_wipe = true so WaveManager can advance
## the difficulty tier.

signal hero_escaped(hero: CombatEntity)
signal trap_triggered(hero: CombatEntity, trap_data: TrapData)
signal wave_cleared(full_wipe: bool)

@onready var dungeon_grid: DungeonGrid = $DungeonGrid

@export var hero_scene: PackedScene
@export var monster_scene: PackedScene
@export var move_speed: float = 200.0

## Forward (x, relative to the party's shared waypoint) offset per
## class_type. Positive = further along the path, i.e. closer to
## whatever the party is about to fight. Rogue sits past the monster
## line entirely (monsters spawn at offset 0 on this axis).
const ROW_OFFSET_X: Dictionary = {
	"Tank": 40.0,
	"Ranger": 0.0,
	"Mage": 0.0,
	"Healer": -40.0,
	"Rogue": 90.0,
}

## Lateral (y) spacing between multiple heroes sharing the same row,
## so e.g. two Tanks don't render stacked exactly on top of each other.
const LANE_SPACING_Y: float = 30.0

var _heroes_escaped_count: int = 0
var _heroes_died_count: int = 0
var _current_wave_hero_data: Array[HeroData] = []

## Each entry: {"entity": Variant (a CombatEntity that may later be
## freed), "data": HeroData, "offset": Vector2, "resolved": bool}
var _party: Array[Dictionary] = []

## room_index (int, matching DungeonManager's room indices) -> Array[CombatEntity].
## Populated all at once at the start of a wave; entries are removed as
## each room is fought, and anything left over is cleaned up when the
## wave ends.
var _room_monsters: Dictionary = {}


func send_wave(hero_data_list: Array[HeroData]) -> void:

	# Safety net: clears out any stale entries if a previous wave was
	# interrupted (e.g. a mid-combat reset) before it fully resolved.
	HeroManager.clear_heroes()

	_heroes_escaped_count = 0
	_heroes_died_count = 0
	_current_wave_hero_data = hero_data_list.duplicate()
	_party.clear()

	_spawn_all_room_monsters()

	var multiplier: float = WaveManager.current_stat_multiplier()
	var offsets: Array[Vector2] = _compute_formation_offsets(hero_data_list)

	for i: int in hero_data_list.size():

		var hero_data: HeroData = hero_data_list[i]
		var hero: CombatEntity = HeroManager.spawn_hero(hero_scene, self) as CombatEntity

		var scaled_max_health: int = int(round(hero_data.max_health * multiplier))
		var scaled_damage: int = int(round(hero_data.damage * multiplier))
		var scaled_armor: int = int(round(hero_data.armor * multiplier))
		var scaled_attack_speed: float = hero_data.attack_speed * multiplier

		hero.configure(scaled_max_health, scaled_damage, scaled_armor, scaled_attack_speed, hero_data.abilities)
		hero.name = "Hero_%s" % hero_data.hero_name

		var offset: Vector2 = offsets[i]
		hero.position = offset

		_party.append({
			"entity": hero,
			"data": hero_data,
			"offset": offset,
			"resolved": false,
		})

	_run_party()


## Assigns each hero a (forward, lateral) offset based on class_type.
## Heroes sharing a row are spread laterally so they don't overlap.
func _compute_formation_offsets(hero_data_list: Array[HeroData]) -> Array[Vector2]:

	var row_counts: Dictionary = {}

	for hero_data: HeroData in hero_data_list:
		var row: String = hero_data.class_type
		row_counts[row] = row_counts.get(row, 0) + 1

	var row_seen: Dictionary = {}
	var offsets: Array[Vector2] = []

	for hero_data: HeroData in hero_data_list:

		var row: String = hero_data.class_type
		var lane_index: int = row_seen.get(row, 0)
		row_seen[row] = lane_index + 1

		var total_in_row: int = row_counts[row]
		var lateral: float = (lane_index - (total_in_row - 1) / 2.0) * LANE_SPACING_Y
		var forward: float = ROW_OFFSET_X.get(row, 0.0)

		offsets.append(Vector2(forward, lateral))

	return offsets


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

			# Path index i corresponds to room index i - 1 (index 0 of
			# the path is the entrance, which has no room).
			var room_index: int = i - 1
			var monsters: Array[CombatEntity] = _room_monsters.get(room_index, [])
			var living_heroes: Array[CombatEntity] = _living_party_entities()

			await CombatManager.begin_group_combat(living_heroes, monsters)

			for monster: CombatEntity in monsters:
				if is_instance_valid(monster):
					monster.queue_free()

			_room_monsters.erase(room_index)

			_resolve_dead_party_members()

			if _living_party_entities().is_empty():
				_finish_wave()
				return

	_resolve_escaped_party()


## Takes an untyped Variant - the value stored in _party may by now be a
## genuinely freed object, and passing that straight into a
## CombatEntity-typed parameter crashes at the call boundary. Checking
## is_instance_valid() first, on the untyped Variant, is what avoids
## that crash.
func _is_alive(entity: Variant) -> bool:
	return entity != null and is_instance_valid(entity) and not entity.is_queued_for_deletion()


func _living_party_entities() -> Array[CombatEntity]:

	var living: Array[CombatEntity] = []

	for member: Dictionary in _party:
		if _is_alive(member["entity"]):
			living.append(member["entity"])

	return living


func _move_party_to(waypoint: Vector2) -> void:

	# NOTE: deliberately does NOT await any Tween's `finished` signal.
	# If a Tween's target node is freed while it's still running (e.g. a
	# hero or monster dying mid-animation), Godot silently stops the
	# tween WITHOUT emitting `finished` - so `await tween.finished` can
	# hang forever with no error. Since each hero's move duration is
	# already known up front, waiting on a plain timer for the longest
	# one sidesteps that failure mode entirely.
	var max_duration: float = 0.0

	for member: Dictionary in _party:

		if not _is_alive(member["entity"]):
			continue

		var hero: CombatEntity = member["entity"]

		var target: Vector2 = waypoint + member["offset"]
		var distance: float = hero.position.distance_to(target)
		var duration: float = distance / move_speed if move_speed > 0.0 else 0.0

		if duration <= 0.0:
			hero.position = target
			continue

		var tween: Tween = create_tween()
		tween.tween_property(hero, "position", target, duration)

		max_duration = maxf(max_duration, duration)

	if max_duration > 0.0:
		await get_tree().create_timer(max_duration).timeout

## Spawns every room's monster group up front, all at once, positioned
## at that room's waypoint. Monsters stay put there for the rest of the
## wave - they never move - until the party reaches them (fought and
## freed in _run_party) or the wave ends (cleaned up in
## _clear_remaining_room_monsters). Monster stats are NOT scaled by
## WaveManager - only heroes get stronger as tiers advance.
func _spawn_all_room_monsters() -> void:

	_clear_remaining_room_monsters()

	var waypoints: Array[Vector2] = dungeon_grid.get_path_waypoints()
	var room_count: int = DungeonManager.room_count()

	for i: int in room_count:

		var room_data: RoomData = DungeonManager.get_room(i)

		if room_data != null and room_data.monster != null:
			# Room i sits at waypoint index i + 1 (index 0 is the entrance).
			_room_monsters[i] = _spawn_monster_group(room_data, waypoints[i + 1])
		else:
			_room_monsters[i] = []


func _spawn_monster_group(room_data: RoomData, at_position: Vector2) -> Array[CombatEntity]:

	var monsters: Array[CombatEntity] = []
	var count: int = maxi(1, room_data.monster_count)

	for i: int in count:

		var monster: CombatEntity = monster_scene.instantiate() as CombatEntity
		monster.name = "Monster_%s_%d" % [room_data.monster.monster_name, i + 1]

		add_child(monster)
		monster.configure(room_data.monster.max_health, room_data.monster.damage, room_data.monster.armor, room_data.monster.attack_speed, room_data.monster.abilities)
		monster.position = at_position + Vector2(0, (i - (count - 1) / 2.0) * 40.0)

		if monster.has_node("Body/Label"):
			monster.get_node("Body/Label").text = room_data.monster.monster_name

		monsters.append(monster)

	return monsters


## Single probabilistic damage instance - no counter-attack, no spawned
## entity, no CombatManager. A miss (roll above trigger_chance) does
## nothing at all. Damage still flows through CombatEntity.take_damage
## so it counts toward damage_taken (and therefore gold) exactly like
## damage from monster combat.
func _resolve_trap_for_member(member: Dictionary, trap_data: TrapData) -> void:

	if not _is_alive(member["entity"]):
		return

	var hero: CombatEntity = member["entity"]

	if randf() > trap_data.trigger_chance:
		return

	hero.take_damage(trap_data.damage, trap_data.ignores_armor)
	trap_triggered.emit(hero, trap_data)

	if not _is_alive(member["entity"]):
		_handle_hero_death(member)


func _resolve_dead_party_members() -> void:

	for member: Dictionary in _party:
		if not member["resolved"] and not _is_alive(member["entity"]):
			_handle_hero_death(member)


## By the time this runs, the hero may be freed already (see the note
## at the top of this file) - so this must NOT touch member["entity"]
## as a CombatEntity unless _is_alive confirms it's safe.
## HeroManager.remove_hero() only updates tracking (it does NOT call
## queue_free()), so this is safe even on an already-freed entry - see
## the double-free note in HeroManager.gd.
func _handle_hero_death(member: Dictionary) -> void:

	if member["resolved"]:
		return

	member["resolved"] = true

	var hero_data: HeroData = member["data"]

	if _is_alive(member["entity"]):
		var hero: CombatEntity = member["entity"]
		EconomyManager.award_hero_damage_gold(hero, hero_data)
		HeroManager.remove_hero(hero)

	_heroes_died_count += 1


func _resolve_escaped_party() -> void:

	for member: Dictionary in _party:

		if member["resolved"]:
			continue

		member["resolved"] = true

		if not _is_alive(member["entity"]):
			continue

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

	_clear_remaining_room_monsters()

	var full_wipe: bool = _heroes_escaped_count == 0 and _heroes_died_count > 0

	if full_wipe:
		EconomyManager.award_wipe_bonus(_current_wave_hero_data)

	wave_cleared.emit(full_wipe)


func _clear_remaining_room_monsters() -> void:

	for key: int in _room_monsters.keys():
		for monster: CombatEntity in _room_monsters[key]:
			if is_instance_valid(monster):
				monster.queue_free()

	_room_monsters.clear()
