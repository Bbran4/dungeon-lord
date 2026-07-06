extends Node2D
class_name Dungeon

## Spawns heroes at the entrance and walks them through the dungeon's
## room sequence to the exit, fighting whatever occupies each room.
## Expects a child node named "DungeonGrid" positioned at local origin,
## since waypoint coordinates from DungeonGrid are used directly as
## this node's children's local positions.
##
## Active hero tracking is delegated to HeroManager (spawn_hero/
## remove_hero/active_heroes) rather than kept locally, so other systems
## can query or react to the live hero roster later.
##
## Gold is awarded per-hero, once, at the moment they're resolved
## (killed or escaped) - based on damage they took over the whole run,
## via EconomyManager.award_hero_damage_gold(). If every hero in the
## wave dies with none escaping, EconomyManager.award_wipe_bonus() also
## fires once the wave finishes.

signal hero_escaped(hero: CombatEntity)
signal wave_cleared

@onready var dungeon_grid: DungeonGrid = $DungeonGrid

@export var hero_scene: PackedScene
@export var move_speed: float = 200.0
@export var hero_spawn_delay: float = 1.0

var _heroes_escaped_count: int = 0
var _heroes_died_count: int = 0
var _current_wave_hero_data: Array[HeroData] = []


func send_wave(hero_data_list: Array[HeroData]) -> void:

	# Safety net: clears out any stale entries if a previous wave was
	# interrupted (e.g. a mid-combat reset) before it fully resolved.
	HeroManager.clear_heroes()

	_heroes_escaped_count = 0
	_heroes_died_count = 0
	_current_wave_hero_data = hero_data_list.duplicate()

	for i: int in hero_data_list.size():
		await get_tree().create_timer(hero_spawn_delay * i).timeout
		_spawn_and_run_hero(hero_data_list[i])


func _spawn_and_run_hero(hero_data: HeroData) -> void:

	var hero: CombatEntity = HeroManager.spawn_hero(hero_scene, self) as CombatEntity
	hero.configure(hero_data.max_health, hero_data.damage, hero_data.armor)
	hero.name = "Hero_%s" % hero_data.hero_name

	var waypoints: Array[Vector2] = dungeon_grid.get_path_waypoints()

	for i: int in waypoints.size():

		if not _is_alive(hero):
			_on_hero_died(hero, hero_data)
			return

		await _move_hero_to(hero, waypoints[i])

		if not _is_alive(hero):
			_on_hero_died(hero, hero_data)
			return

		var room_data: RoomData = dungeon_grid.get_room_data_at_path_index(i)

		if room_data != null and room_data.monster != null:

			var monster: CombatEntity = _spawn_monster_entity(room_data.monster)

			CombatManager.begin_combat(hero, monster)

			if is_instance_valid(monster):
				monster.queue_free()

			if not _is_alive(hero):
				_on_hero_died(hero, hero_data)
				return

	_on_hero_escaped(hero, hero_data)


## True only if the entity is both a valid instance and not already
## scheduled for deletion (queue_free() defers the actual free, so
## is_instance_valid() alone can report true for a frame after death).
func _is_alive(entity: CombatEntity) -> bool:
	return is_instance_valid(entity) and not entity.is_queued_for_deletion()


func _move_hero_to(hero: CombatEntity, target_position: Vector2) -> void:

	var distance: float = hero.position.distance_to(target_position)
	var duration: float = distance / move_speed if move_speed > 0.0 else 0.0

	if duration <= 0.0:
		hero.position = target_position
		return

	var tween: Tween = create_tween()
	tween.tween_property(hero, "position", target_position, duration)

	await tween.finished


func _spawn_monster_entity(monster_data: MonsterData) -> CombatEntity:

	var monster: CombatEntity = CombatEntity.new()
	monster.name = "Monster_%s" % monster_data.monster_name

	add_child(monster)
	monster.configure(monster_data.max_health, monster_data.damage, monster_data.armor)

	return monster


## Hero already freed itself via CombatEntity.die() -> queue_free() by
## the time this runs. HeroManager.remove_hero() only updates tracking
## (it does NOT call queue_free()), so this is safe to call on an
## already-dying hero - see the double-free note in HeroManager.gd.
func _on_hero_died(hero: CombatEntity, hero_data: HeroData) -> void:
	EconomyManager.award_hero_damage_gold(hero, hero_data)
	HeroManager.remove_hero(hero)
	_heroes_died_count += 1
	_on_hero_resolved()


func _on_hero_escaped(hero: CombatEntity, hero_data: HeroData) -> void:
	EconomyManager.award_hero_damage_gold(hero, hero_data)
	HeroManager.remove_hero(hero)
	_heroes_escaped_count += 1
	hero_escaped.emit(hero)
	hero.queue_free()
	_on_hero_resolved()


func _on_hero_resolved() -> void:

	if HeroManager.active_heroes.is_empty():

		if _heroes_escaped_count == 0 and _heroes_died_count > 0:
			EconomyManager.award_wipe_bonus(_current_wave_hero_data)

		wave_cleared.emit()
