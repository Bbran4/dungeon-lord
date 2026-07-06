extends Node2D
class_name PoisonArrowTrapController

## Owns a single PROJECTILE trap's continuous fire behavior for the
## whole wave, regardless of whether the party is anywhere near this
## room - spawned once at wave start (Dungeon._spawn_all_projectile_traps)
## and freed once at wave end, the same lifecycle a room's monster
## group already has. Entering the room does NOT trigger anything; the
## trap has been firing on its own cooldown(s) the entire time.
##
## Runs `max_concurrent_arrows` independent fire-loops in parallel, each
## its own coroutine (started via a bare, un-awaited call to
## _fire_loop() - GDScript lets a function containing `await` run as an
## independent coroutine this way). Because TrapArrow.resolved is
## awaited directly rather than tracked through shared instance state,
## each loop's local variables belong only to that loop - concurrent
## arrows never interfere with each other's bookkeeping.

signal trap_fired(hero: CombatEntity)

@export var room_half_height: float = 125.0
@export var room_half_width: float = 60.0

var _trap_data: TrapData
var _pool: Array[TrapArrow] = []
var _heroes_provider: Callable = Callable()
var _damage_multiplier: float = 1.0
var _running: bool = false


func setup(trap_data: TrapData, pool: Array[TrapArrow], heroes_provider: Callable, damage_multiplier: float = 1.0) -> void:
	_trap_data = trap_data
	_pool = pool
	_heroes_provider = heroes_provider
	_damage_multiplier = damage_multiplier


func start() -> void:

	_running = true

	var slot_count: int = maxi(1, _trap_data.max_concurrent_arrows)

	for i: int in slot_count:
		_fire_loop()


func stop() -> void:
	_running = false


## One independent firing "slot": wait cooldown, acquire a pooled
## arrow, fire it, await its resolution, apply damage/DoT if it hit,
## loop. Each call to this function (see start()) is its own
## concurrent coroutine with entirely local state.
func _fire_loop() -> void:

	while _running:

		await get_tree().create_timer(_trap_data.projectile_cooldown).timeout

		if not _running or not is_inside_tree():
			return

		var arrow: TrapArrow = _acquire_arrow()

		if arrow == null:
			continue

		var start_x: float = randf_range(-room_half_width, room_half_width)
		var start_position: Vector2 = position + Vector2(start_x, -room_half_height)
		var wall_y: float = position.y + room_half_height

		arrow.fire(start_position, wall_y, _trap_data.projectile_speed, _heroes_provider)

		var hero: CombatEntity = await arrow.resolved

		if not _running or not is_inside_tree():
			return

		if hero != null and is_instance_valid(hero):

			var initial: int = int(round(_trap_data.damage * _damage_multiplier))
			hero.take_damage(initial, _trap_data.ignores_armor)
			trap_fired.emit(hero)

			# Fire-and-forget: the DoT runs on its own timeline and does
			# NOT hold this slot's arrow busy, so the slot can go
			# straight back to its cooldown and fire again independently.
			_apply_dot(hero)


## Fire-and-forget damage-over-time ticks, independent of the arrow
## that triggered them. Bails early if this controller is freed (wave
## ended) or the hero is no longer alive.
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
