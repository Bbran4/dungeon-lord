extends Resource
class_name RoomData

@export var room_name : String
@export var cost : int = 50

@export_enum("Empty", "Monster", "Trap", "Boss", "Utility")
var room_type : String = "Monster"

@export var monster : MonsterData

## How many of `monster` this room fields as a group encounter (e.g. a
## Skeleton Den fielding 3 Skeletons). 1 = a single monster, same as
## before this field existed.
@export var monster_count : int = 1

@export var trap : TrapData

@export var health : int = 100

@export var upgrade_path : RoomData

@export var icon : Texture2D

@export_enum("Common", "Rare", "Epic", "Legendary")
var rarity : String = "Common"

## Utility rooms only - applied once when the party arrives here (see
## Dungeon._apply_utility_room). Defaults are no-ops, so these are
## harmless on any non-Utility room.
@export var heal_party_on_entry : bool = false

## Multiplies gold earned by the party for the REST of the wave -
## stacks multiplicatively if more than one utility room is passed.
@export var gold_multiplier : float = 1.0

## Multiplies damage taken from traps (both INSTANT and
## PROJECTILE/DoT) for the rest of the wave - e.g. 0.5 for poison
## resistance, or >1.0 as the cost side of a strong buff elsewhere.
@export var trap_damage_multiplier : float = 1.0
