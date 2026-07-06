extends Node2D
class_name TrapArrow

## A single pooled poison-arrow projectile. Travels straight down
## (local +Y) until it either hits a hero (Area2D overlap, filtered
## against the CURRENT living party via heroes_provider so it ignores
## monsters even though they share the same collision layer) or
## reaches the room's far wall. Either outcome deactivates the arrow
## (hidden, process stopped) rather than freeing it, so the owning
## controller can recycle it from a pool.
##
## Emits a SINGLE `resolved` signal either way (hero on a hit, null on
## a wall miss) rather than two separate signals - this is what lets a
## caller just `await arrow.resolved` directly with no manual
## connect/disconnect bookkeeping.

signal resolved(hero: CombatEntity)

@onready var _area: Area2D = $Area2D

var _speed: float = 260.0
var _wall_y: float = 0.0
var _active: bool = false
var _heroes_provider: Callable = Callable()


func _ready() -> void:
	_area.area_entered.connect(_on_area_entered)
	visible = false
	set_process(false)


## Activates this arrow at `start_position`, traveling straight down
## until reaching `wall_y` (this node's parent-space Y) or hitting a
## hero. heroes_provider must return the CURRENT array of living heroes
## - passed as a Callable rather than a snapshot, since the roster can
## shrink mid-flight.
func fire(start_position: Vector2, wall_y: float, speed: float, heroes_provider: Callable) -> void:
	position = start_position
	_wall_y = wall_y
	_speed = speed
	_heroes_provider = heroes_provider
	_active = true
	visible = true
	set_process(true)


func _process(delta: float) -> void:

	if not _active:
		return

	position.y += _speed * delta

	if position.y >= _wall_y:
		_deactivate()
		resolved.emit(null)


func _on_area_entered(area: Area2D) -> void:

	if not _active:
		return

	var other: Node = area.get_parent()

	if not (other is CombatEntity):
		return

	var living_heroes: Array = _heroes_provider.call() if _heroes_provider.is_valid() else []

	if not living_heroes.has(other):
		return

	_deactivate()
	resolved.emit(other)


func _deactivate() -> void:
	_active = false
	visible = false
	set_process(false)
