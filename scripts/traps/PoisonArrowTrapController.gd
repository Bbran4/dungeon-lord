extends Node2D
class_name PoisonArrowTrapController

## Owns a single PROJECTILE trap's fire-loop for the room it's spawned
## in: waits `projectile_cooldown`, fires a pooled TrapArrow from the
## top of the room downward, and reacts when that arrow reports back
## having hit a hero or reached the far wall - either outcome loops
## back into a fresh cooldown before firing again. Runs continuously
## for as long as this controller exists; Dungeon frees it once the
## party has passed this room, same lifecycle as a room's monster group.
##
## Uses a small poll loop (not `await arrow.hit_target`) to wait for
## resolution, since GDScript lambda captures are by-value snapshots,
## not by-reference - a closure can't cleanly report back into an outer
## local across an await boundary. Polling on a short timer is the
## pragmatic fix, in the same spirit as Dungeon._move_party_to avoiding
## `await tween.finished` for its own reliability reasons.

signal trap_fired(hero: CombatEntity)

const POLL_INTERVAL: float = 0.05

@export var room_half_height: float = 125.0
@export var room_half_width: float = 60.0

var _trap_data: TrapData
var _pool: Array[TrapArrow] = []
var _heroes_provider: Callable = Callable()
var _damage_multiplier: float = 1.0
var _running: bool = false
var _current_arrow: TrapArrow = null
var _last_hit_hero: CombatEntity = null


func setup(trap_data: TrapData, pool: Array[TrapArrow], heroes_provider: Callable, damage_multiplier: float = 1.0) -> void:
	_trap_data = trap_data
	_pool = pool
	_heroes_provider = heroes_provider
	_damage_multiplier = damage_multiplier


func start() -> void:
	_running = true
	_fire_loop()


func stop() -> void:
	_running = false
	if _current_arrow != null and is_instance_valid(_current_arrow):
		_release_arrow(_current_arrow)
		_current_arrow = null


func _fire_loop() -> void:

	while _running:

		await get_tree().create_timer(_trap_data.projectile_cooldown).timeout

		if not _running or not is_inside_tree():
			return

		_fire_arrow()

		while _current_arrow != null:

			await get_tree().create_timer(POLL_INTERVAL).timeout

			if not _running or not is_inside_tree():
				return

		if _last_hit_hero != null:

			var hero: CombatEntity = _last_hit_hero
			_last_hit_hero = null

			if is_instance_valid(hero):
				var initial: int = int(round(_trap_data.damage * _damage_multiplier))
				hero.take_damage(initial, _trap_data.ignores_armor)
				trap_fired.emit(hero)
				_apply_dot(hero)


func _fire_arrow() -> void:

	var arrow: TrapArrow = _acquire_arrow()

	if arrow == null:
		return

	_current_arrow = arrow

	if not arrow.hit_target.is_connected(_on_arrow_hit_target):
		arrow.hit_target.connect(_on_arrow_hit_target)
	if not arrow.hit_wall.is_connected(_on_arrow_hit_wall):
		arrow.hit_wall.connect(_on_arrow_hit_wall)

	var start_x: float = randf_range(-room_half_width, room_half_width)
	var start_position: Vector2 = position + Vector2(start_x, -room_half_height)
	var wall_y: float = position.y + room_half_height

	arrow.fire(start_position, wall_y, _trap_data.projectile_speed, _heroes_provider)


func _on_arrow_hit_target(hero: CombatEntity) -> void:
	_last_hit_hero = hero
	_current_arrow = null


func _on_arrow_hit_wall() -> void:
	_current_arrow = null


## Fire-and-forget damage-over-time ticks, independent of the arrow
## (already recycled by the time this runs). Bails early if this
## controller is freed (wave ended / party passed the room) or the
## hero is no longer alive.
func _apply_dot(hero: CombatEntity) -> void:

	for i: int in _trap_data.tick_count:

		await get_tree().create_timer(_trap_data.tick_interval).timeout

		if not is_inside_tree():
			return

		if not is_instance_valid(hero) or hero.is_queued_for_deletion() or hero.current_health <= 0:
			return

		var tick_amount: int = int(round(_trap_data.tick_damage * _damage_multiplier))
		hero.take_damage(tick_amount, _trap_data.ignores_armor)


func _acquire_arrow() -> TrapArrow:
	for arrow: TrapArrow in _pool:
		if not arrow.visible:
			return arrow
	return null


func _release_arrow(arrow: TrapArrow) -> void:
	arrow.visible = false
	arrow.set_process(false)
