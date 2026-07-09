extends Resource
class_name BossData

## A biome's climax encounter. Fought automatically once the party has
## survived every room the Dungeon Lord built, on the biome's final
## wave - no card, no player placement. BiomeManager.current_biome.boss
## is where Dungeon.gd gets this from (see Dungeon._run_boss_encounter).

@export var boss_name : String
@export_multiline var description : String = ""

@export var max_health : int = 200
@export var damage : int = 12
@export var armor : int = 2
@export var attack_speed : float = 1.0

@export var is_melee : bool = true
@export var projectile_color : Color = Color.WHITE

@export var sprite : Texture2D

## Ordered phases - see BossPhaseData. Must contain at least one entry
## (phase 0) or the boss encounter is skipped entirely.
@export var phases : Array[BossPhaseData]

## Monsters present in the room from the very start, fighting alongside
## the boss (distinct from a phase's summons, which appear mid-fight).
## Empty by default - most bosses start the fight alone.
@export var starting_escort : Array[MonsterData]
