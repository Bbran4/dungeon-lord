extends Resource
class_name MonsterData

@export var monster_name : String

@export var max_health : int = 10

@export var damage : int = 2

@export var armor : int = 0

@export var attack_speed : float = 1.0

@export var abilities : Array[AbilityData]

@export var sprite : Texture2D

## Whether this monster steps forward to meet charging melee heroes
## partway when a room fight begins (see
## Dungeon._charge_melee_into_combat). Defaults true - all current
## monster content is melee.
@export var is_melee : bool = true
## Tint for this monster's ranged CombatProjectile visuals. Unused if
## is_melee is true.
@export var projectile_color : Color = Color.WHITE
