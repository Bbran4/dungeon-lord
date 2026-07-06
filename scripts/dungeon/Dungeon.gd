extends Node2D
class_name Dungeon

## Spawns heroes at the entrance and walks them through the dungeon's
## room sequence to the exit, fighting whatever occupies each room.
## Expects a child node named "DungeonGrid" positioned at local origin,
## since waypoint coordinates from DungeonGrid are used directly as
## this node's children's local positions.

signal hero_escaped(hero: CombatEntity)
signal wave_cleared

@onready var dungeon_grid: DungeonGrid = $DungeonGrid

@export var hero_scene: PackedScene
@export var move_speed: float = 200.0
@export var hero_spawn_delay: float = 1.0

var _active_hero_count: int = 0


func send_wave(hero_data_list: Array[HeroData]) -> void:

	_active_hero_count = hero_data_list.size()

	for i: int in hero_data_list.size():
		await get_tree().create_timer(hero_spawn_delay * i).timeout
		_spawn_and_run_hero(hero_data_list[i])


func _spawn_and_run_hero(hero_data: HeroData) -> void:

	var hero: CombatEntity = hero_scene.instantiate() as CombatEntity
	add_child(hero)
	hero.configure(hero_data.max_health, hero_data.damage, hero_data.armor)
	hero.name = "Hero_%s" % hero_data.hero_name

	var waypoints: Array[Vector2] = dungeon_grid.get_path_waypoints()

	for i: int in waypoints.size():

		if not _is_alive(hero):
			_on_hero_resolved()
			return

		await _move_hero_to(hero, waypoints[i])

		if not _is_alive(hero):
			_on_hero_resolved()
			return

		var room_data: RoomData = dungeon_grid.get_room_data_at_path_index(i)

		if room_data != null and room_data.monster != null:

			var monster: CombatEntity = _spawn_monster_entity(room_data.monster)

			CombatManager.begin_combat(hero, monster)

			if is_instance_valid(monster):
				monster.queue_free()

			if not _is_alive(hero):
				_on_hero_resolved()
				return

	hero_escaped.emit(hero)
	hero.queue_free()
	_on_hero_resolved()


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


func _on_hero_resolved() -> void:

	_active_hero_count -= 1

	if _active_hero_count <= 0:
		wave_cleared.emit()
