extends Resource
class_name TrapData

@export var trap_name : String

@export var damage : int = 5

## Chance (0.0-1.0) the trap actually fires when a hero enters the room.
## A miss deals no damage at all - this is what lets a trap room be
## "risky but not guaranteed," distinct from a monster fight which
## always happens.
@export var trigger_chance : float = 1.0

## Traps like spikes or fire jets classically bypass armor entirely,
## unlike a monster's attack. This is the main mechanical distinction
## between trap resolution and combat.
@export var ignores_armor : bool = true

@export var abilities : Array[String]

@export var icon : Texture2D
