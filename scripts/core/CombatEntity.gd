extends Node2D
class_name CombatEntity

signal health_changed(current_health: int)
signal died(entity: CombatEntity)

@export var max_health: int = 10
@export var damage: int = 2
@export var armor: int = 0
@export var attack_speed: float = 1.0

## Special abilities beyond the implicit basic attack (see
## get_combat_abilities). Authored on HeroData/MonsterData and passed
## in via configure().
@export var abilities: Array[AbilityData] = []

var current_health: int = 0

## Cumulative raw damage this entity has taken (post-armor), across its
## whole lifetime. Used by EconomyManager to reward damage dealt to
## heroes rather than requiring a kill.
var damage_taken: int = 0

## Cumulative healing this entity has received. Added to max_health when
## computing effective max health, so a hero that gets healed mid-run
## doesn't let attackers earn more than 100% gold credit against them.
var healing_received: int = 0

## Visual-only "step toward target and back" distance/duration for the
## attack lunge. Purely cosmetic - never affects global_position, which
## stays the entity's real position for movement/formation/collision.
const ATTACK_LUNGE_DISTANCE: float = 24.0
const ATTACK_LUNGE_DURATION: float = 0.25

## How close (in px, center-to-center) two combatants are allowed to get
## before separation starts pushing them apart, and how strongly.
const SEPARATION_RADIUS: float = 18.0
const SEPARATION_STRENGTH: float = 250.0

## "Body" (optional) wraps the visual (ColorRect/Label) so the attack
## lunge can animate it without touching global_position, which stays
## the entity's real position. "SeparationArea" (optional) is an Area2D
## used to detect overlapping combatants for the separation push. Both
## are looked up defensively - a bare CombatEntity.new() with no child
## scene (e.g. TestHarness's sandbox fight) simply won't lunge or
## separate, and combat still works fine without them.
@onready var _body: Node2D = get_node_or_null("Body") as Node2D
@onready var _separation_area: Area2D = get_node_or_null("SeparationArea") as Area2D

var _attack_tween: Tween

## Auto-generated from damage/attack_speed - always available, always
## rebuilt whenever those stats change via configure(). Authored
## `abilities` only needs to list SPECIAL abilities (Taunt, Buff, Heal,
## etc.) on top of this.
var _basic_attack_ability: AbilityData


func _ready() -> void:
	current_health = max_health
	_rebuild_basic_attack_ability()


func _process(delta: float) -> void:
	_apply_separation(delta)


## Sets stats and resets current_health accordingly. Safe to call before
## or after the node enters the tree.
func configure(new_max_health: int, new_damage: int, new_armor: int, new_abilities: Array[AbilityData] = []) -> void:
	max_health = new_max_health
	damage = new_damage
	armor = new_armor
	current_health = max_health
	damage_taken = 0
	healing_received = 0
	abilities = new_abilities
	_rebuild_basic_attack_ability()


## The implicit basic attack plus any authored special abilities. This
## is what CombatManager picks randomly from each time this entity is
## off cooldown and ready to act.
func get_combat_abilities() -> Array[AbilityData]:
	var list: Array[AbilityData] = [_basic_attack_ability]
	list.append_array(abilities)
	return list


## Deals `damage` to target via the implicit basic attack. Convenience
## wrapper around attack_with_amount() for external callers (e.g. the
## TestHarness sandbox fight) that don't go through CombatManager.
func attack(target: CombatEntity) -> int:
	return attack_with_amount(target, damage)


## Returns the mitigated damage actually dealt (0 if target is null).
## Used by both the basic attack and any Attack-type special ability
## (a future Ranger arrow, etc.), so lunge + damage + threat-tracking
## behave identically regardless of which ability triggered them.
func attack_with_amount(target: CombatEntity, amount: int) -> int:
	if target == null:
		return 0

	_play_attack_lunge(target.global_position)

	return target.take_damage(amount)


## Returns the mitigated damage actually applied.
func take_damage(amount: int, ignore_armor: bool = false) -> int:

	var mitigated: int = amount if ignore_armor else amount - armor
	mitigated = max(1, mitigated)

	current_health -= mitigated
	damage_taken += mitigated

	health_changed.emit(current_health)

	if current_health <= 0:
		die()

	return mitigated


## Restores health (capped at max_health) and records the amount healed.
func heal(amount: int) -> void:
	if amount <= 0:
		return

	healing_received += amount
	current_health = mini(current_health + amount, max_health)

	health_changed.emit(current_health)


## Base max health plus all healing received - the total health pool an
## attacker actually had to overcome to defeat this entity.
func effective_max_health() -> int:
	return max_health + healing_received


func die() -> void:
	died.emit(self)
	queue_free()


func _rebuild_basic_attack_ability() -> void:

	_basic_attack_ability = AbilityData.new()
	_basic_attack_ability.ability_name = "Attack"
	_basic_attack_ability.ability_type = "Attack"
	_basic_attack_ability.cooldown = 1.0 / attack_speed if attack_speed > 0.0 else 1.0
	_basic_attack_ability.magnitude = damage


## Tweens the visual Body a short distance toward the target and back.
## No-op if this entity has no Body (e.g. a bare CombatEntity.new()).
func _play_attack_lunge(target_position: Vector2) -> void:

	if _body == null:
		return

	if _attack_tween != null and _attack_tween.is_valid():
		_attack_tween.kill()

	_body.position = Vector2.ZERO

	var direction: Vector2 = target_position - global_position
	direction = direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT

	var lunge_offset: Vector2 = direction * ATTACK_LUNGE_DISTANCE

	_attack_tween = create_tween()
	_attack_tween.tween_property(_body, "position", lunge_offset, ATTACK_LUNGE_DURATION * 0.5)
	_attack_tween.tween_property(_body, "position", Vector2.ZERO, ATTACK_LUNGE_DURATION * 0.5)


## Pushes this entity away from any other CombatEntity it's overlapping,
## scaled by how much they overlap. No-op if this entity has no
## SeparationArea. Runs continuously (not just during combat), so
## entities also spread out while walking together as a group.
func _apply_separation(delta: float) -> void:

	if _separation_area == null:
		return

	var push: Vector2 = Vector2.ZERO

	for area: Area2D in _separation_area.get_overlapping_areas():

		var other: Node = area.get_parent()

		if other == self or not (other is CombatEntity):
			continue

		var offset: Vector2 = global_position - other.global_position
		var distance: float = offset.length()

		if distance < 0.001:
			offset = Vector2(randf() - 0.5, randf() - 0.5)
			distance = 0.001

		var overlap: float = SEPARATION_RADIUS * 2.0 - distance

		if overlap > 0.0:
			push += offset.normalized() * overlap

	if push != Vector2.ZERO:
		global_position += push * SEPARATION_STRENGTH * delta * 0.01
