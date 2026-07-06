extends Resource
class_name TrapData

@export var trap_name : String

## Initial hit damage - applies once, either on an INSTANT trap's
## trigger roll, or the instant a PROJECTILE trap's arrow connects.
@export var damage : int = 5

## INSTANT traps only: chance (0.0-1.0) the trap fires when a hero
## enters the room. A miss deals no damage at all.
@export var trigger_chance : float = 1.0

## Traps like spikes or fire jets classically bypass armor entirely,
## unlike a monster's attack. Applies to the initial hit AND any DoT
## ticks below.
@export var ignores_armor : bool = true

@export var trap_type : GameEnums.TrapType = GameEnums.TrapType.INSTANT

## PROJECTILE traps only: damage-over-time applied after the initial
## hit (e.g. poison).
@export var tick_damage : int = 2
@export var tick_count : int = 5
@export var tick_interval : float = 1.0

## PROJECTILE traps only: how fast an arrow travels down the room, and
## how long each firing "slot" waits after its arrow is destroyed
## (hero OR wall) before firing its next one.
@export var projectile_speed : float = 260.0
@export var projectile_cooldown : float = 2.0

## PROJECTILE traps only: how many arrows this trap can have in flight
## at once, each firing independently on its own cooldown. The trap
## fires continuously for the whole wave once it starts - regardless
## of whether the party is anywhere near this room yet.
@export var max_concurrent_arrows : int = 1

@export var abilities : Array[String]

@export var icon : Texture2D
