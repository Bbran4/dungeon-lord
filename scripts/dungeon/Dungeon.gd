extends Node2D
class_name Dungeon

## Moves a whole hero party together through the dungeon's room sequence
## and resolves each room as a GROUP encounter via
## CombatManager.begin_group_combat.
##
## ENTRANCE SPAWNING: heroes spawn one at a time at the entrance, with a
## small random gap (hero_spawn_stagger_min..max) between each, all
## landing in their formation position. The whole party only starts
## moving toward the first room once everyone has spawned in.
##
## Room monsters AND projectile traps are both spawned up front, all at
## once, when the wave starts - not lazily when the party happens to
## arrive. A room's monster group and any PoisonArrowTrapController both
## sit/run at that room's position for the whole wave, regardless of
## where the party currently is, until the wave ends and everything
## still standing is cleaned up.
##
## Heroes are positioned using a class-based FORMATION rather than
## simple spawn order: Tank at the front (closest to the monster line),
## Ranger/Mage in the middle, Healer at the back, Rogue positioned past
## the monster line entirely (flanking). See _compute_formation_offsets.
##
## MELEE CHARGE: the instant a room fight begins, melee-flagged living
## heroes (HeroData.is_melee) tween forward, closing part of the gap to
## the monster line (never crossing it - see MELEE_MIN_STANDOFF), while
## melee monsters step forward to meet them partway
## (_charge_melee_into_combat). Ranged heroes (Healer/Mage/Ranger)
## simply hold their formation position. This is purely cosmetic -
## CombatManager's targeting/damage never reads position - and
## survivors are smoothly returned to proper formation automatically by
## the next _move_party_to() call once the room is resolved.
##
## MOVEMENT SLOWDOWN: the party moves at room_danger_speed_multiplier
## (< 1.0) while approaching any room containing a monster or a trap -
## this is what gives a PROJECTILE trap more chances to land a hit,
## since the party lingers in the arrow's path longer.
##
## INSTANT traps still resolve as a single probabilistic hit per hero
## right when the party arrives, same as before. PROJECTILE traps are
## entirely decoupled from party position - see
## PoisonArrowTrapController.
##
## UTILITY ROOMS: arriving at a room with room_type == "Utility" applies
## its one-time/ongoing effects via _apply_utility_room - optionally
## healing the whole living party, and multiplying _gold_multiplier /
## _trap_damage_multiplier for the REST of the wave (both reset to 1.0
## at the start of each new wave in send_wave()).
##
## WAVE SCALING: hero stats (max health, damage, armor, attack speed)
## AND gold_value are all scaled by WaveManager.current_stat_multiplier()
## at spawn time - HeroData resources themselves are never mutated,
## since they're shared assets.
##
## Expects a child node named "DungeonGrid" positioned at local origin,
## since waypoint coordinates from DungeonGrid are used directly as
## this node's children's local positions.
##
## Active hero tracking is delegated to HeroManager (spawn_hero/
## remove_hero/active_heroes) as before. Internally, Dungeon also keeps
## its own small per-wave roster (_party) pairing each hero's
## CombatEntity with its HeroData, formation offset, SCALED gold_value,
## and a "resolved" flag, so gold can be awarded exactly once per hero
## whether they die mid-run or escape at the end.
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
@export var trap_arrow_scene: PackedScene
@export var move_speed: float = 200.0

## Random gap range between each hero spawning at the entrance.
@export var hero_spawn_stagger_min: float = 0.05
@export var hero_spawn_stagger_max: float = 0.1

## Multiplier applied to move_speed while the party approaches a room
## containing a monster or a trap. < 1.0 = slower, giving traps and
## monsters more exposure time.
@export var room_danger_speed_multiplier: float = 0.5

@export var arrow_pool_size: int = 12

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

## How much a melee hero closes their forward-offset distance to the
## monster line when a fight begins, and the closest they're ever
## allowed to get (so they never overshoot past x=0 or stack on top of
## monsters).
const MELEE_CHARGE_DISTANCE: float = 30.0
const MELEE_MIN_STANDOFF: float = 10.0

## How far melee monsters step forward (toward the hero line) to meet
## charging melee heroes partway.
const MONSTER_CHARGE_OFFSET: float = 15.0

const CHARGE_TWEEN_DURATION: float = 0.35

var _heroes_escaped_count: int = 0
var _heroes_died_count: int = 0

## Each entry: {"entity": Variant (a CombatEntity that may later be
## freed), "data": HeroData, "offset": Vector2, "gold_value": int
## (already scaled by the wave multiplier at spawn time), "resolved": bool}
var _party: Array[Dictionary] = []

## room_index -> Array[CombatEntity]. Populated all at once at the
## start of a wave; entries are removed as each room is fought, and
## anything left over is cleaned up when the wave ends.
var _room_monsters: Dictionary = {}

## room_index -> PoisonArrowTrapController. Populated all at once at
## the start of a wave for every room with a PROJECTILE trap; all freed
## together when the wave ends (see _finish_wave).
var _room_projectile_traps: Dictionary = {}

var _arrow_pool: Array[TrapArrow] = []

## Runtime modifiers set by utility rooms, reset each wave. Applied at
## gold-award time and at trap-damage time respectively (see
## _apply_utility_room, _handle_hero_death, _resolve_escaped_party,
## _finish_wave, _resolve_trap_for_member).
var _gold_multiplier: float = 1.0
var _trap_damage_multiplier: float = 1.0


func send_wave(hero_data_list: Array[HeroData]) -> void:

	# Safety net: clears out any stale entries if a previous wave was
	# interrupted (e.g. a mid-combat reset) before it fully resolved.
	HeroManager.clear_heroes()

	_heroes_escaped_count = 0
	_heroes_died_count = 0
	_gold_multiplier = 1.0
	_trap_damage_multiplier = PassiveManager.get_trap_damage_multiplier()
	_party.clear()

	_spawn_all_room_monsters()
	_spawn_all_projectile_traps()

	var multiplier: float = WaveManager.current_stat_multiplier()
	var offsets: Array[Vector2] = _compute_formation_offsets(hero_data_list)

	for i: int in hero_data_list.size():

		var hero_data: HeroData = hero_data_list[i]
		var hero: CombatEntity = HeroManager.spawn_hero(hero_scene, self) as CombatEntity

		var scaled_max_health: int = int(round(hero_data.max_health * multiplier))
		var scaled_damage: int = int(round(hero_data.damage * multiplier))
		var scaled_armor: int = int(round(hero_data.armor * multiplier))
		var scaled_attack_speed: float = hero_data.attack_speed * multiplier
		var scaled_gold_value: int = int(round(hero_data.gold_value * multiplier))

		hero.configure(scaled_max_health, scaled_damage, scaled_armor, scaled_attack_speed, hero_data.abilities)
		hero.is_melee = hero_data.is_melee
		hero.projectile_color = hero_data.projectile_color
		hero.name = "Hero_%s" % hero_data.hero_name

		var offset: Vector2 = offsets[i]
		hero.position = offset

		_party.append({
			"entity": hero,
			"data": hero_data,
			"offset": offset,
			"gold_value": scaled_gold_value,
			"resolved": false,
		})

		# Stagger entrance spawning so the party visibly files in one at
		# a time rather than popping in all at once. Skip the wait after
		# the LAST hero - nothing to gain by delaying the move-out.
		if i < hero_data_list.size() - 1:
			await get_tree().create_timer(randf_range(hero_spawn_stagger_min, hero_spawn_stagger_max)).timeout

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

		var room_data: RoomData = dungeon_grid.get_room_data_at_path_index(i)
		var is_dangerous: bool = room_data != null and (room_data.monster != null or room_data.trap != null)
		var speed_multiplier: float = room_danger_speed_multiplier if is_dangerous else 1.0

		await _move_party_to(waypoints[i], speed_multiplier)

		if room_data != null and room_data.room_type == "Utility":
			_apply_utility_room(room_data)

		if room_data != null and room_data.trap != null and room_data.trap.trap_type == GameEnums.TrapType.INSTANT:
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

			_charge_melee_into_combat(monsters, waypoints[i])

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


## Fire-and-forget visual charge: melee-flagged living heroes step
## forward (reducing their distance to the monster line, but never
## crossing it) and melee monsters step forward to meet them partway,
## right as combat begins. Ranged heroes (Healer/Mage/Ranger) and any
## future ranged monsters simply hold their formation position - this
## is what gives "ranged stay at range, melee charge in" its visual
## distinction. Purely cosmetic: CombatManager's targeting/damage logic
## doesn't read these positions at all, and surviving heroes get
## tweened back into proper formation automatically by the next
## _move_party_to() call once this room is resolved.
func _charge_melee_into_combat(monsters: Array[CombatEntity], room_waypoint: Vector2) -> void:

	for member: Dictionary in _party:

		if not member["data"].is_melee or not _is_alive(member["entity"]):
			continue

		var hero: CombatEntity = member["entity"]
		var offset: Vector2 = member["offset"]

		var direction: float = signf(offset.x) if offset.x != 0.0 else 1.0
		var reduced_x: float = maxf(absf(offset.x) - MELEE_CHARGE_DISTANCE, MELEE_MIN_STANDOFF)
		var charge_target: Vector2 = room_waypoint + Vector2(direction * reduced_x, offset.y)

		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(hero, "position", charge_target, CHARGE_TWEEN_DURATION)

	for monster: CombatEntity in monsters:

		if not _is_alive(monster) or not monster.is_melee:
			continue

		var charge_target: Vector2 = monster.position + Vector2(MONSTER_CHARGE_OFFSET, 0.0)

		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(monster, "position", charge_target, CHARGE_TWEEN_DURATION)


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


func _move_party_to(waypoint: Vector2, speed_multiplier: float = 1.0) -> void:

	# NOTE: deliberately does NOT await any Tween's `finished` signal.
	# If a Tween's target node is freed while it's still running (e.g. a
	# hero or monster dying mid-animation), Godot silently stops the
	# tween WITHOUT emitting `finished` - so `await tween.finished` can
	# hang forever with no error. Since each hero's move duration is
	# already known up front, waiting on a plain timer for the longest
	# one sidesteps that failure mode entirely.
	var max_duration: float = 0.0
	var effective_speed: float = move_speed * speed_multiplier

	for member: Dictionary in _party:

		if not _is_alive(member["entity"]):
			continue

		var hero: CombatEntity = member["entity"]

		var target: Vector2 = waypoint + member["offset"]
		var distance: float = hero.position.distance_to(target)
		var duration: float = distance / effective_speed if effective_speed > 0.0 else 0.0

		if duration <= 0.0:
			hero.position = target
			continue

		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(hero, "position", target, duration)

		max_duration = maxf(max_duration, duration)

	if max_duration > 0.0:
		await get_tree().create_timer(max_duration).timeout


## Spawns every room's monster group up front, all at once, positioned
## at that room's waypoint. Monsters stay put there for the rest of the
## wave - they never move (aside from the cosmetic charge-in, see
## _charge_melee_into_combat) - until the party reaches them (fought and
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

		var scaled_monster_health: int = int(round(room_data.monster.max_health * PassiveManager.get_monster_health_multiplier()))
		var scaled_monster_damage: int = int(round(room_data.monster.damage * PassiveManager.get_monster_damage_multiplier()))

		monster.configure(scaled_monster_health, scaled_monster_damage, room_data.monster.armor, room_data.monster.attack_speed, room_data.monster.abilities)
		monster.is_melee = room_data.monster.is_melee
		monster.projectile_color = room_data.monster.projectile_color
		monster.position = at_position + Vector2(0, (i - (count - 1) / 2.0) * 40.0)

		if monster.has_node("Body/Label"):
			monster.get_node("Body/Label").text = room_data.monster.monster_name

		monsters.append(monster)

	return monsters


## Spawns a PoisonArrowTrapController for every room whose trap is
## PROJECTILE-type, up front, all at once - each one starts firing
## immediately and keeps firing on its own cooldown(s) for the rest of
## the wave regardless of where the party currently is. Freed all at
## once in _finish_wave, same lifecycle as room monsters.
func _spawn_all_projectile_traps() -> void:

	_clear_remaining_projectile_traps()
	_ensure_arrow_pool()

	var waypoints: Array[Vector2] = dungeon_grid.get_path_waypoints()
	var room_count: int = DungeonManager.room_count()

	for i: int in room_count:

		var room_data: RoomData = DungeonManager.get_room(i)

		if room_data != null and room_data.trap != null and room_data.trap.trap_type == GameEnums.TrapType.PROJECTILE:

			var controller: PoisonArrowTrapController = PoisonArrowTrapController.new()
			add_child(controller)
			# Room i sits at waypoint index i + 1 (index 0 is the entrance).
			controller.position = waypoints[i + 1]
			controller.setup(room_data.trap, _arrow_pool, Callable(self, "_living_party_entities"), _trap_damage_multiplier)

			var trap_data: TrapData = room_data.trap
			controller.trap_fired.connect(func(hero: CombatEntity) -> void:
				if is_instance_valid(hero):
					trap_triggered.emit(hero, trap_data)
			)

			controller.start()

			_room_projectile_traps[i] = controller


func _ensure_arrow_pool() -> void:

	if not _arrow_pool.is_empty() or trap_arrow_scene == null:
		return

	for i: int in arrow_pool_size:
		var arrow: TrapArrow = trap_arrow_scene.instantiate() as TrapArrow
		add_child(arrow)
		arrow.visible = false
		_arrow_pool.append(arrow)


func _clear_remaining_projectile_traps() -> void:

	for key: int in _room_projectile_traps.keys():
		var controller: PoisonArrowTrapController = _room_projectile_traps[key]
		if is_instance_valid(controller):
			controller.stop()
			controller.queue_free()

	_room_projectile_traps.clear()


## Applies a Utility room's one-time/ongoing effects. Multipliers stack
## multiplicatively across multiple utility rooms passed in one wave.
func _apply_utility_room(room_data: RoomData) -> void:

	if room_data.heal_party_on_entry:
		for member: Dictionary in _party:
			if _is_alive(member["entity"]):
				var hero: CombatEntity = member["entity"]
				hero.heal(hero.max_health)

	_gold_multiplier *= room_data.gold_multiplier
	_trap_damage_multiplier *= room_data.trap_damage_multiplier


## Single probabilistic damage instance for INSTANT traps only - no
## counter-attack, no spawned entity, no CombatManager. A miss (roll
## above trigger_chance) does nothing at all. Damage still flows
## through CombatEntity.take_damage so it counts toward damage_taken
## (and therefore gold) exactly like damage from monster combat.
func _resolve_trap_for_member(member: Dictionary, trap_data: TrapData) -> void:

	if not _is_alive(member["entity"]):
		return

	var hero: CombatEntity = member["entity"]

	if randf() > trap_data.trigger_chance:
		return

	var amount: int = int(round(trap_data.damage * _trap_damage_multiplier))
	hero.take_damage(amount, trap_data.ignores_armor)
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

	if _is_alive(member["entity"]):
		var hero: CombatEntity = member["entity"]
		var gold_value: int = int(round(member["gold_value"] * _gold_multiplier))
		EconomyManager.award_hero_damage_gold(hero, gold_value)
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
		var gold_value: int = int(round(member["gold_value"] * _gold_multiplier))

		EconomyManager.award_hero_damage_gold(hero, gold_value)
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
	_clear_remaining_projectile_traps()

	var full_wipe: bool = _heroes_escaped_count == 0 and _heroes_died_count > 0

	if full_wipe:

		var total_gold_value: int = 0

		for member: Dictionary in _party:
			total_gold_value += member["gold_value"]

		total_gold_value = int(round(total_gold_value * _gold_multiplier))

		EconomyManager.award_wipe_bonus(total_gold_value)

	wave_cleared.emit(full_wipe)


func _clear_remaining_room_monsters() -> void:

	for key: int in _room_monsters.keys():
		for monster: CombatEntity in _room_monsters[key]:
			if is_instance_valid(monster):
				monster.queue_free()

	_room_monsters.clear()
